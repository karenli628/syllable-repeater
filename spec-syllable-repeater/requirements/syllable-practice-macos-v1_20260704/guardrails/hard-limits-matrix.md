# hard-limits-matrix.md — 硬性限制總表

> 專案／需求：Syllable Repeater macOS v1（`syllable-practice-macos-v1_20260704`）
> 建立日期：2026-07-05
> 選用 profile：`local-single-user`（本機自用桌面工具、單一使用者、無伺服器、無金流、免簽章 Q4）
>
> **狀態值（只允許以下七種）**：
> `NOT_REVIEWED`／`IMPLEMENTED`／`PARTIAL`／`NOT_APPLICABLE_PENDING_HUMAN_REVIEW`／`APPROVED_NOT_APPLICABLE`／`BLOCKED`／`REJECTED_NEEDS_IMPLEMENTATION`
>
> **規則**：AI 不得刪行；不適用走狀態機不是刪行；批准人不得是 AI；`IMPLEMENTED` 落地位置必填。

## 專案上下文（判定依據，跨列共用）

- **架構**：無 HTTP 伺服器；Domain（純 Dart）+ Infra（sidecar wrapper）+ Flutter macOS app；本機 SQLite（Drift）+ 檔案 IO（原子搬移）；sidecar = FFmpeg、whisper.cpp、demucs.cpp。
- **使用者**：單一本機使用者；無註冊、無登入、無多租戶。
- **對外**：僅 AIService v1（翻譯）走使用者自備 API key（Keychain 儲存）；無 Web／Mobile 遠端介面。
- **發布**：Q4 定案免簽章＋略過 Gatekeeper（不上 Mac App Store、不做 notarization）。
- **核心維持原則（requirement §2.5 M1-M10）** 對應本表：M1 → 6/13；M2 → 13；M3 → 13；M4 → 6/13；M5 → 13（domain purity policy-as-code）；M6 → 13；M7 → 3/13（schema 結構斷言）；M8 → 27（soft delete 狀態機）；M9 → 12/29/32；M10 → 3/13/19/36。

