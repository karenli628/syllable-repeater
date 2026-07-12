# 交接檔 - 2026-07-06 - fullstack-code-implementation / S6 LessonPackEngine + AIService + ProgressEngine + FP6/FP1/FP7

> 產出日期：2026-07-06（Asia/Taipei）
> 專案根目錄：`/Users/karen_files/vibercoding project/syllable repeater`
> 目前階段：`fullstack-code-implementation` / **S5 code 面完成且輕量門檻綠；S6 尚未開始**
> 用途：讓新 session AI agent 接手 S6；亦作本 session 收尾與續接錨點。

## 0. 一句話結論

S0/S1a/S1b/S1c、hard-guardrails、S2 PracticeEngine + FP4 播放、S3 exportStep/exportMerged + FP5 匯出、S4 ProsodyAnalyzer + FP3 韻律疊圖、S5 RecordingComparator + FP4 錄音比對皆已完成。S5 收尾後 `flutter analyze`、domain/infra/app tests 全綠；`check_guardrails.py` 仍因 5 條使用者裁決為 `REJECTED_NEEDS_IMPLEMENTATION` 的 guardrails 預期失敗（#9/#22/#23/#31/#34）。下一棒請從 S6 的 `7.1 .abopack write/read` TDD-red 起手，之後再接 AIService、ProgressEngine、前端 FP6/FP1/FP7。

## 1. 新 session 必讀順序

1. 共通記憶與偏好：
   - `/Users/karen_files/vibercoding project/02_Memory/constitution.md`
   - `/Users/karen_files/vibercoding project/02_Memory/preferences.md`
   - `/Users/karen_files/vibercoding project/02_Memory/MEMORY.md`

2. 本專案 memory（Precision > Recall，建議挑 5 條）：
   - `spec-syllable-repeater/memory/workflow_export_ct03_domain_infra_fp5.md`
   - `spec-syllable-repeater/memory/workflow_analysis_pipeline_domain_port_infra_adapter.md`
   - `spec-syllable-repeater/memory/workflow_domain_purity_ci_ready防線.md`
   - `spec-syllable-repeater/memory/workflow_flutter_workspace_dart_test_gotcha.md`
   - `spec-syllable-repeater/memory/workflow_切片對照與schema確認解套.md`

3. 本交接檔：
   - `/Users/karen_files/vibercoding project/syllable repeater/交接檔-20260706-fullstack-code-implementation_S6-LessonPackEngine_AIService_ProgressEngine_FP6_FP1_FP7.md`

4. 上一份交接檔（必要時回查 S5 細節）：
   - `/Users/karen_files/vibercoding project/syllable repeater/交接檔-20260706-fullstack-code-implementation_S5-RecordingComparator_FP4錄音比對.md`

5. S6 相關規格與設計：
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/requirement/requirement.md`
     - 重點讀：`REQ-07 課件封裝與譯文`、`REQ-08 練習進度與 SRS`、`REQ-09 跨平台兼容性架構約束`
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/design/backend-design.md`
     - 重點讀：`§3.1.1 Lesson / PracticeGroup / Attempt / Translation`、`§3.1.2 Drift schema`、`§3.1.3 SRS/Archive 狀態機`、`§3.2.5 LessonPackEngine / AIService`、`§3.2.6 ProgressEngine`
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/design/frontend-design.md`
     - 重點讀：功能點 1 library、功能點 6 pack_translate、功能點 7 progress_settings，以及 PracticeScreen 的 SettleBar
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/task-split.md`
     - 重點讀：`7.1`～`7.6`、FP6、FP1、FP7、`8.4.1`～`8.4.5`
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/execution-log.md`
     - 重點讀：Task S5 收尾紀錄與目前輕量門檻狀態
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/hard-limits-matrix.md`
     - 重點讀：剩餘 5 條 `REJECTED_NEEDS_IMPLEMENTATION`

## 2. 目前實際狀態

### 2.1 已完成

- S0 / S1a / S1b / S1c 已完成。
- hard-guardrails bootstrap 與 checker / git hooks 已落地；目前 checker 預期因 5 條 REJECTED 失敗。
- S2 PracticeEngine + FP4 播放已完成：
  - CT-01 / CT-02 TDD-red -> green。
  - `renderStep` 與播放路徑採「寫 WAV 檔 -> just_audio 播檔」。
  - 4.7 `singleSyllableStep` 與 editor chip 真播放已完成。
