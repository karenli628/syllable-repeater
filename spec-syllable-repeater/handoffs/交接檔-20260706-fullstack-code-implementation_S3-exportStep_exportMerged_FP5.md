# 交接檔 - 2026-07-06 - fullstack-code-implementation / S3 exportStep/exportMerged + FP5

> 產出日期：2026-07-06（Asia/Taipei）
> 專案根目錄：`/Users/karen_files/vibercoding project/syllable repeater`
> 目前階段：`fullstack-code-implementation` / **S3 尚未動工（S2 code 面完成、全 test 綠、尚未 commit）**
> 用途：讓新 session AI agent 接手立即續作 S3；亦作本 session 若中途中斷的續接錨點。

## 0. 一句話結論

S2 PracticeEngine 4.1-4.4、4.7、WAV encoder、FP4 播放已完成且 `flutter analyze`、domain/infra/app tests 全綠；目前 working tree 尚未 commit。下一個新 session 請從 S3-1：task 4.5 的 TDD-red 匯出靜音規則測試開始，接著做 4.6 exportStep/exportMerged 與 FP5 匯出對話框。

## 1. 新 session 必讀順序

1. 共通記憶與偏好：
   - `/Users/karen_files/vibercoding project/02_Memory/constitution.md`
   - `/Users/karen_files/vibercoding project/02_Memory/preferences.md`
   - `/Users/karen_files/vibercoding project/02_Memory/MEMORY.md`

2. 本專案 memory（Precision > Recall，挑 5 條相關）：
   - `spec-syllable-repeater/memory/workflow_practice_engine_tdd_ct01_ct02.md`
   - `spec-syllable-repeater/memory/workflow_just_audio_write_file_fake_backend_fp4.md`
   - `spec-syllable-repeater/memory/decision_zero_crossing_search_window_10ms.md`
   - `spec-syllable-repeater/memory/workflow_analysis_pipeline_domain_port_infra_adapter.md`
   - `spec-syllable-repeater/memory/workflow_flutter_workspace_dart_test_gotcha.md`

3. 本交接檔：
   - `/Users/karen_files/vibercoding project/syllable repeater/交接檔-20260706-fullstack-code-implementation_S3-exportStep_exportMerged_FP5.md`

4. S3 相關規格與設計：
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/requirement/requirement.md`
     - 重點讀：`§2.5 M1/M3`、`§12 CT-01/CT-03`、`REQ-04 AT-04-01～AT-04-06`
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/design/backend-design.md`
     - 重點讀：`§3.2.2 PracticeEngine` 的 `exportStep` / `exportMerged`、M3 靜音規則
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/design/frontend-design.md`
     - 重點讀：功能點 5 匯出對話框 FP5
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/task-split.md`
     - 重點讀：`4.5`、`4.6`、`FP5`
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/execution-log.md`
     - 重點讀：最新 S2 完成紀錄
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/hard-limits-matrix.md`
     - 重點讀：目前仍有 5 條 REJECTED，pre-push 仍會被擋

## 2. 目前實際狀態

### 2.1 已完成

- S0 / S1a / S1b / S1c 已完成。
- hard-guardrails 已完成，並已落地 checker / git hooks；目前 checker 預期因 5 條 REJECTED 失敗。
- S2 PracticeEngine + FP4 播放已完成：
  - 4.1 / 4.2：`buildSteps` TDD-red -> green，涵蓋 CT-02。
  - 4.3 / 4.4：`renderStep` TDD-red -> green，涵蓋 CT-01。
  - S2-5：WAV encoder 完成。
  - 4.7：`singleSyllableStep` 與 editor chip 真實播放完成。
  - FP4：`PracticePlayer` 走「寫 WAV 檔 -> just_audio 播檔」，搭配 `PracticeController` / `PracticeScreen`。

### 2.2 驗證狀態

最新 S2 驗證結果：

```text
flutter analyze                         -> No issues found
flutter test packages/domain/test       -> 39/39 passed
flutter test packages/infra/test        -> 51/51 passed, 2 skipped sidecar integration tests
cd app && flutter test                  -> 27/27 passed
python3 scripts/check_guardrails.py ... -> expected fail: 5 REJECTED
```

guardrails checker 的 5 條 REJECTED 是預期狀態；M9 / release / sandbox 前置完成前不要 push。

### 2.3 Git 狀態

- 最新 commit 仍是 `416e6e0 feat(s1c): demucs.cpp 分離契約接入...`。
- S2 實作、測試、任務紀錄、memory 更新都還在 working tree，尚未 commit。
- 下一棒不要假設 S2 已在 Git commit 裡；請先 `git status --short` 看現況。

