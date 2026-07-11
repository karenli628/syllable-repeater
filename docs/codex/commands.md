# 指令速查（Syllable Repeater）

> 所有指令在 repo 根目錄執行（除非另註）。與 CI 同源的完整閘門只有一條：`bash scripts/ci_core_checks.sh`。

## 環境

```bash
# 首次 clone 後（啟用 pre-commit 金鑰掃描與 pre-push guardrails 閘門）
git config core.hooksPath .githooks

# 相依安裝（Dart pub workspace：根跑一次即可）
flutter pub get

# 工具鏈版本（CI pin 死：Flutter 3.44.4 / macos-15 runner / Python 3.12）
flutter --version

# dev sidecar 路徑：預設讀 .local-tools/；他機用環境變數覆寫
export SYLLABLE_REPEATER_DEV_ROOT="<repo 絕對路徑>"
export FFMPEG_PATH=/usr/local/bin/ffmpeg          # dev-only GPL build，禁止進 release
# 其他可覆寫：FFPROBE_PATH / WHISPER_CLI_PATH / WHISPER_MODEL_PATH / CMUDICT_PATH /
#            DEMUCS_CLI_PATH / DEMUCS_MODEL_PATH / SYLLABLE_REPEATER_TEMP_DIR
```

## 測試與分析

```bash
# ★ 交付前完整閘門（=GitHub Actions Core CI 同一腳本）
bash scripts/ci_core_checks.sh
# 內容依序：flutter pub get → guardrails → license gate → license/staging unittest
#          → domain tests → infra tests → app widget tests → flutter analyze

# 分包測試
flutter test packages/domain/test          # 82 tests（含 CT-01~08、domain purity）
flutter test packages/infra/test           # 67 tests（sidecar/DB/整合；缺 sidecar 的整合測試自動 skip）
( cd app && flutter test )                 # 59 widget tests

# 單一檔案 / 關鍵防線
flutter test packages/domain/test/practice_build_steps_test.dart   # M1/M2（CT-01/CT-02）
flutter test packages/domain/test/domain_purity_test.dart          # M5（CT-05）
flutter test packages/domain/test/progress_archive_test.dart       # M8（CT-08 167h/169h）

# 靜態分析
flutter analyze
```

## Guardrails 與授權

```bash
MATRIX="spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/hard-limits-matrix.md"
DLOG="spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/decision-log.md"
MANIFEST="spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/release/license-manifest.json"

# 硬性限制 matrix 檢查（pre-push 也會跑；NOT_REVIEWED / AI 自批 / REJECTED 未實作都會擋）
python3 scripts/check_guardrails.py "$MATRIX" "$DLOG"

# CT-09 授權白名單 gate（擋 GPL/AGPL/CC BY-NC/research-only/bundled Python/LGPL static）
python3 scripts/check_licenses.py "$MANIFEST"
python3 -m unittest scripts/test_check_licenses.py scripts/test_prepare_release_sidecars.py
```

## 效能 benchmark（Q10）

```bash
# 10 秒音檔完整對齊管線實測（需 .local-tools/ 的 ffmpeg/whisper/cmudict 就緒）
( cd packages/infra && dart run bin/benchmark_alignment_pipeline.dart )
# 基準（i5-8259U，2026-07-07）：elapsedMs=4689，目標 ≤60s；換模型/晶片/sidecar 版本必重跑
```

## Release（任務 2.1 / 9.1 / 9.2）

```bash
# sidecar 工件盤點/下載（來源 URL+SHA-256 確認前只盤點，不硬寫來源）
python3 scripts/fetch_sidecar_artifacts.py --inventory-only
python3 scripts/fetch_sidecar_artifacts.py --print-template

# sidecar staging（先 license gate 再複製；拒 GPL/static FFmpeg；產 sidecar-manifest.json）
python3 scripts/prepare_release_sidecars.py --dry-run   # 先看盤點結果
python3 scripts/prepare_release_sidecars.py             # 實跑（工件就緒後）

# release build（9.1；前置：entitlements app-sandbox 改 false、staging 完成）
flutter build macos --release
# Release build phase 會執行 app/macos/Runner/Scripts/copy_release_sidecars.sh，缺件即中止（fail-closed 為預期）

# 產物驗證
codesign -dv app/build/macos/Build/Products/Release/syllable_repeater_app.app 2>&1 | head -3   # 未簽章屬預期
otool -L <bundle 內 ffmpeg>   # 確認 LGPL dylib 動態連結
```

## Git / CI

```bash
git log --oneline -8
gh run list --limit 5                      # GitHub Actions Core CI 狀態
gh run view <run-id> --log-failed          # 失敗時看 log
# main 有 Repository Ruleset（禁 deletion / non_fast_forward）；不要 force push
```

## 常見狀況對照

| 症狀 | 原因與處置 |
|------|------------|
| App 啟動黑屏（macOS run） | entitlements `app-sandbox: true` 擋 sidecar——9.1 前屬已知狀態，用 widget/e2e test 驗證；9.1 時改 false |
| whisper 輸出亂碼/異常 | 沒轉 16k mono WAV 或沒加 `--no-gpu`（Intel 地雷，wrapper 已處理，繞過 wrapper 才會遇到） |
| infra 整合測試被 skip | `.local-tools/` 缺 sidecar 二進位——屬設計行為（@Tags sidecar），補齊工件即轉綠 |
| pre-push 被擋 | guardrails matrix 有未落地項或格式錯——跑 check_guardrails.py 看明細，禁止 --no-verify 交付 |
| `dart` 找不到 | PATH 加 `/usr/local/opt/dart/libexec/bin` |
| 匯入按鈕沒反應（dev） | `SidecarPaths.dev().missingPaths()` 非空→fallback preview runner；設環境變數或補 .local-tools |
