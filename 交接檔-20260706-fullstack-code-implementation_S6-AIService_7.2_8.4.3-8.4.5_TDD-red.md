# 交接檔 - 2026-07-06 - fullstack-code-implementation / S6 AIService 7.2 + hard-guardrails 8.4.3-8.4.5 TDD-red

> 產出日期：2026-07-06（Asia/Taipei）
> 專案根目錄：`/Users/karen_files/vibercoding project/syllable repeater`
> 目前階段：`fullstack-code-implementation` / **S6-1 已完成；S6-2 已建立並確認 TDD-red，尚未實作**
> 用途：讓新 session AI agent 接手 S6-2，不重做 7.1，直接從 AIService missing symbols 實作。

## 0. 一句話結論

S0/S1a/S1b/S1c、hard-guardrails bootstrap、S2 PracticeEngine + FP4、S3 exportStep/exportMerged + FP5、S4 ProsodyAnalyzer + FP3、S5 RecordingComparator + FP4、S6-1 LessonPackEngine 7.1 `.abopack` write/read 皆已完成。S6-2 已新增 `packages/domain/test/ai_service_test.dart` 並確認紅測：目前因 `AIService`、`AiClient`、`SecureStore`、`AiProviderConfig`、`AiRateLimit` 等符號尚未存在而編譯失敗。下一棒請從實作 Domain AIService ports/value types 開始，並同步落地 hard-guardrails #23/#31/#34 的自動拒絕測試。

## 1. 新 session 必讀順序

1. 共通記憶與偏好：
   - `/Users/karen_files/vibercoding project/02_Memory/constitution.md`
   - `/Users/karen_files/vibercoding project/02_Memory/preferences.md`
   - `/Users/karen_files/vibercoding project/02_Memory/MEMORY.md`

2. 本專案 memory（Precision > Recall，建議挑 5 條）：
   - `spec-syllable-repeater/memory/workflow_lesson_pack_domain_zip_contenthash.md`
   - `spec-syllable-repeater/memory/decision_hard_guardrails_matrix_20260705.md`
   - `spec-syllable-repeater/memory/workflow_analysis_pipeline_domain_port_infra_adapter.md`
   - `spec-syllable-repeater/memory/workflow_domain_purity_ci_ready防線.md`
   - `spec-syllable-repeater/memory/workflow_flutter_workspace_dart_test_gotcha.md`

3. 本交接檔：
   - `/Users/karen_files/vibercoding project/syllable repeater/交接檔-20260706-fullstack-code-implementation_S6-AIService_7.2_8.4.3-8.4.5_TDD-red.md`

4. 上一份 S6 架構交接檔（必要時回查 S6 全局拆分）：
   - `/Users/karen_files/vibercoding project/syllable repeater/交接檔-20260706-fullstack-code-implementation_S6-LessonPackEngine_AIService_ProgressEngine_FP6_FP1_FP7.md`

