// AI-Generate
import 'dart:typed_data';
import 'dart:ui';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/features/arrangement/arrangement_section.dart';
import 'package:syllable_repeater_app/features/arrangement/widgets/arrangement_row.dart';
import 'package:syllable_repeater_app/features/editor/editor_controller.dart';

final _updatedAt = DateTime.utc(2026, 7, 14, 12);

Pcm _pcm() => Pcm(Int16List(44100));

List<Syllable> _syllables() => [
  Syllable(
    text: 'one',
    startMs: 0,
    endMs: 300,
    wordIndex: 0,
    needsReview: false,
  ),
  Syllable(
    text: 'two',
    startMs: 300,
    endMs: 600,
    wordIndex: 1,
    needsReview: false,
  ),
  Syllable(
    text: 'three',
    startMs: 600,
    endMs: 900,
    wordIndex: 2,
    needsReview: false,
  ),
];

List<Syllable> _manySyllables() => List.generate(
  8,
  (index) => Syllable(
    text: 's${index + 1}',
    startMs: index * 100,
    endMs: (index + 1) * 100,
    wordIndex: index,
    needsReview: false,
  ),
);

Lesson _lesson({PracticeArrangement? arrangement, List<Syllable>? source}) {
  final syllables = source ?? _syllables();
  return Lesson(
    id: 'arrangement-lesson',
    title: 'Arrangement lesson',
    audioRelPath: 'audio/original.wav',
    originalAudioBytes: Uint8List.fromList([1]),
    contentHash: 'hash',
    words: [
      Word(
        text: syllables.map((syllable) => syllable.text).join(' '),
        startMs: 0,
        endMs: syllables.last.endMs,
        index: 0,
      ),
    ],
    syllables: syllables,
    translations: const [],
    prosody: null,
    practiceConfig: const PracticeConfig(repeatN: 3),
    arrangement: arrangement,
    updatedAt: _updatedAt,
  );
}

