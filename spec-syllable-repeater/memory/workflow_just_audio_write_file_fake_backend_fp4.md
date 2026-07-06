id: WF-20260706-just-audio-write-file-fake-backend-fp4
type: workflow
scope: project
source: syllable-repeater / fullstack-code-implementation S2 FP4 playback
context: 使用者拍板 renderStep→播放走「寫檔→just_audio 播檔」，且本輪不可關 macOS App Sandbox。FP4 播放要能在 widget/unit tests 中驗證，不可讓測試真的啟動平台播放器；editor 單音節 chip 也要從 S1b SnackBar stub 換成真播放。
action: 新增 `app/lib/features/practice/practice_player.dart`，分三層：`PracticePlayback` 介面、`PracticeAudioBackend` 介面、`JustAudioPracticeBackend` 實作。`PracticePlayer` 走 `PracticeEngine.renderStep` → repeatN 預串接 → `encodeWav` → `<systemTemp>/syllable_repeater_steps/step-<hash>.wav` → `AudioSource.uri(Uri.file(path))`。controller/widget tests 透過 `practicePlayerProvider.overrideWithValue(fake)` 取代真 backend；`flutter pub get` 會自動更新 `app/macos/Flutter/GeneratedPluginRegistrant.swift` 註冊 `audio_session`/`just_audio`。
result: `cd app && flutter test` 27/27 ✅；新增 `practice_player_test.dart` 驗證 WAV 檔與 fake backend 呼叫順序（stop→load→ready→play）、`practice_controller_test.dart` 驗證切步先 stop 與 play 狀態、`practice_screen_test.dart` 驗證 PracticeScreen 播放與 editor chip 單音節播放。`flutter analyze` No issues found。macOS entitlements 未修改。
reasoning: just_audio 是平台 plugin，直接在 controller/widget test 裡 new `AudioPlayer` 會把測試綁到 macOS plugin lifecycle；抽介面後測試只驗「是否寫對檔、是否呼叫播放」，真播放器只留在 app runtime。寫 `.wav` 檔且副檔名正確也符合 just_audio macOS 文件：本機 file playback 依副檔名判斷格式。
recommendation: 後續新增錄音比對播放、匯出預覽或連播時，繼續透過 `PracticePlayback`/fake backend 測試，不要在 widget test 直接啟動 `AudioPlayer`。新增 audio plugin 依賴後要檢查 `GeneratedPluginRegistrant.swift` 是否有預期變更；不要為了本輪播放去關 macOS Sandbox，sandbox 前置仍留到 M9。
confidence: high
status: active
verified_count: 1
created: 2026-07-06
last_used: 2026-07-06
