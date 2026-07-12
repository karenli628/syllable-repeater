# 交接檔 - 2026-07-06 - fullstack-code-implementation / S5 RecordingComparator + FP4 錄音比對

> 產出日期：2026-07-06（Asia/Taipei）
> 專案根目錄：`/Users/karen_files/vibercoding project/syllable repeater`
> 目前階段：`fullstack-code-implementation` / **S5 已開始但尚未完成（S0-S4 code 面完成且門檻綠；S5 domain/infra 目標綠，app 錄音 UI 半成品且 analyze 紅）**
> 用途：讓新 session AI agent 接手完成 S5；亦作本 session 中途中斷的續接錨點。

## 0. 一句話結論

S0/S1a/S1b/S1c、hard-guardrails、S2 PracticeEngine + FP4 播放、S3 exportStep/exportMerged + FP5 匯出、S4 ProsodyAnalyzer + FP3 韻律疊圖皆已完成，S4 完整門檻全綠。S5 已開始：`RecordingComparator`、`ComparisonResult`、`RecordingAudioSource` port、infra `FileRecordingAudioSource` 與測試已落地，目標測試 `recording_comparator_test.dart` + `recording_audio_source_test.dart` 為 7/7 綠；但 app 端 `practice_recording.dart` / `practice_controller.dart` 仍在半成品狀態，`flutter analyze` 目前因 `practice_controller.dart` 缺 `dart:async` import 產生 2 個錯誤，FP4 錄音面板/疊圖/mic 權限設定與 app tests 尚未完成。

## 1. 新 session 必讀順序

1. 共通記憶與偏好：
   - `/Users/karen_files/vibercoding project/02_Memory/constitution.md`
   - `/Users/karen_files/vibercoding project/02_Memory/preferences.md`
   - `/Users/karen_files/vibercoding project/02_Memory/MEMORY.md`

2. 本專案 memory（Precision > Recall，挑 5 條相關）：
   - `spec-syllable-repeater/memory/workflow_practice_engine_tdd_ct01_ct02.md`
   - `spec-syllable-repeater/memory/workflow_just_audio_write_file_fake_backend_fp4.md`
   - `spec-syllable-repeater/memory/workflow_analysis_pipeline_domain_port_infra_adapter.md`
   - `spec-syllable-repeater/memory/workflow_flutter_workspace_dart_test_gotcha.md`
   - `spec-syllable-repeater/memory/workflow_prosody_analyzer_intensity_overlay_fp3.md`

3. 本交接檔：
   - `/Users/karen_files/vibercoding project/syllable repeater/交接檔-20260706-fullstack-code-implementation_S5-RecordingComparator_FP4錄音比對.md`

4. S5 相關規格與設計：
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/requirement/requirement.md`
     - 重點讀：`REQ-06 錄音比對與差異疊圖`、`AT-06-01`～`AT-06-05`
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/design/backend-design.md`
     - 重點讀：`§3.2.4 RecordingComparator`、介面 8、CT-10/M10 刪錄音
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/design/frontend-design.md`
     - 重點讀：PracticeScreen = StepNavigator + PlayerBar + RecordPanel + OverlayChart + SettleBar；錄音中停用原音播放；切步/卸載丟棄暫存
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/task-split.md`
     - 重點讀：`6.1`、`6.2`、功能點 4「實作錄音比對面板與疊圖」
   - `spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/execution-log.md`
     - 重點讀：S2/S3/S4 完成紀錄；S5 尚未正式追加完成批次
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
  - FP4 播放：`PracticePlayer` 走「寫 WAV 檔 -> just_audio 播檔」。
- S3 PracticeEngine export + FP5 匯出已完成：
  - 4.5：CT-03/M3 匯出靜音規則 TDD-red -> green。
  - 4.6：domain 純 PCM assembly + infra `PracticeExporter` MP3 adapter。
  - FP5：`PracticeExportDialog`、步驟 checklist、file picker provider、錯誤保留選取狀態。
- S4 ProsodyAnalyzer + FP3 韻律疊圖已完成：
  - 5.1：rhythm/intensity/stress，停頓落在 low-energy intensity windows。
  - 5.2：pitch extraction + `pitchAvailable=false` 降級。
  - FP3：editor overlay 顯示 pitch curve、stress markers、invalid/NaN 音節灰底、音高不可用徽章。

### 2.2 S5 已做但未收尾

已新增 / 修改的 S5 domain：

```text
packages/domain/lib/src/model/comparison_result.dart
packages/domain/lib/src/ports/recording_audio_source.dart
packages/domain/lib/src/recording/recording_comparator.dart
packages/domain/test/recording_comparator_test.dart
packages/domain/lib/domain.dart
```

