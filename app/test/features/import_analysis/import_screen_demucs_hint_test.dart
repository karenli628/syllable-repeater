// AI-Generate
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/features/import_analysis/analysis_controller.dart';
import 'package:syllable_repeater_app/main.dart';

Future<void> _pumpApp(WidgetTester tester,
    {required bool demucsReady}) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(SyllableRepeaterApp(overrides: [
    demucsReadyProvider.overrideWithValue(demucsReady),
  ]));
}

void main() {
  testWidgets('demucs 就緒 → 勾 separateVocals 不顯示未就緒 icon', (tester) async {
    await _pumpApp(tester, demucsReady: true);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.info_outline), findsNothing);
  });

  testWidgets('demucs 未就緒 → 未勾時不顯示 icon（無干擾）', (tester) async {
    await _pumpApp(tester, demucsReady: false);
    // 不點 checkbox
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.info_outline), findsNothing);
  });

  testWidgets('demucs 未就緒 → 勾 separateVocals 顯示未就緒 tooltip icon',
      (tester) async {
    await _pumpApp(tester, demucsReady: false);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    // Tooltip message 存在
    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip).first);
    expect(tooltip.message, contains('demucs 未就緒'));
  });
}
