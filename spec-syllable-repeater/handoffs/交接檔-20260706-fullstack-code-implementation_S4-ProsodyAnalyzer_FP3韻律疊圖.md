# 交接檔 - 2026-07-06 - fullstack-code-implementation / S4 ProsodyAnalyzer + FP3 韻律疊圖

> 產出日期：2026-07-06（Asia/Taipei）
> 專案根目錄：`/Users/karen_files/vibercoding project/syllable repeater`
> 目前階段：`fullstack-code-implementation` / **S4 已開始但尚未完成（S2/S3 code 面完成、S4 domain 局部綠、尚未 commit）**
> 用途：讓新 session AI agent 接手完成 S4；亦作本 session 中途中斷的續接錨點。

## 0. 一句話結論

S2 PracticeEngine + FP4 播放、S3 exportStep/exportMerged + FP5 匯出已完成，S3 當時 `flutter analyze`、domain/infra/app tests 全綠；本 session 又已開始 S4，新增 `Prosody` / `ProsodyAnalyzer` / `prosody_analyzer_test.dart`，且 `flutter test packages/domain/test` 已從 41/41 推進到 45/45。S4 尚未完成：5.1 的停頓偵測/輸出決策未收斂，FP3 韻律疊圖與 pitch unavailable badge 尚未接上，S4 後尚未重跑完整 analyze/infra/app 門檻。

## 1. 新 session 必讀順序

1. 共通記憶與偏好：
   - `/Users/karen_files/vibercoding project/02_Memory/constitution.md`
   - `/Users/karen_files/vibercoding project/02_Memory/preferences.md`
   - `/Users/karen_files/vibercoding project/02_Memory/MEMORY.md`

2. 本專案 memory（Precision > Recall，挑 5 條相關）：
   - `spec-syllable-repeater/memory/workflow_practice_engine_tdd_ct01_ct02.md`
   - `spec-syllable-repeater/memory/workflow_just_audio_write_file_fake_backend_fp4.md`
   - `spec-syllable-repeater/memory/workflow_export_ct03_domain_infra_fp5.md`
   - `spec-syllable-repeater/memory/workflow_analysis_pipeline_domain_port_infra_adapter.md`
   - `spec-syllable-repeater/memory/workflow_flutter_workspace_dart_test_gotcha.md`

3. 本交接檔：
   - `/Users/karen_files/vibercoding project/syllable repeater/交接檔-20260706-fullstack-code-implementation_S4-ProsodyAnalyzer_FP3韻律疊圖.md`

4. S4 相關規格與設計：
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/requirement/requirement.md`
     - 重點讀：`REQ-05 韻律分析與視覺化`、`AT-05-01`～`AT-05-04`
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/design/backend-design.md`
     - 重點讀：`§3.2.3 ProsodyAnalyzer`、介面 7、pitch 降級
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/design/frontend-design.md`
     - 重點讀：功能點 3 editor、`prosody: AsyncValue<Prosody>`、`pitchAvailable=false` 顯示「音高不可用」
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/task-split.md`
     - 重點讀：`5.1`、`5.2`、功能點 3「單音節試聽與韻律疊圖顯示」
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/execution-log.md`
     - 重點讀：最新 S2/S3 完成紀錄；S4 尚未正式追加完成批次
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/hard-limits-matrix.md`
     - 重點讀：目前仍有 5 條 REJECTED，pre-push 仍會被擋

## 2. 目前實際狀態

### 2.1 已完成

- S0 / S1a / S1b / S1c 已完成。
- hard-guardrails 已完成，checker / git hooks 已落地；目前 checker 預期因 5 條 REJECTED 失敗。
- S2 PracticeEngine + FP4 播放已完成：
  - 4.1 / 4.2：`buildSteps` TDD-red -> green，涵蓋 CT-02。
  - 4.3 / 4.4：`renderStep` TDD-red -> green，涵蓋 CT-01。
  - S2-5：WAV encoder 完成。
  - 4.7：`singleSyllableStep` 與 editor chip 真實播放完成。
  - FP4：`PracticePlayer` 走「寫 WAV 檔 -> just_audio 播檔」，搭配 `PracticeController` / `PracticeScreen`。
- S3 PracticeEngine export + FP5 匯出已完成：
  - 4.5：CT-03/M3 匯出靜音規則 TDD-red -> green。
  - 4.6：domain 純 PCM assembly + infra `PracticeExporter` MP3 adapter。
  - FP5：`PracticeExportDialog`、步驟 checklist、file picker provider、錯誤保留選取狀態。

### 2.2 S4 已做但未收尾

已新增：

```text
packages/domain/lib/src/model/prosody.dart
packages/domain/lib/src/analysis/prosody_analyzer.dart
packages/domain/test/prosody_analyzer_test.dart
```

