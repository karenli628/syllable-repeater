# AI-Generate
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Fetch and inventory release sidecar artifacts.

This script is the acquisition gate before scripts/prepare_release_sidecars.py.
It is intentionally conservative for M9 / CT-09:
  * every downloadable artifact must declare URL + SHA-256 + license;
  * every download must use HTTPS with normal certificate verification;
  * FFmpeg/ffprobe artifacts must be LGPL dynamic/shared, never GPL/nonfree;
  * manual-build artifacts must pin their source archive SHA-256 or git commit;
  * demucs.cpp can be declared as a manual-build artifact when no official
    binary is approved, but the source pin and expected local output are still
    checked.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import ssl
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from urllib.error import URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ARTIFACT_MANIFEST = (
    ROOT
    / "spec-syllable-repeater/requirements/"
    / "syllable-practice-macos-v1_20260704/release/sidecar-artifacts.json"
)

SHA256_RE = re.compile(r"^[0-9a-fA-F]{64}$")
GIT_COMMIT_RE = re.compile(r"^[0-9a-fA-F]{40}$")
BANNED_LICENSE_TOKENS = (
    "GPL",
    "AGPL",
    "CC-BY-NC",
    "CC BY-NC",
    "NON-COMMERCIAL",
    "NONCOMMERCIAL",
    "RESEARCH-ONLY",
    "RESEARCH ONLY",
)
INSECURE_TLS_KEYS = {
    "allowInsecure",
    "allow_insecure",
    "certNone",
    "cert_none",
    "sslCertNone",
    "ssl_cert_none",
    "tlsVerify",
    "tls_verify",
    "verifyTls",
    "verify_tls",
}


class FetchError(Exception):
    pass


@dataclass(frozen=True)
class ExpectedArtifact:
    label: str
    path: Path
    prepare_arg: str
    env_var: str
    required: bool = True
    executable: bool = False


@dataclass(frozen=True)
class ArtifactStatus:
    artifact: ExpectedArtifact
    exists: bool


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)

    if args.print_template:
        print(json.dumps(_template_manifest(), indent=2, ensure_ascii=False))
        return 0

    try:
        if args.manifest.exists():
            manifest = _load_manifest(args.manifest)
            errors = validate_manifest(manifest)
            if errors:
                raise FetchError("artifact manifest validation failed:\n" + "\n".join(errors))
            if not args.inventory_only:
                fetch_artifacts(manifest, args.cache_dir)
        elif args.manifest != DEFAULT_ARTIFACT_MANIFEST:
            raise FetchError(f"artifact manifest not found: {args.manifest}")
        else:
            print(
                "[sidecar-fetch] source URL selection is pending human "
                f"confirmation; no manifest found at {args.manifest}"
            )

        statuses = collect_inventory(os.environ)
        _print_inventory(statuses)
        missing = [s for s in statuses if s.artifact.required and not s.exists]
        command = build_prepare_command(statuses, dry_run=args.run_prepare_dry_run)

        if missing:
            _print_manual_next_steps()
            return 1

        print("[sidecar-fetch] prepare command:")
        print(" ".join(command))

        if args.run_prepare_dry_run or args.run_prepare:
            if args.run_prepare:
                command = build_prepare_command(statuses, dry_run=False)
            return subprocess.run(command, cwd=ROOT, check=False).returncode
        return 0
    except FetchError as exc:
        print(f"❌ {exc}", file=sys.stderr)
        return 1


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Fetch/inventory release sidecar artifacts with SHA-256 pinning.",
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=DEFAULT_ARTIFACT_MANIFEST,
        help="Artifact manifest with URL + SHA-256 + license triples.",
    )
    parser.add_argument(
        "--cache-dir",
        type=Path,
        default=ROOT / ".local-tools/release-artifact-cache",
    )
    parser.add_argument("--inventory-only", action="store_true")
    parser.add_argument("--print-template", action="store_true")
    parser.add_argument("--run-prepare-dry-run", action="store_true")
    parser.add_argument("--run-prepare", action="store_true")
    return parser


