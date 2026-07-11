# 交接檔 - 2026-07-06 - fullstack-code-implementation / S6 ProgressEngine 7.3 + 接 7.4-7.6 + FP6/FP1/FP7

> 產出日期：2026-07-06（Asia/Taipei）
> 專案根目錄：`/Users/karen_files/vibercoding project/syllable repeater`
> 目前階段：`fullstack-code-implementation` / **S6-1、S6-2、S6-3 Domain code 面已完成；下一棒從 7.4 進度匯入匯出 TDD-red 起手**
> 用途：讓新 session AI agent 接手 S6 後半段，不重做 `.abopack`、AIService Domain guardrails、ProgressEngine 7.3 settle/dueList。

## 0. 一句話結論

S0/S1a/S1b/S1c、hard-guardrails bootstrap、S2 PracticeEngine + FP4、S3 exportStep/exportMerged + FP5、S4 ProsodyAnalyzer + FP3、S5 RecordingComparator + FP4、S6-1 LessonPackEngine 7.1 `.abopack`、S6-2 AIService Domain ports + #23/#31/#34 自動拒絕測試、S6-3 ProgressEngine 7.3 `settle/dueList` 皆已完成到 Domain 可測層。最新驗證：`progress_engine_test.dart` 4/4、domain 65/65、`flutter analyze`、`git diff --check` 全綠；`check_guardrails.py` 仍因 #9 Branch Protection、#22 Audit Log 兩條 `REJECTED_NEEDS_IMPLEMENTATION` 預期失敗。下一棒請從 7.4 `exportProgress/importProgress` TDD-red 起手，接 7.5 歸檔狀態機與 7.6 reminderConfig；處理 #22 Audit Log 前須先回報 schema / 持久化方案。

## 1. 新 session 必讀順序

1. 共通記憶與偏好：
   - `/Users/karen_files/vibercoding project/02_Memory/constitution.md`
   - `/Users/karen_files/vibercoding project/02_Memory/preferences.md`
   - `/Users/karen_files/vibercoding project/02_Memory/MEMORY.md`

2. 本專案 memory（Precision > Recall，建議挑 5 條）：
   - `spec-syllable-repeater/memory/workflow_ai_service_domain_guardrails_ports.md`
   - `spec-syllable-repeater/memory/workflow_lesson_pack_domain_zip_contenthash.md`
   - `spec-syllable-repeater/memory/decision_hard_guardrails_matrix_20260705.md`
   - `spec-syllable-repeater/memory/workflow_domain_purity_ci_ready防線.md`
   - `spec-syllable-repeater/memory/workflow_flutter_workspace_dart_test_gotcha.md`

3. 本交接檔：
   - `/Users/karen_files/vibercoding project/syllable repeater/交接檔-20260706-fullstack-code-implementation_S6-ProgressEngine_7.3_接7.4-7.6_FP6_FP1_FP7.md`

4. 上一份交接檔（必要時回查 AIService 紅轉綠前的脈絡）：
   - `/Users/karen_files/vibercoding project/syllable repeater/交接檔-20260706-fullstack-code-implementation_S6-AIService_7.2_8.4.3-8.4.5_TDD-red.md`
   - `/Users/karen_files/vibercoding project/syllable repeater/交接檔-20260706-fullstack-code-implementation_S6-LessonPackEngine_AIService_ProgressEngine_FP6_FP1_FP7.md`

5. S6 後半段相關規格與設計：
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/requirement/requirement.md`
     - 重點讀：`REQ-08 練習進度與 SRS`、`REQ-07 課件封裝與譯文`、`REQ-09 跨平台兼容性架構約束`。
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/design/backend-design.md`
     - 重點讀：`§3.1.1 Lesson / PracticeGroup / Attempt / Translation`、`§3.1.2 Drift schema`、`§3.1.3 SRS/Archive 狀態機`、`§3.2.6 ProgressEngine`、錯誤碼 `ERR_ARCHIVE_RESTORE_EXPIRED` / `ERR_PROGRESS_CORRUPTED`。
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/design/frontend-design.md`
     - 重點讀：功能點 1 library、功能點 6 pack_translate、功能點 7 progress_settings、PracticeScreen 的 `SettleBar`。
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/task-split.md`
     - 重點讀：`7.4`、`7.5`、`7.6`、FP6、FP1、FP7、`8.4.2`。
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/execution-log.md`
     - 重點讀：S6-1/S6-2 紀錄；注意 7.3 文件同步若尚未補，請先補後再動 7.4。
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/hard-limits-matrix.md`
     - 重點讀：#9 Branch Protection、#22 Audit Log；#23/#31/#34 已有 Domain 自動拒絕測試證據。

