id: PF-20260706-riverpod-session-source-null-equality
type: pitfall
scope: project
source: syllable-repeater / fullstack-code-implementation S6-9 Editor/Practice lesson session
context: Editor 同時支援 analysis result 與 pack lesson session。初版判斷 session 是否適用時使用 `sourceLessonId == session.lesson?.id`，當兩者都為 null 時，analysis-derived editor 會被誤判為 pack session active，導致單音節試聽和 PCM 選擇可能使用錯誤來源。
action: 在 `EditorScreen` 的 session 判斷加入明確非空條件：只有 `sourceLessonId != null && sourceLessonId == session.lesson?.id` 才使用 pack session PCM/peaks。`EditorController` 的 initial build 也同時讀 existing session 與 analysis result，避免 provider 建立順序讓 hydrate 事件被漏接。
result: Analysis-derived editor 不再因 null equality 誤用 pack session；pack lesson editor/practice 仍能正確使用 hydrate 後的 PCM/peaks。相關行為由 `lesson_session_controller_test.dart`、`progress_ui_test.dart`、`practice_screen_test.dart` 覆蓋。
reasoning: Riverpod state 常會有「尚無來源」的 null 狀態；在多資料來源 UI 中，`null == null` 只代表兩邊都未知，不代表兩邊指向同一實體。來源識別必須用非空 id 或 explicit enum，而不是單靠 nullable equality。
recommendation: 後續新增 analysis/session/cache 等多來源切換時，先定義 source identity（例如 `sourceLessonId` 或 source enum）。任何 nullable id 比對都要加非空守門；若兩個 null 可以出現，測試要覆蓋「兩邊 null 不等於同一來源」。
confidence: high
status: active
verified_count: 1
created: 2026-07-06
last_used: 2026-07-06