目前 domain 行為：

- `RecordingComparator.compare(userRecordingPath, syllables, step, originalPcm)`。
- 透過 `PracticeEngine.renderExportStep(step, originalPcm).pcm` 從整句原音切出 reference segment。
- 讀取使用者錄音 PCM 後，錄音長度 `< 200ms` 拋 `ERR_RECORDING_TOO_SHORT`。
- rhythmDelta：RMS curve DTW distance。
- intonationDelta：pitch contour DTW distance；抽不到 pitch 時不失敗。
- overlayData：`userWave`、`referenceWave`、`userPitch`、`referencePitch`、`diffRanges`。
- `score` 目前有回傳，但需求定義為 optional，後續 UI 不必強依賴。
- `finally` 一律呼叫 `audioSource.delete(userRecordingPath)`；Domain 不 import `dart:io`，仍符合 M5。

已新增 / 修改的 S5 infra：

```text
packages/infra/lib/src/practice/recording_audio_source.dart
packages/infra/test/recording_audio_source_test.dart
packages/infra/lib/infra.dart
```

目前 infra 行為：

- `FileRecordingAudioSource implements RecordingAudioSource`。
- 透過 `FileIo.readBytes/delete` 讀取與刪除錄音檔。
- WAV decoder 支援 RIFF/WAVE PCM 16-bit mono；格式不符映射 `ERR_DECODE_FAILED`。

已新增 / 修改的 S5 app 半成品：

```text
app/lib/features/practice/practice_recording.dart
app/lib/features/practice/practice_controller.dart
app/pubspec.yaml
app/macos/Flutter/GeneratedPluginRegistrant.swift
```

目前 app 半成品內容：

- `record: ^7.1.1` 已加入 `app/pubspec.yaml`，`flutter pub get` 已更新 plugin registrant。
- `PracticeRecorder` / `RecordPracticeRecorder` 已建立，使用 `AudioRecorder` 錄 WAV、100ms amplitude stream 做 level meter。
- `PracticeComparisonService` / `DomainPracticeComparisonService` 已建立，接 `RecordingComparator` + `FileRecordingAudioSource`。
- `PracticeController` 已新增 `PracticeRecordStatus`、`recordingLevel`、`ComparisonResult? comparison`、`startRecording()`、`stopRecording()`、`cancelRecording()`。
- `canPlay` 已在 recording 時關閉，符合錄音中原音播放置灰的方向。

尚未完成：

- `practice_controller.dart` 尚未 import `dart:async`，所以 `StreamSubscription` / `unawaited` analyze 會紅。
- 尚未新增 `record_panel.dart`、`overlay_chart.dart`。
- 尚未把 RecordPanel 掛進 `practice_screen.dart`。
- 尚未補 app controller/widget tests。
- 尚未補 macOS mic 權限 plist / entitlement。
- 尚未補 S5 execution-log / task-split 完成註記 / memory / chronicle。

### 2.3 驗證狀態

S4 完成時的完整門檻：

```text
flutter analyze                         -> No issues found
flutter test packages/domain/test       -> 46/46 passed
flutter test packages/infra/test        -> 55/55 passed, 2 skipped sidecar integration tests
cd app && flutter test                  -> 35/35 passed
python3 scripts/check_guardrails.py ... -> expected fail: 5 REJECTED
```

S5 domain/infra 目標驗證（2026-07-06 本交接前已重跑）：

```text
flutter test packages/domain/test/recording_comparator_test.dart packages/infra/test/recording_audio_source_test.dart -> 7/7 passed
```

S5 app 目前驗證：

```text
flutter analyze -> failed
```

目前 analyze 紅點：

```text
app/lib/features/practice/practice_controller.dart:90:3
  Undefined class 'StreamSubscription'

app/lib/features/practice/practice_controller.dart:104:7
  The method 'unawaited' isn't defined for the type 'PracticeController'
```

判斷：第一步先在 `practice_controller.dart` 補 `import 'dart:async';`，再跑 format/analyze；後續仍可能出現下一批 app 半成品錯誤，需逐一收斂。

### 2.4 Git 狀態

- 最新 commit：`8de5bfa docs(memory): 範本化新 session 啟動提示 8 段結構`。
- S2、S3、S4、S5 局部實作與文件更新都在 working tree，尚未 commit。
- `git status --short --untracked-files=all` 目前包含大量 untracked 新增檔；不要只看 `git diff --stat`，它不會列 untracked。
- 下一棒接手第一步請先跑 `git status --short --untracked-files=all`，確認使用者沒有新增其他變更。