5. S6-2 相關規格與設計：
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/requirement/requirement.md`
     - 重點讀：`REQ-07 課件封裝與譯文`，尤其 AT-07-02/04/06 與「AIService 僅處理文字，不得用於生成或示範音訊」。
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/design/backend-design.md`
     - 重點讀：`§3.2.5 LessonPackEngine｜REQ-07（含 AIService）`、`介面 11/12`、`ERR_AI_KEY_MISSING`、`ERR_AI_CALL_FAILED`。
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/task-split.md`
     - 重點讀：`7.2`、`8.4.3`、`8.4.4`、`8.4.5`。
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/execution-log.md`
     - 重點讀：`Task S6-1（LessonPackEngine .abopack write/read）`。
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/hard-limits-matrix.md`
     - 重點讀：#23 Rate Limit、#31 Network Policy、#34 Prompt Injection Guard；目前仍是 `REJECTED_NEEDS_IMPLEMENTATION`。

## 2. 目前實際狀態

### 2.1 已完成

- S0 / S1a / S1b / S1c 已完成。
- hard-guardrails bootstrap 與 checker / git hooks 已落地；checker 仍因 REJECTED guardrails 預期失敗。
- S2 PracticeEngine + FP4 播放已完成：
  - CT-01 / CT-02 TDD-red -> green。
  - `renderStep` 採「寫 WAV 檔 -> just_audio 播檔」。
  - 4.7 `singleSyllableStep` 與 editor chip 真播放已完成。
- S3 PracticeEngine export + FP5 匯出已完成。
- S4 ProsodyAnalyzer + FP3 韻律疊圖已完成。
- S5 RecordingComparator + FP4 錄音比對已完成。
- S6-1 LessonPackEngine 7.1 `.abopack` write/read 已完成：
  - 新增 `Lesson` / `Translation` / `PracticeConfig`。
  - 新增 `LessonPackEngine.write/read`。
  - `.abopack` 為 zip + JSON；`schemaVersion=1`；`contentHash` 寫入前重算。
  - pack entry 只用相對路徑；不含 key/secret/password；損毀 zip/JSON/缺音訊一律 `ERR_PACK_CORRUPTED`，不部分載入。
  - Domain 仍不 import `dart:io`、Flutter、infra、sidecar。

### 2.2 目前 in-progress：S6-2 TDD-red

已新增：

```text
packages/domain/test/ai_service_test.dart
```

紅測內容：

- AT-07-02：未設定 credential 時 `translate` 拋 `ERR_AI_KEY_MISSING`，且不呼叫外部 client。
- 已設定 credential 時呼叫 fake client，回傳 `Translation(source: ai)`。
- AT-07-04：fake client 失敗時回 `ERR_AI_CALL_FAILED`，不洩漏原始例外。
- AT-07-06：`AIService.mergeTranslation(existing: manual, incomingAi: ai)` 保留 manual；existing 為 null 時採 AI result。
- 8.4.3：rate limit 第 N+1 次立刻拒絕，且不呼叫外部 client；window 過後可再次呼叫。
- 8.4.4：baseUrl host 不在 allowlist 時拒絕，且不呼叫 client。
- 8.4.5：明顯 prompt injection 樣本拒絕，且不呼叫 client。

已確認紅測：

```text
flutter test packages/domain/test/ai_service_test.dart -> expected fail
```

紅測失敗原因：

```text
Type 'AIService' not found
Type 'AiClient' not found
Type 'AiRateLimit' not found
Type 'SecureStore' not found
Type 'AiClientResponse' not found
Type 'AiClientRequest' not found
Method not found: 'AiProviderConfig'
```

這是預期 TDD-red，不是回歸。下一棒第一件事是新增這些 Domain 層型別與實作，讓此單測轉綠。

### 2.3 驗證狀態

S6-1 收尾時已確認：

```text
flutter test packages/domain/test/lesson_pack_engine_test.dart -> 4/4 passed
flutter test packages/domain/test -> 54/54 passed
flutter analyze -> No issues found
git diff --check -> passed
python3 scripts/check_guardrails.py ... -> expected fail: 5 REJECTED
```

本交接前新增 S6-2 紅測後，當前狀態改為：

```text
flutter test packages/domain/test/ai_service_test.dart -> expected red / compilation failed
```

注意：在 AIService symbols 實作前，不要期待 `flutter test packages/domain/test` 全綠；紅測檔會讓 domain 全套失敗。實作後請先跑目標測試，再跑 domain 全套與 analyze。

### 2.4 Git 狀態

- S2～S6-1 的程式與文件變更仍在 working tree，尚未 commit。
- `packages/domain/test/ai_service_test.dart` 是 S6-2 TDD-red 新增檔。
- working tree 仍有大量 untracked 新增檔；新 session 第一個命令請跑：

```text
git status --short --untracked-files=all
```

- 不要只看 `git diff --stat`，它不會列出 untracked。
- 不要 revert 使用者或前一棒留下的未提交變更。

## 3. 下一棒動工順序

### S6-2-0：啟動前盤點

1. 讀本交接檔與 §1 的規格。
2. 跑 `git status --short --untracked-files=all`。
3. 讀目前紅測：

```text
packages/domain/test/ai_service_test.dart
```

4. 確認 `packages/domain/lib/domain.dart` 目前尚未 export AIService/ports。
5. 確認 `packages/domain/lib/src/errors.dart` 已有：

```text
ERR_AI_KEY_MISSING
ERR_AI_CALL_FAILED
```

### S6-2-1：新增 Domain ports / value types

建議新增：

```text
packages/domain/lib/src/ports/secure_store.dart
packages/domain/lib/src/ports/ai_client.dart
packages/domain/lib/src/ai/ai_service.dart
```

建議型別：

```text
abstract interface class SecureStore
abstract interface class AiClient
class AiProviderConfig
class AiRateLimit
class AiClientRequest
class AiClientResponse
class AIService
```

建議契約：

- `SecureStore.read/write` 只處理 key/value，不碰 Flutter/Keychain 實作。
- `AiClient.translate` 是外部 provider port；Domain 不 import `http`。
- `AiProviderConfig` 保存 `baseUrl` 與 `model`；不要在 Domain 寫死 provider SDK。
- `AiRateLimit` 保存 `maxRequests` 與 `window`；測試用 fake clock。
- `AiClientRequest` 攜帶 `baseUrl`、credential、model、text、targetLang。
- `AiClientResponse` 攜帶 translated text 與 optional modelName。

### S6-2-2：實作 AIService 行為

最低應滿足紅測：

- `configure(String credential, AiProviderConfig cfg)`：
  - credential 空白要拒絕。
  - 寫入 `SecureStore` key `ai.apiKey`。
  - 保存 provider config。
- `translate(String text, String targetLang)`：
  - 未設定 key/config 時丟 `DomainException(ErrorCodes.aiKeyMissing, ...)`。
  - 呼叫外部 client 前先做 hard guardrails：
    - rate limit：超限直接 `ERR_AI_CALL_FAILED`，不呼叫 client。
    - network policy：`https` 且 host 在 allowlist；否則 `ERR_AI_CALL_FAILED`，不呼叫 client。
    - prompt injection guard：明顯 injection 樣本 fail-closed，回 `ERR_AI_CALL_FAILED`，不呼叫 client。
  - client 失敗一律包成 `ERR_AI_CALL_FAILED`，不要洩漏 `socket down` 等原始例外。
  - 成功回 `Translation(source: TranslationSource.ai, modelName: response.modelName ?? cfg.model, createdAt: clock.now().toUtc())`。
- `mergeTranslation(existing, incomingAi)`：
  - existing 為 `source=manual` 時永遠保留 existing。
  - existing 為 null 或非 manual 時採 incoming AI。

### S6-2-3：驗證命令

請依序跑，Flutter/Dart 指令不要並行：

```text
dart format packages/domain/lib/src/ports/secure_store.dart packages/domain/lib/src/ports/ai_client.dart packages/domain/lib/src/ai/ai_service.dart packages/domain/lib/domain.dart packages/domain/test/ai_service_test.dart
flutter test packages/domain/test/ai_service_test.dart
flutter test packages/domain/test
flutter analyze
git diff --check
python3 scripts/check_guardrails.py spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/hard-limits-matrix.md
```

預期：

- `ai_service_test.dart` 要由紅轉綠。
- `flutter test packages/domain/test` 應恢復全綠，數量會大於 S6-1 的 54。
- `flutter analyze` 應 No issues。
- guardrails checker 若只完成 #23/#31/#34，仍可能因 #9/#22 失敗；這是預期，請在文件寫明剩餘項。

### S6-2-4：更新文件與 matrix

完成實作後同步更新：

```text
spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/task-split.md
spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/execution-log.md
spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/hard-limits-matrix.md
```

文件更新注意：

- `7.2` 屬 `[需要回報]`。若只完成 Domain ports + fake client tests，請不要宣稱真 HTTP/Keychain adapter 完成。
- `8.4.3` / `8.4.4` / `8.4.5` 若已由 `AIService.translate` 前置拒絕並有測試證據，可標示完成或至少從 `REJECTED_NEEDS_IMPLEMENTATION` 改為 `PARTIAL`，但落地位置與剩餘風險必須寫清楚。
- 若尚未建立真 AI infra adapter，matrix #23/#31/#34 建議先誠實標 `PARTIAL`；只有在未來真 call path 也證明必經此 AIService 時才標 `IMPLEMENTED`。
- 更新狀態統計時請重算數字，不要只改表格列。

## 4. 待回報 / 待拍板事項

- 7.2 外部服務商契約與 key 安全路徑仍需回報核對：
  - provider base URL / model 命名。
  - 是否先支援 OpenAI、Anthropic 或僅保留 config。
  - infra 真 adapter 何時加入 `http`。
  - app 真 SecureStore 何時加入 `flutter_secure_storage` / Keychain adapter。
- 8.4.2 Audit Log 仍是 `REJECTED_NEEDS_IMPLEMENTATION`，但不屬本 S6-2 紅測範圍；之後處理 ProgressEngine/settings 時再接較合理。
- #9 Branch Protection 需要 GitHub repo / main branch 狀態，不要用本機檔案假裝完成。
- `02_Memory/wiki/chronicle_syllable-repeater.md` 位於 workspace 可寫根之外；先前授權被系統拒絕。不要用繞路方式寫入。

## 5. 不要做的事

- 不要重做 7.1 `.abopack`；它已完成且已有測試。
- 不要跳過 `packages/domain/test/ai_service_test.dart` 的紅轉綠流程。
- 不要在未回報 provider/key 安全路徑前實作真 HTTP client 或真 Keychain adapter。
- 不要把 `http`、`flutter_secure_storage`、Flutter、`dart:io` 放進 `packages/domain`。
- 不要把 API key 寫進 `.abopack`、`.aboprogress`、DB、log、memory、測試 fixture 或交接檔。
- 不要讓 AIService 生成、示範或處理音訊；REQ-07 §0.1 禁止。
- 不要只改 hard-limits-matrix 狀態而沒有自動拒絕機制與測試證據。
- 不要關 macOS Sandbox；M9 是 9.1 release 前置，不是 S6-2 起手要處理的事。
- 不要把損毀 pack/progress 做部分載入；S6 後續 ProgressEngine 也必須整檔驗證後才套用。
- 不要 push；pre-push / guardrails 仍應因剩餘 REJECTED 阻擋。

## 6. 本機關鍵路徑

專案根目錄：

```text
/Users/karen_files/vibercoding project/syllable repeater
```

S6-2 目前紅測：

```text
packages/domain/test/ai_service_test.dart
```

S6-2 建議新增 / 修改：

```text
packages/domain/lib/src/ai/ai_service.dart
packages/domain/lib/src/ports/ai_client.dart
packages/domain/lib/src/ports/secure_store.dart
packages/domain/lib/domain.dart
spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/task-split.md
spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/execution-log.md
spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/hard-limits-matrix.md
```

S6-1 已完成且可沿用：

```text
packages/domain/lib/src/model/lesson.dart
packages/domain/lib/src/model/translation.dart
packages/domain/lib/src/model/practice_config.dart
packages/domain/lib/src/pack/lesson_pack_engine.dart
packages/domain/test/lesson_pack_engine_test.dart
```

共用 ports / helpers：

```text
packages/domain/lib/src/ports/clock.dart
packages/domain/lib/src/ports/file_io.dart
packages/domain/lib/src/errors.dart
```

## 7. 本 session 已寫入記憶 / 文件

本 session 已新增 S6-2 紅測：

```text
packages/domain/test/ai_service_test.dart
```

本交接檔新增：

```text
交接檔-20260706-fullstack-code-implementation_S6-AIService_7.2_8.4.3-8.4.5_TDD-red.md
```

本 session 未新增 project memory。若下一棒完成 AIService guardrails，建議新增一張 project memory，記錄「AIService guardrails 先在 Domain ports + fake tests 落地，真 HTTP/Keychain adapter 另行回報」。

全域 chronicle：

```text
/Users/karen_files/vibercoding project/02_Memory/wiki/chronicle_syllable-repeater.md
```

未更新。原因：`02_Memory` 位於本 workspace 可寫根之外，先前授權請求被系統拒絕；不要用繞路方式寫入。

## 8. 新 session 可直接複製的啟動提示

```text
請先讀 02_Memory/constitution.md、preferences.md、MEMORY.md，
再讀本專案 spec-syllable-repeater/memory/（Precision > Recall 挑 5 條相關），
接著讀 /Users/karen_files/vibercoding project/syllable repeater/交接檔-20260706-fullstack-code-implementation_S6-AIService_7.2_8.4.3-8.4.5_TDD-red.md。

