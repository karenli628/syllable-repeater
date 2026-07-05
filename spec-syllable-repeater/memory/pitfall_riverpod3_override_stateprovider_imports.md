id: PIT-20260705-riverpod3-override-stateprovider-imports
type: pitfall
scope: project
source: syllable-repeater / fullstack-code-implementation Frontend FP2 收尾
context: 專案用 `flutter_riverpod ^3.3.2`。在 `main.dart` 準備 `List<Override>` 給 `ProviderScope`，並在 `shared/navigation.dart` 用 `StateProvider<int>` 管 tab index。`flutter analyze` 報 `The name 'Override' isn't a type` 與 `The function 'StateProvider' isn't defined`。
action: Riverpod 3.x 沒有從 `package:flutter_riverpod/flutter_riverpod.dart` 主匯出 `Override`——它從 `package:flutter_riverpod/misc.dart` 匯出。修法之一是 `import 'package:flutter_riverpod/misc.dart' show Override;`。同時 `StateProvider` 在 3.x 屬 legacy（`package:flutter_riverpod/legacy.dart`）；本專案改用 `NotifierProvider` + 自訂 Notifier（`AppShellSelectedIndex extends Notifier<int>` + `select(int)`）替代，避免綁定 legacy。
result: 兩處 analyze error 全消；`flutter analyze` No issues found；tab 切換行為與 StateProvider 版一致。
reasoning: Riverpod 3.x 為了避免污染主匯出，把 provider-composition 用 `Override` 型別移到 `misc.dart`；legacy provider（StateProvider/StateNotifierProvider/ChangeNotifierProvider）移到 `legacy.dart`。這是刻意的分層，未來套件更新時 legacy 可能被移除。
recommendation: 本專案後續要覆寫 provider 一律用 `import 'package:flutter_riverpod/misc.dart' show Override;`；tab、簡單 flag 等狀態一律用 `NotifierProvider` + `Notifier`，不再引 `StateProvider`。
confidence: high
status: active
verified_count: 1
created: 2026-07-05
last_used: 2026-07-05