## 2. 目前實際狀態

### 2.1 已完成

- S0 / S1a / S1b / S1c 已完成。
- hard-guardrails bootstrap 與 checker / git hooks 已落地；目前 checker 只剩 #9/#22 阻擋。
- S2 PracticeEngine + FP4 播放已完成：
  - CT-01 / CT-02 TDD-red -> green。
  - `renderStep` 採「寫 WAV 檔 -> just_audio 播檔」。
  - 4.7 `singleSyllableStep` 與 editor chip 真播放已完成。
- S3 PracticeEngine export + FP5 匯出已完成。
- S4 ProsodyAnalyzer + FP3 韻律疊圖已完成。
- S5 RecordingComparator + FP4 錄音比對已完成。
- S6-1 LessonPackEngine 7.1 `.abopack` write/read 已完成：
  - `Lesson` / `Translation` / `PracticeConfig` 與 `LessonPackEngine.write/read` 已落地。
  - `.abopack` 為 zip + JSON；`schemaVersion=1`；`contentHash` 寫入前重算；pack entry 只用相對路徑；不含 key/secret/password；損毀 zip/JSON/缺音訊一律 `ERR_PACK_CORRUPTED`。
- S6-2 AIService 7.2 Domain 可測部分已完成：
  - 新增 `SecureStore` / `AiClient` ports、`AiProviderConfig` / `AiRateLimit` / request-response value types、`AIService.configure/translate/mergeTranslation`。
  - 未設 key 回 `ERR_AI_KEY_MISSING`；client 失敗包成 `ERR_AI_CALL_FAILED`；manual translation 永遠勝出。
  - #23 rate limit、#31 network policy、#34 prompt injection guard 皆在 client 呼叫前 fail-closed，測試驗證不呼叫 fake client。
  - 尚未做真 HTTP provider adapter / 真 Keychain adapter，因外部服務商契約與 key 安全路徑仍需回報核對。
- S6-3 ProgressEngine 7.3 Domain 可測部分已完成：
  - 新增 `packages/domain/lib/src/model/progress.dart`
  - 新增 `packages/domain/lib/src/ports/progress_repository.dart`
  - 新增 `packages/domain/lib/src/progress/progress_engine.dart`
  - 更新 `packages/domain/lib/domain.dart` export。
  - 新增 `packages/domain/test/progress_engine_test.dart`。
  - `ProgressEngine.settle` 採 interval days `[0,1,3,7,14,30]`；HARD -1、NORMAL +1、EASY +2，皆 clamp 0..5。
  - `dueList(now)` 只列 `nextDue <= now` 且 `PracticeGroup.status == ACTIVE`；HARD 最高優先，同級依 `nextDue` 早者先。
  - M7/CT-07 已由測試鎖住：跨日未練只進 dueList，不寫失敗、逾期、懲罰，也不改 SRS state / attempt。

### 2.2 尚未完成

- 7.4 `exportProgress/importProgress`：
  - `.aboprogress` 或等效進度檔格式尚未實作。
  - 全檔驗證後交易套用、`updatedAt` upsert、相等冪等、`contentHash` 變更只 reset 該 Lesson 尚未實作。
- 7.5 archive / restore：
  - `ACTIVE -> ARCHIVED -> ACTIVE(<168h) / EXPIRED(>=168h)` 狀態機尚未實作。
  - 167h / 169h 邊界測試尚未寫。
- 7.6 reminderConfig：
  - 預設 15/5/2、讀寫 `app_settings`、不可硬編碼在 UI 尚未實作。
