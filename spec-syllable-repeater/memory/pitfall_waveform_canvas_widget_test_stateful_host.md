id: PIT-20260706-waveform-canvas-widget-test-stateful-host
type: pitfall
scope: project
source: syllable-repeater / fullstack-code-implementation S1b FP3 waveform_canvas_test
context: `WaveformCanvas` 是 stateless widget，接受 `draggingBoundaryIndex` / `draggingPreviewMs` 為 prop；內部 `GestureDetector.onPanUpdate` 有 guard「`if (draggingBoundaryIndex == null) return;`」——正確設計（controller 才是狀態擁有者）。widget test 想驗「拖動時 onDragUpdate 被呼叫」，若一次性 pumpWidget 傳 `draggingBoundaryIndex: null`＋callback，在真實 startGesture→moveTo 流程中 update callback **不會 fire**，因為 canvas 從未收到「index 已非 null」的重繪 tick。
action: 測試 host 用 `StatefulBuilder` 包 `WaveformCanvas`，在 `onDragStart` 內 `setState` 更新 `startedIndex`，`onDragUpdate` 內 `setState` 更新 `updatedMs`，`onDragEnd` 清回 null——這就把 controller 的 wire up 邏輯搬到 test host，canvas 得以在 gesture 進行中收到 `draggingBoundaryIndex: non-null` 的 rebuild。修完後 3/3 全綠。**不要**改 canvas 拿掉 guard（那樣 UI 端每次 pointer 移動都會 update，即使沒 dragStart）。
result: `waveform_canvas_test.dart` 3 tests 全綠（邊界內拖動觸發完整 start→update→end；邊界外 >12dp 不觸發；空 peaks/totalDurationMs=0 不 crash）。順帶抓到 e2e_pipeline_test 舊斷言 `#1`/`#11` 為 EditorScreen 最小殼版標籤，本輪 chip 化後改讀 controller state 驗 11 音節。
reasoning: `tester.startGesture` + `moveTo` 送 pointer events 走 flutter 的 gesture arena；但 widget rebuild 需要 host 觸發 `setState`（stateless widget 不會自己重繪）。這是 stateless widget 內含 guard 的通用問題——test host 必須模擬 controller wire up 才能覆蓋真實 flow。
recommendation: 未來寫 stateless widget widget test 遇到「callback 需要 prop 更新才 fire」的情境，一律用 `StatefulBuilder` 或建 mini `StatefulWidget` 包起來當 test host；別為了測試方便改 production code 拿掉 guard。若 controller-widget 分工複雜到 host 難模擬，就改測 controller unit test（[[workflow_editor_undo_stack_domain_stateless]]）＋ e2e 蓋 UI 整合，兩者分工。
confidence: high
status: active
verified_count: 1
created: 2026-07-06
last_used: 2026-07-06
