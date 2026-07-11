# AI-Generate
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "scripts" / "make_release_zip.py"


class MakeReleaseZipTest(unittest.TestCase):
    def test_dry_run_validates_release_app(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            app = _create_release_app(root)
            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "--app",
                    str(app),
                    "--output-dir",
                    str(root / "dist"),
                    "--dry-run",
                ],
                text=True,
                capture_output=True,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("dry-run", result.stdout)
            self.assertFalse((root / "dist").exists())

    def test_missing_sidecar_fails_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            app = root / "Bad.app"
            (app / "Contents" / "MacOS").mkdir(parents=True)
            (app / "Contents" / "Info.plist").write_text("plist", encoding="utf-8")
            (app / "Contents" / "MacOS" / "syllable_repeater_app").write_text(
                "bin",
                encoding="utf-8",
            )

            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "--app",
                    str(app),
                    "--output-dir",
                    str(root / "dist"),
                    "--dry-run",
                ],
                text=True,
                capture_output=True,
            )

            self.assertEqual(result.returncode, 1)
            self.assertIn("sidecar-manifest.json", result.stderr)

    def test_package_uses_ditto_and_writes_sha256(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            app = _create_release_app(root)
            fake_ditto = root / "fake_ditto.py"
            fake_ditto.write_text(
                "#!/usr/bin/env python3\n"
                "from pathlib import Path\n"
                "import sys\n"
                "Path(sys.argv[-1]).write_bytes(b'fake zip bytes')\n",
                encoding="utf-8",
            )
            os.chmod(fake_ditto, 0o755)

            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT),
                    "--app",
                    str(app),
                    "--output-dir",
                    str(root / "dist"),
                    "--zip-name",
                    "test.zip",
                    "--ditto",
                    str(fake_ditto),
                ],
                text=True,
                capture_output=True,
            )

            self.assertEqual(result.returncode, 0, result.stderr)
            zip_path = root / "dist" / "test.zip"
            sha_path = root / "dist" / "test.zip.sha256"
            self.assertEqual(zip_path.read_bytes(), b"fake zip bytes")
            self.assertIn("test.zip", sha_path.read_text(encoding="utf-8"))


def _create_release_app(root: Path) -> Path:
    app = root / "syllable_repeater_app.app"
    required = [
        "Contents/Info.plist",
        "Contents/MacOS/syllable_repeater_app",
        "Contents/Resources/sidecar/sidecar-manifest.json",
        "Contents/Resources/sidecar/bin/ffmpeg",
        "Contents/Resources/sidecar/bin/ffprobe",
        "Contents/Resources/sidecar/bin/whisper-cli",
        "Contents/Resources/sidecar/bin/demucs.cpp.main",
        "Contents/Resources/sidecar/models/ggml-small.en.bin",
        "Contents/Resources/sidecar/models/ggml-model-htdemucs-4s-f16.bin",
        "Contents/Resources/sidecar/data/cmudict.dict",
    ]
    for rel in required:
        path = app / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(rel, encoding="utf-8")
    return app


if __name__ == "__main__":
    unittest.main()