- 8.4.2 Audit Log：
  - 仍是 `REJECTED_NEEDS_IMPLEMENTATION`。
  - 涉及 schema 或設定持久化，必須先回報方案並取得使用者確認；不可偷偷新增 Drift table 或改 schema。
- 8.4.1 Branch Protection：
  - 需要 GitHub repo / main branch 狀態，不可用本機檔案假裝完成。
- Infra / App 後續：
  - 真 `ProgressRepository` Drift adapter 尚未接。
  - FP6 課件儲存/開啟與譯文編輯、FP1 library/dueList、FP7 進度設定、PracticeScreen `SettleBar` 尚未做。
  - AIService 真 HTTP provider adapter 與真 Keychain adapter 尚未做。

### 2.3 驗證狀態

本交接前最新已跑：

```text
flutter test packages/domain/test/progress_engine_test.dart -> 4/4 passed
flutter test packages/domain/test                      -> 65/65 passed
flutter analyze                                        -> No issues found
git diff --check                                      -> passed
python3 scripts/check_guardrails.py ...                -> expected fail: #9/#22
```

Guardrails checker 最新統計：

```text
限制項總數：37
APPROVED_NOT_APPLICABLE: 10
IMPLEMENTED: 5
PARTIAL: 20
REJECTED_NEEDS_IMPLEMENTATION: 2

違規：
#9 Branch Protection
#22 Audit Log
```

注意：本次交接前沒有重跑 `packages/infra/test` 或 `app/` 全套 widget tests；S6-3 只動 domain 層，最新保證是 domain 65/65 與 workspace analyze 全綠。若下一棒動 infra/app，請補跑對應測試。

### 2.4 Git 狀態

- S2～S6-3 的程式與文件變更仍在 working tree，尚未 commit。
- working tree 有大量 untracked 新增檔；新 session 第一個命令請跑：

```text
git status --short --untracked-files=all
```

- 不要只看 `git diff --stat`，它不會列出 untracked。
- 不要 revert 使用者或前一棒留下的未提交變更。

## 3. 下一棒動工順序

### S6-4-0：啟動前盤點

1. 讀本交接檔與 §1 的規格。
2. 跑 `git status --short --untracked-files=all`。
3. 讀 S6-3 目前檔案：

```text
packages/domain/lib/src/model/progress.dart
packages/domain/lib/src/ports/progress_repository.dart
packages/domain/lib/src/progress/progress_engine.dart
packages/domain/test/progress_engine_test.dart
packages/domain/lib/domain.dart
```

4. 若 `task-split.md` / `execution-log.md` / `hard-limits-matrix.md` 尚未補 7.3 狀態，請先補文件同步，再動 7.4。

### S6-4-1：7.4 `exportProgress/importProgress` TDD-red

建議先寫紅測，檔名可沿用：

```text
packages/domain/test/progress_engine_test.dart
```

或若測試變長，拆成：

```text
packages/domain/test/progress_import_export_test.dart
```

紅測建議：

- `exportProgress` 產出 schemaVersion / profileId / courseId / lessons / groups / srsStates / attempts / contentHash 摘要。
- 進度檔不含音訊 bytes、不含 AI key / secret / credential。
- 損毀 JSON / 缺必要欄位 / contentHash 不合格時拋 `ERR_PROGRESS_CORRUPTED`，不得部分套用。
- `importProgress` 先全檔驗證，驗證通過才交易套用。
- `updatedAt` 較新者覆寫；較舊者忽略；相等時冪等。
- `contentHash` 變更只 reset 該 Lesson 的 groups / srsState，不動其他 Lesson。
- MergeSummary 回報 created / updated / skipped / reset counts。

### S6-4-2：7.4 實作方向

建議保持 Domain 純度：

- Domain 定義 progress snapshot value types、merge policy 與 validation。
- 真檔案讀寫可沿用 `FileIo` port，不在 Domain import `dart:io`。
- 真 SQLite 交易由 infra adapter 實作，Domain 透過 repository port 表達需求。
- JSON 請用結構化 encode/decode；不要字串拼接。
- 任何 corrupt / schema mismatch 都 fail-closed，不可部分載入。

可能新增：

