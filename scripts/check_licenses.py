#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# AI-Generate
"""
check_licenses.py — release license gate for Syllable Repeater.

The checker validates a JSON release dependency manifest. It intentionally
keeps the rules explicit and local so CT-09 can fail fast before packaging.

Usage:
    python3 scripts/check_licenses.py <release-license-manifest.json>

Exit codes:
    0 = passed
    1 = failed
"""

import json
import sys

ALLOWED_LICENSES = {
    "MIT",
    "BSD-2-Clause",
    "BSD-3-Clause",
    "BSD-like",
    "ISC",
    "Apache-2.0",
    "LGPL-2.1-or-later",
    "LGPL-3.0-or-later",
    "MPL-2.0",
}

BANNED_TOKENS = (
    "AGPL",
    "CC-BY-NC",
    "CC BY-NC",
    "NON-COMMERCIAL",
    "NONCOMMERCIAL",
    "RESEARCH-ONLY",
    "RESEARCH ONLY",
)


def _load_manifest(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except OSError as exc:
        raise ValueError(f"無法讀取 manifest：{exc}") from exc
    except json.JSONDecodeError as exc:
        raise ValueError(f"manifest 不是合法 JSON：{exc}") from exc


def _is_lgpl(license_id):
    return license_id.startswith("LGPL-")


def _is_banned_license(license_id):
    normalized = license_id.upper()
    return normalized.startswith("GPL") or any(token in normalized for token in BANNED_TOKENS)


def validate_manifest(manifest):
    errors = []

    components = manifest.get("components")
    if not isinstance(components, list) or not components:
        return ["manifest.components 必須是非空陣列"]

    for index, component in enumerate(components, start=1):
        name = str(component.get("name", "")).strip()
        license_id = str(component.get("license", "")).strip()
        distribution = str(component.get("distribution", "")).strip()
        category = str(component.get("category", "")).strip().lower()
        source = str(component.get("source", "")).strip()
        language = str(component.get("language", "")).strip().lower()
        linking = str(component.get("linking", "")).strip().lower()
        label = name or f"component #{index}"

        if not name:
            errors.append(f"{label}：缺少 name")
        if not license_id:
            errors.append(f"{label}：缺少 license")
        if not distribution:
            errors.append(f"{label}：缺少 distribution")

        if category in {"sidecar", "sidecar-transitive", "model"} and not source:
            errors.append(f"{label}：sidecar/model 必須有 source")

        if _is_banned_license(license_id):
            errors.append(f"{label}：禁止授權 {license_id}")
            continue

        if license_id not in ALLOWED_LICENSES:
            errors.append(f"{label}：授權 {license_id} 不在白名單")

        if language == "python" and distribution != "dev-only":
            errors.append(f"{label}：bundled/release 依賴不得要求 Python runtime")

        if distribution == "bundled" and _is_lgpl(license_id) and linking != "dynamic":
            errors.append(f"{label}：LGPL bundled 元件必須 dynamic linking")

    return errors


def main(argv):
    if len(argv) != 2:
        print("用法：python3 scripts/check_licenses.py <release-license-manifest.json>")
        return 1

    try:
        manifest = _load_manifest(argv[1])
    except ValueError as exc:
        print(f"❌ {exc}")
        return 1

    errors = validate_manifest(manifest)

    print("=" * 60)
    print("授權白名單檢查（CT-09 / M9）")
    print("=" * 60)
    print(f"manifest：{argv[1]}")
    print(f"元件數：{len(manifest.get('components', []))}")
    print("-" * 60)

    if errors:
        print(f"❌ 違規 {len(errors)} 項：")
        for error in errors:
            print(f"  ❌ {error}")
        print("結果：不通過——發布流程中止。")
        return 1

    print("結果：✅ 通過。")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
