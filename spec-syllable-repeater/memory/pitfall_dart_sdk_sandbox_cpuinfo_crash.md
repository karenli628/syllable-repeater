id: PIT-20260705-dart-sandbox-cpuinfo-crash
type: pitfall
scope: project
source: syllable-repeater / fullstack-code-implementation S1a AnalysisPipeline
context: 在 Codex sandbox 內執行 Dart SDK 3.12.2（macOS x64）的 `dart format`、`dart analyze`、`dart test`。
action: 指令在 sandbox 內於 `runtime/vm/cpuinfo_macos.cc:42` crash；同一批指令改以非 sandbox 執行後可正常格式化、分析與測試，且 `dart analyze` 無問題、domain/infra 測試全綠。
result: 判定為工具執行環境問題，不是專案程式碼或測試失敗；本次驗證改用非 sandbox 執行 Dart 指令。
reasoning: `dart --version` 可正常輸出，但 Dart CLI 子命令在 sandbox 內讀 macOS CPU 資訊時崩潰；離開 sandbox 後同命令立即成功，具備環境差異證據。
recommendation: 後續在此專案若看到 `cpuinfo_macos.cc:42`，不要先改程式碼；改以非 sandbox 重跑 `dart format/analyze/test`。若非 sandbox 仍失敗，才視為工具鏈或程式碼問題另查。
confidence: high
status: active
verified_count: 1
created: 2026-07-05
last_used: 2026-07-05