def validate_manifest(manifest: dict) -> list[str]:
    errors: list[str] = []
    if manifest.get("schemaVersion") != 1:
        errors.append("schemaVersion 必須為 1")

    artifacts = manifest.get("artifacts")
    if not isinstance(artifacts, list) or not artifacts:
        errors.append("artifacts 必須是非空陣列")
        return errors

    for index, artifact in enumerate(artifacts, start=1):
        label = str(artifact.get("name") or f"artifact #{index}")
        errors.extend(_validate_no_insecure_tls_switches(label, artifact))
        license_id = str(artifact.get("license", "")).strip()
        linking = str(artifact.get("linking", "")).strip().lower()
        dest = str(artifact.get("dest", "")).strip()
        sources = artifact.get("sources", [])
        manual_build = artifact.get("manualBuild")

        if not str(artifact.get("name", "")).strip():
            errors.append(f"{label}：缺少 name")
        if not license_id:
            errors.append(f"{label}：缺少 license")
        elif _is_banned_license(license_id):
            errors.append(f"{label}：禁止授權 {license_id}")
        if _is_lgpl(license_id) and linking != "dynamic":
            errors.append(f"{label}：LGPL artifact 必須宣告 linking=dynamic")
        if not dest:
            errors.append(f"{label}：缺少 dest")
        else:
            errors.extend(_validate_relative_repo_path(label, dest, "dest"))

        if sources:
            if not isinstance(sources, list):
                errors.append(f"{label}：sources 必須是陣列")
            else:
                for source_index, source in enumerate(sources, start=1):
                    errors.extend(_validate_source(label, source_index, source))
        elif manual_build:
            errors.extend(_validate_manual_build(label, manual_build))
        else:
            errors.append(f"{label}：必須提供 sources 或 manualBuild")

    return errors


def _validate_source(label: str, source_index: int, source: dict) -> list[str]:
    errors: list[str] = []
    prefix = f"{label}.sources[{source_index}]"
    if not isinstance(source, dict):
        return [f"{prefix}：必須是物件"]
    errors.extend(_validate_no_insecure_tls_switches(prefix, source))

    url = str(source.get("url", "")).strip()
    sha256 = str(source.get("sha256", "")).strip()
    if not url:
        errors.append(f"{prefix}：缺少 url")
    elif urlparse(url).scheme != "https":
        errors.append(f"{prefix}：url 必須使用 https")
    if not sha256:
        errors.append(f"{prefix}：缺少 sha256")
    elif not SHA256_RE.match(sha256) or set(sha256) == {"0"}:
        errors.append(f"{prefix}：sha256 必須是 64 位十六進位且不可為 placeholder")
    return errors


def _validate_manual_build(label: str, manual_build: dict) -> list[str]:
    errors: list[str] = []
    if not isinstance(manual_build, dict):
        return [f"{label}.manualBuild：必須是物件"]
    errors.extend(_validate_no_insecure_tls_switches(f"{label}.manualBuild", manual_build))

    source_url = str(manual_build.get("sourceUrl", "")).strip()
    source_sha256 = str(manual_build.get("sourceSha256", "")).strip()
    source_commit = str(manual_build.get("sourceCommit", "")).strip()
    expected_local_path = str(manual_build.get("expectedLocalPath", "")).strip()
    commands = manual_build.get("commands")

    if not source_url:
        errors.append(f"{label}.manualBuild：缺少 sourceUrl")
    elif urlparse(source_url).scheme != "https":
        errors.append(f"{label}.manualBuild：sourceUrl 必須使用 https")
    if not source_sha256 and not source_commit:
        errors.append(f"{label}.manualBuild：缺少 sourceSha256 或 sourceCommit")
    if source_sha256 and (
        not SHA256_RE.match(source_sha256) or set(source_sha256) == {"0"}
    ):
        errors.append(
            f"{label}.manualBuild：sourceSha256 必須是 64 位十六進位且不可為 placeholder"
        )
    if source_commit and not GIT_COMMIT_RE.match(source_commit):
        errors.append(
            f"{label}.manualBuild：sourceCommit 必須是 40 位 git commit hash"
        )
    if not expected_local_path:
        errors.append(f"{label}.manualBuild：缺少 expectedLocalPath")
    else:
        errors.extend(
            _validate_relative_repo_path(
                f"{label}.manualBuild",
                expected_local_path,
                "expectedLocalPath",
            )
        )
    if not isinstance(commands, list) or not commands:
        errors.append(f"{label}.manualBuild：commands 必須是非空陣列")
    return errors


def _validate_no_insecure_tls_switches(label: str, value: dict) -> list[str]:
    errors: list[str] = []
    for key, nested in value.items():
        if key in INSECURE_TLS_KEYS and nested is not True:
            errors.append(f"{label}.{key}：禁止 TLS/CERT 驗證降級")
        if isinstance(nested, dict):
            errors.extend(_validate_no_insecure_tls_switches(f"{label}.{key}", nested))
        elif isinstance(nested, list):
            for index, item in enumerate(nested):
                if isinstance(item, dict):
                    errors.extend(
                        _validate_no_insecure_tls_switches(
                            f"{label}.{key}[{index}]",
                            item,
                        )
                    )
    return errors


def _validate_relative_repo_path(label: str, value: str, field: str) -> list[str]:
    path = Path(value)
    if path.is_absolute() or ".." in path.parts:
        return [f"{label}.{field}：必須是 repo 內相對路徑"]
    return []


