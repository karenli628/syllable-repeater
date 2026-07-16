// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/features/editor/waveform_node_range.dart';
import 'package:syllable_repeater_app/features/editor/widgets/waveform_canvas.dart';

Widget _wrap(Widget child, {double width = 400}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(width: width, height: 180, child: child),
    ),
  ),
);

List<Syllable> _twoSyllables() => [
  Syllable(text: 'a', startMs: 0, endMs: 500, wordIndex: 0, needsReview: false),
  Syllable(
    text: 'b',
    startMs: 500,
    endMs: 1000,
    wordIndex: 1,
    needsReview: true,
  ),
];

List<Syllable> _edgeGappedSyllables() => [
  Syllable(
    text: 'first',
    startMs: 100,
    endMs: 400,
    wordIndex: 0,
    needsReview: false,
  ),
  Syllable(
    text: 'last',
    startMs: 400,
    endMs: 800,
    wordIndex: 1,
    needsReview: false,
  ),
];

void main() {
  testWidgets('AT-14-07 播放位置顯示紅色虛線軸', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 160,
          child: WaveformCanvas(
            peaks: const [],
            syllables: [
              Syllable(
                text: 'test',
                startMs: 0,
                endMs: 1200,
                wordIndex: 0,
                needsReview: false,
              ),
            ],
            totalDurationMs: 1200,
            draggingBoundaryIndex: null,
            draggingPreviewMs: null,
            playheadMs: 600,
            onDragStart: (_) {},
            onDragUpdate: (_) {},
            onDragEnd: () {},
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('editor-playhead')), findsOneWidget);
  });

  test('AT-17-09 首尾高亮區間吸附波形邊緣與節點線', () {
    final syllables = _edgeGappedSyllables();

    expect(
      waveformNodeRange(
        syllables: syllables,
        syllableIndex: 0,
        totalDurationMs: 1000,
      ),
      TimeRange(0, 400),
    );
    expect(
      waveformNodeRange(
        syllables: syllables,
        syllableIndex: 1,
        totalDurationMs: 1000,
      ),
      TimeRange(400, 1000),
    );
  });

  testWidgets('點在邊界 ±12dp 內 → onDragStart 被呼叫', (tester) async {
    int? startedIndex;
    int? updatedMs;
    var ended = 0;

    // WaveformCanvas 內 onPanUpdate 依 draggingBoundaryIndex 為 non-null 才 fire；
    // 用 StatefulBuilder 模擬 controller 收到 onDragStart 後把 index 塞回 prop。
    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return WaveformCanvas(
              peaks: List.filled(10, WaveformPeak(-0.5, 0.5)),
              syllables: _twoSyllables(),
              totalDurationMs: 1000,
              draggingBoundaryIndex: startedIndex,
              draggingPreviewMs: updatedMs,
              onDragStart: (i) => setState(() => startedIndex = i),
              onDragUpdate: (ms) => setState(() => updatedMs = ms),
              onDragEnd: () => setState(() {
                ended++;
                startedIndex = null;
              }),
            );
          },
        ),
      ),
    );

    // 邊界（endMs=500）→ 200dp（500/1000 * 400）
    final canvas = find.byType(WaveformCanvas);
    final center = tester.getCenter(canvas);

    // 找一個容器的 top-left，計算邊界應該在 x=200 附近（相對於 canvas）
    final canvasRect = tester.getRect(canvas);
    final boundaryX = canvasRect.left + 200;

    final startPoint = Offset(boundaryX, center.dy);
    final gesture = await tester.startGesture(startPoint);
    await tester.pump();
    // 滑動一小段觸發 pan 進入 gesture arena；此時 onPanDown 才會 fire
    await gesture.moveTo(Offset(boundaryX + 20, center.dy));
    await tester.pump();

    expect(startedIndex, 0, reason: '邊界 0 應該被命中');
    expect(updatedMs, isNotNull, reason: 'moveTo 應觸發 onDragUpdate');
    expect(updatedMs, greaterThan(500));

    await gesture.up();
    await tester.pump();
    expect(ended, 1);
  });

  testWidgets('點在邊界外 > 12dp → 不觸發 onDragStart', (tester) async {
    int? startedIndex;

    await tester.pumpWidget(
      _wrap(
        WaveformCanvas(
          peaks: const [],
          syllables: _twoSyllables(),
          totalDurationMs: 1000,
          draggingBoundaryIndex: null,
          draggingPreviewMs: null,
          onDragStart: (i) => startedIndex = i,
          onDragUpdate: (_) {},
          onDragEnd: () {},
        ),
      ),
    );

    final canvasRect = tester.getRect(find.byType(WaveformCanvas));
    final farFromBoundary = Offset(
      canvasRect.left + 100,
      canvasRect.center.dy,
    ); // 距 200 有 100dp
    final gesture = await tester.startGesture(farFromBoundary);
    await tester.pump();

    expect(startedIndex, isNull);
    await gesture.up();
  });

  testWidgets('渲染不 crash（peaks 空、totalDurationMs=0）', (tester) async {
    await tester.pumpWidget(
      _wrap(
        WaveformCanvas(
          peaks: const [],
          syllables: const [],
          totalDurationMs: 0,
          draggingBoundaryIndex: null,
          draggingPreviewMs: null,
          onDragStart: (_) {},
          onDragUpdate: (_) {},
          onDragEnd: () {},
        ),
      ),
    );

    expect(find.byType(WaveformCanvas), findsOneWidget);
  });

  testWidgets('韻律疊圖渲染不 crash（pitch/stress/NaN 音節）', (tester) async {
    await tester.pumpWidget(
      _wrap(
        WaveformCanvas(
          peaks: List.filled(12, WaveformPeak(-0.4, 0.5)),
          syllables: _twoSyllables(),
          totalDurationMs: 1000,
          draggingBoundaryIndex: null,
          draggingPreviewMs: null,
          prosody: Prosody(
            rhythm: const [1, double.nan],
            intensity: const [0.2, 0.0, 0.3],
            stress: const [0.8, double.nan],
            pitchContour: const [180, 190, 190, 185],
            pitchAvailable: true,
          ),
          onDragStart: (_) {},
          onDragUpdate: (_) {},
          onDragEnd: () {},
        ),
      ),
    );

    expect(find.byType(WaveformCanvas), findsOneWidget);
  });

  testWidgets('點選音節區段 → 回傳選取音節 index', (tester) async {
    int? selectedIndex;
    await tester.pumpWidget(
      _wrap(
        WaveformCanvas(
          peaks: const [],
          syllables: _twoSyllables(),
          totalDurationMs: 1000,
          draggingBoundaryIndex: null,
          draggingPreviewMs: null,
          selectedSyllableIndex: 1,
          onSelectSyllable: (index) => selectedIndex = index,
          onDragStart: (_) {},
          onDragUpdate: (_) {},
          onDragEnd: () {},
        ),
      ),
    );

    final rect = tester.getRect(find.byType(WaveformCanvas));
    await tester.tapAt(Offset(rect.left + 100, rect.center.dy));
    await tester.pump();

    expect(selectedIndex, 0);
  });

  testWidgets('AT-17-01 非切點拖曳 → 回傳開始、更新與結束時間', (tester) async {
    int? startedAtMs;
    int? updatedAtMs;
    var ended = 0;
    await tester.pumpWidget(
      _wrap(
        WaveformCanvas(
          peaks: const [],
          syllables: _twoSyllables(),
          totalDurationMs: 1000,
          draggingBoundaryIndex: null,
          draggingPreviewMs: null,
          onTimeSelectionStart: (atMs) => startedAtMs = atMs,
          onTimeSelectionUpdate: (atMs) => updatedAtMs = atMs,
          onTimeSelectionEnd: () => ended++,
          onDragStart: (_) {},
          onDragUpdate: (_) {},
          onDragEnd: () {},
        ),
      ),
    );

    final rect = tester.getRect(find.byType(WaveformCanvas));
    final gesture = await tester.startGesture(
      Offset(rect.left + 100, rect.center.dy),
    );
    await gesture.moveTo(Offset(rect.left + 300, rect.center.dy));
    await gesture.up();
    await tester.pump();

    expect(startedAtMs, 250);
    expect(updatedAtMs, 750);
    expect(ended, 1);
  });

  testWidgets('AT-13-08 刪除切點控制只回呼 boundary index', (tester) async {
    int? removedIndex;
    await tester.pumpWidget(
      _wrap(
        WaveformCanvas(
          peaks: const [],
          syllables: _twoSyllables(),
          totalDurationMs: 1000,
          draggingBoundaryIndex: null,
          draggingPreviewMs: null,
          onRemoveBoundary: (index) => removedIndex = index,
          onDragStart: (_) {},
          onDragUpdate: (_) {},
          onDragEnd: () {},
        ),
      ),
    );

    final deleteButton = find.byTooltip('刪除切點 1');
    expect(deleteButton, findsOneWidget);
    await tester.tap(deleteButton);
    await tester.pump();

    expect(removedIndex, 0);
  });

  testWidgets('音節內有足夠空間 → 新增切點回呼音節 index 與毫秒', (tester) async {
    int? insertedIndex;
    int? insertedAtMs;
    await tester.pumpWidget(
      _wrap(
        WaveformCanvas(
          peaks: const [],
          syllables: _twoSyllables(),
          totalDurationMs: 1000,
          draggingBoundaryIndex: null,
          draggingPreviewMs: null,
          onInsertBoundary: (index, atMs) {
            insertedIndex = index;
            insertedAtMs = atMs;
          },
          onDragStart: (_) {},
          onDragUpdate: (_) {},
          onDragEnd: () {},
        ),
      ),
    );

    final addButton = find.byTooltip('新增切點 1');
    expect(addButton, findsOneWidget);
    await tester.tap(addButton);
    await tester.pump();

    expect(insertedIndex, 0);
    expect(insertedAtMs, 250);
  });

  testWidgets('AT-17-10 最後區段新增切點使用最後節點至音檔結尾', (tester) async {
    int? insertedIndex;
    int? insertedAtMs;
    await tester.pumpWidget(
      _wrap(
        WaveformCanvas(
          peaks: const [],
          syllables: _edgeGappedSyllables(),
          totalDurationMs: 1000,
          draggingBoundaryIndex: null,
          draggingPreviewMs: null,
          onInsertBoundary: (index, atMs) {
            insertedIndex = index;
            insertedAtMs = atMs;
          },
          onDragStart: (_) {},
          onDragUpdate: (_) {},
          onDragEnd: () {},
        ),
      ),
    );

    await tester.tap(find.byTooltip('新增切點 2'));
    await tester.pump();

    expect(insertedIndex, 1);
    expect(insertedAtMs, 700);
  });

  testWidgets('音節短於兩側各 50ms → 新增切點控制停用', (tester) async {
    var inserted = false;
    await tester.pumpWidget(
      _wrap(
        WaveformCanvas(
          peaks: const [],
          syllables: [
            Syllable(
              text: 'short',
              startMs: 0,
              endMs: 80,
              wordIndex: 0,
              needsReview: false,
            ),
          ],
          totalDurationMs: 80,
          draggingBoundaryIndex: null,
          draggingPreviewMs: null,
          onInsertBoundary: (_, __) => inserted = true,
          onDragStart: (_) {},
          onDragUpdate: (_) {},
          onDragEnd: () {},
        ),
      ),
    );

    final addButton = find.byTooltip('新增切點 1');
    expect(addButton, findsOneWidget);
    await tester.tap(addButton);
    await tester.pump();

    expect(inserted, isFalse);
  });
}
