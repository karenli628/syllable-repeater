// AI-Generate
# 監測規劃：Syllable Repeater macOS v1

## 0. 基本資訊

- 分級：輕量版（本機/單人）。判定依據：`requirement.md` §2.3 明定純本機、單人、自有資料、無 server deployment。
- 依據文件：`requirement.md` §2.5、`guardrails/hard-limits-matrix.md`、`design/backend-design.md`、`release/release-checklist.md`。
- 本檔地位：唯一正式監測契約；巡檢一律對照本檔。
- 建立日期 / 最近更新：2026-07-11 / 2026-07-11。

## 1. 核心監測映射表

| # | 核心條目 | 看守方式 | 指標/巡檢項 | 告警閾值或抽測情境 | 觸發後第一動作 | 對應防線位置 |
|---|----------|----------|-------------|--------------------|----------------|--------------|
| 1 | M1 原聲不可替換 | CI + release 前巡檢 | CT-01 / `PracticeEngine.renderStep` sample equality | 任一 CT-01 失敗 | 停止 release，回退相關音訊路徑變更 | `practice_engine_test.dart`、`PracticeEngine.renderStep` |
| 2 | M2 疊加演算法 | CI | CT-02 / 金標準 11 步、第 2 步 `tion skills` | 任一 buildSteps 測試失敗 | 停止 release，檢查 syllable ordering | `practice_build_steps_test.dart` |
| 3 | M3 合併匯出靜音 | CI | CT-03 / sample-count silence gaps | 超過 ±20ms 或尾端多靜音 | 停止 release，檢查 export merge | export tests |
| 4 | M4 sidecar 崩潰隔離 | CI + smoke | sidecar timeout/crash/nonzero tests | 任一 sidecar fault test 失敗 | 停止 release，修 `SidecarRunner`/wrapper | `sidecar_runner_test.dart`、wrapper tests |
| 5 | M5 Domain 純 Dart | CI | domain purity scan | 發現 Flutter/infra/dart:io/ffi/html import | 停止 release，移除違規依賴 | `domain_purity_test.dart` |
| 6 | M6 進度合併 | CI | CT-06 newer-wins/contentHash reset tests | 進度合併測試失敗 | 停止 release，檢查 `ProgressEngine.importProgress` | progress tests |
| 7 | M7 跨日零懲罰 | CI + schema 巡檢 | CT-07 / schema 無 overdue/fail/penalty 欄位 | 測試失敗或 schema 出現懲罰欄位 | 停止 release，回復 schema/logic | `db_schema_test.dart`、progress tests |
| 8 | M8 歸檔 168h | CI | CT-08 167h/169h 邊界 | 邊界測試失敗 | 停止 release，檢查 clock/status transition | `progress_archive_test.dart` |
| 9 | M9 授權白名單 | CI + release gate | CT-09 license manifest、bundle ffmpeg `-version`、`otool -L` | GPL/AGPL/non-commercial/static LGPL、`--enable-gpl` 或 bundle 缺檔 | 停止 release，重建 sidecar，禁止用 `/usr/local/bin/ffmpeg` | `check_licenses.py`、`fetch/prepare` scripts、release checklist |
| 10 | M10 隱私 | CI + code review | key scan、recording cleanup tests、DB schema 無 audio/path | key 出現在 repo、錄音未刪、DB/pack/log 存敏感資料 | 停止 release，清除敏感資料並輪替 key | AI/recording/schema tests |

## 2. 不可接受清單 → 零容忍抽測

| # | 不可接受條目 | 偵測方式 | 通知方式與對象 |
|---|--------------|----------|----------------|
| 1 | TTS/AI 合成/音高重算進播放或匯出 | CT-01、code review 搜尋音訊生成路徑 | 巡檢報告標必修；通知 Karen |
| 2 | 疊加吸附單字邊界 | CT-02 金標準與第 2 步測試 | 巡檢報告標必修；通知 Karen |
| 3 | GPL/AGPL/non-commercial 進 release | CT-09、`fetch_sidecar_artifacts.py`、`prepare_release_sidecars.py` | 停止打包；通知 Karen |
| 4 | API key 明文落檔/DB/log | key scan、AI adapter tests、人工抽查 | 停止 release；通知 Karen 並輪替 key |
| 5 | 未經同意保留錄音檔 | recording cleanup tests、schema 巡檢 | 停止 release；通知 Karen |

## 3. 資安監測

- 金鑰掃描：每次 release 前以 `rg -n "sk-|api[_-]?key|Authorization: Bearer|password|secret"` 抽查 repo；常態依 code review 與 `.gitignore` 防止 `.env` 入庫。
- 依賴漏洞掃描：目前未接自動 vulnerability scanner；輕量巡檢每月檢查 Dart/Flutter 依賴版本與 GitHub Security alerts（若 repo 已啟用）。
- license / guardrails 複跑：每次 release 前跑 `bash scripts/ci_core_checks.sh`；至少每月手動跑一次核心 gate。
- audit log 巡檢點：抽查 `audit_log` 是否只存設定/狀態摘要，不存 key/audio/path。

## 4. 備份與還原

- 備份方式與頻率：使用者自行保存 `.abopack` 與 `.aboprogress`；release 前保留 zip + `.sha256`。
- 還原演練節奏：每季在隔離資料夾用一份 `.abopack` + `.aboprogress` 做讀取/匯入 smoke。
- RPO/RTO：本機 App 無 server RPO/RTO；實務目標為使用者可從最近保存的 pack/progress 檔恢復。

## 5. 巡檢節奏與觸發機制

| 巡檢類型 | 頻率 | 由誰/什麼機制觸發 | 執行方式 |
|----------|------|-------------------|----------|
| release 巡檢 | 每次準備交付 zip | Karen 或 AI coding agent | `flutter pub get` → `bash scripts/ci_core_checks.sh` → release checklist sidecar/zip 核對 |
| 輕巡 | 每月一次 | 行事曆或手動對 AI 說「執行巡檢」 | 重跑 Core CI、license/guardrails、檢查 release README 與最新 artifact hash |
| 使用者 smoke | 每次新 zip | Karen | 解壓 zip，右鍵開啟或 `xattr -cr`，以一段音檔跑 REQ-01→08 |
| 還原演練 | 每季 | Karen | 以隔離資料夾匯入 `.abopack` / `.aboprogress`，確認資料可讀 |

## 6. 告警接收

- 通知管道：目前為本 Codex task / 交接檔 / 巡檢報告。
- 接收人：Karen。
- 無回應升級規則：本機單人專案不設即時升級；任何必修項未解前不得發布新 zip。
