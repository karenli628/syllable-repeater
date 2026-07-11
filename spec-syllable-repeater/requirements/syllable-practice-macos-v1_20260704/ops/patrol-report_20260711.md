// AI-Generate
# 巡檢報告：Syllable Repeater macOS v1 2026-07-11（release 深巡）

## 總體結論一句話

release build、sidecar 授權、unsigned zip 與 Core CI 全數通過；仍建議在 Karen 端執行一次解壓/略過 Gatekeeper/完整 GUI smoke 後再標記為可分發版本。

## 統計

通過 9 項｜建議 2 項｜必修 0 項

## 執行明細

| 項目 | 結果 | 說明 |
|------|------|------|
| `flutter pub get` | 通過 | 動工前已執行 |
| release sidecar inventory | 通過 | `fetch_sidecar_artifacts.py --inventory-only` 全部工件存在 |
| sidecar staging | 通過 | `fetch_sidecar_artifacts.py --run-prepare-dry-run` / `--run-prepare` 通過 |
| x86_64 release build | 通過 | `flutter build macos --release --no-pub` 產 `.app` 634MB；主執行檔 Mach-O x86_64 |
| bundled FFmpeg / FFprobe | 通過 | `--enable-shared --disable-static --disable-gpl --disable-nonfree --enable-libmp3lame`；`otool -L` 為 bundled dynamic dylib |
| bundled demucs.cpp | 通過 | x86_64；只連系統 `Accelerate.framework`、`libc++`、`libSystem` |
| CT-09 license gate | 通過 | `check_licenses.py` 25 components 通過 |
| unsigned zip | 通過 | `dist/SyllableRepeater-macos-x86_64-unsigned.zip` 524MB；SHA-256 `38de745c051c7d19f11c254fe0406055979dbca7c4e6c07ef4474f2f670db8a2` |
| Core CI | 通過 | Python 22 tests、domain 82、infra 69 + 2 skips、app 67 + 1 skip、`flutter analyze` no issues |
| 使用者端 Gatekeeper smoke | 建議 | 本輪未由 Karen 端解壓 zip 實測右鍵開啟 / `xattr -cr` / REQ-01→08 |
| 依賴漏洞掃描 | 建議 | 尚未接自動 vulnerability scanner；本輪以 license/CI/manifest gate 為主 |

## 必修

無。

## 建議

1. 由 Karen 在目標 macOS x86_64 環境解壓 `dist/SyllableRepeater-macos-x86_64-unsigned.zip`，依 `release/README-unsigned-macos.md` 右鍵開啟或 `xattr -cr`，跑一次 REQ-01→08 GUI smoke。
2. 後續若要向非親友分發，補 Apple Developer ID signing/notarization 評估；目前 v1 仍依已拍板的免簽章路線。
3. 若專案進入更正式發版節奏，可加依賴漏洞掃描與 FFmpeg PGP 驗章；目前 SHA-256 pinning + source build + CT-09 gate 已通過。

## 下次巡檢

時點：下一次 zip 發布前。類型：release 巡檢。特別要盯：M9 sidecar 授權、M1/M2/M3 音訊核心測試、使用者端 Gatekeeper smoke。
