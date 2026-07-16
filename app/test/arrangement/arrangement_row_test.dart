// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/features/arrangement/widgets/arrangement_row.dart';

List<Syllable> _syllables(String prefix) => [
  Syllable(
    text: '$prefix-one',
    startMs: 0,
    endMs: 300,
    wordIndex: 0,
    needsReview: false,
  ),
  Syllable(
    text: '$prefix-two',
    startMs: 300,
    endMs: 600,
    wordIndex: 1,
    needsReview: false,
  ),
];

PracticeRow _row(int index, String prefix) {
  final syllables = _syllables(prefix);
  return PracticeRow(
    index: index,
    blocks: [
      PracticeBlock(syllables: [syllables[0]]),
      PracticeBlock(syllables: [syllables[1]]),
    ],
  );
}

Widget _wrap(List<Widget> rows) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(child: Column(children: rows)),
  ),
);

ArrangementRow _widget({
  required PracticeRow row,
  required void Function(int, int, int) onGroup,
  required void Function(int, int, int) onMove,
  void Function(int, int)? onRemoveBlock,
  void Function(int, int, int)? onRemoveGroupedSyllable,
  void Function(int, int, int, int)? onExtractGroupedSyllable,
  void Function(int, int, int, int)? onMoveSingleIntoGroup,
}) => ArrangementRow(
  row: row,
  rowIndex: row.index - 1,
  canRemove: true,
  onInsertBefore: () {},
  onRemove: () {},
  onGroup: onGroup,
  onMove: onMove,
  onPlaceSyllable: (_, __, ___, ____) {},
  onReorderGroupedSyllable: (_, __, ___, ____) {},
  onUngroup: (_, __) {},
  onRemoveBlock: onRemoveBlock ?? (_, __) {},
  onRemoveGroupedSyllable: onRemoveGroupedSyllable ?? (_, __, ___) {},
  onExtractGroupedSyllable: onExtractGroupedSyllable ?? (_, __, ___, ____) {},
  onMoveSingleIntoGroup: onMoveSingleIntoGroup ?? (_, __, ___, ____) {},
);

