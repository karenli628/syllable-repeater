id: WF-20260706-fp6-pack-service-practicegroup-linkage-s6
type: workflow
scope: project
source: syllable-repeater / fullstack-code-implementation S6-8 FP6 + PracticeGroup linkage
context: FP6 原本只有 LibraryScreen manual translation shell；SettleBar 原本使用 `practice-step-{index}` placeholder groupId，`ProgressEngine.settle` 需要真 `PracticeGroup` 才能寫 SRS。必須保持 LessonPackEngine/ProgressEngine 為規則來源，不在 UI 解析 pack、重寫 SRS 或新增 overdue/failed/penalty 欄位。
action: 新增 `app/lib/features/library/lesson_pack_service.dart`，集中 `LessonPackFilePicker`、`LessonPackService`、`AppLessonPackService` 與 current lesson draft builder；用 `LessonPackEngine + AtomicFileIo + file_selector` 真開啟/儲存 `.abopack`，成功後同步 `lesson_registry`，損毀 pack 只顯示錯誤不覆蓋現有手動譯文。`ProgressService` 新增 `ensurePracticeGroup`；`PracticeScreen` 用目前 lesson/step 建穩定 `PracticeGroup`，`SettleBar` 結算前先 ensure group 再 settle；`DriftProgressRepository.saveGroup` 對未註冊 lesson 建最小 registry row。
result: `flutter test app/test/progress/progress_ui_test.dart` 10/10 綠；`flutter test packages/infra/test/drift_progress_repository_test.dart` 7/7 綠；`flutter test packages/domain/test` 78/78 綠；`flutter test packages/infra/test` 66/66 綠（2 sidecar skips）；`cd app && flutter test` 52/52 綠；`flutter analyze` No issues。
reasoning: Pack 格式和 contentHash 仍由 Domain `LessonPackEngine` 控制，UI 只取路徑、顯示狀態與呼叫 service；PracticeGroup 建立放在 ProgressService/Repository 路徑，讓 SettleBar 不再依賴 placeholder，同時避免 UI 直接寫 DB 或改 SRS 狀態機。未註冊 lesson 的最小 registry row 是為即時分析後直接練習的合理 fallback，不污染 pack/progress 匯出格式。
recommendation: `LessonPackService` 仍是 `.abopack` open/save 的唯一 app 入口；後續若調整 pack UI、hydration 或 PracticeGroup linkage，沿用 `lesson_session_controller.dart`（詳 `workflow_fp6_lesson_hydrate_shortcuts_s6.md`）同步 editor/practice state，失敗仍不得部分套用。若調整 PracticeGroup id，需保持同 lesson+step 穩定且不要新增 overdue/failed/penalty 欄位。
confidence: high
status: active
verified_count: 1
created: 2026-07-06
last_used: 2026-07-06
