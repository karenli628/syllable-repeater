id: DEC-20260704-開發環境工具鏈
type: decision
scope: project
source: syllable-repeater / fullstack-code-implementation S0
context: 全新機器（Intel i5-8259U，macOS 14）建置開發環境；儲存庫為 Dart pub workspace（根 pubspec + app + packages/domain + packages/infra）。
action: ①Dart SDK 3.12.2 經 brew tap dart-lang/dart 安裝（新版 brew 需先 `brew trust dart-lang/dart`）；②FFmpeg 8.1.2 經 brew 安裝——**GPL build，僅限本機開發測試，發布必須換 LGPL build（M9／任務 2.1）**；③Flutter SDK 3.44.4 stable 經 Homebrew 安裝，`flutter create --platforms=macos --project-name syllable_repeater_app app` 已建立 app；完整 Xcode / CocoaPods 未就緒（macOS plugin/build 可能阻塞，Xcode 須使用者自 App Store 裝）；④Drift 表名會把類名複數化（PracticeGroups→practice_groups），須覆寫 `tableName` 才能對齊設計的單數表名。
result: S0 全綠：dart analyze 零問題、domain 5/23 infra 測試全過、真 FFmpeg 整合 demo 通過；2026-07-05 前端起手版 `flutter analyze` 無問題、`cd app && flutter test` 2/2 通過。
reasoning: 環境事實跨 session 不變且無法從程式碼推得（brew trust、GPL/LGPL 區別、Xcode 待裝清單），記下可省下次盤點。
recommendation: 新 session 若 `dart` 找不到，PATH 加 `/usr/local/opt/dart/libexec/bin`；純 Dart 測試指令：workspace 根 `dart pub get`→infra 內 `dart run build_runner build`→各包 `dart test`。Flutter 指令需順序執行且多半要非 sandbox：workspace 根 `flutter pub get`、`flutter analyze`，前端測試在 `app/` 跑 `flutter test`。動到 Drift 新表時記得 tableName 覆寫與結構測試同步。發布前任務 2.1 必須把 brew FFmpeg 換成 LGPL build 並附授權文件。
confidence: high
status: active
verified_count: 0
created: 2026-07-04
last_used: 2026-07-05
