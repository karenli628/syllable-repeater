// AI-Generate
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// AppShell 目前選中的頁面索引；提升為 Notifier 讓 FP2 完成後可切到 editor。
///
/// 索引對應 `app_shell.dart` 內 NavigationRail destinations：
///   0=課程匯入、1=段落標籤、2=單句分析、3=段落校正、4=錄音練習、5=課程設定。
final appShellSelectedIndexProvider =
    NotifierProvider<AppShellSelectedIndex, int>(AppShellSelectedIndex.new);

class AppShellSelectedIndex extends Notifier<int> {
  @override
  int build() => AppSection.library.sectionIndex;

  void select(int index) {
    state = index;
  }
}

enum AppSection {
  library(0),
  labeling(1),
  importAnalysis(2),
  editor(3),
  practice(4),
  settings(5);

  const AppSection(this.sectionIndex);
  final int sectionIndex;
}
