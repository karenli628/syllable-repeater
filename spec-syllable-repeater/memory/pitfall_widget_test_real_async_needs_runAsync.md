id: PIT-20260705-widget-test-real-async-needs-runAsync
type: pitfall
scope: project
source: syllable-repeater / fullstack-code-implementation FP2 e2e
context: 寫 `app/test/e2e_pipeline_test.dart`：`testWidgets` 內用 `tester.pump(200ms)` 迴圈輪詢 pipeline `AnalysisRunStatus`，希望等到 `done`。真 pipeline 內走 `Process.start` + `Process.exitCode`（FFmpeg / whisper.cpp）需要真時間流逝。實測 90 秒逾時，最後狀態仍卡在 `AnalysisStage.decoding`。
action: `TestWidgetsFlutterBinding.pump` 只推 fake time（scheduler tick），不會真等 IO；`Process.exitCode` 完成需要真時間。要跑真 sidecar 就要進入 `tester.runAsync`——它把 callback 放到真 async zone，允許 real timers 與 Process 完成。修法：`await tester.runAsync(() async { await controller.start(); }); await tester.pump();`。7 秒真檔 e2e 通過。
result: e2e_pipeline_test 1/1 ✅，7 秒（FFmpeg 解碼 + 16k WAV + whisper.cpp small.en `--no-gpu` + CMUdict + AlignmentEngine + waveform peaks + editor tab 切換 assert）。
reasoning: `testWidgets` 預設用 fake time 讓動畫、Future.delayed 可控；但這與 dart:io Process/socket 的真非同步不相容。runAsync 是 flutter_test 給整合類 e2e 的官方逃生艙。
recommendation: 本專案凡是 widget test 要碰真 sidecar（S1c demucs、S2 renderStep + just_audio、S5 錄音比對等），一律用 `tester.runAsync` 包裹。不要為了「不撞真 sidecar」而降級到 preview runner——那樣 e2e 就不再是 e2e。若要多次輪詢中間狀態，也把整段輪詢放進 runAsync（然後外面補一次 `tester.pump()` 讓 UI 反映最新 state）。
confidence: high
status: active
verified_count: 1
created: 2026-07-05
last_used: 2026-07-05