```text
packages/domain/lib/src/progress/progress_export.dart
packages/domain/lib/src/model/progress_snapshot.dart
packages/domain/test/progress_import_export_test.dart
```

### S6-5：7.5 archive / restore 狀態機

建議測項：

- `archive(groupId)`：ACTIVE -> ARCHIVED，寫 `archivedAt=clock.now()`。
- `restore(groupId)`：167h 成功回 ACTIVE 並清 `archivedAt`。
- `restore(groupId)`：169h 拋 `ERR_ARCHIVE_RESTORE_EXPIRED`，狀態變 EXPIRED 或保持不可恢復狀態，依設計檔確認。
- archived / expired 不出現在 dueList。
- Clock 必須可注入，不可用 `DateTime.now()` 直呼。

### S6-6：7.6 reminderConfig + #22 Audit Log

先做 7.6 前，請確認 #22 Audit Log 方案，因它是 hard-guardrails 剩餘阻擋項之一且可能牽涉 schema：

候選方案可回報給使用者：

- Drift 新表 `audit_log`：結構清楚，最符合 matrix #22；但涉及 schema，需要使用者確認。
- `app_settings` 內保存 JSON：改動小，但查詢性弱。
- 本機 sidecar-style log 檔：不碰 DB schema，但和 settings/SRS 交易一致性較弱。

確認後再 TDD-red：

- reminderConfig 預設 15/5/2。
- config 往返保存於 `app_settings`，UI 不硬編碼。
- 改 reminderConfig / SRS critical setting / AI key setting 後 audit log 有一筆。
- audit log 不記錄 API key 明文、不記錄音訊、不記錄錄音路徑。

### S6-7：接前端 FP6 / FP1 / FP7 / SettleBar

建議等 7.4～7.6 domain/infra 綠後再接：

```text
app/lib/features/pack_translate/
app/lib/features/library/
app/lib/features/progress_settings/
app/lib/features/practice/widgets/settle_bar.dart
```

UI 注意：

- FP6：手動譯文永遠可用；未設 key 時自動翻譯按鈕 disabled + tooltip；AI late result 不覆蓋 manual。
- FP1：課件庫與今日到期清單只顯示 ProgressEngine 計算結果，不在 UI 寫 SRS 規則。
- FP7：歸檔 168h 倒數、EXPIRED 恢復不可用、MergeSummary 對話框、AI key obscure 輸入送出即清空。
- PracticeScreen `SettleBar`：三顆難度鈕，呼叫介面 13，顯示 nextDue；不可用失敗/懲罰語彙。

## 4. 待回報 / 待拍板事項

- 8.4.2 Audit Log 方案必須回報：新增 Drift table、app_settings JSON、或本機檔案三選一，不能由 AI 自行拍板。
- 7.2 外部服務商契約與 key 安全路徑仍需回報核對；真 HTTP / Keychain adapter 不要先做。
- #9 Branch Protection 需要 GitHub repo / main branch 狀態。
- 7.5 `restore` 169h 後是「轉 EXPIRED」或「保持 ARCHIVED 但不可恢復」若設計檔語句不夠清楚，請先回報確認。
- `02_Memory/wiki/chronicle_syllable-repeater.md` 位於 workspace 可寫根之外；先前授權被系統拒絕。不要用繞路方式寫入。

## 5. 不要做的事

- 不要重做 7.1 `.abopack`、7.2 AIService Domain guardrails、7.3 ProgressEngine settle/dueList。
- 不要跳過 CT-06 / CT-08 / AT-08-* 的 TDD-red。
- 不要在未確認 #22 方案前新增或修改 Drift schema。
- 不要新增 overdue / failed / penalty 欄位或文案；M7 是跨日零懲罰。
- 不要讓 `dueList` 寫狀態；它必須是 pure query。
- 不要把 API key、secret、credential、音訊 bytes、錄音路徑寫入 `.abopack`、`.aboprogress`、DB、log、memory 或測試 fixture。
- 不要在 Domain import Flutter、infra、`dart:io`、http provider SDK。
- 不要關 macOS Sandbox；M9 是 9.1 release 前置，不是 S6 後半段要偷偷做的事。
- 不要 push；guardrails checker 仍因 #9/#22 阻擋。

