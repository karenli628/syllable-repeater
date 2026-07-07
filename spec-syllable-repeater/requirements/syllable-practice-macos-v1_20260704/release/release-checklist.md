# Release Checklist — Syllable Repeater macOS v1

> AI-Generate
> 本檔是 task 8.2 / CT-09 的發布 gate 清單。GitHub Actions 與 branch protection 已於 2026-07-07 接上；release 實機 gate 仍需本檔逐項核對。

## 必跑 Gate

1. `python3 scripts/check_licenses.py spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/release/license-manifest.json`
2. `python3 -m unittest scripts/test_check_licenses.py scripts/test_prepare_release_sidecars.py`
3. `flutter test packages/domain/test`
4. `flutter test packages/infra/test`
5. `cd app && flutter test`
6. `flutter analyze`
7. `python3 scripts/check_guardrails.py spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/hard-limits-matrix.md spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/decision-log.md`

## Sidecar staging

- 先用 `scripts/prepare_release_sidecars.py` 產生 `app/macos/Runner/Resources/sidecar/` staging 內容；實際 binaries/models/dictionaries 由 `.gitignore` 擋住，不進版控。
- `prepare_release_sidecars.py` 會先跑 CT-09 license manifest gate，再拒絕 `--enable-gpl` / `--enable-nonfree` 或非 shared 的 FFmpeg/ffprobe。
- macOS Release build phase 會檢查 `sidecar-manifest.json`、`bin/ffmpeg`、`bin/ffprobe`、`bin/whisper-cli`、`bin/demucs.cpp.main`、`models/ggml-small.en.bin`、`models/ggml-model-htdemucs-4s-f16.bin`、`data/cmudict.dict`，缺任一項即中止 release build。

## CT-09 人工核對

- FFmpeg release build 必須是 LGPL-only build 且 dynamic linking。
- Homebrew FFmpeg 只能作為 dev-only 工具，不得隨 App 發布。
- release bundle 不得包含 GPL、AGPL、CC BY-NC、non-commercial、research-only 授權元件或模型。
- release bundle 不得引入 bundled Python runtime。
- Whisper model weights 必須保留 MIT 授權告知；本案使用 `ggml-small.en.bin`。
