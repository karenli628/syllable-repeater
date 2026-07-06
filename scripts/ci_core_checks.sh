#!/usr/bin/env bash
# AI-Generate
# Core CI gate for Syllable Repeater.
#
# Keep this script aligned with task-split 8.2: it is the local/remote
# executable mapping for CT-01..CT-10 plus hard-guardrails.

set -euo pipefail

MATRIX="spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/hard-limits-matrix.md"
DECISION_LOG="spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/decision-log.md"
LICENSE_MANIFEST="spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/release/license-manifest.json"

section() {
  printf '\n==> %s\n' "$1"
}

section "Flutter toolchain"
flutter --version
flutter pub get

section "Hard guardrails"
python3 scripts/check_guardrails.py "$MATRIX" "$DECISION_LOG"

section "CT-09 license gate"
python3 scripts/check_licenses.py "$LICENSE_MANIFEST"
python3 -m unittest scripts/test_check_licenses.py

section "CT-01..CT-10 domain tests"
flutter test packages/domain/test

section "Infra tests"
flutter test packages/infra/test

section "App widget tests"
(
  cd app
  flutter test
)

section "Static analysis"
flutter analyze

section "Core CI gate passed"