| # | 限制 | 白話說明 | 狀態 | 落地位置（檔案/設定/SQL） | 批准人 | decision-log 編號／備註 |
|---|------|----------|------|---------------------------|--------|--------------------------|
| 1 | Sandbox | 沙盒：限制 AI 或程式能碰哪些檔案、能執行哪些命令、能不能連網 | PARTIAL | `app/macos/Runner/DebugProfile.entitlements`＋`Release.entitlements`（**目前 `com.apple.security.app-sandbox: true` 但反而擋 sidecar；M9 前置＝改 `false`**）；AI coding agent 端靠 Claude Code 互動 approval（未設目錄白名單） | — | 詳見 memory `decision_macos_sandbox_ui_demo_waived_v1`；task 9.1 前置必須關 macOS App Sandbox；AI-agent 端 sandbox 白名單留待 profile `ai-agent-tool` 擴充時處理 |
| 2 | File Permission | 檔案權限：限制檔案只能讀、不能改 | PARTIAL | `AtomicFileIo`（`packages/infra/lib/src/file_io_impl.dart`）＋`.gitignore` 保護 `.local-tools/s1a/*` 等 dev 產物不進版控；OS 層檔案權限未特別限制（單人本機） | — | 單人本機工具，OS 層 chmod 隔離無收益；AtomicFileIo 已守「寫入中斷不留半成品」 |
| 3 | Database Permission | 資料庫權限：限制資料庫帳號能讀寫哪些資料 | IMPLEMENTED | `packages/infra/lib/src/db/app_database.dart`（V1 schema：attempt 表**無音訊欄位**＝M10 隱私結構防線；practice_group 表**無逾期/失敗欄位**＝M7 跨日零懲罰結構防線）；`packages/infra/test/db_schema_test.dart`（結構斷言 6 項） | — | 本機 SQLite 單使用者，無帳號分權；用「schema 上不存在該欄位」做結構防線比程式邏輯防線更硬（見 `execution-log.md` Task 1.2） |
| 4 | API Schema | API 資料格式規格：API 只接受指定欄位 | APPROVED_NOT_APPLICABLE | — | eslite0220@gmail.com（使用者 2026-07-05 確認） | DL-001：無 HTTP API；「介面對齊」錨在 Domain API 編號（backend-design §3.2 介面 1–19 欄位表）而非 REST/GraphQL schema。裁決前使用者確認「桌面即時同步→手機 PWA」路徑未啟動 |
| 5 | Type System | 型別系統：用程式語言限制資料形狀 | IMPLEMENTED | Dart 3.12.2 static types + null-safety 全套；`packages/domain/`、`packages/infra/`、`app/` 三包全為 sound null-safe Dart；領域型別（Syllable、PracticeStep、AnalysisEvent、Pcm 等）以 immutable class 建構＋建構子 assertion（如 `progress ∈ [0,1]`） | — | `flutter analyze` 無問題即基本保證；型別是 M5 Domain 純 Dart 的基礎 |
| 6 | Validation | 驗證：輸入輸出不合格就拒絕 | IMPLEMENTED | `packages/infra/lib/src/sidecar/ffmpeg_decoder.dart`（副檔名白名單＋10 分鐘上限＋錯誤碼映射）；`packages/infra/lib/src/sidecar/ffprobe_duration.dart`（UI 前置時長）；`packages/domain/lib/src/errors.dart`（17 個錯誤碼總表 backend-design §3.2.8）；`packages/infra/lib/src/sidecar/sidecar_runner.dart`（Process crash/timeout 映射 M4）；`packages/domain/lib/src/analysis/analysis_pipeline.dart`（重入鎖 ERR_ANALYSIS_IN_PROGRESS） | — | M4 崩潰隔離＋17 錯誤碼是主軸；未來 3.6 `updateSyllableBoundary` 開區間驗證屬同類補完 |
| 7 | Git Hook | Git 鉤子：commit / push 前自動檢查 | IMPLEMENTED | `.githooks/pre-commit` + `.githooks/pre-push`（`git config core.hooksPath .githooks`）；**pre-commit**（本機保存）：①簡易金鑰掃描（api_key/secret/password/token 樣式 + 至少 16 字元）②`.env` 誤送擋下（憲法 C6）；**pre-push**（推遠端前，交付閘門）：硬性限制 matrix 檢查（`scripts/check_guardrails.py`）——skill 鐵律 4「REJECTED 未實作即擋交付」語意上應在推遠端時擋，本機 commit 不擋。2026-07-05 使用者拍板 git init + 兩層 hook | — | 遠端 CI（GitHub Actions）仍待使用者決定是否 push GitHub 後接（見項 8） |
| 8 | CI | 持續整合：push / PR 後自動檢查 | PARTIAL | 本地 CI-ready 防線：`packages/domain/test/domain_purity_test.dart`（M5＋AT-09-02 違規匯入範例驗證）；`packages/infra/test/db_schema_test.dart`（M7/M10 結構斷言）；`flutter test packages/domain/test`＋`flutter test packages/infra/test`＋`cd app && flutter test`（本地跑 5+18+39=62 tests 全綠）。**遠端 CI（GitHub Actions）待 git init 後接** | — | 見 memory `workflow_domain_purity_ci_ready防線`＋`workflow_flutter_workspace_dart_test_gotcha`；task 8.1 已完成，8.2/8.3 待實作 |
| 9 | Branch Protection | 分支保護：沒通過檢查不能合併 | REJECTED_NEEDS_IMPLEMENTATION | — | eslite0220@gmail.com（使用者 2026-07-05 REJECT AI 判斷；要求實作） | DL-002：使用者裁決 REJECT——單人 repo 也要防 force push 到 main；實作追蹤 task 8.4.1（本次新增） |
| 10 | CODEOWNERS | 指定檔案必須由指定人 review | APPROVED_NOT_APPLICABLE | — | eslite0220@gmail.com（使用者 2026-07-05 確認） | DL-003：單人 repo，唯一 owner = 使用者本人 |
| 11 | Secret Scanning | 秘密金鑰掃描：防止 API key、密碼被提交 | PARTIAL | `.gitignore` 已排除 `.local-tools/s1a/*`（whisper 輸出 JSON 可能含使用者音檔路徑）；AIService v1 之 API key 走 Keychain **不落地檔案**（frontend-design §7.2、M10；UI「送 Domain 即清空欄位」）；`.githooks/pre-commit` 已加簡易金鑰樣式掃描（api_key/secret/password/token + 16+ 字元）＋`.env` 誤送擋下（憲法 C6）。**遠端 secret scanning（GitHub secret scan / gitleaks CI job）待推 GitHub 後接** | — | M10 隱私防線 + AT-07-05 pack 無 key 明文；本地 Keychain + `.gitignore` + pre-commit 三重前置防護 |
| 12 | Dependency Scanning | 依賴掃描：檢查第三方套件已知漏洞 | PARTIAL | `pubspec.yaml` 依賴清單可手動核對；M9 授權白名單掃描腳本 = task 8.2（CT-09）**待實作**；brew FFmpeg 記錄為 dev-only GPL build（需 M9 換 LGPL）；demucs.cpp（sevagh）LICENSE **S1c 前必核**（memory `decision_開發環境工具鏈事實`） | — | 見 memory `decision_開發環境工具鏈事實`；task 2.1 標為 InProgress；CT-09 待實作 |
| 13 | Test | 測試：自動驗證行為符合規格（含核心不被破壞測試） | PARTIAL | **已完成**：M4（`sidecar_runner_test.dart` 五情境含 kill -9）、M5（`domain_purity_test.dart` 15 tests）、M7/M10 結構部分（`db_schema_test.dart` 6 tests）、M10 部分（AT-07-05 pack 無 key 待 7.1）；**待實作**：CT-01（M1 renderStep 逐 sample 相等，task 4.3-4.4 TDD）／CT-02（M2 buildSteps 11 步 tion skills，task 4.1-4.2）／CT-03（M3 靜音規則 ±20ms，task 4.5-4.6）／CT-06（M6 進度合併，task 7.4）／CT-08（M8 167h/169h，task 7.5）／CT-09 授權掃描／CT-10 錄音刪除+pack 無 key。目前 62 tests 全綠；核心驗收總表 CT-01～10 有 4 已完成、6 待 S2/S6 | — | 三同步：requirement §12 核心驗收總表逐條對應。M1（原聲不可替換）是最高防線（CT-01），task 4.3 明訂 TDD 先寫紅測試 |
| 14 | Policy as Code | 政策即程式碼：把規則寫成可自動執行的檢查 | PARTIAL | 已 code：M5 `domain_purity_test.dart`（掃 `lib/**` import + `pubspec.yaml`）；M7/M10 結構斷言（`db_schema_test.dart`）；規則以測試碼形式落地即 policy-as-code。待補：M1/M2/M3 policy 對應測試（task 4.1/4.3/4.5 TDD 先紅） | — | domain_purity_test 是本專案 policy-as-code 的參考樣板（見 memory `workflow_domain_purity_ci_ready防線`） |
| 15 | RBAC | 角色權限控管：依角色決定能做什麼 | APPROVED_NOT_APPLICABLE | — | eslite0220@gmail.com（使用者 2026-07-05 確認） | DL-004：單一使用者，無角色差異 |
| 16 | ABAC | 屬性權限控管：依屬性（部門、時間、標籤）決定能做什麼 | APPROVED_NOT_APPLICABLE | — | eslite0220@gmail.com（使用者 2026-07-05 確認） | DL-005：單一使用者，無屬性維度 |
| 17 | Tenant Isolation | 租戶隔離：不同客戶的資料互相看不到 | APPROVED_NOT_APPLICABLE | — | eslite0220@gmail.com（使用者 2026-07-05 確認） | DL-006：無多租戶概念；本機一份 DB |
| 18 | RLS | 資料列層級安全：同一張表內按列控制誰能讀寫 | APPROVED_NOT_APPLICABLE | — | eslite0220@gmail.com（使用者 2026-07-05 確認） | DL-007：無多使用者，無 RLS 需求 |
| 19 | Encryption at Rest | 靜態加密：存起來的資料是加密的 | PARTIAL | AI key 走 macOS Keychain（`SecureStore` port，介面 11／M10）；**實作待 task 7.2**。使用者音訊、字稿、practice attempt、SRS 狀態存本機 SQLite/檔案**不加密**（本機自用工具，資料落地即物理擁有） | — | Keychain 是「等效於加密」的 macOS 標準保管路徑；音訊/課件不加密符合 requirement §2.5 允許變動範圍 |
| 20 | Encryption in Transit | 傳輸加密：資料在網路上跑時是加密的（TLS） | PARTIAL | AIService.translate 對外呼叫（介面 12）走服務商 HTTPS API；**實作待 task 7.2**。本機 sidecar Process.start stdout/stderr 為本機 IPC 不涉及網路 | — | 服務商（OpenAI/Anthropic 等）API 皆為 HTTPS；只要客戶端不強制 http:// 即可自然滿足 |
| 21 | KMS | 金鑰管理服務：加密金鑰集中管理、輪替 | APPROVED_NOT_APPLICABLE | — | eslite0220@gmail.com（使用者 2026-07-05 確認） | DL-008：macOS Keychain 已提供 OS 級金鑰管理（含系統輪替 policy），本機工具無 KMS（AWS KMS / Vault 等）需求 |
| 22 | Audit Log | 稽核紀錄：誰在何時做了什麼，事後可查 | REJECTED_NEEDS_IMPLEMENTATION | — | eslite0220@gmail.com（使用者 2026-07-05 REJECT AI 判斷；要求實作） | DL-009：使用者裁決 REJECT——「記錄我上週改了什麼設定/SRS」有價值；實作追蹤 task 8.4.2（本次新增） |
| 23 | Rate Limit | 流量限制：單位時間內請求次數上限 | REJECTED_NEEDS_IMPLEMENTATION | — | eslite0220@gmail.com（使用者 2026-07-05 REJECT AI 判斷；要求實作） | DL-010：使用者裁決 REJECT——App 端 AIService 呼叫需加內部 rate limit 防手滑狂點耗 API 費；實作追蹤 task 8.4.3（本次新增） |
| 24 | Quota | 配額：使用量上限（儲存、次數、金額） | APPROVED_NOT_APPLICABLE | — | eslite0220@gmail.com（使用者 2026-07-05 確認） | DL-011：無多使用者，無 quota 需求；使用者自付 AI API 費用，配額由服務商端控 |
| 25 | Human Approval | 人工批准：高風險操作必須有人按下同意 | PARTIAL | 需求已定義「歸檔前確認對話框」（frontend-design 功能點 7．M8；task 7.5 前端）＋「未設 AI key 翻譯鈕停用＋tooltip」＋「重試此階段按鈕」＋「進入編輯器按鈕」——皆為 UI 端明示同意。**實作待 task 7.5（歸檔）／7.4（進度匯入 MergeSummary 對話框）** | — | 本 skill 定義的「Human Approval」為程式層閘門；UI 對話框是本專案最貼近的落點 |
| 26 | Backup / Restore | 備份還原：資料可回復到出事前 | PARTIAL | 需求定義：`.abopack` write/read（介面 9/10，M6）＋ progress export/import（介面 15/16，M6）；**實作待 task 7.1／7.4**。DB 檔本身可由使用者手動複製作為備份 | — | 使用者手動匯出 = 備份；MergeSummary 對話框透明化 applied/skipped/resetLessons（M6） |
| 27 | Soft Delete | 軟刪除：刪除先標記不真刪，可反悔 | PARTIAL | 需求定義：歸檔狀態機 ACTIVE→ARCHIVED→ACTIVE(<168h)/EXPIRED(≥168h)（M8）；**實作待 task 7.5**。DB schema `practice_group.archived_at` 欄位＋Clock 注入的 168h 判定測試（CT-08） | — | 歸檔 = soft delete；EXPIRED 為不可逆終態，仍不真刪 DB row（保留歷史稽核） |
| 28 | Immutable Log | 不可竄改紀錄：寫入後不能改的日誌 | APPROVED_NOT_APPLICABLE | — | eslite0220@gmail.com（使用者 2026-07-05 確認） | DL-012：無稽核情境；attempt 表可修改亦符合單人本機需求（M7 跨日零懲罰） |
| 29 | Deployment Gate | 部署閘門：沒通過檢查不能上線 | PARTIAL | 本地 test-based gate（domain purity + schema 結構斷言 + 62 tests）皆在 `flutter test` 一鍵可跑；發布 gate（M9 授權白名單掃描 CT-09、AT-09-05）**待實作**（task 8.2）；發布依免簽章路線＋Gatekeeper 略過說明文件（task 9.2） | — | 見 memory `decision_macOS發布免簽章路線`；9.1／9.2 落地前必須完成 8.2（授權掃描腳本） |
| 30 | Environment Separation | 環境分離：開發／測試／正式環境互不影響 | PARTIAL | dev sidecar 路徑 = `.local-tools/`（`SidecarPaths.dev()` env-var 覆寫＋絕對路徑 fallback＋`missingPaths()` fail-closed）；release sidecar 路徑 = `Contents/Resources/sidecar/`（task 2.1／9.1 前置，工廠方法 `SidecarPaths.bundled()` **未建**）；dev/release 共用同一份 SQLite（本機無 staging DB） | — | 見 memory `decision_sidecar_paths_dev_env_override`；task 2.1/9.1 前置補 `SidecarPaths.bundled()` |
| 31 | Network Policy | 網路政策：限制哪些服務能互相連線 | REJECTED_NEEDS_IMPLEMENTATION | — | eslite0220@gmail.com（使用者 2026-07-05 REJECT AI 判斷；要求實作） | DL-013：使用者裁決 REJECT——App 端 hardcode allowlist 只允許連 AI 服務商官方 domain（防 DNS poisoning/惡意端點）；實作追蹤 task 8.4.4（本次新增） |
| 32 | Allowlist / Blocklist | 白名單／黑名單：只允許或明確禁止特定對象 | IMPLEMENTED | 音檔格式白名單：`FfmpegDecoder.supportedExtensions = {mp3, wav, m4a, flac}`（Q8）＋`FfprobeDurationProbe.supportedExtensions`（共用常數）＋`app/lib/features/import_analysis/analysis_controller.dart` `_isSupportedAudio` 雙保險；white-list 驗證測試 `packages/infra/test/ffmpeg_decoder_test.dart`＋`ffprobe_duration_test.dart` | — | M9 授權白名單（GPL/AGPL/非商用擋掉）尚屬 12 Dependency Scanning／29 Deployment Gate 職責，不重複算 |
| 33 | Content Filter | 內容過濾：擋掉不允許的輸入或輸出內容 | APPROVED_NOT_APPLICABLE | — | eslite0220@gmail.com（使用者 2026-07-05 確認） | DL-014：無 UGC 情境；使用者字稿是自己輸入的自用資料，非不可信外部內容 |
| 34 | Prompt Injection Guard | 提示注入防護：防外部文字操縱 AI 行為 | REJECTED_NEEDS_IMPLEMENTATION | — | eslite0220@gmail.com（使用者 2026-07-05 REJECT AI 判斷；要求實作） | DL-015：使用者裁決 REJECT——未來拿線上歌詞/subtitle 當字稿的情境需先建 sanitizer 防線；實作追蹤 task 8.4.5（本次新增） |
| 35 | Tool Permission | 工具權限：限制 AI agent 能呼叫哪些工具 | PARTIAL | AI coding agent（Claude Code）於本專案內開發時，能呼叫的工具由 Claude Code settings/permissions 控制（互動 approval）；**未配置目錄白名單／deny 規則**（例：拒絕讀取其他 `spec-*/memory/`——見項 37）。app 內無 AI agent 執行 tool 動作（AIService 僅呼叫翻譯 API 為單一函式端點，非 tool-calling） | — | 本專案不是 agent tool 型；若未來 AIService 擴至 tool-calling 才需重評 |
| 36 | DLP | 資料外洩防護：防敏感資料被送出系統 | PARTIAL | M10 隱私防線：attempt 表**結構上無音訊欄位**（`db_schema_test.dart` 斷言）；`.abopack` 匯出**不含 API key**（AT-07-05；待 task 7.1 掃描驗證 CT-10）；錄音**用完即刪**（`RecordingComparator.compare` finally 刪錄音，AT-06-02，task 6.1 TDD 先紅）；AIService **不得觸碰音訊**（介面設計限制，M10） | — | 結構防線＋測試斷言即最硬 DLP；CT-10 兩項掃描（磁碟無錄音、pack 無 key 明文）待 6.1／7.1 落地 |
| 37 | Project Memory Isolation | 專案記憶隔離（套件預置）：`spec-*/memory/` 僅供本專案任務讀寫，其他專案不得調用（憲法 C8） | PARTIAL | 憲法 C8 明訂於 `02_Memory/constitution.md`；每個 skill 的「啟動程序」步驟 4 明訂「禁止讀取其他 `spec-*/memory/`」；本專案記憶落 `spec-syllable-repeater/memory/`。**Claude Code 工具層 sandbox 目錄白名單／`deny` 規則未配置**（規則層有；工具強制執行層未有） | — | 目前靠 AI 遵守憲法＋每 skill 啟動時逐項確認；升級為工具強制的落點：Claude Code `settings.json` 加 `permissions.deny` 規則拒絕讀其他 `spec-*/memory/`，屬 universal 設定範疇，本專案不獨立處理 |

