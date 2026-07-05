id: WF-20260705-pipeline-checkpoint-resume-pattern
type: workflow
scope: project
source: syllable-repeater / fullstack-code-implementation Frontend FP2 收尾
context: 需求 REQ-01 AT-01-04「N2 解碼結果保留」＋frontend-design §八「ERR_SIDECAR_CRASHED/TIMEOUT 顯示重試此階段」要求 pipeline 失敗後可從失敗階段（不是整段）重跑。若採「重新分析」降級，會違反需求語意；使用者已明確要求真做 checkpoint。
action: 在 domain `AnalysisPipeline` 加入 `PipelineCheckpoint {decodedPcm?, separated?, words?}` 值物件；`analyze(ImportRequest request, {PipelineCheckpoint? resume})` 於 stream 開頭把 `resume` 拆進本地變數，若對應階段已有結果就跳過 `decoder.decode` / `vocalSeparator.separate` / `transcriber.transcribe`；`failed` 事件透過 `AnalysisEvent.failed(error, checkpoint: currentCheckpoint())` 攜帶當下所有已完成階段的產物；UI `AnalysisController` 把 `event.checkpoint` 存到 `state.lastCheckpoint`，`retryStage()` 走 `_run(resume: state.lastCheckpoint, clearCheckpoint: false)`。UI 顯示「重試此階段」按鈕的判斷用 `state.canRetryStage`（失敗態＋checkpoint 非空）。
result: domain 新增 3 tests（failed 帶 checkpoint、resume decodedPcm 跳過 decoder、resume words 跳過 transcriber）全綠；既有事件序列與行為不變（既有 3 tests 不動仍通過）。
reasoning: 純值物件＋stream 開頭 branching 是最小可讀落點；不需要引入狀態機或 checkpoint 儲存層。checkpoint 只是 in-memory 值，UI 卸載即消失，符合 M10 隱私（不落地）；重進頁面就是「重新分析」。
recommendation: 之後 S2 `PracticeEngine` 或其他長流程若也要「重試」語意，套同一模式：port 加 optional resume 參數、失敗事件帶當下 checkpoint、UI 存 lastCheckpoint。不要把 checkpoint 塞進 `ImportRequest`（會污染輸入語意）；獨立參數更清楚。
confidence: high
status: active
verified_count: 1
created: 2026-07-05
last_used: 2026-07-05
