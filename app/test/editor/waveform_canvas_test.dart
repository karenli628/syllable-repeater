// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/features/editor/widgets/waveform_canvas.dart';

Widget _wrap(Widget child, {double width = 400}) => MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: width, height: 180, child: child)),
      ),
    );

List<Syllable> _twoSyllables() => [
      Syllable(
          text: 'a',
          startMs: 0,
          endMs: 500,
          wordIndex: 0,
          needsReview: false),
      Syllable(
          text: 'b',
          startMs: 500,
          endMs: 1000,
          wordIndex: 1,
          needsReview: true),
    ];

void main() {
  testWidgets('點在邊界 ±12dp 內 → onDragStart 被呼叫', (tester) async {
    int? startedIndex;
    int? updatedMs;
    var ended = 0;

    // WaveformCanvas 內 onPanUpdate 依 draggingBoundaryIndex 為 non-null 才 fire；
    // 用 StatefulBuilder 模擬 controller 收到 onDragStart 後把 index 塞回 prop。
    await tester.pumpWidget(_wrap(StatefulBuilder(
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
    )));

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

    await tester.pumpWidget(_wrap(WaveformCanvas(
      peaks: const [],
      syllables: _twoSyllables(),
      totalDurationMs: 1000,
      draggingBoundaryIndex: null,
      draggingPreviewMs: null,
      onDragStart: (i) => startedIndex = i,
      onDragUpdate: (_) {},
      onDragEnd: () {},
    )));

    final canvasRect = tester.getRect(find.byType(WaveformCanvas));
    final farFromBoundary =
        Offset(canvasRect.left + 100, canvasRect.center.dy); // 距 200 有 100dp
    final gesture = await tester.startGesture(farFromBoundary);
    await tester.pump();

    expect(startedIndex, isNull);
    await gesture.up();
  });

  testWidgets('渲染不 crash（peaks 空、totalDurationMs=0）', (tester) async {
    await tester.pumpWidget(_wrap(WaveformCanvas(
      peaks: const [],
      syllables: const [],
      totalDurationMs: 0,
      draggingBoundaryIndex: null,
      draggingPreviewMs: null,
      onDragStart: (_) {},
      onDragUpdate: (_) {},
      onDragEnd: () {},
    )));

    expect(find.byType(WaveformCanvas), findsOneWidget);
  });
}