def fetch_artifacts(manifest: dict, cache_dir: Path) -> None:
    cache_dir.mkdir(parents=True, exist_ok=True)
    for artifact in manifest["artifacts"]:
        name = artifact["name"]
        if artifact.get("manualBuild"):
            _print_manual_artifact(name, artifact["manualBuild"])
            continue
        dest = _resolve_repo_path(artifact["dest"])
        sources = artifact["sources"]
        last_error: str | None = None
        for source in sources:
            try:
                _download_and_verify(
                    url=source["url"],
                    expected_sha256=source["sha256"].lower(),
                    dest=dest,
                    cache_dir=cache_dir,
                )
                print(f"[sidecar-fetch] fetched {name}: {dest}")
                last_error = None
                break
            except FetchError as exc:
                last_error = str(exc)
                print(f"[sidecar-fetch] source failed for {name}: {last_error}")
        if last_error:
            raise FetchError(f"{name} download failed: {last_error}")


def collect_inventory(env: dict[str, str]) -> list[ArtifactStatus]:
    return [
        ArtifactStatus(artifact, artifact.path.exists())
        for artifact in expected_artifacts(env)
    ]


def expected_artifacts(env: dict[str, str]) -> list[ExpectedArtifact]:
    release_root = ROOT / ".local-tools/release-sidecars"
    return [
        ExpectedArtifact(
            "ffmpeg LGPL shared binary",
            Path(env.get("RELEASE_FFMPEG_PATH", release_root / "ffmpeg/bin/ffmpeg")),
            "--ffmpeg",
            "RELEASE_FFMPEG_PATH",
            executable=True,
        ),
        ExpectedArtifact(
            "ffprobe LGPL shared binary",
            Path(env.get("RELEASE_FFPROBE_PATH", release_root / "ffmpeg/bin/ffprobe")),
            "--ffprobe",
            "RELEASE_FFPROBE_PATH",
            executable=True,
        ),
        ExpectedArtifact(
            "whisper-cli",
            Path(
                env.get(
                    "WHISPER_CLI_PATH",
                    ROOT / ".local-tools/whisper.cpp/build/bin/whisper-cli",
                )
            ),
            "--whisper-cli",
            "WHISPER_CLI_PATH",
            executable=True,
        ),
        ExpectedArtifact(
            "Whisper small.en model",
            Path(
                env.get(
                    "WHISPER_MODEL_PATH",
                    ROOT / ".local-tools/whisper.cpp/models/ggml-small.en.bin",
                )
            ),
            "--whisper-model",
            "WHISPER_MODEL_PATH",
        ),
        ExpectedArtifact(
            "CMUdict",
            Path(env.get("CMUDICT_PATH", ROOT / ".local-tools/cmudict/cmudict.dict")),
            "--cmudict",
            "CMUDICT_PATH",
        ),
        ExpectedArtifact(
            "demucs.cpp.main",
            Path(
                env.get(
                    "DEMUCS_CLI_PATH",
                    ROOT / ".local-tools/demucs.cpp/build/demucs.cpp.main",
                )
            ),
            "--demucs-cli",
            "DEMUCS_CLI_PATH",
            executable=True,
        ),
        ExpectedArtifact(
            "htdemucs 4-source model",
            Path(
                env.get(
                    "DEMUCS_MODEL_PATH",
                    ROOT
                    / ".local-tools/demucs.cpp/ggml-demucs/"
                    / "ggml-model-htdemucs-4s-f16.bin",
                )
            ),
            "--demucs-model",
            "DEMUCS_MODEL_PATH",
        ),
    ]


def build_prepare_command(
    statuses: list[ArtifactStatus],
    *,
    dry_run: bool,
    env: dict[str, str] | None = None,
) -> list[str]:
    env = env or os.environ
    release_root = ROOT / ".local-tools/release-sidecars"
    command = [sys.executable, "scripts/prepare_release_sidecars.py"]
    for status in statuses:
        command.extend([status.artifact.prepare_arg, str(status.artifact.path)])

    optional_dirs = [
        (
            "--ffmpeg-lib-dir",
            env.get(
                "RELEASE_FFMPEG_LIB_DIR",
                str(release_root / "ffmpeg/lib"),
            ),
        ),
        (
            "--whisper-lib-dir",
            env.get(
                "WHISPER_LIB_DIR",
                str(ROOT / ".local-tools/whisper.cpp/build/bin"),
            ),
        ),
        ("--demucs-lib-dir", env.get("DEMUCS_LIB_DIR")),
    ]
    for flag, value in optional_dirs:
        if value and Path(value).exists():
            command.extend([flag, value])
    if dry_run:
        command.append("--dry-run")
    return command


