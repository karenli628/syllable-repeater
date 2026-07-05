id: WF-20260706-editor-undo-stack-domain-stateless
type: workflow
scope: project
source: syllable-repeater / fullstack-code-implementation S1b FP3
context: backend-design §3.2.1 介面 2 定義「Domain 無狀態；撤銷由 UI 以回傳值堆疊實作」。首次實作 EditorController 時容易走成「Notifier 內部維護當前狀態 + 補 domain 的 undo API」，但那會讓 undo 語意分兩處，違反介面契約。
action: 把 `updateSyllableBoundary` 寫成純函式（回傳完整新 `List<Syllable>`＋`snappedMs`，不吃現有 syllables 之外的狀態）；`EditorController.state.undoStack` 型別為 `List<List<Syllable>>`——每次 `dragEnd` 成功時把「呼叫前的 syllables 完整快照」push 進去，`undo()` 從尾端 pop 復原。失敗的 dragEnd（`ERR_BOUNDARY_INVALID`）**不** push undo（維持「undo 只回上一次成功狀態」語意）。連續拖動只有最終 `dragEnd` 打 domain 並產生一筆 undo，符合 AT-02-03。
result: `alignment_boundary_test.dart` 7 tests + `editor_controller_test.dart` 7 tests + `waveform_canvas_test.dart` 3 tests 全綠；AT-02-01 到 AT-02-05 全數落地在 domain / controller 兩層，無 UI 端業務規則重算（frontend-design §四 3.4 明訂）。
reasoning: 「domain 純函式 + UI 端堆疊」比「domain 端 undo API」的優勢：①測試 domain 只需驗當次呼叫、UI 只需驗堆疊語意；②未來把 editor 換 target（Web 版、CLI 版）時 domain 完全不動；③失敗事件的 rollback 自動達成（因為根本沒改到 controller 的 syllables）。
recommendation: 後續有類似「使用者操作 → 純函式產出新狀態 → 可撤銷」語意的地方（例：S3 exportStep 步驟勾選、S6 譯文欄手動 vs AI），一律套用同一 pattern。**不要**把 undoStack 存進 DB／pack——那會鎖死呈現方式；本專案定案 undo 只活在 session 記憶體內，關 App 即消失（見 requirement §2.4 Non-scope）。若未來要 persist undo，改為「audit log」（見 [[decision_hard_guardrails_matrix_20260705]] task 8.4.2）而非讓 domain 攜狀態。
confidence: high
status: active
verified_count: 1
created: 2026-07-06
last_used: 2026-07-06