目前階段 fullstack-code-implementation / S6 / AIService 7.2 + hard-guardrails 8.4.3-8.4.5。
本 session（2026-07-06）已完成 S6-1 LessonPackEngine 7.1 `.abopack` write/read；S6-1 收尾時 flutter analyze、domain 54/54、git diff --check 全綠；本 session 另已新增 S6-2 `packages/domain/test/ai_service_test.dart` 並確認 TDD-red，單測目前因 AIService/AiClient/SecureStore/AiRateLimit 等符號未實作而紅。
請切 fullstack-code-implementation skill，並因 #23/#31/#34 同步使用 hard-guardrails skill，按交接檔 §3 從 S6-2-1 實作 AIService Domain ports / value types 動工。

拍板：7.2 外部服務商契約與 key 安全路徑屬需要回報；下一棒先做 Domain ports + fake client/fake secure store + hard guardrail tests；AIService 僅處理文字、不碰音訊；manual translation 永遠優先。
不要：重做 7.1、跳過 `ai_service_test.dart` 紅轉綠、未回報就加真 HTTP/Keychain adapter、把 key 寫入 pack/progress/DB/log/test fixture、讓 AIService 生成或處理音訊、關 macOS Sandbox、只改 matrix 狀態但沒有自動拒絕測試。
```
