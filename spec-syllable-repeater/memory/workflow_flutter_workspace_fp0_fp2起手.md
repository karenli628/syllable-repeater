id: WF-20260705-flutter-workspace-fp0-fp2-bootstrap
type: workflow
scope: project
source: syllable-repeater / fullstack-code-implementation Frontend FP0-FP2 起手
context: 在既有 Dart pub workspace（packages/domain、packages/infra）中加入 Flutter macOS app；既有 domain/infra 使用 `lints ^5.x`，Flutter 3.44.4 `flutter create` 預設 app 使用 `flutter_lints ^6.0.0`；前端 FP0/FP2 需要 Riverpod、desktop_drop、file_selector。
action: 將 root `pubspec.yaml` workspace 加入 `app`，在 `app/pubspec.yaml` 加 `resolution: workspace` 與 domain/infra path deps；先把 `flutter_lints` 對齊為 `^5.0.0`，再用 `flutter pub add flutter_riverpod desktop_drop file_selector` 解析外部依賴。FP0/FP2 起手先以 `PreviewAnalysisRunner` 餵 `Stream<AnalysisEvent>`，讓 UI/狀態/錯誤碼可測；真 sidecar pipeline 注入留到下一小步。widget test 設 1200x800，並讓 app shell 支援 1100x700 最小桌面布局。
result: `flutter pub get` 成功；Pub workspace 移除 `app/pubspec.lock` 與 `app/.dart_tool/package_config.json`，根 `pubspec.lock` 成為集中 lockfile。`flutter analyze` 無問題，`cd app && flutter test` 2/2 通過；第一次 widget test 抓到拖放區 overflow 32px，修正高度後全綠。
reasoning: Dart pub workspace 會把所有成員一起解版本，dev_dependency 的 `lints` major 版本也會互相衝突；新 Flutter app 必須配合既有 workspace 約束，不能保留產生器預設的 `flutter_lints ^6.0.0`。FP2 UI 先用 preview runner 能讓畫面、Riverpod 狀態與 `AnalysisEvent` 階段文案獨立於 `.local-tools` sidecar 路徑穩定驗證，避免把 UI 起手卡在真 pipeline 聯調。
recommendation: 後續在此專案新增 Flutter 依賴時，先確認 workspace 內 lints/analyzer/test 約束是否同 major；接受根 lockfile 集中管理，不要重建 app 子 lockfile。Flutter/Dart 前端指令不要並行，且遇 sandbox cache/cpuinfo 問題改用非 sandbox。FP0/FP2 任務不可因 preview runner 全綠就勾完成；只有真 `AnalysisPipeline` 注入、10 分鐘時長檢查、重試/導向與剩餘驗收補齊後才勾。
confidence: high
status: active
verified_count: 1
created: 2026-07-05
last_used: 2026-07-05