<!-- 第 37 項為本套件預置的專案特有限制；其餘專案特有限制可從 38 起加行；AI 不得刪除以上任何一行。 -->

## 狀態統計（每次更新後重算）

| 狀態 | 數量 |
|------|------|
| IMPLEMENTED | 5 |
| PARTIAL | 17 |
| NOT_APPLICABLE_PENDING_HUMAN_REVIEW | 0 |
| APPROVED_NOT_APPLICABLE | 10 |
| BLOCKED | 0 |
| REJECTED_NEEDS_IMPLEMENTATION | 5 |
| NOT_REVIEWED（交付前必須為 0） | 0 |

## 使用者裁決紀錄（2026-07-05）

| 裁決 | 條目 |
|---|---|
| APPROVED_NOT_APPLICABLE（10 條） | #4 API Schema／#10 CODEOWNERS／#15 RBAC／#16 ABAC／#17 Tenant Isolation／#18 RLS／#21 KMS／#24 Quota／#28 Immutable Log／#33 Content Filter |
| REJECTED_NEEDS_IMPLEMENTATION（5 條） | #9 Branch Protection／#22 Audit Log／#23 Rate Limit／#31 Network Policy／#34 Prompt Injection Guard |

批准人／請求人：使用者 eslite0220@gmail.com（於 2026-07-05 逐條裁決確認）。REJECTED 5 條之實作追蹤 task 8.4.1–8.4.5（見 `task-split.md`）；review／archive 前必須全數落地為 IMPLEMENTED 或 PARTIAL（附任務進度）。

## 交付條件備忘（本 matrix 尚未進入 review／archive 前務必檢核）

1. 15 條 `NOT_APPLICABLE_PENDING_HUMAN_REVIEW` 皆須經使用者逐條裁決 → 改為 `APPROVED_NOT_APPLICABLE` + 批准人 = 使用者姓名／email + 裁決日期，或改為 `REJECTED_NEEDS_IMPLEMENTATION` 回頭實作。**AI 不得自批**。
2. 1 條 `BLOCKED`（項 7 Git Hook）待使用者決定 git init 走向後解 block。
3. 17 條 `PARTIAL` 於 `task-split.md` 有對應任務可追蹤；review／archive 前確認全數落地或明示延後階段。
4. `fullstack-code-review` 步驟 2 第 9 項會核對本表完整性；`project-archive` 部署驗收檢查第 9 項會確認 matrix 無 `NOT_REVIEWED` 殘留與人類批准痕跡。