### 2.4 尚未完成

- S3：4.5 / 4.6 exportStep/exportMerged + FP5 匯出對話框。
- S4：prosody / timing / stress / pause derived metrics。
- S5：錄音與比較。
- S6：難度結算、session progress、最終整合。
- task 2.1：FFmpeg LGPL release build / license notice。
- task 8.2：license scanner。
- task 8.3：performance guardrail。
- task 8.4.1-8.4.5：hard-guardrails 剩餘補強。
- task 9.1 / 9.2：release readiness、macOS Sandbox M9。

## 3. S3 拆分

### S3-1：TDD-red 匯出靜音規則測試（task 4.5）

目標：先寫 failing tests，不先補 implementation。

建議測試位置：

- `packages/domain/test/practice_export_test.dart`

必要測項：

- `thank you very much`、N=3、全 5 steps merged export。
- silence gaps 必須等於前一步 `totalDurationMs`，例如：
  - step 1 後 gap = step 1 total duration = 1200ms
  - step 2 後 gap = step 2 total duration = 1800ms
  - 以此類推
- 誤差以 sample count 或 duration 換算，需符合 CT-03 / M3 的 ±20ms。
- single-step merged export 不得在檔尾補靜音。
- last step 後不得補 trailing silence。

完成條件：

- 新測試在尚未實作 export assembly 前應紅燈。
- 不要跳過 CT-03 TDD-red。

### S3-2：先處理 domain / infra 邊界

backend-design 目前把 `exportStep` / `exportMerged` 寫在 `PracticeEngine` 下，且描述包含 FFmpeg、檔案輸出、temp -> atomic move。但既有 M5 與目前測試要求 domain 保持純 Dart，不應把 `dart:io`、`Process`、FFmpeg runner 放進 `packages/domain`。

建議下一棒採用的落點：

- Domain：只做可測的純規則與 PCM 組裝，例如 `renderMerged` / export assembly helper，輸出 PCM bytes、duration、`silenceGapsMs`。
- Infra / App service：負責 FFmpeg MP3 encode、temp file、atomic move、reentry lock、destination error mapping。

這樣能同時守住 M3 靜音規則與 M5 domain purity。

### S3-3：實作 export audio assembly（task 4.6 的 domain 部分）

目標：

- `exportStep` 語意：單一 step 沿用 `renderStep` 原聲 copy 路徑，不做生成/重合成。
- `exportMerged` 語意：多個 step 串接，中間插入「上一 step 總時長」的 silence。
- silence 用 sample count 產生，不靠浮點累積。
- 回傳 `silenceGapsMs`，並確保單步或最後一步沒有 trailing silence。

注意：

- 可以重用 S2 已完成的 `PracticeStep`、`PracticeEngine.renderStep`、WAV encoder 測試思路。
- CT-01 / CT-02 既有測試不可退化。

### S3-4：實作 MP3 export adapter（task 4.6 的 infra/app 部分）

目標：

- 將 domain 產出的 PCM/WAV 送入 FFmpeg MP3 encode。
- 使用 temp path -> atomic move。
- 同一 destination path 重入時拒絕，對應 `ERR_EXPORT_IN_PROGRESS`。
- destination 不可寫時回 `ERR_EXPORT_DEST_UNWRITABLE`。
- 不支援 mp3 以外格式。

注意：

- 不要把 FFmpeg / Process / file IO 寫進 `packages/domain`。
- 若目前 infra 既有 sidecar runner / fake backend pattern 可重用，優先沿用。
- FFmpeg LGPL release build / license notice 屬 task 2.1，S3 可留下待辦，但不要把 release 合規誤當已完成。

### S3-5：FP5 匯出對話框

目標：

- 建立匯出對話框與最小 usable flow。
- 支援步驟 checklist。
- 未勾選任何步驟時匯出 disabled。
- 匯出中 disabled，且 reentry 對應 `ERR_EXPORT_IN_PROGRESS`。
- destination unwritable 顯示錯誤並保留選取狀態。

注意：

- FP5 只做匯出；不要做 S5 錄音比對，也不要做 S6 難度結算。
- macOS Finder reveal / GUI open 若要實測，需留意 sandbox / approval，不要在無必要時引入。

### S3-6：驗證與紀錄

建議跑：

```text
flutter analyze
flutter test packages/domain/test
flutter test packages/infra/test
cd app && flutter test
python3 scripts/check_guardrails.py spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/hard-limits-matrix.md spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/decision-log.md
```

