id: WF-20260705-flutter-workspace-dart-test-gotcha
type: workflow
scope: project
source: syllable-repeater / fullstack-code-implementation Frontend FP2 收尾
context: pub workspace 已把 `app`（Flutter package）納入 workspace member；`packages/domain` 與 `packages/infra` 是純 Dart package。之前 S1a 8.1 domain purity 防線靠 `cd packages/domain && dart test` 跑 15/15；本輪要跑 domain 新增 checkpoint tests 時該指令回報 `flutter_test from sdk which doesn't exist`。
action: 在 workspace 加入 Flutter member 後，`dart pub`／`dart test` 於任何 workspace 成員內執行都會嘗試 resolve 整個 workspace，就會撞到 `flutter_test`（來自 flutter SDK）。改用 `flutter pub get`（workspace root）與 `flutter test packages/domain/test`、`flutter test packages/infra/test` 執行純 Dart 包測試；Flutter CLI 會補上 flutter SDK 解析且仍以純 Dart 執行 domain/infra 測試檔。
result: `flutter test packages/domain/test` 18/18 ✅（含 3 個 PipelineCheckpoint 新測試）；`flutter test packages/infra/test` 39/39 ✅（含 9 個 FfprobeDurationProbe 新測試）；`flutter analyze` No issues found；`cd app && flutter test` 4/4 ✅。
reasoning: 前一個成功跑 `dart test` 的紀錄（execution-log「S1a 8.1」時）是在 `app/` 被納入 workspace 之前；本輪為納入之後的第一次 domain/infra 測試，因此踩到此差異。之後若把 `packages/domain/pubspec.yaml` 加 `resolution: workspace` 拿掉或分開 workspace，就可以復用 `dart test`，但不必要——`flutter test <path>` 已能替代並保有 non-Flutter 執行結果。
recommendation: 本專案的 CI-ready 防線與後續驗證指令一律用 `flutter test packages/domain/test` 與 `flutter test packages/infra/test`；不要再回頭寫 `cd packages/domain && dart test`。記憶檔 [[workflow_domain_purity_ci_ready防線]] 描述的「domain `dart test`」現況已改為 `flutter test`，未來接 GitHub Actions 時腳本要同步。
confidence: high
status: active
verified_count: 1
created: 2026-07-05
last_used: 2026-07-05