目前 S5 重要 untracked / modified：

```text
M  app/pubspec.yaml
M  app/macos/Flutter/GeneratedPluginRegistrant.swift
M  packages/domain/lib/domain.dart
M  packages/infra/lib/infra.dart
?? app/lib/features/practice/practice_recording.dart
?? packages/domain/lib/src/model/comparison_result.dart
?? packages/domain/lib/src/ports/recording_audio_source.dart
?? packages/domain/lib/src/recording/recording_comparator.dart
?? packages/domain/test/recording_comparator_test.dart
?? packages/infra/lib/src/practice/recording_audio_source.dart
?? packages/infra/test/recording_audio_source_test.dart
?? 交接檔-20260706-fullstack-code-implementation_S5-RecordingComparator_FP4錄音比對.md
```

另外：`app/lib/features/practice/practice_controller.dart`、`practice_player.dart`、`practice_screen.dart`、practice tests 等仍是 S2/S5 共用的 untracked 檔；它們包含已完成的播放功能與目前 S5 半成品，不可刪除或重建。

### 2.5 尚未完成

- S5：6.1 / 6.2 需在 task-split / execution-log 正式收尾；目前 code 與目標測試已綠，但 app 尚未完成，不要標整個 S5 Done。
- FP4 錄音比對：
  - 補 `practice_controller.dart` import 與可能後續 analyze 紅點。
  - 補 `RecordPanel`、`OverlayChart`。
  - PracticeScreen 掛錄音面板；錄音中播放按鈕 disabled。
  - 切步 / 卸載中止錄音並刪暫存。
  - 麥克風權限拒絕時引導 macOS 系統設定或至少顯示明確指引。
  - app tests 覆蓋 AT-06-01/02/03/05。
- macOS mic 權限設定：
  - `Info.plist` 補 `NSMicrophoneUsageDescription`。
  - `DebugProfile.entitlements` / `Release.entitlements` 補 `com.apple.security.device.audio-input = true`。
  - **不要改 `com.apple.security.app-sandbox`**；M9 前置不是本切片要處理。
- S6：LessonPack / AIService / ProgressEngine / 難度結算 / 設定仍未開始。
- task 2.1：FFmpeg LGPL release build / license notice。
- task 8.2：license scanner / CT-01～CT-10 常駐整合。
- task 8.3：performance guardrail。
- task 8.4.1-8.4.5：hard-guardrails 剩餘補強。
- task 9.1 / 9.2：release readiness、macOS Sandbox M9。

## 3. S5 接續拆分

### S5-0：先修 app analyze 紅點

第一步：

- 先讀 `app/lib/features/practice/practice_controller.dart` 現況，不要覆蓋 S2 播放功能。
- 在檔案開頭補 `import 'dart:async';`。
- 跑 `dart format app/lib/features/practice/practice_controller.dart app/lib/features/practice/practice_recording.dart`。
- 跑 `flutter analyze`，再依新紅點逐一修。

注意：

- `ref.onDispose` 目前在 dispose callback 內 `ref.read(practiceRecorderProvider)`；若 analyze/test 或 Riverpod lifecycle 不喜歡，建議改為 build 時先 `final recorder = ref.read(practiceRecorderProvider);` 再在 onDispose 捕獲該 recorder。
- `cancelRecording()` 目前先把 `_recordingPath = null` 再呼叫 recorder cancel；因 recorder 自己保存 path，暫時可用。若後續 fake test 難寫，可再整理，但不要改壞 CT-10。

### S5-1：補 PracticeController 錄音 TDD

建議新增 / 更新：

```text
app/test/practice/practice_controller_test.dart
```

必要 fake：

- `_FakeRecorder implements PracticeRecorder`：
  - `levels` 用 broadcast `StreamController<double>`。
  - `start()` 回 `/tmp/attempt.wav` 或拋 `ERR_MIC_PERMISSION_DENIED`。
  - `stop()` 回 path。
  - `cancel()` 記錄呼叫次數。
- `_FakeComparisonService implements PracticeComparisonService`：
  - 回 `ComparisonResult` 或拋 `ERR_RECORDING_TOO_SHORT`。

必要測項：

- `startRecording()` 先 stop 播放，狀態轉 `recording`，level event 更新 `recordingLevel`。
- 錄音中 `state.canPlay == false`。
- `stopRecording()` 轉 `comparing` 後呼叫 compare，成功時寫入 `state.comparison`。
- compare 拋 `ERR_RECORDING_TOO_SHORT` 時顯示錯誤，`comparison == null`。
- `selectStep()` 在 recording 中會 `cancelRecording()`，切步且不留下 comparison。

