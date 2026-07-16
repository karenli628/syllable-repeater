// AI-Generate
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/main.dart';
import 'package:syllable_repeater_app/shared/error/error_messages.dart';

void main() {
  testWidgets('app shell opens lesson library home screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SyllableRepeaterApp());

    expect(find.text('課程匯入'), findsWidgets);
    expect(find.text('開啟課件'), findsOneWidget);
    expect(find.text('選擇 .abopack'), findsOneWidget);
    expect(find.text('尚未開啟課件'), findsOneWidget);
    expect(find.byIcon(Icons.library_music), findsOneWidget);
    for (final label in ['段落標籤', '單句分析', '段落校正', '錄音練習', '課程設定']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('error mapping covers all backend error codes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SyllableRepeaterApp());

    expect(ErrorMessages.mappedCodeCount, 26);
  });
}