Future<void> _longPressDrag(
  WidgetTester tester,
  Finder source,
  Finder target,
) async {
  final gesture = await tester.startGesture(tester.getCenter(source));
  await tester.pump(const Duration(milliseconds: 350));
  await gesture.moveTo(tester.getCenter(target));
  await tester.pump();
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('AT-15-17 同列積木本體長按拖到另一積木後成組', (tester) async {
    final groups = <List<int>>[];
    await tester.pumpWidget(
      _wrap([
        _widget(
          row: _row(1, 'row'),
          onGroup: (row, from, to) => groups.add([row, from, to]),
          onMove: (_, __, ___) {},
        ),
      ]),
    );

    await _longPressDrag(
      tester,
      find.byKey(const ValueKey('arrangement-block-0')),
      find.byKey(const ValueKey('arrangement-block-1')),
    );

    expect(groups, [
      [0, 0, 1],
    ]);
  });

  testWidgets('AT-15-17 跨列長按拖曳取消，且沒有六點把手', (tester) async {
    final moves = <List<int>>[];
    final groups = <List<int>>[];
    await tester.pumpWidget(
      _wrap([
        _widget(
          row: _row(1, 'first'),
          onGroup: (row, from, to) => groups.add([row, from, to]),
          onMove: (row, from, to) => moves.add([row, from, to]),
        ),
        _widget(
          row: _row(2, 'second'),
          onGroup: (row, from, to) => groups.add([row, from, to]),
          onMove: (row, from, to) => moves.add([row, from, to]),
        ),
      ]),
    );

    expect(find.byIcon(Icons.drag_indicator), findsNothing);
    await _longPressDrag(
      tester,
      find.byKey(const ValueKey('arrangement-block-0')).first,
      find.byKey(const ValueKey('arrangement-gap-1-0')),
    );

    expect(groups, isEmpty);
    expect(moves, isEmpty);
  });

  testWidgets('成組積木內長按排序，且拆組按鈕回呼', (tester) async {
    final syllables = _syllables('group');
    final reorders = <List<int>>[];
    var ungrouped = false;
    final row = PracticeRow(
      index: 1,
      blocks: [PracticeBlock(syllables: syllables, isGrouped: true)],
    );
    await tester.pumpWidget(
      _wrap([
        ArrangementRow(
          row: row,
          rowIndex: 0,
          canRemove: true,
          onInsertBefore: () {},
          onRemove: () {},
          onGroup: (_, __, ___) {},
          onMove: (_, __, ___) {},
          onPlaceSyllable: (_, __, ___, ____) {},
          onReorderGroupedSyllable: (r, b, from, to) =>
              reorders.add([r, b, from, to]),
          onUngroup: (_, __) => ungrouped = true,
          onRemoveBlock: (_, __) {},
          onRemoveGroupedSyllable: (_, __, ___) {},
          onExtractGroupedSyllable: (_, __, ___, ____) {},
          onMoveSingleIntoGroup: (_, __, ___, ____) {},
        ),
      ]),
    );

    await _longPressDrag(
      tester,
      find.byKey(const ValueKey('arrangement-member-0-0')),
      find.byKey(const ValueKey('arrangement-member-target-0-0-2')),
    );
    expect(reorders, [
      [0, 0, 0, 1],
    ]);

    await tester.tap(find.byTooltip('拆組'));
    await tester.pump();
    expect(ungrouped, isTrue);
  });

  testWidgets('AT-15-10 選取來源段落後可點空列放下', (tester) async {
    final syllable = _syllables('pool').first;
    final placed = <Object>[];
    final emptyRow = PracticeRow(index: 1, blocks: const []);
    await tester.pumpWidget(
      _wrap([
        ArrangementRow(
          row: emptyRow,
          rowIndex: 0,
          canRemove: true,
          onInsertBefore: () {},
          onRemove: () {},
          onGroup: (_, __, ___) {},
          onMove: (_, __, ___) {},
          onPlaceSyllable: (row, position, value, lessonId) =>
              placed.addAll([row, position, value.text, lessonId]),
          onReorderGroupedSyllable: (_, __, ___, ____) {},
          onUngroup: (_, __) {},
          onRemoveBlock: (_, __) {},
          onRemoveGroupedSyllable: (_, __, ___) {},
          onExtractGroupedSyllable: (_, __, ___, ____) {},
          onMoveSingleIntoGroup: (_, __, ___, ____) {},
          pendingSourceSyllable: syllable,
          pendingSourceLessonId: 'lesson-a',
        ),
      ]),
    );

    await tester.tap(find.text('點此放下積木'));
    await tester.pump();
    expect(placed, [0, 0, 'pool-one', 'lesson-a']);
  });

  testWidgets('積木右側無設定與播放圖示，雙擊積木才開設定', (tester) async {
    final configured = <int>[];
    await tester.pumpWidget(
      _wrap([
        ArrangementRow(
          row: _row(1, 'row'),
          rowIndex: 0,
          canRemove: true,
          onInsertBefore: () {},
          onRemove: () {},
          onGroup: (_, __, ___) {},
          onMove: (_, __, ___) {},
          onPlaceSyllable: (_, __, ___, ____) {},
          onReorderGroupedSyllable: (_, __, ___, ____) {},
          onUngroup: (_, __) {},
          onRemoveBlock: (_, __) {},
          onRemoveGroupedSyllable: (_, __, ___) {},
          onExtractGroupedSyllable: (_, __, ___, ____) {},
          onMoveSingleIntoGroup: (_, __, ___, ____) {},
          onConfigureBlock: (row, block) => configured.add(block),
        ),
      ]),
    );

    final block = find.byKey(const ValueKey('arrangement-block-0'));
    expect(
      find.descendant(of: block, matching: find.byIcon(Icons.tune)),
      findsNothing,
    );
    expect(
      find.descendant(of: block, matching: find.byIcon(Icons.play_arrow)),
      findsNothing,
    );
    expect(find.byIcon(Icons.mic_none), findsNothing);
    expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('arrangement-block-0')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const ValueKey('arrangement-block-0')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(configured, [0]);
  });

  testWidgets('AT-15-17 點選單一積木後可刪除，六點把手已移除', (tester) async {
    final removed = <List<int>>[];
    await tester.pumpWidget(
      _wrap([
        _widget(
          row: _row(1, 'single'),
          onGroup: (_, __, ___) {},
          onMove: (_, __, ___) {},
          onRemoveBlock: (row, block) => removed.add([row, block]),
        ),
      ]),
    );

    expect(
      find.byKey(const ValueKey('arrangement-block-handle-0')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('arrangement-block-0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('arrangement-block-0')));
    await tester.pump();
    await tester.tap(find.byTooltip('刪除積木'));
    await tester.pump();

    expect(removed, [
      [0, 0],
    ]);
  });

  testWidgets('AT-15-17 點選組合背景會刪除整組，整組六點把手已移除', (tester) async {
    final removed = <List<int>>[];
    final row = PracticeRow(
      index: 1,
      blocks: [PracticeBlock(syllables: _syllables('group'), isGrouped: true)],
    );
    await tester.pumpWidget(
      _wrap([
        _widget(
          row: row,
          onGroup: (_, __, ___) {},
          onMove: (_, __, ___) {},
          onRemoveBlock: (r, b) => removed.add([r, b]),
        ),
      ]),
    );

    expect(
      find.byKey(const ValueKey('arrangement-group-handle-0')),
      findsNothing,
    );
    final groupRect = tester.getRect(
      find.byKey(const ValueKey('arrangement-group-0')),
    );
    await tester.tapAt(groupRect.topLeft + const Offset(3, 3));
    await tester.pump();
    await tester.tap(find.byTooltip('刪除整個組合'));
    await tester.pump();
    expect(removed, [
      [0, 0],
    ]);
  });

  testWidgets('AT-15-18 組內音節可個別選取刪除', (tester) async {
    final removed = <List<int>>[];
    final row = PracticeRow(
      index: 1,
      blocks: [PracticeBlock(syllables: _syllables('member'), isGrouped: true)],
    );
    await tester.pumpWidget(
      _wrap([
        _widget(
          row: row,
          onGroup: (_, __, ___) {},
          onMove: (_, __, ___) {},
          onRemoveGroupedSyllable: (r, b, s) => removed.add([r, b, s]),
        ),
      ]),
    );

    await tester.tap(find.byKey(const ValueKey('arrangement-member-0-1')));
    await tester.pump();
    await tester.tap(find.byTooltip('刪除組內音節'));
    await tester.pump();
    expect(removed, [
      [0, 0, 1],
    ]);
  });

  testWidgets('AT-15-18 組內音節可抽到積木間成為單一積木', (tester) async {
    final extracted = <List<int>>[];
    final row = PracticeRow(
      index: 1,
      blocks: [PracticeBlock(syllables: _syllables('member'), isGrouped: true)],
    );
    await tester.pumpWidget(
      _wrap([
        _widget(
          row: row,
          onGroup: (_, __, ___) {},
          onMove: (_, __, ___) {},
          onExtractGroupedSyllable: (row, block, syllable, to) =>
              extracted.add([row, block, syllable, to]),
        ),
      ]),
    );

    await _longPressDrag(
      tester,
      find.byKey(const ValueKey('arrangement-member-0-1')),
      find.byKey(const ValueKey('arrangement-gap-0-1')),
    );
    expect(extracted, [
      [0, 0, 1, 1],
    ]);
  });

  testWidgets('AT-15-18 單一積木可拖入組合的指定序位', (tester) async {
    final moved = <List<int>>[];
    final syllables = _syllables('mix');
    final row = PracticeRow(
      index: 1,
      blocks: [
        PracticeBlock(syllables: [syllables.first]),
        PracticeBlock(syllables: syllables, isGrouped: true),
      ],
    );
    await tester.pumpWidget(
      _wrap([
        _widget(
          row: row,
          onGroup: (_, __, ___) {},
          onMove: (_, __, ___) {},
          onMoveSingleIntoGroup: (row, fromBlock, toBlock, toSyllable) =>
              moved.add([row, fromBlock, toBlock, toSyllable]),
        ),
      ]),
    );

    await _longPressDrag(
      tester,
      find.byKey(const ValueKey('arrangement-block-0')),
      find.byKey(const ValueKey('arrangement-member-target-0-1-1')),
    );
    expect(moved, [
      [0, 0, 1, 1],
    ]);
  });

  testWidgets('AT-15-20 來源段落插入按鈕可放到第一個、中間與列尾', (tester) async {
    final syllable = _syllables('source').first;
    final placed = <List<Object>>[];
    var cleared = 0;
    await tester.pumpWidget(
      _wrap([
        ArrangementRow(
          row: _row(1, 'target'),
          rowIndex: 0,
          canRemove: true,
          onInsertBefore: () {},
          onRemove: () {},
          onGroup: (_, __, ___) {},
          onMove: (_, __, ___) {},
          onPlaceSyllable: (row, position, value, lessonId) =>
              placed.add([row, position, value.text, lessonId]),
          onReorderGroupedSyllable: (_, __, ___, ____) {},
          onUngroup: (_, __) {},
          onRemoveBlock: (_, __) {},
          onRemoveGroupedSyllable: (_, __, ___) {},
          onExtractGroupedSyllable: (_, __, ___, ____) {},
          onMoveSingleIntoGroup: (_, __, ___, ____) {},
          pendingSourceSyllable: syllable,
          pendingSourceLessonId: 'lesson-a',
          onPendingPlaced: () => cleared++,
        ),
      ]),
    );

    expect(find.byIcon(Icons.vertical_align_center), findsNothing);
    expect(
      find.byKey(const ValueKey('arrangement-source-insert-0-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('arrangement-source-insert-0-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('arrangement-source-insert-0-2')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('arrangement-source-insert-0-0')),
    );
    await tester.pump();
    expect(placed, [
      [0, 0, 'source-one', 'lesson-a'],
    ]);
    expect(cleared, 1);
  });
}