### S5-2：補 RecordPanel / OverlayChart 與 PracticeScreen 接線

建議新增：

```text
app/lib/features/practice/widgets/record_panel.dart
app/lib/features/practice/widgets/overlay_chart.dart
```

RecordPanel 行為：

- `state.recordStatus == idle`：顯示「錄音」按鈕；`state.canRecord` false 時 disabled。
- `recording`：顯示「停止」與「丟棄」；電平表顯示 `recordingLevel`。
- `comparing`：顯示比對中狀態，按鈕 disabled。
- `comparison != null`：顯示 rhythmDelta / intonationDelta 與 OverlayChart。
- 錯誤文案沿用既有全域錯誤映射或就地顯示，不清空已完成的步驟/選擇。

OverlayChart 行為：

- 畫 reference / user 雙波形；diffRanges 以差異色標記。
- pitch arrays 可先以簡化折線畫出；若空陣列就跳過，不當錯誤。
- 不做 pixel-diff 脆弱測試；先以 widget smoke/state test 覆蓋渲染、空 pitch 不 crash。

PracticeScreen 接線：

- import `widgets/record_panel.dart`。
- 在 `_PracticePlayerBar` 下方放 `RecordPanel(state: state)`。
- 播放按鈕已依 `state.canPlay` disable；錄音中不要再手動開後門。

### S5-3：補 macOS mic 權限設定

需要修改：

```text
app/macos/Runner/Info.plist
app/macos/Runner/DebugProfile.entitlements
app/macos/Runner/Release.entitlements
```

建議設定：

```xml
<key>NSMicrophoneUsageDescription</key>
<string>用於錄製你的跟讀聲音並立即比對；錄音檔比對後會刪除。</string>
```

```xml
<key>com.apple.security.device.audio-input</key>
<true/>
```

注意：

- 不要修改 `com.apple.security.app-sandbox`；本切片只加 mic audio-input entitlement。
- 不要加 `temporary-exception.files.absolute-path.*`。

### S5-4：驗證與紀錄

完成 S5 後建議跑：

```text
dart format <本次修改的 Dart 檔>
flutter analyze
flutter test packages/domain/test
flutter test packages/infra/test
cd app && flutter test
python3 scripts/check_guardrails.py spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/hard-limits-matrix.md spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/guardrails/decision-log.md
```

預期：

- analyze / domain / infra / app tests 應全綠。
- guardrails checker 在剩餘 5 條 REJECTED 未處理前仍應失敗；這不是 S5 的通過條件，但要在 execution-log 說清楚。

完成後要更新：

```text
spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/task-split.md
spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/execution-log.md
spec-syllable-repeater/memory/（必要時新增 S5 workflow/pitfall）
/Users/karen_files/vibercoding project/02_Memory/wiki/chronicle_syllable-repeater.md
```

## 4. 待拍板但不阻塞事項

- REQ-06 寫「overlayData＋參數保留為 Attempt 記錄」，但目前 DB / ProgressEngine 尚未到 S6；S5 先保留 UI state 的 `comparison`，不要新增錄音持久化。
- 麥克風權限拒絕的「引導至 macOS 系統設定」可先做明確 dialog / SnackBar 指引；若要一鍵打開系統設定，需小心挑選 macOS API / dependency，不要為此擴大範圍。
- `score` 已由 comparator 回傳，但需求標 optional；UI 可以顯示，也可以先不顯示，不可讓流程依賴 score。

## 5. 待補提醒

- 不要關 macOS Sandbox；M9 前置不是 S5 要處理的事。
- 不要跳過 CT-10 / AT-06-02 / AT-06-03 / AT-06-05 的測試。
- 不要保存錄音檔；Domain finally delete 已是核心防線，UI 也不可另存錄音。
- 不要把 `dart:io`、FFmpeg、Process、Flutter import 放進 `packages/domain`。
- 不要把 FP4 錄音 UI 半成品標 Done。
- 不要讓錄音中仍可播放原音。
- 不要讓 pitch arrays 空陣列變成錯誤；疊圖可降級跳過 pitch。
- 不要把 `renderStep` 或比對流程改成生成/合成路徑；比對只讀原音與錄音 PCM。
- 不要 push；pre-push 仍應因 5 條 REJECTED 被擋。

## 6. 本機關鍵路徑

專案根目錄：

```text
/Users/karen_files/vibercoding project/syllable repeater
```

S5 已新增 / 修改：

