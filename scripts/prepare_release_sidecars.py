#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# AI-Generate
"""
Prepare the macOS release sidecar bundle.

This script stages sidecar binaries into:
  app/macos/Runner/Resources/sidecar/

It is intentionally fail-closed for M9 / CT-09:
  * FFmpeg/ffprobe must not be a GPL or nonfree build.
  * FFmpeg/ffprobe must be a shared/dynamic build.
  * The release license manifest must pass before files are copied.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import stat
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT_DIR = ROOT / "app/macos/Runner/Resources/sidecar"
DEFAULT_LICENSE_MANIFEST = (
    ROOT
    / "spec-syllable-repeater/requirements/"
    / "syllable-practice-macos-v1_20260704/release/license-manifest.json"
)


class BundleError(Exception):
    pass


def main(argv: list[str] | None = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)

    try:
        plan = _build_plan(args)
        _validate_plan(plan, args.license_manifest)
        if args.dry_run:
            _print_plan(plan)
            return 0
        _stage(plan)
        _print_plan(plan)
        return 0
    except BundleError as exc:
        print(f"❌ {exc}", file=sys.stderr)
        return 1


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Stage release sidecars for Syllable Repeater macOS.",
    )
    parser.add_argument("--ffmpeg", required=True, type=Path)
    parser.add_argument("--ffprobe", required=True, type=Path)
    parser.add_argument("--whisper-cli", required=True, type=Path)
    parser.add_argument("--whisper-model", required=True, type=Path)
    parser.add_argument("--cmudict", required=True, type=Path)
    parser.add_argument("--demucs-cli", required=True, type=Path)
    parser.add_argument("--demucs-model", required=True, type=Path)
    parser.add_argument("--ffmpeg-lib-dir", type=Path)
    parser.add_argument("--whisper-lib-dir", type=Path)
    parser.add_argument("--demucs-lib-dir", type=Path)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument(
        "--license-manifest",
        type=Path,
        default=DEFAULT_LICENSE_MANIFEST,
    )
    parser.add_argument("--dry-run", action="store_true")
    return parser


def _build_plan(args: argparse.Namespace) -> dict:
    output_dir = args.output_dir.resolve()
    whisper_lib_dir = args.whisper_lib_dir or args.whisper_cli.parent
    return {
        "output_dir": output_dir,
        "files": [
            _entry("ffmpeg", args.ffmpeg, output_dir / "bin/ffmpeg", "bin"),
            _entry("ffprobe", args.ffprobe, output_dir / "bin/ffprobe", "bin"),
            _entry(
                "whisper-cli",
                args.whisper_cli,
                output_dir / "bin/whisper-cli",
                "bin",
            ),
            _entry(
                "whisper-small.en-model",
                args.whisper_model,
                output_dir / "models/ggml-small.en.bin",
                "model",
            ),
            _entry(
                "cmudict",
                args.cmudict,
                output_dir / "data/cmudict.dict",
                "data",
            ),
            _entry(
                "demucs.cpp",
                args.demucs_cli,
                output_dir / "bin/demucs.cpp",
                "bin",
            ),
            _entry(
                "demucs-model",
                args.demucs_model,
                output_dir / "models/ggml-model-htdemucs",
                "model",
            ),
        ],
        "lib_dirs": [
            p for p in [args.ffmpeg_lib_dir, whisper_lib_dir, args.demucs_lib_dir] if p
        ],
    }


def _entry(label: str, source: Path, dest: Path, kind: str) -> dict:
    return {
        "label": label,
        "source": source.resolve(),
        "dest": dest,
        "kind": kind,
    }


def _validate_plan(plan: dict, license_manifest: Path) -> None:
    _run_license_gate(license_manifest)
    errors = []
    for entry in plan["files"]:
        source = entry["source"]
        if not source.exists():
            errors.append(f"{entry['label']} not found: {source}")

    for lib_dir in plan["lib_dirs"]:
        if not lib_dir.exists():
            errors.append(f"library directory not found: {lib_dir}")

    if errors:
        raise BundleError("\n".join(errors))

    _validate_ffmpeg(plan["files"][0]["source"], "ffmpeg")
    _validate_ffmpeg(plan["files"][1]["source"], "ffprobe")


def _run_license_gate(license_manifest: Path) -> None:
    checker = ROOT / "scripts/check_licenses.py"
    result = subprocess.run(
        [sys.executable, str(checker), str(license_manifest)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if result.returncode != 0:
        raise BundleError(
            "license manifest gate failed before sidecar staging:\n"
            f"{result.stdout}"
        )


def _validate_ffmpeg(executable: Path, label: str) -> None:
    result = subprocess.run(
        [str(executable), "-version"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    if result.returncode != 0:
        raise BundleError(f"{label} -version failed:\n{result.stdout}")

    output = result.stdout
    lowered = output.lower()
    if "--enable-gpl" in lowered or "--enable-nonfree" in lowered:
        raise BundleError(
            f"{label} is not release-safe: GPL/nonfree flags found in -version"
        )
    if "configuration:" in lowered and "--enable-shared" not in lowered:
        raise BundleError(f"{label} must be a shared/dynamic FFmpeg build")


def _stage(plan: dict) -> None:
    output_dir = plan["output_dir"]
    _clean_output(output_dir)
    staged = []

    for entry in plan["files"]:
        source = entry["source"]
        dest = entry["dest"]
        if source.is_dir():
            shutil.copytree(source, dest)
        else:
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, dest)
            if entry["kind"] == "bin":
                _make_executable(dest)
                _patch_macho_rpath(dest)
        staged.append(_manifest_entry(entry["label"], dest))

    for lib_dir in plan["lib_dirs"]:
        for dylib in sorted(lib_dir.glob("*.dylib")):
            dest = output_dir / "lib" / dylib.name
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(dylib, dest)
            staged.append(_manifest_entry(f"lib:{dylib.name}", dest))

    _write_manifest(output_dir, staged)


def _clean_output(output_dir: Path) -> None:
    for child in ("bin", "lib", "models", "data", "licenses"):
        path = output_dir / child
        if path.exists():
            shutil.rmtree(path)
    manifest = output_dir / "sidecar-manifest.json"
    if manifest.exists():
        manifest.unlink()


def _make_executable(path: Path) -> None:
    mode = path.stat().st_mode
    path.chmod(mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def _patch_macho_rpath(path: Path) -> None:
    if not shutil.which("install_name_tool") or not _is_macho(path):
        return
    rpaths = _macho_rpaths(path)
    release_rpath = "@executable_path/../lib"
    for rpath in rpaths:
        if ".local-tools" in rpath or rpath.startswith("/Users/"):
            subprocess.run(
                ["install_name_tool", "-delete_rpath", rpath, str(path)],
                check=False,
            )
    if release_rpath not in rpaths:
        subprocess.run(
            ["install_name_tool", "-add_rpath", release_rpath, str(path)],
            check=False,
        )


def _is_macho(path: Path) -> bool:
    result = subprocess.run(
        ["file", str(path)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    return "Mach-O" in result.stdout


def _macho_rpaths(path: Path) -> list[str]:
    result = subprocess.run(
        ["otool", "-l", str(path)],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    lines = result.stdout.splitlines()
    rpaths = []
    for index, line in enumerate(lines):
        if line.strip() == "cmd LC_RPATH" and index + 2 < len(lines):
            maybe_path = lines[index + 2].strip()
            if maybe_path.startswith("path "):
                value = maybe_path[len("path "):]
                if " (offset" in value:
                    value = value.split(" (offset", 1)[0]
                rpaths.append(value)
    return rpaths


def _manifest_entry(label: str, path: Path) -> dict:
    if path.is_dir():
        files = [p for p in path.rglob("*") if p.is_file()]
        size = sum(p.stat().st_size for p in files)
        digest = _hash_directory(path)
    else:
        size = path.stat().st_size
        digest = _sha256(path)
    return {
        "label": label,
        "path": str(path),
        "sizeBytes": size,
        "sha256": digest,
    }


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _hash_directory(path: Path) -> str:
    digest = hashlib.sha256()
    for file_path in sorted(p for p in path.rglob("*") if p.is_file()):
        digest.update(str(file_path.relative_to(path)).encode("utf-8"))
        digest.update(b"\0")
        digest.update(_sha256(file_path).encode("ascii"))
        digest.update(b"\0")
    return digest.hexdigest()


def _write_manifest(output_dir: Path, entries: list[dict]) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    manifest = {
        "schemaVersion": 1,
        "layout": "Contents/Resources/sidecar",
        "entries": entries,
    }
    (output_dir / "sidecar-manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def _print_plan(plan: dict) -> None:
    print("=" * 60)
    print("Release sidecar staging plan")
    print("=" * 60)
    print(f"output: {plan['output_dir']}")
    for entry in plan["files"]:
        print(f"- {entry['label']}: {entry['source']} -> {entry['dest']}")
    for lib_dir in plan["lib_dirs"]:
        print(f"- dylibs: {lib_dir}/*.dylib -> {plan['output_dir'] / 'lib'}")


if __name__ == "__main__":
    sys.exit(main())