已修改：

```text
packages/domain/lib/domain.dart
spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/task-split.md
```

S4 domain 目前內容：

- `Prosody`：`rhythm`、`intensity`、`stress`、`pitchContour?`、`pitchAvailable`。
- `ProsodyAnalyzer.analyze(Pcm pcm, List<Syllable> syllables)`：
  - rhythm = 有效音節時長 / 平均有效音節時長。
  - intensity = 20ms window RMS 曲線。
  - stress = 音節 RMS energy × duration weight。
  - pitchContour = autocorrelation style pitch extraction；抽不到時 `pitchAvailable=false`、`pitchContour=null`。
  - 只讀 PCM，不改寫原 sample。
- `prosody_analyzer_test.dart` 已涵蓋：
  - AT-05-01：金標準 11 音節 rhythm/stress 長度、intensity、pitch 可用、原 PCM 不變。
  - rhythm 比例公式。
  - AT-05-02：零 PCM pitch unavailable，rhythm/intensity/stress 照常。
  - AT-05-03：sample 換算後無有效樣本的音節標記 NaN，不讓整體失敗。

尚未完成：

- 5.1 task 文字中的「停頓偵測」尚未明確輸出或測試；目前只透過 intensity/stress 隱含低能量，不能把 5.1 標 Done。
- 5.2 pitch 已有基本 autocorrelation 降級，但尚未經 frontend badge / overlay 驗收。
- FP3 韻律疊圖未接：
  - `EditorController` 尚未掛 `ProsodyAnalyzer`。
  - `WaveformCanvas` 尚未畫 pitch curve / stress markers。
  - UI 尚未在 `pitchAvailable=false` 顯示「音高不可用」。
  - 還沒有 AT-05-01/02 對應 widget test。

### 2.3 驗證狀態

S3 完成時的完整門檻：

```text
flutter analyze                         -> No issues found
flutter test packages/domain/test       -> 41/41 passed
flutter test packages/infra/test        -> 55/55 passed, 2 skipped sidecar integration tests
cd app && flutter test                  -> 31/31 passed
python3 scripts/check_guardrails.py ... -> expected fail: 5 REJECTED
```

S4 domain 局部驗證：

```text
flutter test packages/domain/test/prosody_analyzer_test.dart -> 4/4 passed
flutter test packages/domain/test                            -> 45/45 passed
```

注意：S4 domain 新增後尚未重跑 `flutter analyze`、`flutter test packages/infra/test`、`cd app && flutter test`。下一棒完成 FP3 後必須跑完整門檻。

### 2.4 Git 狀態

- 最新 commit 仍是 `416e6e0 feat(s1c): demucs.cpp 分離契約接入...`。
- S2、S3、S4 局部實作與文件更新都在 working tree，尚未 commit。
- `git status --short` 目前包含大量 untracked 新增檔；不要只看 `git diff --stat`，它不會列 untracked。
- 下一棒接手第一步請先跑 `git status --short`，確認使用者沒有新增其他變更。

目前重要 untracked 新增檔：

```text
app/lib/features/practice/
app/lib/features/export/export_dialog.dart
app/test/practice/
app/test/export/
packages/domain/lib/src/practice/
packages/domain/lib/src/model/practice_step.dart
packages/domain/lib/src/model/prosody.dart
packages/domain/lib/src/analysis/prosody_analyzer.dart
packages/domain/test/practice_build_steps_test.dart
packages/domain/test/practice_export_test.dart
packages/domain/test/prosody_analyzer_test.dart
packages/domain/test/wav_encoder_test.dart
packages/infra/lib/src/practice/practice_exporter.dart
packages/infra/test/practice_exporter_test.dart
spec-syllable-repeater/memory/workflow_export_ct03_domain_infra_fp5.md
spec-syllable-repeater/memory/workflow_just_audio_write_file_fake_backend_fp4.md
spec-syllable-repeater/memory/workflow_practice_engine_tdd_ct01_ct02.md
交接檔-20260706-fullstack-code-implementation_S3-exportStep_exportMerged_FP5.md
交接檔-20260706-fullstack-code-implementation_S4-ProsodyAnalyzer_FP3韻律疊圖.md
```

### 2.5 尚未完成

- S4：5.1 / 5.2 ProsodyAnalyzer 完整收尾 + FP3 韻律疊圖。
- S5：RecordingComparator、錄音與比較。
- S6：LessonPack / AIService / ProgressEngine / 難度結算 / 設定。
- task 2.1：FFmpeg LGPL release build / license notice。
- task 8.2：license scanner。
- task 8.3：performance guardrail。
- task 8.4.1-8.4.5：hard-guardrails 剩餘補強。
- task 9.1 / 9.2：release readiness、macOS Sandbox M9。

