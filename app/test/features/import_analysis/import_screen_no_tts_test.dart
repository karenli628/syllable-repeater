// AI-Generate
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syllable_repeater_app/features/import_analysis/import_screen.dart';

void main() {
  testWidgets('無音檔時開始分析置灰並指引段落標籤入口，沒有 TTS／生成選項', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: ImportScreen())),
      ),
    );
    await tester.pump();

    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '開始分析'),
    );
    expect(startButton.onPressed, isNull);
    expect(find.text('請先匯入音檔，或到「段落標籤」選擇一個區段'), findsOneWidget);
    expect(find.textContaining('TTS'), findsNothing);
    expect(find.textContaining('生成'), findsNothing);
  });
}
