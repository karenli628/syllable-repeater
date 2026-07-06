id: WF-20260706-fp1-fp7-library-archive-ui-s6
type: workflow
scope: project
source: syllable-repeater / fullstack-code-implementation S6-7 FP1 + FP7 UI
context: S6 已有 ProgressEngine dueList、archive/restore、export/import 與 Drift adapter；前端需要把課件庫、歸檔確認、168h 恢復倒數與進度匯入匯出接成可測 UI，但不能在 UI 重寫 SRS merge、168h window 或新增 overdue/failed/penalty 概念。
action: `LibraryScreen` 外層改為可捲動版面，置頂保留 dueList，新增 `libraryLessonEntriesProvider` 從 `lesson_registry` 讀課件清單並在 Dart 層排序，避免 app 直接依賴 drift；課件卡只切換到練習/編輯 tab，不自行建立 Lesson 狀態。due item 新增歸檔確認對話框後呼叫 `ProgressService.archive`。`ProgressSettingsScreen` 新增 archived groups provider，顯示剩餘 168h 倒數、EXPIRED disabled 與恢復按鈕。widget test 覆蓋 due item、歸檔確認、課件入口切 tab、進度匯入匯出、archived restore 與 SettleBar。
result: `app/test/progress/progress_ui_test.dart` 10/10 綠；`cd app && flutter test` 52/52 綠；`flutter analyze` No issues。一次並行 Flutter 測試會撞 native assets 暫存清理 race，改為序列重跑即可通過，非程式碼缺陷。
reasoning: FP1/FP7 的 UI 只負責呈現與呼叫 app service，Domain 仍是 dueList 排序、archive/restore 狀態機、import/export merge 的唯一規則來源。app 不直接依賴 drift 可避免 package 邊界漂移；固定高度區塊放在外層 scroll view 內，可避免 widget test 與小視窗 RenderFlex overflow。
recommendation: 後續做 FP6 真 `.abopack` open/save、PracticeGroup linkage 或 lesson hydrate 時，沿用 service/provider 層接線，不在 LibraryScreen 直接改 DB；若新增 lesson selection state，測試要覆蓋「進練習/編輯時帶入同一 lesson」且仍不得出現逾期/懲罰文案。
confidence: high
status: active
verified_count: 1
created: 2026-07-06
last_used: 2026-07-06