- S3 PracticeEngine export + FP5 匯出已完成：
  - CT-03/M3 靜音規則 TDD-red -> green。
  - Domain 純 PCM assembly；infra `PracticeExporter` 負責 MP3 / FFmpeg / atomic write。
  - UI 匯出對話框與 fake provider tests 已完成。
- S4 ProsodyAnalyzer + FP3 韻律疊圖已完成：
  - rhythm/intensity/stress/pitch extraction。
  - pitch unavailable 可降級，NaN/invalid 音節灰底。
- S5 RecordingComparator + FP4 錄音比對已完成：
  - Domain `ComparisonResult`、`OverlayData`、`RecordingAudioSource` port、`RecordingComparator`。
  - Infra `FileRecordingAudioSource` 讀 WAV PCM 16-bit mono 並刪除錄音。
  - App `PracticeRecorder`、`PracticeComparisonService`、`PracticeController` 錄音狀態、`RecordPanel`、`OverlayChart`、PracticeScreen 接線。
  - macOS 已補 `NSMicrophoneUsageDescription` 與 `com.apple.security.device.audio-input=true`；未更動 `com.apple.security.app-sandbox`。
  - `record` plugin 延遲初始化，避免 `IndexedStack` hidden PracticeScreen 在 widget test 觸發 `MissingPluginException`。

### 2.2 尚未開始

- S6 後端 7.1～7.6：
  - `.abopack` write/read。
  - AIService configure/translate、manual override、key 不落地。
  - ProgressEngine settle/dueList/exportProgress/importProgress/archive/restore/reminderConfig。
- S6 前端：
  - FP6 課件儲存/開啟與譯文編輯。
  - FP1 課件庫/今日到期。
  - FP7 進度、SRS、設定。
  - PracticeScreen 的難度結算列 `SettleBar`。
- hard-guardrails 8.4.1～8.4.5：
  - #9 Branch Protection。
  - #22 Audit Log。
  - #23 Rate Limit。
  - #31 Network Policy。
  - #34 Prompt Injection Guard。
- task 2.1：FFmpeg LGPL release build / license notice。
- task 8.2：CT-01～CT-10 常駐整合與授權掃描。
- task 8.3：performance guardrail。
- task 9.1 / 9.2：macOS release readiness、M9 sandbox 前置、免簽章發布說明。

### 2.3 驗證狀態

S5 收尾後已跑：

```text
flutter analyze                         -> No issues found
flutter test packages/domain/test       -> 50/50 passed
flutter test packages/infra/test        -> 58/58 passed, 2 skipped sidecar integration tests
cd app && flutter test                  -> 42/42 passed
git diff --check                        -> passed
python3 scripts/check_guardrails.py ... -> expected fail: 5 REJECTED
```

Guardrails 失敗明細：

```text
#9  Branch Protection
#22 Audit Log
#23 Rate Limit
#31 Network Policy
#34 Prompt Injection Guard
```

### 2.4 Git 狀態

- S2～S5 的程式與文件變更仍在 working tree，尚未 commit。
- working tree 內有大量 untracked 新增檔；新 session 第一個命令請跑：

```text
git status --short --untracked-files=all
```

- 不要只看 `git diff --stat`，它不會列出 untracked。
- 不要 revert 使用者或前一棒留下的未提交變更。

## 3. S6 接續拆分

### S6-0：啟動前盤點

1. 讀本交接檔與 §1 的規格。
2. 跑 `git status --short --untracked-files=all`，確認沒有使用者新插入的變更。
3. 讀現有模型與 port：
   - `packages/domain/lib/src/ports/file_io.dart`
   - `packages/infra/lib/src/file_io_impl.dart`
   - `packages/infra/lib/src/db/app_database.dart`
   - `packages/domain/lib/domain.dart`
4. 確認 S6 需要的新 dependency：
   - 目前 `packages/infra` 已有 `drift` / `sqlite3` / `path`。
   - 尚未看到 `archive`、`http`、`flutter_secure_storage`；加入前先放在正確 package，並確認 license / M5。

### S6-1：7.1 `.abopack` write/read TDD-red

建議第一個紅測：

```text
packages/domain/test/lesson_pack_engine_test.dart
```

測項建議：

- `write -> read` 後 Lesson JSON 欄位等價，原音 bytes 位元級一致。
- `schemaVersion=1` 存在。
- `contentHash` 寫入前重算。
- `manifest.json` 與 pack 內路徑不含絕對路徑。
- `.abopack` 不含任何 key / secret 欄位。
- 損毀 zip / 損毀 JSON 拋 `ERR_PACK_CORRUPTED`，不得部分載入。

