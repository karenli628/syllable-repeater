// AI-Generate
id: PIT-20260711-flutter-gen-snapshot-quarantine-release-build
type: pitfall
scope: project
source: syllable-repeater / fullstack-code-implementation task 9.1 release build, 2026-07-11
context: 在 Intel macOS 14.1.2 + Flutter 3.44.4 / Dart 3.12.2 上執行 `flutter build macos --release --no-pub`，Release build AOT 階段反覆出現 `Dart snapshot generator failed with exit code -9` 或 `gen_snapshot_x64` 0% CPU / 40K footprint 卡住；`gen_snapshot_x64 --version` / `--help` 本體也無輸出。
action: 先排除專案程式碼與 sidecar 問題，改查 Flutter SDK artifact 本體；對 `/usr/local/share/flutter/bin/cache/artifacts/engine/darwin-x64-release/gen_snapshot_x64` 執行 `xattr -l`，發現 `com.apple.quarantine: ... Homebrew Cask`；移除該 xattr 後再跑 release build。
result: `xattr -d com.apple.quarantine /usr/local/share/flutter/bin/cache/artifacts/engine/darwin-x64-release/gen_snapshot_x64` 後，`gen_snapshot_x64 --version` 正常回應 Dart SDK 3.12.2，`flutter build macos --release --no-pub` 成功產出 x86_64 `.app`。
reasoning: Homebrew Cask 來源的 Flutter engine artifact 被 macOS quarantine 標記時，`gen_snapshot_x64` 可能不是明確報 Gatekeeper 錯，而是在 AOT 子程序中卡住或被 kill；這會看起來像 Flutter/Dart 編譯器或專案程式碼問題，但實際是本機工具鏈 xattr 狀態。
recommendation: 若 macOS release build 在 AOT / `gen_snapshot_x64` 階段卡住，先執行 `xattr -l /usr/local/share/flutter/bin/cache/artifacts/engine/darwin-x64-release/gen_snapshot_x64`；若有 quarantine，移除後驗 `gen_snapshot_x64 --version`，再重跑 `flutter build macos --release --no-pub`。不要先改專案程式碼、不要誤判為 sidecar 或 license gate 問題。
confidence: high
status: active
verified_count: 1
created: 2026-07-11
last_used: 2026-07-11
