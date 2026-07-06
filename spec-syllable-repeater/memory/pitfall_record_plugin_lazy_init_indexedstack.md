id: PF-20260706-record-plugin-lazy-init-indexedstack
type: pitfall
scope: project
source: syllable-repeater / fullstack-code-implementation S5 FP4 錄音比對
context: S5 新增 record 套件後，`AppShell` 使用 `IndexedStack` 同時 build 隱藏的 `PracticeScreen`。若 `PracticeController.build()` 立即 `ref.read(practiceRecorderProvider)`，即使使用者尚未進練習頁或按錄音，widget/e2e test 也會 new `AudioRecorder()`，在沒有平台 plugin 的 Flutter test 環境拋 `MissingPluginException(No implementation found for method create on channel com.llfbandit.record/messages)`。
action: 將 `PracticeRecorder` 延遲到 `startRecording()` 成功時才讀取與保存；controller 以 `_activeRecorder` 持有已啟動的 recorder，`stopRecording()` / `cancelRecording()` 使用該 instance。`dispose` 只取消 level subscription 並在 `_recordingPath != null && _activeRecorder != null` 時 fire-and-forget cancel，不在 dispose lifecycle 內呼叫 `ref.read` / `ref.exists`。
result: `cd app && flutter test` 從 e2e pipeline MissingPluginException 失敗恢復為 42/42 全綠；PracticeScreen 可留在 `IndexedStack` 中，不會因隱藏頁 build 而初始化 record plugin。錄音流程仍由 `practice_controller_test.dart` / `practice_screen_test.dart` 透過 fake recorder 覆蓋。
reasoning: 平台 plugin 的建構本身可能觸發 method channel；在 Flutter widget test 中沒有原生 plugin 實作，因此 provider 不應在頁面 build 或 controller build 階段建立真 plugin。延遲到使用者按錄音才建立，符合實際生命週期，也讓隱藏頁/測試環境不碰平台能力。
recommendation: 後續新增 just_audio、record、file_selector、secure storage 等平台 plugin provider 時，避免在 controller `build()` 或 hidden tab build 階段 eager read；用 fake-able port/provider，並把真 plugin 建構延遲到使用者動作或 runtime provider override。Riverpod `onDispose` 裡也不要讀其他 provider；需要清理時保存已建立的 instance。
confidence: high
status: active
verified_count: 1
created: 2026-07-06
last_used: 2026-07-06
