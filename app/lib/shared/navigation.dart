// AI-Generate
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AppShell 目前選中的頁面索引；提升為 Notifier 讓 FP2 完成後可切到 editor。
///
/// 索引對應 `app_shell.dart` 內 NavigationRail destinations：
///   0=課件庫、1=匯入、2=校正（editor）、3=練習、4=設定。
final appShellSelectedIndexProvider =
    NotifierProvider<AppShellSelectedIndex, int>(AppShellSelectedIndex.new);

class AppShellSelectedIndex extends Notifier<int> {
  @override
  int build() => 1;

  void select(int index) {
    state = index;
  }
}

enum AppSection {
  library(0),
  importAnalysis(1),
  editor(2),
  practice(3),
  settings(4);

  const AppSection(this.sectionIndex);
  final int sectionIndex;
}