可能新增檔案：

```text
packages/domain/lib/src/model/lesson.dart
packages/domain/lib/src/model/translation.dart
packages/domain/lib/src/model/practice_config.dart
packages/domain/lib/src/pack/lesson_pack_engine.dart
packages/domain/test/lesson_pack_engine_test.dart
```

注意：

- Domain 不可 import `dart:io`、Flutter、infra、Process。
- 可沿用 `FileIo` port；真檔案寫入仍交 infra。
- 打包格式請用結構化 JSON / zip API，不要用字串拼接。
- 原子寫入要走 `FileIo.writeBytesAtomic` 的 temp -> rename 模式。

### S6-2：7.2 AIService + 8.4.3/8.4.4/8.4.5

AIService 觸及外部服務與 key，請先回報服務商契約與 key 安全路徑。可先用 fake client / fake secure store 寫 domain tests。

建議測項：

- 未設 key 時 `translate` 拋 `ERR_AI_KEY_MISSING`，手動譯文不受影響。
- AI 呼叫失敗拋 `ERR_AI_CALL_FAILED`，不阻斷 pack/manual 流程。
- manual translation 永遠覆蓋 late AI result。
- key 只進 SecureStore 介面，不寫入 `.abopack` / DB / log。
- rate limit：N+1 次呼叫回 rate-limit 類 `ERR_AI_CALL_FAILED`，且不呼叫外部 API。
- network policy：host 不在 allowlist 直接拒絕，不發 request。
- prompt injection guard：明顯 injection 樣本被 sanitizer 標註或拒絕；乾淨字稿不受影響。

可能新增檔案：

```text
packages/domain/lib/src/ai/ai_service.dart
packages/domain/lib/src/ports/secure_store.dart
packages/domain/lib/src/ports/ai_client.dart
packages/domain/test/ai_service_test.dart
packages/infra/lib/src/ai/
```

### S6-3：7.3～7.6 ProgressEngine + 8.4.2 Audit Log

現有 Drift schema 已有：

```text
lesson_registry
practice_group
srs_state
attempt
app_settings
```

ProgressEngine 建議測項：

- `settle(HARD/NORMAL/EASY)` 套用間隔序列 `[0,1,3,7,14,30]`。
- `dueList(now)` 只列 `nextDue <= now`，HARD 優先，無 OVERDUE / failed / penalty 欄位。
- `exportProgress/importProgress` 全檔驗證後交易套用。
- updatedAt 較新者覆寫；相等時冪等。
- contentHash 變更只 reset 該 Lesson，不動其他 Lesson。
- `archive -> restore` 167h 成功，169h 拋 `ERR_ARCHIVE_RESTORE_EXPIRED` 並不可逆。
- reminderConfig 預設 15/5/2，存 `app_settings`，不可硬編碼在 UI。
- settings/SRS 關鍵變更寫入輕量 audit log（#22）；若需新增 Drift table，請先確認 schema 變更策略，不要偷偷改 schema。

可能新增檔案：

```text
packages/domain/lib/src/progress/progress_engine.dart
packages/domain/lib/src/model/progress.dart
packages/domain/test/progress_engine_test.dart
packages/infra/lib/src/progress/
packages/infra/test/progress_repository_test.dart
```

### S6-4：前端 FP6 / FP1 / FP7 / SettleBar

建議在 domain/infra 綠後接：

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

## 4. 待拍板但不阻塞事項

- AIService 的外部服務商與 base URL/model 契約需回報核對；在拍板前可先以 `AiClient` fake/port 寫 tests。
- `archive` / `http` / `flutter_secure_storage` 等 dependency 尚未加入；新增前需核對 license 與 package 落點。
- 8.4.2 Audit Log 若採 Drift 新表，屬 schema 變更，需先向使用者確認實作方案。
- #9 Branch Protection 需要 GitHub repo / main branch 狀態，不能只靠本機檔案假裝完成。

## 5. 待補提醒

