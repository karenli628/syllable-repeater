# AI-Generate
#!/usr/bin/env python3
"""
make_release_zip.py — package unsigned macOS release app for Syllable Repeater.

The script intentionally fails closed before zipping: a release app must exist
and include the sidecar payload required by task 9.1/9.2. Packaging uses macOS
`ditto` to preserve app bundle metadata and symlinks.
"""

from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import subprocess
import sys


DEFAULT_APP = Path("app/build/macos/Build/Products/Release/syllable_repeater_app.app")
DEFAULT_OUTPUT_DIR = Path("dist")
DEFAULT_ZIP_NAME = "SyllableRepeater-macos-x86_64-unsigned.zip"
DEFAULT_DITTO = Path("/usr/bin/ditto")

REQUIRED_APP_PATHS = (
    Path("Contents/Info.plist"),
    Path("Contents/MacOS/syllable_repeater_app"),
    Path("Contents/Resources/sidecar/sidecar-manifest.json"),
    Path("Contents/Resources/sidecar/bin/ffmpeg"),
    Path("Contents/Resources/sidecar/bin/ffprobe"),
    Path("Contents/Resources/sidecar/bin/whisper-cli"),
    Path("Contents/Resources/sidecar/bin/demucs.cpp.main"),
    Path("Contents/Resources/sidecar/models/ggml-small.en.bin"),
    Path("Contents/Resources/sidecar/models/ggml-model-htdemucs-4s-f16.bin"),
    Path("Contents/Resources/sidecar/data/cmudict.dict"),
)


def validate_release_app(app_path: Path) -> list[str]:
    errors: list[str] = []
    if not app_path.exists():
        return [f"release app 不存在：{app_path}"]
    if not app_path.is_dir() or app_path.suffix != ".app":
        errors.append(f"release app 必須是 .app 目錄：{app_path}")

    for rel_path in REQUIRED_APP_PATHS:
        if not (app_path / rel_path).exists():
            errors.append(f"缺少必要檔案：{app_path / rel_path}")
    return errors


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def package_with_ditto(app_path: Path, zip_path: Path, ditto_path: Path) -> None:
    if not ditto_path.exists():
        raise RuntimeError(f"找不到 ditto：{ditto_path}")

    tmp_path = zip_path.with_suffix(zip_path.suffix + ".tmp")
    if tmp_path.exists():
        tmp_path.unlink()

    command = [
        str(ditto_path),
        "-c",
        "-k",
        "--sequesterRsrc",
        "--keepParent",
        str(app_path),
        str(tmp_path),
    ]
    subprocess.run(command, check=True)
    os.replace(tmp_path, zip_path)


def write_sha_file(zip_path: Path) -> Path:
    sha = sha256_file(zip_path)
    sha_path = zip_path.with_suffix(zip_path.suffix + ".sha256")
    sha_path.write_text(f"{sha}  {zip_path.name}\n", encoding="utf-8")
    return sha_path


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Package unsigned macOS release app into a Gatekeeper-ready zip.",
    )
    parser.add_argument("--app", type=Path, default=DEFAULT_APP)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--zip-name", default=DEFAULT_ZIP_NAME)
    parser.add_argument("--ditto", type=Path, default=DEFAULT_DITTO)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate inputs and print the planned output without creating a zip.",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    app_path = args.app.resolve()
    output_dir = args.output_dir.resolve()
    zip_path = output_dir / args.zip_name

    errors = validate_release_app(app_path)
    if errors:
        for error in errors:
            print(f"❌ {error}", file=sys.stderr)
        return 1

    print("=" * 60)
    print("Unsigned macOS release package")
    print("=" * 60)
    print(f"app：{app_path}")
    print(f"zip：{zip_path}")

    if args.dry_run:
        print("dry-run：✅ release app 結構完整，未產生 zip。")
        return 0

    output_dir.mkdir(parents=True, exist_ok=True)
    package_with_ditto(app_path, zip_path, args.ditto.resolve())
    sha_path = write_sha_file(zip_path)
    print(f"結果：✅ {zip_path}")
    print(f"SHA-256：{sha_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