```text
packages/domain/lib/src/model/comparison_result.dart
packages/domain/lib/src/ports/recording_audio_source.dart
packages/domain/lib/src/recording/recording_comparator.dart
packages/domain/lib/domain.dart
packages/domain/test/recording_comparator_test.dart
packages/infra/lib/src/practice/recording_audio_source.dart
packages/infra/lib/infra.dart
packages/infra/test/recording_audio_source_test.dart
app/lib/features/practice/practice_recording.dart
app/lib/features/practice/practice_controller.dart
app/pubspec.yaml
app/macos/Flutter/GeneratedPluginRegistrant.swift
```

S5 下一棒大概率會修改 / 新增：

```text
app/lib/features/practice/practice_controller.dart
app/lib/features/practice/practice_screen.dart
app/lib/features/practice/widgets/record_panel.dart
app/lib/features/practice/widgets/overlay_chart.dart
app/test/practice/practice_controller_test.dart
app/test/practice/practice_screen_test.dart
app/macos/Runner/Info.plist
app/macos/Runner/DebugProfile.entitlements
app/macos/Runner/Release.entitlements
spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/task-split.md
spec-syllable-repeater/requirements/syllable-practice-macos-v1_20260704/task/execution-log.md
```

S2/S3/S4 已完成但尚未 commit 的關鍵檔：

```text
packages/domain/lib/src/practice/practice_engine.dart
packages/domain/lib/src/practice/practice_export_audio.dart
packages/domain/lib/src/practice/wav_encoder.dart
packages/domain/lib/src/model/practice_step.dart
packages/domain/lib/src/model/prosody.dart
packages/domain/lib/src/analysis/prosody_analyzer.dart
packages/infra/lib/src/practice/practice_exporter.dart
app/lib/features/practice/practice_player.dart
app/lib/features/practice/practice_screen.dart
app/lib/features/export/export_dialog.dart
app/lib/features/editor/widgets/prosody_overlay.dart
```

## 7. 本 session 已寫入記憶 / 文件

本交接前已存在並已使用的 project memory：

```text
spec-syllable-repeater/memory/workflow_practice_engine_tdd_ct01_ct02.md
spec-syllable-repeater/memory/workflow_just_audio_write_file_fake_backend_fp4.md
spec-syllable-repeater/memory/workflow_export_ct03_domain_infra_fp5.md
spec-syllable-repeater/memory/workflow_prosody_analyzer_intensity_overlay_fp3.md
spec-syllable-repeater/memory/workflow_交接檔新session啟動提示範本.md
spec-syllable-repeater/memory/workflow_交接檔命名需用原流程階段與任務編號.md
```

本交接檔新增：

```text
交接檔-20260706-fullstack-code-implementation_S5-RecordingComparator_FP4錄音比對.md
```

S5 尚未寫入新的 memory 卡。下一棒完成 S5 後，如遇可重用經驗，依 C8 主動寫入 `spec-syllable-repeater/memory/`，並在 final 列報；若沒有新記憶，也需明說「本次未新增記憶」。

## 8. 新 session 可直接複製的啟動提示

```text
請先讀 02_Memory/constitution.md、preferences.md、MEMORY.md，
再讀本專案 spec-syllable-repeater/memory/（Precision > Recall 挑 5 條相關），
接著讀 /Users/karen_files/vibercoding project/syllable repeater/交接檔-20260706-fullstack-code-implementation_S5-RecordingComparator_FP4錄音比對.md。

目前階段 fullstack-code-implementation / S5 / RecordingComparator 6.1-6.2 + FP4 錄音比對。
本 session（2026-07-06）已完成 S0/S1a/S1b/S1c + hard-guardrails、S2 PracticeEngine + FP4 播放、S3 exportStep/exportMerged + FP5 匯出、S4 ProsodyAnalyzer + FP3 韻律疊圖；S4 完整門檻全綠。S5 domain/infra 目標測試 7/7 綠，但 app 錄音 UI 尚未完成，flutter analyze 目前因 practice_controller.dart 缺 dart:async import 有 2 issues。
請切 fullstack-code-implementation skill，按交接檔 §3 從 S5-0 修 `practice_controller.dart` import/analyze 紅點，再接 S5-1 FP4 錄音比對面板 TDD 動工。

拍板：4.7 已完成；renderStep 與播放路徑走「寫檔→just_audio 播檔」；S5 採 Domain port `RecordingAudioSource` + infra `FileRecordingAudioSource`，錄音檔 compare finally 刪除；record 套件已加入。
不要：關 macOS Sandbox（M9 前置）、跳過 CT-10/AT-06-02/AT-06-03/AT-06-05 TDD、把 dart:io/Process/Flutter 放進 packages/domain、保存錄音檔、把 FP4 錄音 UI 半成品標 Done、讓 renderStep 或比對流程走生成路徑。
```