- 不要關 macOS Sandbox；M9 是 9.1 release 前置，不是 S6 起手要偷做的事。
- 不要把 key 寫進 `.abopack`、`.aboprogress`、DB、log、memory 或測試 fixture。
- 不要讓 AIService 生成、示範或處理音訊；REQ-07 §0.1 明確禁止。
- 不要把 `dart:io`、FFmpeg、Process、Flutter import 放進 `packages/domain`。
- 不要跳過 7.1 `.abopack` TDD-red；S6 起手先紅測再實作。
- 不要把損毀 pack/progress 做部分載入；必須整檔驗證後才套用。
- 不要在 schema 增加 overdue/failed/penalty 欄位；M7 要求跨日零懲罰。
- 不要 push；pre-push / guardrails 仍應因 5 條 REJECTED 阻擋。

## 6. 本機關鍵路徑

專案根目錄：

```text
/Users/karen_files/vibercoding project/syllable repeater
```

S6 大概率會新增 / 修改：

```text
packages/domain/lib/src/model/lesson.dart
packages/domain/lib/src/model/translation.dart
packages/domain/lib/src/model/practice_config.dart
packages/domain/lib/src/pack/lesson_pack_engine.dart
packages/domain/lib/src/ai/ai_service.dart
packages/domain/lib/src/progress/progress_engine.dart
packages/domain/lib/domain.dart
packages/domain/pubspec.yaml
packages/domain/test/lesson_pack_engine_test.dart
packages/domain/test/ai_service_test.dart
packages/domain/test/progress_engine_test.dart
packages/infra/lib/src/ai/
packages/infra/lib/src/progress/
packages/infra/pubspec.yaml
packages/infra/test/
app/lib/features/pack_translate/
app/lib/features/library/
app/lib/features/progress_settings/
app/lib/features/practice/widgets/settle_bar.dart
app/test/
```

現有可沿用：

```text
packages/domain/lib/src/ports/file_io.dart
packages/infra/lib/src/file_io_impl.dart
packages/infra/lib/src/db/app_database.dart
packages/domain/lib/src/model/comparison_result.dart
packages/domain/lib/src/model/practice_step.dart
packages/domain/lib/src/model/prosody.dart
packages/domain/lib/src/model/syllable.dart
packages/domain/lib/src/model/word.dart
```

## 7. 本 session 已寫入記憶 / 文件

本 session 已新增 project memory：

```text
spec-syllable-repeater/memory/pitfall_record_plugin_lazy_init_indexedstack.md
```

本 session 已更新文件：

```text
spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/task-split.md
spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/execution-log.md
spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/hard-limits-matrix.md
```

本交接檔新增：

```text
交接檔-20260706-fullstack-code-implementation_S6-LessonPackEngine_AIService_ProgressEngine_FP6_FP1_FP7.md
```

全域 chronicle：

```text
/Users/karen_files/vibercoding project/02_Memory/wiki/chronicle_syllable-repeater.md
```

未更新。原因：`02_Memory` 位於本 workspace 可寫根之外，先前授權請求被系統拒絕；不要用繞路方式寫入。

## 8. 新 session 可直接複製的啟動提示

```text
請先讀 02_Memory/constitution.md、preferences.md、MEMORY.md，
再讀本專案 spec-syllable-repeater/memory/（Precision > Recall 挑 5 條相關），
接著讀 /Users/karen_files/vibercoding project/syllable repeater/交接檔-20260706-fullstack-code-implementation_S6-LessonPackEngine_AIService_ProgressEngine_FP6_FP1_FP7.md。

目前階段 fullstack-code-implementation / S6 / LessonPackEngine 7.1 + AIService 7.2 + ProgressEngine 7.3-7.6 + FP6/FP1/FP7。
本 session（2026-07-06）已完成 S5 RecordingComparator + FP4 錄音比對；flutter analyze、domain 50/50、infra 58/58（2 skip）、app 42/42、git diff --check 全綠；guardrails checker 仍因 #9/#22/#23/#31/#34 預期失敗。
請切 fullstack-code-implementation skill，按交接檔 §3 從 S6-1 的 7.1 `.abopack` write/read TDD-red 動工。

拍板：S5 錄音檔 compare finally 刪除且 UI 不另存；macOS 只加 microphone usage/audio-input entitlement，未關 Sandbox；S6 仍需遵守 Domain port + Infra adapter、Domain purity、key 不落地。
不要：關 macOS Sandbox（M9 前置）、跳過 7.1 `.abopack` TDD-red、把 dart:io/Process/Flutter 放進 packages/domain、讓 AIService 生成或處理音訊、把 key 寫入 pack/progress/DB/log、把損毀 pack/progress 部分載入、繞過 guardrails 5 條 REJECTED。
```