預期：

- analyze / domain / infra / app tests 應全綠。
- guardrails checker 在剩餘 5 條 REJECTED 未處理前仍應失敗；這不是 S3 的通過條件，但要在 execution-log 說清楚。

## 4. 待拍板但影響不大細節

目前沒有需要使用者立即拍板才能開工的事項。S3 可先照以下假設前進：

- 匯出核心音訊內容沿用 renderStep 原聲 copy 路徑。
- MP3 encode 放在 infra/app 邊界，不污染 domain。
- 匯出只支援 mp3。
- FP5 先做本機檔案匯出對話框，不延伸分享、雲端、批次格式設定。

若下一棒發現 backend-design 的 `PracticeEngine.exportStep(step, destPath)` 簽名與 domain purity 衝突，請保留設計意圖但調整實作分層，不要硬塞 IO 進 domain。

## 5. 待補提醒

- 不要關 macOS Sandbox；M9 前置完成前保持現狀。
- 不要 push；pre-push 仍應因 5 條 REJECTED 被擋。
- 不要跳過 CT-03 TDD-red。
- 不要用生成/合成音訊取代 renderStep 原聲 copy。
- 不要在 merged export 最後補 trailing silence。
- 不要把 FFmpeg、Process、File IO、platform channel 放進 `packages/domain`。
- S3 完成後要更新：
  - `task/task-split.md`
  - `logs/execution-log.md`
  - 必要 memory

## 6. 本機關鍵路徑

專案根目錄：

```text
/Users/karen_files/vibercoding project/syllable repeater
```

關鍵檔案：

```text
packages/domain/lib/src/practice/practice_engine.dart
packages/domain/lib/src/model/practice_step.dart
packages/domain/lib/src/audio/wav_encoder.dart
packages/domain/test/practice_build_steps_test.dart
packages/domain/test/wav_encoder_test.dart
app/lib/features/practice/practice_player.dart
app/lib/features/practice/practice_controller.dart
app/lib/features/practice/practice_screen.dart
app/test/practice/practice_controller_test.dart
app/test/practice/practice_screen_test.dart
```

S3 可能新增或修改：

```text
packages/domain/test/practice_export_test.dart
packages/domain/lib/src/practice/practice_export.dart
packages/infra/test/...export...
packages/infra/lib/src/...export...
app/lib/features/export/export_dialog.dart
app/test/export/export_dialog_test.dart
```

實際命名請優先跟現有架構與 import/export style 一致。

## 7. 本 session 已寫入記憶

S2 已新增 / 更新：

```text
spec-syllable-repeater/memory/workflow_practice_engine_tdd_ct01_ct02.md
spec-syllable-repeater/memory/workflow_just_audio_write_file_fake_backend_fp4.md
/Users/karen_files/vibercoding project/02_Memory/wiki/chronicle_syllable-repeater.md
```

本交接檔本身是給下一個新 session 的 S3 起點；尚未更新 memory。若下一棒完成 S3，請依照 memory 規則補寫可復用經驗。

## 8. 新 session 可直接複製的啟動提示

```text
請先讀 02_Memory/constitution.md、preferences.md、MEMORY.md，
再讀本專案 spec-syllable-repeater/memory/（Precision > Recall 挑 5 條相關），
接著讀 /Users/karen_files/vibercoding project/syllable repeater/交接檔-20260706-fullstack-code-implementation_S3-exportStep_exportMerged_FP5.md。

目前階段 fullstack-code-implementation / S3 / PracticeEngine 4.5-4.6 exportStep/exportMerged + FP5 匯出對話框。
本 session（2026-07-06）已完成 S2 PracticeEngine 4.1-4.4、4.7、WAV encoder、FP4 播放，flutter analyze/domain/infra/app tests 全綠；guardrails checker 仍因 5 條 REJECTED 預期不通過；S2 changes 尚未 commit。
請切 fullstack-code-implementation skill，按交接檔 §3 從 S3-1 TDD-red 匯出靜音規則測試（task 4.5）動工。

拍板：S3 以 CT-03/M3 靜音規則先測後寫；匯出內容必須沿用 renderStep 原聲 copy 路徑；FP5 只做匯出對話框，不做錄音比對/難度結算。
不要：把 FFmpeg/Process/File IO 寫進 packages/domain、跳過 CT-03 TDD、合併檔末尾加靜音、用生成/合成音訊、關 macOS Sandbox、push 遠端。
```
