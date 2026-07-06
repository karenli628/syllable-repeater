id: WF-20260706-fp6-lesson-hydrate-shortcuts-s6
type: workflow
scope: project
source: syllable-repeater / fullstack-code-implementation S6-9 FP6/FP1 lesson hydrate
context: FP6 已有 `.abopack` open/save service，但 pack 開啟後只同步 registry/譯文，editor/practice 仍主要依 analysis result 的 decoded PCM。這會讓課件卡切到練習或編輯時沒有同一份 Lesson PCM/peaks，也讓單音節試聽與 SettleBar 的 lesson id/title 不穩。必須保持 LessonPackEngine 為 pack 規則來源，不在 UI 解析 zip 或重算 contentHash。
action: 新增 `lesson_session_controller.dart` 作為 pack lesson session 的單一 app 狀態入口；`hydrateLesson` 用 domain `decodeWav` 解 `.abopack` audio bytes 並計算 waveform peaks。`AppLessonPackService.open` 先驗證 WAV 可解碼再同步 registry，損毀或解碼失敗不更新 UI/session。`LibraryScreen` 的課件卡、開啟、儲存都會 hydrate session；FP6 panel 加 `CallbackShortcuts` 支援 Meta/Ctrl O/S。`EditorController` 增加 `sourceLessonId`，`EditorScreen` 和 `PracticeController/Screen` 只有 source lesson id 與 session lesson id 一致時才使用 pack PCM/peaks，否則回落 analysis result。
result: `flutter test packages/domain/test/wav_encoder_test.dart`、`flutter test packages/infra/test/recording_audio_source_test.dart`、`cd app && flutter test test/pack_translate/lesson_session_controller_test.dart test/progress/progress_ui_test.dart test/practice/practice_screen_test.dart` 通過；完整回歸為 domain 82/82、infra 67/67（2 sidecar skips）、app 58/58。
reasoning: Pack lesson 是不同於 analysis result 的資料來源，需要一個明確 session boundary，否則 UI 很容易在「目前有音節但沒有 PCM」或「切 tab 後仍指向舊 analysis PCM」之間漂移。將 WAV decode 提升到 domain 可讓 pack validation 和 recording decode 共用同一規則，減少重複 parser。`sourceLessonId` 是避免 analysis editor 誤吃 pack session 的關鍵。
recommendation: 後續所有從 `.abopack` 進 editor/practice 的路徑都先經 `LessonSessionController.hydrateLesson`；任何 pack decode 失敗必須 fail-closed，不要部分更新譯文、session 或 tab。若新增課件列表操作，仍讓 `LessonPackService` 負責 open/save，UI 只處理使用者動作與錯誤呈現。
confidence: high
status: active
verified_count: 1
created: 2026-07-06
last_used: 2026-07-06
