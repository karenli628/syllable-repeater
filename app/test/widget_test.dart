// AI-Generate
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/main.dart';
import 'package:syllable_repeater_app/shared/error/error_messages.dart';

void main() {
  testWidgets('app shell opens import analysis screen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SyllableRepeaterApp());

    expect(find.text('匯入與分析'), findsOneWidget);
    expect(find.text('選擇音檔'), findsOneWidget);
    expect(find.text('開始分析'), findsOneWidget);
    expect(find.byIcon(Icons.upload_file), findsOneWidget);
  });

  testWidgets('error mapping covers all backend error codes', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SyllableRepeaterApp());

    expect(ErrorMessages.mappedCodeCount, 19);
  });
}