Widget _wrap(
  ProviderContainer container, {
  ValueChanged<bool>? onOuterScrollLockChanged,
}) => UncontrolledProviderScope(
  container: container,
  child: MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: ArrangementSection(
          onOuterScrollLockChanged: onOuterScrollLockChanged,
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('AT-16-11 固定來源段落工具列且排列列有獨立垂直捲軸', (tester) async {
    tester.view.physicalSize = const Size(1100, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final syllables = _manySyllables();
    final arrangement = PracticeEngine().generateArrangement(
      syllables,
      lessonId: 'arrangement-lesson',
      updatedAt: _updatedAt,
    );
    container
        .read(editorControllerProvider.notifier)
        .loadLesson(
          _lesson(arrangement: arrangement, source: syllables),
          pcm: _pcm(),
        );

    await tester.pumpWidget(_wrap(container));

    expect(
      find.byKey(const ValueKey('arrangement-source-toolbar')),
      findsOneWidget,
    );
    final rowsScroll = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey('arrangement-rows-scroll')),
    );
    expect(rowsScroll.scrollDirection, Axis.vertical);
    expect(rowsScroll.controller, isNotNull);
    final scrollbar = tester.widget<Scrollbar>(
      find.byKey(const ValueKey('arrangement-rows-scrollbar')),
    );
    expect(scrollbar.thumbVisibility, isTrue);

    await tester.drag(
      find.byKey(const ValueKey('arrangement-rows-scroll')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(rowsScroll.controller!.offset, greaterThan(0));
    expect(
      find.byKey(const ValueKey('arrangement-source-toolbar')),
      findsOneWidget,
    );
  });

  testWidgets('AT-15-16 游標在列區或拖曳時鎖定外層捲動', (tester) async {
    tester.view.physicalSize = const Size(1100, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final syllables = _manySyllables();
    final arrangement = PracticeEngine().generateArrangement(
      syllables,
      lessonId: 'arrangement-lesson',
      updatedAt: _updatedAt,
    );
    container
        .read(editorControllerProvider.notifier)
        .loadLesson(
          _lesson(arrangement: arrangement, source: syllables),
          pcm: _pcm(),
        );
    final locks = <bool>[];
    await tester.pumpWidget(
      _wrap(container, onOuterScrollLockChanged: locks.add),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(1, 1));
    await mouse.moveTo(
      tester.getCenter(
        find.byKey(const ValueKey('arrangement-rows-mouse-region')),
      ),
    );
    await tester.pump();
    expect(locks.last, isTrue);

    await mouse.moveTo(const Offset(1, 1));
    await tester.pump();
    expect(locks.last, isFalse);

    final drag = await tester.startGesture(
      tester.getCenter(
        find.byKey(const ValueKey('arrangement-block-0')).first,
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
    expect(locks.last, isTrue);
    await drag.up();
    await tester.pump();
    expect(locks.last, isFalse);
  });

  testWidgets('AT-16-12 在第 5 列前插入後自動定位並短暫標示新列', (tester) async {
    tester.view.physicalSize = const Size(1100, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final syllables = _manySyllables();
    final arrangement = PracticeEngine().generateArrangement(
      syllables,
      lessonId: 'arrangement-lesson',
      updatedAt: _updatedAt,
    );
    container
        .read(editorControllerProvider.notifier)
        .loadLesson(
          _lesson(arrangement: arrangement, source: syllables),
          pcm: _pcm(),
        );
    await tester.pumpWidget(_wrap(container));

    final insertBeforeFive = find.byTooltip('在第 5 列前插入');
    await tester.ensureVisible(insertBeforeFive);
    await tester.tap(insertBeforeFive);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('arrangement-new-row-highlight-5')),
      findsOneWidget,
    );
    expect(
      container.read(editorControllerProvider).arrangement!.rows,
      hasLength(9),
    );
    expect(
      tester
          .getRect(
            find.byKey(const ValueKey('arrangement-new-row-highlight-5')),
          )
          .overlaps(
            tester.getRect(
              find.byKey(const ValueKey('arrangement-rows-viewport')),
            ),
          ),
      isTrue,
    );
  });

  testWidgets('AT-15-20 選來源段落後列區仍可直接捲動，不啟動拖曳', (tester) async {
    tester.view.physicalSize = const Size(1100, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final syllables = _manySyllables();
    final arrangement = PracticeEngine().generateArrangement(
      syllables,
      lessonId: 'arrangement-lesson',
      updatedAt: _updatedAt,
    );
    container
        .read(editorControllerProvider.notifier)
        .loadLesson(
          _lesson(arrangement: arrangement, source: syllables),
          pcm: _pcm(),
        );
    await tester.pumpWidget(_wrap(container));

    final rowsScroll = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey('arrangement-rows-scroll')),
    );
    await tester.tap(
      find.byKey(const ValueKey('arrangement-source-syllable-0')),
    );
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey('arrangement-rows-scroll')),
      const Offset(0, -350),
    );
    await tester.pumpAndSettle();

    expect(rowsScroll.controller!.offset, greaterThan(0));
    expect(
      find.byKey(const ValueKey('arrangement-pending-place-hint')),
      findsOneWidget,
    );
  });

  testWidgets('AT-15-19 捲到底後最後一列完整留在 viewport 且不回彈', (tester) async {
    tester.view.physicalSize = const Size(1100, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final rows = List.generate(
      8,
      (index) => PracticeRow(index: index + 1, blocks: const []),
    );
    final arrangement = PracticeArrangement(
      lessonId: 'arrangement-lesson',
      rows: rows,
      updatedAt: _updatedAt,
    );
    container
        .read(editorControllerProvider.notifier)
        .loadLesson(_lesson(arrangement: arrangement), pcm: _pcm());
    await tester.pumpWidget(_wrap(container));

    final rowsScroll = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey('arrangement-rows-scroll')),
    );
    rowsScroll.controller!.jumpTo(
      rowsScroll.controller!.position.maxScrollExtent,
    );
    await tester.pumpAndSettle();

    final viewport = tester.getRect(
      find.byKey(const ValueKey('arrangement-rows-viewport')),
    );
    final lastRow = tester.getRect(
      find.byKey(const ValueKey('arrangement-row-8')),
    );
    expect(lastRow.top, greaterThanOrEqualTo(viewport.top));
    expect(lastRow.bottom, lessThanOrEqualTo(viewport.bottom));
    final settledOffset = rowsScroll.controller!.offset;
    await tester.pump(const Duration(milliseconds: 500));
    expect(rowsScroll.controller!.offset, settledOffset);
  });

  testWidgets('AT-15-20 點選來源段落後可放手捲動，再點第 20 列空列放下', (tester) async {
    tester.view.physicalSize = const Size(1100, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final arrangement = PracticeArrangement(
      lessonId: 'arrangement-lesson',
      rows: List.generate(
        20,
        (index) => PracticeRow(index: index + 1, blocks: const []),
      ),
      updatedAt: _updatedAt,
    );
    container
        .read(editorControllerProvider.notifier)
        .loadLesson(_lesson(arrangement: arrangement), pcm: _pcm());
    await tester.pumpWidget(_wrap(container));

    expect(find.text('來源段落'), findsOneWidget);
    expect(find.text('來源積木'), findsNothing);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('arrangement-source-syllable-0')),
        matching: find.byType(Draggable<ArrangementDragData>),
      ),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('arrangement-source-syllable-0')),
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('arrangement-pending-place-hint')),
      findsOneWidget,
    );
    expect(find.textContaining('請點各列的插入圖示'), findsOneWidget);

    final rowsScroll = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey('arrangement-rows-scroll')),
    );
    rowsScroll.controller!.jumpTo(
      rowsScroll.controller!.position.maxScrollExtent,
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('arrangement-source-empty-19')),
      warnIfMissed: false,
    );
    await tester.pump();

    final row20 = container
        .read(editorControllerProvider)
        .arrangement!
        .rows[19];
    expect(row20.blocks, hasLength(1));
    expect(row20.blocks.single.syllables.single.text, 'one');
    expect(
      find.byKey(const ValueKey('arrangement-pending-place-hint')),
      findsNothing,
    );
  });

  testWidgets('一鍵生成排列 → 依音節數建立 N 列並同步 editor', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(editorControllerProvider.notifier)
        .loadLesson(_lesson(), pcm: _pcm());

    await tester.pumpWidget(_wrap(container));
    expect(find.byKey(const ValueKey('arrangement-generate')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('arrangement-generate')));
    await tester.pump();

    expect(find.byKey(const ValueKey('arrangement-row-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('arrangement-row-3')), findsOneWidget);
    expect(
      container.read(editorControllerProvider).arrangement!.rows,
      hasLength(3),
    );
  });

  testWidgets('插入／刪除列後重新編號，排列 undo 不污染校正 undo', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(editorControllerProvider.notifier)
        .loadLesson(_lesson(), pcm: _pcm());

    await tester.pumpWidget(_wrap(container));
    await tester.tap(find.byKey(const ValueKey('arrangement-generate')));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('arrangement-insert-row')));
    await tester.pump();
    expect(find.byKey(const ValueKey('arrangement-row-4')), findsOneWidget);
    expect(container.read(editorControllerProvider).undoStack, isEmpty);

    final undo = find.byKey(const ValueKey('arrangement-undo'));
    await tester.ensureVisible(undo);
    await tester.tap(undo);
    await tester.pump();
    expect(find.byKey(const ValueKey('arrangement-row-4')), findsNothing);
    expect(find.byKey(const ValueKey('arrangement-row-3')), findsOneWidget);
  });

  testWidgets('FP19.1 刪除排列入口位於自由排列標題左側並可確認刪除', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final arrangement = PracticeEngine().generateArrangement(
      _syllables(),
      lessonId: 'arrangement-lesson',
      updatedAt: _updatedAt,
    );
    container
        .read(editorControllerProvider.notifier)
        .loadLesson(_lesson(arrangement: arrangement), pcm: _pcm());

    await tester.pumpWidget(_wrap(container));
    expect(find.byKey(const ValueKey('arrangement-remove')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('arrangement-remove')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('arrangement-remove-confirm')));
    await tester.pumpAndSettle();

    expect(container.read(editorControllerProvider).arrangement, isNull);
    expect(find.byKey(const ValueKey('arrangement-generate')), findsOneWidget);
  });

  testWidgets('音節總數變更顯示 stale banner，保留後清除旗標', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final arrangement = PracticeEngine().generateArrangement(
      _syllables(),
      lessonId: 'arrangement-lesson',
      updatedAt: _updatedAt,
    );
    final editor = container.read(editorControllerProvider.notifier);
    editor.loadLesson(_lesson(arrangement: arrangement), pcm: _pcm());

    await tester.pumpWidget(_wrap(container));
    expect(
      find.byKey(const ValueKey('arrangement-stale-banner')),
      findsNothing,
    );

    final extra = Syllable(
      text: 'again',
      startMs: 900,
      endMs: 1200,
      wordIndex: 2,
      needsReview: true,
    );
    editor.applySyllableEdit(
      AlignmentResult(
        words: const [],
        syllables: [..._syllables(), extra],
        source: 'arrangement-test',
        confidence: 1,
      ),
      updatedAt: _updatedAt.add(const Duration(minutes: 1)),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('arrangement-stale-banner')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('arrangement-keep')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('arrangement-stale-banner')),
      findsNothing,
    );
    expect(
      container.read(editorControllerProvider).arrangement!.staleFlag,
      isFalse,
    );
  });

  testWidgets('AT-15-04 雙擊積木開啟設定後立即同步 repeatN', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(editorControllerProvider.notifier)
        .loadLesson(_lesson(), pcm: _pcm());

    await tester.pumpWidget(_wrap(container));
    await tester.tap(find.byKey(const ValueKey('arrangement-generate')));
    await tester.pump();
    final block = find.byKey(const ValueKey('arrangement-block-0')).first;
    await tester.tap(block);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(block);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('block-repeat-increment')));
    await tester.pump();

    expect(
      container
          .read(editorControllerProvider)
          .arrangement!
          .rows
          .first
          .blocks
          .first
          .repeatN,
      2,
    );
  });
}
