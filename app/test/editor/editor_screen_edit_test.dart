// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/features/editor/editor_controller.dart';
import 'package:syllable_repeater_app/features/editor/editor_screen.dart';
import 'package:syllable_repeater_app/shared/tokens.dart';

List<Syllable> _sample() => [
  Syllable(
    text: 'she',
    startMs: 0,
    endMs: 500,
    wordIndex: 0,
    needsReview: false,
  ),
  Syllable(
    text: 'has',
    startMs: 500,
    endMs: 1000,
    wordIndex: 1,
    needsReview: false,
  ),
];

Future<ProviderContainer> _pumpEditor(
  WidgetTester tester, {
  List<Syllable>? syllables,
}) async {
  final container = ProviderContainer();
  container
      .read(editorControllerProvider.notifier)
      .loadFrom(syllables ?? _sample());
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: EditorScreen())),
    ),
  );
  return container;
}

Future<void> _doubleTap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('AT-10-06 校正頁主標題使用段落校正且無舊名稱', (tester) async {
    final container = await _pumpEditor(tester);
    addTearDown(container.dispose);

    expect(find.text('段落校正'), findsOneWidget);
    expect(find.text('音節校正'), findsNothing);
  });

  testWidgets('chip 顯示 1-based 序號，點選後與 controller 共用選中', (tester) async {
    final container = await _pumpEditor(tester);
    addTearDown(container.dispose);

    expect(find.byKey(const ValueKey('syllable-index-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('syllable-index-2')), findsOneWidget);

    await tester.tap(find.text('has'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(editorControllerProvider).selectedSyllableIndex, 1);
  });

  testWidgets('雙擊 chip 進入 TextField，修改文字保留原始辨識文字', (tester) async {
    final container = await _pumpEditor(tester);
    addTearDown(container.dispose);

    await _doubleTap(tester, find.byType(InkWell).at(3));
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'had');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    final syllable = container.read(editorControllerProvider).syllables[1];
    expect(syllable.text, 'had');
    expect(syllable.originalText, 'has');
    expect(syllable.needsReview, isFalse);
  });

  testWidgets('AT-17-01 同一選取時間範圍內的所有 chip 一起顯示黃色', (tester) async {
    final container = await _pumpEditor(tester);
    addTearDown(container.dispose);
    final ctl = container.read(editorControllerProvider.notifier);

    ctl.beginTimeSelection(250);
    ctl.updateTimeSelection(750);
    ctl.endTimeSelection();
    await tester.pump();

    for (final index in [1, 2]) {
      final chip = tester.widget<Container>(
        find.byKey(ValueKey('syllable-chip-$index')),
      );
      final decoration = chip.decoration! as BoxDecoration;
      expect(decoration.color, AppTokens.selectedHighlight);
    }
  });

  testWidgets('雙擊 chip 清空文字 → Domain 標記 needsReview', (tester) async {
    final container = await _pumpEditor(tester);
    addTearDown(container.dispose);

    await _doubleTap(tester, find.byType(InkWell).at(3));
    await tester.enterText(find.byType(TextField), '');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    final syllable = container.read(editorControllerProvider).syllables[1];
    expect(syllable.text, isEmpty);
    expect(syllable.originalText, 'has');
    expect(syllable.needsReview, isTrue);
  });

  testWidgets('刪除切點後 chip 序號連續重排', (tester) async {
    final container = await _pumpEditor(tester);
    addTearDown(container.dispose);

    container.read(editorControllerProvider.notifier).removeBoundary(0);
    await tester.pump();

    expect(find.byKey(const ValueKey('syllable-index-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('syllable-index-2')), findsNothing);
  });
}
