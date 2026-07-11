# AI-Generate
#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import hashlib
import io
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fetch_sidecar_artifacts


def valid_source():
    return {
        "url": "https://downloads.example.test/ffmpeg",
        "sha256": "a" * 64,
    }


def manifest_with(artifact):
    return {"schemaVersion": 1, "artifacts": [artifact]}


class FetchSidecarArtifactsTest(unittest.TestCase):
    def test_allows_lgpl_dynamic_artifact_contract(self):
        errors = fetch_sidecar_artifacts.validate_manifest(
            manifest_with({
                "name": "ffmpeg",
                "license": "LGPL-2.1-or-later",
                "linking": "dynamic",
                "dest": ".local-tools/release-sidecars/ffmpeg/bin/ffmpeg",
                "sources": [valid_source()],
            })
        )

        self.assertEqual([], errors)

    def test_rejects_download_without_sha256_pinning(self):
        errors = fetch_sidecar_artifacts.validate_manifest(
            manifest_with({
                "name": "ffmpeg",
                "license": "LGPL-2.1-or-later",
                "linking": "dynamic",
                "dest": ".local-tools/release-sidecars/ffmpeg/bin/ffmpeg",
                "sources": [{"url": "https://downloads.example.test/ffmpeg"}],
            })
        )

        self.assertIn("ffmpeg.sources[1]：缺少 sha256", errors)

    def test_rejects_non_https_source_url(self):
        source = valid_source()
        source["url"] = "http://downloads.example.test/ffmpeg"

        errors = fetch_sidecar_artifacts.validate_manifest(
            manifest_with({
                "name": "ffmpeg",
                "license": "LGPL-2.1-or-later",
                "linking": "dynamic",
                "dest": ".local-tools/release-sidecars/ffmpeg/bin/ffmpeg",
                "sources": [source],
            })
        )

        self.assertIn("ffmpeg.sources[1]：url 必須使用 https", errors)

    def test_rejects_cert_none_or_tls_verification_bypass(self):
        source = valid_source()
        source["verify_tls"] = False

        errors = fetch_sidecar_artifacts.validate_manifest(
            manifest_with({
                "name": "ffmpeg",
                "license": "LGPL-2.1-or-later",
                "linking": "dynamic",
                "dest": ".local-tools/release-sidecars/ffmpeg/bin/ffmpeg",
                "sources": [source],
            })
        )

        self.assertIn(
            "ffmpeg.sources[0].verify_tls：禁止 TLS/CERT 驗證降級",
            errors,
        )

    def test_rejects_gpl_or_static_lgpl_artifact_contract(self):
        gpl_errors = fetch_sidecar_artifacts.validate_manifest(
            manifest_with({
                "name": "bad-ffmpeg",
                "license": "GPL-3.0-only",
                "linking": "dynamic",
                "dest": ".local-tools/release-sidecars/ffmpeg/bin/ffmpeg",
                "sources": [valid_source()],
            })
        )
        static_errors = fetch_sidecar_artifacts.validate_manifest(
            manifest_with({
                "name": "static-ffmpeg",
                "license": "LGPL-2.1-or-later",
                "linking": "static",
                "dest": ".local-tools/release-sidecars/ffmpeg/bin/ffmpeg",
                "sources": [valid_source()],
            })
        )

        self.assertIn("bad-ffmpeg：禁止授權 GPL-3.0-only", gpl_errors)
        self.assertIn(
            "static-ffmpeg：LGPL artifact 必須宣告 linking=dynamic",
            static_errors,
        )

    def test_allows_demucs_manual_build_contract(self):
        errors = fetch_sidecar_artifacts.validate_manifest(
            manifest_with({
                "name": "demucs.cpp.main",
                "license": "MIT",
                "linking": "n/a",
                "dest": ".local-tools/demucs.cpp/build/demucs.cpp.main",
                "manualBuild": {
                    "sourceUrl": "https://github.com/sevagh/demucs.cpp",
                    "sourceCommit": "84e62f07ff77c5058a3493f7f9702cde606dae76",
                    "expectedLocalPath":
                        ".local-tools/demucs.cpp/build/demucs.cpp.main",
                    "commands": ["build upstream demucs.cpp.main for x86_64"],
                },
            })
        )

        self.assertEqual([], errors)

    def test_rejects_manual_build_without_source_pin(self):
        errors = fetch_sidecar_artifacts.validate_manifest(
            manifest_with({
                "name": "demucs.cpp.main",
                "license": "MIT",
                "linking": "n/a",
                "dest": ".local-tools/demucs.cpp/build/demucs.cpp.main",
                "manualBuild": {
                    "sourceUrl": "https://github.com/sevagh/demucs.cpp",
                    "expectedLocalPath":
                        ".local-tools/demucs.cpp/build/demucs.cpp.main",
                    "commands": ["build upstream demucs.cpp.main for x86_64"],
                },
            })
        )

        self.assertIn(
            "demucs.cpp.main.manualBuild：缺少 sourceSha256 或 sourceCommit",
            errors,
        )

    def test_inventory_and_prepare_command_use_official_demucs_cli_name(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            paths = {
                "RELEASE_FFMPEG_PATH": root / "ffmpeg",
                "RELEASE_FFPROBE_PATH": root / "ffprobe",
                "WHISPER_CLI_PATH": root / "whisper-cli",
                "WHISPER_MODEL_PATH": root / "ggml-small.en.bin",
                "CMUDICT_PATH": root / "cmudict.dict",
                "DEMUCS_CLI_PATH": root / "demucs.cpp.main",
                "DEMUCS_MODEL_PATH":
                    root / "ggml-model-htdemucs-4s-f16.bin",
            }
            for path in paths.values():
                Path(path).write_bytes(b"fixture")

            env = {k: str(v) for k, v in paths.items()}
            statuses = fetch_sidecar_artifacts.collect_inventory(env)
            command = fetch_sidecar_artifacts.build_prepare_command(
                statuses,
                dry_run=True,
                env=env,
            )

            self.assertTrue(all(status.exists for status in statuses))
            self.assertIn("--demucs-cli", command)
            self.assertIn(str(paths["DEMUCS_CLI_PATH"]), command)
            self.assertIn("--dry-run", command)

    def test_prepare_command_includes_default_ffmpeg_lib_dir_when_present(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            ffmpeg_lib_dir = root / ".local-tools/release-sidecars/ffmpeg/lib"
            ffmpeg_lib_dir.mkdir(parents=True)
            env = {
                "RELEASE_FFMPEG_PATH": str(root / "ffmpeg"),
                "RELEASE_FFPROBE_PATH": str(root / "ffprobe"),
                "WHISPER_CLI_PATH": str(root / "whisper-cli"),
                "WHISPER_MODEL_PATH": str(root / "ggml-small.en.bin"),
                "CMUDICT_PATH": str(root / "cmudict.dict"),
                "DEMUCS_CLI_PATH": str(root / "demucs.cpp.main"),
                "DEMUCS_MODEL_PATH":
                    str(root / "ggml-model-htdemucs-4s-f16.bin"),
            }
            original_root = fetch_sidecar_artifacts.ROOT
            try:
                fetch_sidecar_artifacts.ROOT = root
                for value in env.values():
                    Path(value).write_bytes(b"fixture")
                statuses = fetch_sidecar_artifacts.collect_inventory(env)
                command = fetch_sidecar_artifacts.build_prepare_command(
                    statuses,
                    dry_run=True,
                    env=env,
                )
            finally:
                fetch_sidecar_artifacts.ROOT = original_root

            self.assertIn("--ffmpeg-lib-dir", command)
            self.assertIn(str(ffmpeg_lib_dir), command)

    def test_download_resume_uses_binary_append_mode(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            dest = root / "model.bin"
            cache_dir = root / "cache"
            cache_dir.mkdir()
            part = cache_dir / "model.bin.part"
            part.write_bytes(b"hello ")
            expected = hashlib.sha256(b"hello world").hexdigest()

            class Response(io.BytesIO):
                status = 206

                def __enter__(self):
                    return self

                def __exit__(self, exc_type, exc, traceback):
                    return False

                def getcode(self):
                    return self.status

            with mock.patch(
                "fetch_sidecar_artifacts.urlopen",
                return_value=Response(b"world"),
            ):
                fetch_sidecar_artifacts._download_and_verify(
                    url="https://downloads.example.test/model.bin",
                    expected_sha256=expected,
                    dest=dest,
                    cache_dir=cache_dir,
                )

            self.assertEqual(b"hello world", dest.read_bytes())


if __name__ == "__main__":
    unittest.main()