## 3. S4 接續拆分

### S4-1：補齊 ProsodyAnalyzer 5.1 的「停頓偵測」決策與測試

目前風險：REQ-05 重要邏輯列了「停頓：低能量區間偵測」，但 backend-design 的 `Prosody` 欄位表沒有 pause list，只有 `rhythm/intensity/stress/pitchContour/pitchAvailable`。下一棒不要直接把 5.1 勾 Done。

建議做法：

- 先讀 `requirement.md` REQ-05 與 `backend-design.md` 介面 7，決定停頓偵測落點。
- 若維持設計欄位不擴張，至少在 test / execution-log 說清楚低能量停頓如何由 intensity/stress 表達。
- 若新增 `pauseRegions` 或類似欄位，需同步：
  - `Prosody` model。
  - `prosody_analyzer_test.dart`。
  - UI overlay 用法。
  - task/execution-log 說明這是對 REQ-05 N3 的欄位補強。

必要測項：

- 一段含低能量 gap 的 PCM，停頓偵測結果穩定。
- 停頓偵測不可改寫 PCM。
- pitch unavailable 時停頓/rhythm/intensity/stress 仍可用。

### S4-2：處理 AT-05-03 的模型張力

現況：`Syllable` constructor 已禁止 `endMs <= startMs`，因此不能直接建立真正 0 長度音節。現有測試用低 sampleRate + 0..1ms 區間造成 sample index 換算後 0 samples，作為資料損毀近似案例。

下一棒要注意：

- 不要為了測 literal 0-length 而輕易放寬 `Syllable` invariant；那會影響 boundary engine 與既有測試。
- 若需要真正測 corrupted data，應考慮是否需要 raw DTO / parser 層測試，而不是削弱 domain model。
- 無論採哪條路，都要在 execution-log 寫清楚 AT-05-03 的落點。

### S4-3：接 EditorController 的 prosody state

目標：

- 將 `ProsodyAnalyzer` 掛進 editor flow。
- 當 analysis done 且有 `decodedPcm` + syllables 時，自動分析 prosody。
- 邊界拖動成功後，對更新後 syllables 重新分析。
- pitch unavailable 不進 error；UI 顯示 badge。

建議：

- 先看現有 `EditorController` state pattern，再決定是否照 frontend-design 寫 `AsyncValue<Prosody>`。
- 若引入 provider，建議建立 fake-able `prosodyAnalyzerProvider`，讓 widget/controller tests 不碰平台或檔案。
- 保持 domain 純 Dart：不要在 `packages/domain` 加 `dart:io`、FFmpeg、Process、Flutter import。

### S4-4：接 WaveformCanvas / FP3 韻律疊圖

目標：

- `WaveformCanvas` 在既有 waveform + boundary layer 上，選擇性畫：
  - pitch curve（`pitchAvailable=true` 且 `pitchContour != null`）。
  - stress markers。
  - invalid/NaN syllable 的灰階提示或安全跳過。
- `pitchAvailable=false` 時，隱藏 pitch curve 並在 editor UI 顯示「音高不可用」徽章。
- 不破壞既有 boundary dragging、undo、single syllable playback。

必要測項：

- AT-05-01：金標準 11 syllables 時 UI 能渲染 waveform + pitch overlay + 11 boundary lines（widget test 可先驗 smoke/state，不必做脆弱 pixel diff）。
- AT-05-02：pitch unavailable 時顯示「音高不可用」，不是 SnackBar/error。
- WaveformCanvas 傳入 NaN rhythm/stress 不 crash。
- 既有 editor controller / waveform canvas / practice playback tests 保持綠。

### S4-5：驗證與紀錄

完成 S4 後建議跑：

```text
flutter analyze
flutter test packages/domain/test
flutter test packages/infra/test
cd app && flutter test
python3 scripts/check_guardrails.py spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/hard-limits-matrix.md spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/decision-log.md
```

預期：

- analyze / domain / infra / app tests 應全綠。
- guardrails checker 在剩餘 5 條 REJECTED 未處理前仍應失敗；這不是 S4 的通過條件，但要在 execution-log 說清楚。

完成後要更新：

```text
spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/task-split.md
spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/execution-log.md
spec-syllable-repeater/memory/（必要時新增 S4 workflow/pitfall）
/Users/karen_files/vibercoding project/02_Memory/wiki/chronicle_syllable-repeater.md
```

## 4. 待拍板但不阻塞事項

目前沒有需要使用者立即拍板才能開工的事項；S4 可先照規格推進。

可能需要下一棒自行小心收斂的設計點：

