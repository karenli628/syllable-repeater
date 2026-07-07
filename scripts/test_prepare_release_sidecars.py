#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# AI-Generate

import json
import os
import tempfile
import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import prepare_release_sidecars


class PrepareReleaseSidecarsTest(unittest.TestCase):
    def test_rejects_gpl_ffmpeg_build(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            ffmpeg = _fake_executable(
                root / "ffmpeg",
                "ffmpeg version fake\nconfiguration: --enable-shared --enable-gpl\n",
            )
            result = prepare_release_sidecars.main([
                "--ffmpeg",
                str(ffmpeg),
                "--ffprobe",
                str(_fake_ffmpeg(root / "ffprobe")),
                "--whisper-cli",
                str(_fake_executable(root / "whisper-cli", "whisper\n")),
                "--whisper-model",
                str(_file(root / "ggml-small.en.bin")),
                "--cmudict",
                str(_file(root / "cmudict.dict")),
                "--demucs-cli",
                str(_fake_executable(root / "demucs.cpp", "demucs\n")),
                "--demucs-model",
                str(_dir(root / "ggml-model-htdemucs")),
                "--license-manifest",
                str(_manifest(root / "license-manifest.json")),
                "--output-dir",
                str(root / "out"),
            ])

            self.assertEqual(1, result)
            self.assertFalse((root / "out/bin/ffmpeg").exists())

    def test_stages_release_layout_with_manifest(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            out = root / "out"
            result = prepare_release_sidecars.main([
                "--ffmpeg",
                str(_fake_ffmpeg(root / "ffmpeg")),
                "--ffprobe",
                str(_fake_ffmpeg(root / "ffprobe")),
                "--whisper-cli",
                str(_fake_executable(root / "whisper-cli", "whisper\n")),
                "--whisper-model",
                str(_file(root / "ggml-small.en.bin")),
                "--cmudict",
                str(_file(root / "cmudict.dict")),
                "--demucs-cli",
                str(_fake_executable(root / "demucs.cpp", "demucs\n")),
                "--demucs-model",
                str(_dir(root / "ggml-model-htdemucs")),
                "--license-manifest",
                str(_manifest(root / "license-manifest.json")),
                "--output-dir",
                str(out),
            ])

            self.assertEqual(0, result)
            self.assertTrue((out / "bin/ffmpeg").exists())
            self.assertTrue((out / "bin/ffprobe").exists())
            self.assertTrue((out / "bin/whisper-cli").exists())
            self.assertTrue((out / "bin/demucs.cpp").exists())
            self.assertTrue((out / "models/ggml-small.en.bin").exists())
            self.assertTrue((out / "models/ggml-model-htdemucs").is_dir())
            self.assertTrue((out / "data/cmudict.dict").exists())
            manifest = json.loads((out / "sidecar-manifest.json").read_text())
            self.assertEqual(1, manifest["schemaVersion"])
            self.assertEqual("Contents/Resources/sidecar", manifest["layout"])


def _fake_ffmpeg(path):
    return _fake_executable(
        path,
        "ffmpeg version fake\nconfiguration: --enable-shared --disable-gpl\n",
    )


def _fake_executable(path, output):
    path.write_text(f"#!/bin/sh\ncat <<'EOF'\n{output}EOF\n", encoding="utf-8")
    path.chmod(path.stat().st_mode | 0o755)
    return path


def _file(path):
    path.write_bytes(b"fixture")
    return path


def _dir(path):
    path.mkdir()
    (path / "model.bin").write_bytes(b"fixture")
    return path


def _manifest(path):
    path.write_text(
        json.dumps({
            "schemaVersion": 1,
            "components": [{
                "name": "FFmpeg release build",
                "license": "LGPL-2.1-or-later",
                "distribution": "bundled",
                "language": "C/C++",
                "linking": "dynamic",
            }],
        }),
        encoding="utf-8",
    )
    return path


if __name__ == "__main__":
    unittest.main()