def _download_and_verify(
    *,
    url: str,
    expected_sha256: str,
    dest: Path,
    cache_dir: Path,
) -> None:
    if dest.exists() and _sha256(dest) == expected_sha256:
        return

    part = cache_dir / f"{dest.name}.part"
    part.parent.mkdir(parents=True, exist_ok=True)
    headers = {}
    mode = "wb"
    resume_from = part.stat().st_size if part.exists() else 0
    if resume_from:
        headers["Range"] = f"bytes={resume_from}-"

    request = Request(url, headers=headers)
    context = ssl.create_default_context()
    try:
        with urlopen(request, timeout=60, context=context) as response:
            status = getattr(response, "status", response.getcode())
            if resume_from and status == 206:
                mode = "ab"
            elif resume_from:
                mode = "wb"
            with part.open(mode) as output:
                while True:
                    chunk = response.read(1024 * 1024)
                    if not chunk:
                        break
                    output.write(chunk)
    except URLError as exc:
        raise FetchError(f"download failed for {url}: {exc}") from exc

    actual = _sha256(part)
    if actual != expected_sha256:
        raise FetchError(
            f"sha256 mismatch for {url}: expected {expected_sha256}, got {actual}"
        )
    dest.parent.mkdir(parents=True, exist_ok=True)
    part.replace(dest)
    if dest.name in {"ffmpeg", "ffprobe", "whisper-cli", "demucs.cpp.main"}:
        dest.chmod(dest.stat().st_mode | 0o755)


def _load_manifest(path: Path) -> dict:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        raise FetchError(f"cannot read artifact manifest: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise FetchError(f"artifact manifest is not valid JSON: {exc}") from exc


def _template_manifest() -> dict:
    return {
        "schemaVersion": 1,
        "artifacts": [
            {
                "name": "ffmpeg",
                "license": "LGPL-2.1-or-later",
                "linking": "dynamic",
                "dest": ".local-tools/release-sidecars/ffmpeg/bin/ffmpeg",
                "sources": [
                    {
                        "url": "https://example.invalid/ffmpeg-lgpl-shared-x86_64",
                        "sha256": "<64 lowercase hex chars>",
                    }
                ],
            },
            {
                "name": "demucs.cpp.main",
                "license": "MIT",
                "linking": "n/a",
                "dest": ".local-tools/demucs.cpp/build/demucs.cpp.main",
                "manualBuild": {
                    "sourceUrl": "https://github.com/sevagh/demucs.cpp",
                    "sourceCommit": "<40 hex git commit>",
                    "expectedLocalPath": ".local-tools/demucs.cpp/build/demucs.cpp.main",
                    "commands": [
                        "git clone https://github.com/sevagh/demucs.cpp .local-tools/demucs.cpp/src",
                        "build demucs.cpp.main for macOS x86_64 per upstream README",
                    ],
                },
            },
        ],
    }


def _print_inventory(statuses: list[ArtifactStatus]) -> None:
    print("=" * 60)
    print("Release sidecar artifact inventory")
    print("=" * 60)
    for status in statuses:
        marker = "✅" if status.exists else "❌"
        print(f"{marker} {status.artifact.label}: {status.artifact.path}")


def _print_manual_artifact(name: str, manual_build: dict) -> None:
    print(f"[sidecar-fetch] {name} has no approved binary source yet.")
    print(f"[sidecar-fetch] source: {manual_build['sourceUrl']}")
    print("[sidecar-fetch] build/check locally:")
    for command in manual_build["commands"]:
        print(f"  - {command}")


def _print_manual_next_steps() -> None:
    print("[sidecar-fetch] missing release artifacts remain.")
    print("[sidecar-fetch] next steps:")
    print("  1. choose and confirm LGPL shared FFmpeg/ffprobe source URLs + SHA-256;")
    print("  2. build demucs.cpp.main locally if no approved binary source exists;")
    print("  3. rerun this script, then scripts/prepare_release_sidecars.py --dry-run.")


def _is_lgpl(license_id: str) -> bool:
    return license_id.startswith("LGPL-")


def _is_banned_license(license_id: str) -> bool:
    normalized = license_id.upper()
    if normalized.startswith("GPL") or normalized.startswith("AGPL"):
        return True
    softer_tokens = [token for token in BANNED_LICENSE_TOKENS if token not in {"GPL", "AGPL"}]
    return any(token in normalized for token in softer_tokens)


def _resolve_repo_path(value: str) -> Path:
    path = (ROOT / value).resolve()
    try:
        path.relative_to(ROOT)
    except ValueError as exc:
        raise FetchError(f"dest escapes repository: {value}") from exc
    return path


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


if __name__ == "__main__":
    sys.exit(main())
