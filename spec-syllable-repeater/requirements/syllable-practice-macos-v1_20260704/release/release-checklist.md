# Release Checklist — Syllable Repeater macOS v1

> AI-Generate
> 本檔是 task 8.2 / CT-09 的本機發布 gate 清單。GitHub 上載與 branch protection 保留到最後處理。

## 必跑 Gate

1. `python3 scripts/check_licenses.py spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/release/license-manifest.json`
2. `python3 -m unittest scripts/test_check_licenses.py`
3. `flutter test packages/domain/test`
4. `flutter test packages/infra/test`
5. `cd app && flutter test`
6. `flutter analyze`
7. `python3 scripts/check_guardrails.py spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/hard-limits-matrix.md spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/decision-log.md`

## CT-09 人工核對

- FFmpeg release build 必須是 LGPL-only build 且 dynamic linking。
- Homebrew FFmpeg 只能作為 dev-only 工具，不得隨 App 發布。
- release bundle 不得包含 GPL、AGPL、CC BY-NC、non-commercial、research-only 授權元件或模型。
- release bundle 不得引入 bundled Python runtime。
- GitHub repo / branch protection 若尚未建立，保留到發布前最後 gate，不先上載。