## 6. 本機關鍵路徑

專案根目錄：

```text
/Users/karen_files/vibercoding project/syllable repeater
```

S6-3 已完成 ProgressEngine 相關：

```text
packages/domain/lib/src/model/progress.dart
packages/domain/lib/src/ports/progress_repository.dart
packages/domain/lib/src/progress/progress_engine.dart
packages/domain/test/progress_engine_test.dart
```

S6-2 已完成 AIService Domain 相關：

```text
packages/domain/lib/src/ai/ai_service.dart
packages/domain/lib/src/ports/ai_client.dart
packages/domain/lib/src/ports/secure_store.dart
packages/domain/test/ai_service_test.dart
```

S6-1 已完成 LessonPack 相關：

```text
packages/domain/lib/src/model/lesson.dart
packages/domain/lib/src/model/translation.dart
packages/domain/lib/src/model/practice_config.dart
packages/domain/lib/src/pack/lesson_pack_engine.dart
packages/domain/test/lesson_pack_engine_test.dart
```

任務 / guardrails 文件：

```text
spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/task-split.md
spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/execution-log.md
spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/hard-limits-matrix.md
```

## 7. 本 session 已寫入記憶 / 文件

本 session 已新增或累積的 S6-3 程式檔：

```text
packages/domain/lib/src/model/progress.dart
packages/domain/lib/src/ports/progress_repository.dart
packages/domain/lib/src/progress/progress_engine.dart
packages/domain/test/progress_engine_test.dart
```

本交接檔新增：

```text
交接檔-20260706-fullstack-code-implementation_S6-ProgressEngine_7.3_接7.4-7.6_FP6_FP1_FP7.md
```

本交接步驟未新增 project memory。若下一棒完成 7.4 / 7.5 / 7.6，建議新增一張 project memory，記錄 ProgressEngine 匯入匯出、M7 零懲罰、M8 168h 狀態機與 #22 Audit Log 的落地方案。

全域 chronicle：

```text
/Users/karen_files/vibercoding project/02_Memory/wiki/chronicle_syllable-repeater.md
```

未更新。原因：`02_Memory` 位於本 workspace 可寫根之外，先前授權請求被系統拒絕；不要用繞路方式寫入。

## 8. 新 session 可直接複製的啟動提示

```text
請先讀 02_Memory/constitution.md、preferences.md、MEMORY.md，
再讀本專案 spec-syllable-repeater/memory/（Precision > Recall 挑 5 條相關），
接著讀 /Users/karen_files/vibercoding project/syllable repeater/交接檔-20260706-fullstack-code-implementation_S6-ProgressEngine_7.3_接7.4-7.6_FP6_FP1_FP7.md。

目前階段 fullstack-code-implementation / S6 / ProgressEngine 7.4 進度匯入匯出 + 7.5 歸檔狀態機 + 7.6 reminderConfig（接 FP6/FP1/FP7）。
本 session（2026-07-06）已完成 S6-1 LessonPackEngine 7.1、S6-2 AIService Domain + #23/#31/#34 自動拒絕測試、S6-3 ProgressEngine 7.3 settle/dueList；最新 domain 65/65、flutter analyze 綠、git diff --check 綠；guardrails checker 仍因 #9/#22 預期失敗。
請切 fullstack-code-implementation skill；處理 #22 Audit Log 前同步使用 hard-guardrails skill，按交接檔 §3 從 S6-4-1 7.4 exportProgress/importProgress TDD-red 動工。

拍板：AIService 先 Domain ports + fake tests，真 HTTP/Keychain adapter 待 provider/key 路徑回報；ProgressEngine 7.3 採 [0,1,3,7,14,30]，HARD 優先，dueList 跨日零懲罰且不寫狀態。
不要：重做 7.1/7.2/7.3 Domain、跳過 CT-06/CT-08 TDD、未確認就新增 #22 audit schema、建立 overdue/failed/penalty 欄位、把 key/audio 寫入 pack/progress/DB/log、關 macOS Sandbox、push guardrails 尚未通過的分支。
```
