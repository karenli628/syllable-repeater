// AI-Generate
# 未簽章 macOS Release 安裝說明

本專案 v1 採免簽章發佈路線，不使用 Apple Developer ID / notarization，也不上架 Mac App Store。

## 使用者安裝

1. 下載 `SyllableRepeater-macos-x86_64-unsigned.zip` 與同名 `.sha256`。
2. 解壓縮 zip，得到 `syllable_repeater_app.app`。
3. 若 macOS 顯示「無法打開，因為無法驗證開發者」，可擇一處理：
   - 在 Finder 對 app 按右鍵，選「打開」，再於提示中按「打開」。
   - 或在 Terminal 執行：`xattr -cr /path/to/syllable_repeater_app.app`
4. 第一次開啟後，匯入音檔、sidecar 分析與 Keychain 儲存 AI key 都在本機執行；AI 翻譯僅在使用者自備 key 且觸發文字翻譯時外呼。

## 發布者打包

1. 先完成 release sidecar staging：`python3 scripts/fetch_sidecar_artifacts.py --run-prepare`
2. 跑 release build：`cd app && flutter build macos --release`
3. 打 zip：`python3 scripts/make_release_zip.py`
4. 交付 `dist/SyllableRepeater-macos-x86_64-unsigned.zip` 與 `dist/SyllableRepeater-macos-x86_64-unsigned.zip.sha256`

## 發布前必查

- 不得把 `/usr/local/bin/ffmpeg` 的 GPL build 放進 release。
- `python3 scripts/check_licenses.py spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/release/license-manifest.json` 必須通過。
- `bash scripts/ci_core_checks.sh` 必須通過。
