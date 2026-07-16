#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# AI-Generate

import unittest
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
from check_licenses import validate_manifest


def manifest_with(component):
    return {"schemaVersion": 1, "components": [component]}


class CheckLicensesTest(unittest.TestCase):
    def test_allows_current_release_manifest_shape(self):
        errors = validate_manifest(manifest_with({
            "name": "ffmpeg",
            "license": "LGPL-2.1-or-later",
            "distribution": "bundled",
            "language": "C",
            "linking": "dynamic",
        }))

        self.assertEqual([], errors)

    def test_rejects_gpl_dependency(self):
        errors = validate_manifest(manifest_with({
            "name": "bad-audio-codec",
            "license": "GPL-3.0-only",
            "distribution": "bundled",
            "language": "C",
            "linking": "dynamic",
        }))

        self.assertIn("bad-audio-codec：禁止授權 GPL-3.0-only", errors)

    def test_rejects_plain_gpl_dependency(self):
        errors = validate_manifest(manifest_with({
            "name": "plain-gpl-codec",
            "license": "GPL",
            "distribution": "bundled",
            "language": "C",
            "linking": "dynamic",
        }))

        self.assertIn("plain-gpl-codec：禁止授權 GPL", errors)

    def test_rejects_lgpl_static_linking(self):
        errors = validate_manifest(manifest_with({
            "name": "ffmpeg",
            "license": "LGPL-2.1-or-later",
            "distribution": "bundled",
            "language": "C",
            "linking": "static",
        }))

        self.assertIn("ffmpeg：LGPL bundled 元件必須 dynamic linking", errors)

    def test_rejects_bundled_python_runtime(self):
        errors = validate_manifest(manifest_with({
            "name": "python-sidecar",
            "license": "MIT",
            "distribution": "bundled",
            "language": "Python",
            "linking": "n/a",
        }))

        self.assertIn("python-sidecar：bundled/release 依賴不得要求 Python runtime", errors)

    def test_requires_non_empty_components(self):
        errors = validate_manifest({"schemaVersion": 1, "components": []})

        self.assertEqual(["manifest.components 必須是非空陣列"], errors)

    def test_requires_source_for_bundled_sidecar_or_model(self):
        errors = validate_manifest(manifest_with({
            "name": "new-asr-engine",
            "category": "sidecar",
            "license": "MIT",
            "distribution": "bundled",
            "language": "C/C++",
            "linking": "n/a",
        }))

        self.assertIn("new-asr-engine：sidecar/model 必須有 source", errors)


if __name__ == "__main__":
    unittest.main()