- 「停頓偵測」是否擴充 `Prosody` 欄位，或維持為 intensity/stress 的可視化推導。
- frontend-design 寫 `prosody: AsyncValue<Prosody>`，但現有 code 以 Riverpod Notifier 自訂 state 為主；落地時以現有架構一致性優先，但要保留 loading/unavailable/error 的語意。

## 5. 待補提醒

- 不要把 S4 目前狀態標 Done；5.1/5.2/FP3 還沒完整收尾。
- 不要關 macOS Sandbox；M9 前置完成前保持現狀。
- 不要 push；pre-push 仍應因 5 條 REJECTED 被擋。
- 不要讓 `pitchAvailable=false` 變成 error；它是預期降級狀態。
- 不要跳過 AT-05-01/AT-05-02 的 frontend 驗收。
- 不要讓 ProsodyAnalyzer 生成、改寫或輸出音訊；REQ-05 只讀。
- 不要把 FFmpeg、Process、File IO、platform channel 放進 `packages/domain`。
- 不要為了 AT-05-03 直接破壞 `Syllable` 的 `endMs > startMs` invariant。

## 6. 本機關鍵路徑

專案根目錄：

```text
/Users/karen_files/vibercoding project/syllable repeater
```

S4 已新增 / 修改：

```text
packages/domain/lib/src/model/prosody.dart
packages/domain/lib/src/analysis/prosody_analyzer.dart
packages/domain/lib/domain.dart
packages/domain/test/prosody_analyzer_test.dart
spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/task-split.md
```

S4 下一棒大概率會修改：

```text
app/lib/features/editor/editor_controller.dart
app/lib/features/editor/editor_screen.dart
app/lib/features/editor/widgets/waveform_canvas.dart
app/test/editor/editor_controller_test.dart
app/test/editor/waveform_canvas_test.dart
app/test/e2e_pipeline_test.dart
```

S2/S3 已完成但尚未 commit 的關鍵檔：

```text
packages/domain/lib/src/practice/practice_engine.dart
packages/domain/lib/src/practice/practice_export_audio.dart
packages/domain/lib/src/practice/wav_encoder.dart
packages/domain/lib/src/model/practice_step.dart
packages/infra/lib/src/practice/practice_exporter.dart
app/lib/features/practice/practice_player.dart
app/lib/features/practice/practice_controller.dart
app/lib/features/practice/practice_screen.dart
app/lib/features/export/export_dialog.dart
```

## 7. 本 session 已寫入記憶 / 文件

S2/S3 已新增或更新：

```text
spec-syllable-repeater/memory/workflow_practice_engine_tdd_ct01_ct02.md
spec-syllable-repeater/memory/workflow_just_audio_write_file_fake_backend_fp4.md
spec-syllable-repeater/memory/workflow_export_ct03_domain_infra_fp5.md
/Users/karen_files/vibercoding project/02_Memory/wiki/chronicle_syllable-repeater.md
spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/execution-log.md
spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/task-split.md
```

S4 目前只把 `task-split.md` 的 5.1 標成 `InProgress 2026-07-06`，尚未寫 execution-log / memory。下一棒完成 S4 後再補，不要現在就把 S4 經驗寫成既成結論。

## 8. 新 session 可直接複製的啟動提示

```text
請先讀 02_Memory/constitution.md、preferences.md、MEMORY.md，
再讀本專案 spec-syllable-repeater/memory/（Precision > Recall 挑 5 條相關），
接著讀 /Users/karen_files/vibercoding project/syllable repeater/交接檔-20260706-fullstack-code-implementation_S4-ProsodyAnalyzer_FP3韻律疊圖.md。

目前階段 fullstack-code-implementation / S4 / ProsodyAnalyzer 5.1-5.2 + FP3 韻律疊圖。
本 session（2026-07-06）已完成 S2 PracticeEngine + FP4 播放、S3 exportStep/exportMerged + FP5 匯出；S3 完整門檻全綠。另已開始 S4 domain TDD-red→green，新增 Prosody/ProsodyAnalyzer/prosody_analyzer_test，domain tests 45/45；但 S4 尚未跑完整 analyze/infra/app，5.1 停頓偵測與 FP3 overlay 尚未完成。
請切 fullstack-code-implementation skill，按交接檔 §3 從 S4-1 補齊 ProsodyAnalyzer 5.1 停頓偵測/輸出決策與 frontend overlay 動工。

拍板：4.7 已順帶完成；renderStep 與播放路徑走「寫檔→just_audio 播檔」；S4 只讀 PCM，不生成/改寫音訊，pitch 抽不到要降級而非錯誤。
不要：把 dart:io/FFmpeg/Process 放進 packages/domain、關 macOS Sandbox、push 遠端、把 S4 半成品標 Done、跳過 AT-05-01/AT-05-02 frontend overlay TDD、讓 pitchAvailable=false 成為錯誤態。
```
