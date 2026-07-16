// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/features/labeling/widgets/full_track_waveform.dart';
import 'package:syllable_repeater_app/features/labeling/widgets/segment_list.dart';
import 'package:syllable_repeater_app/features/labeling/labeling_controller.dart';

void main() {
  testWidgets('FullTrackWaveform 顯示時間軸並把線操作委派給 callbacks', (tester) async {
    final selected = <int>[];
    final inserted = <int>[];
    final removed = <int>[];
    final dragUpdates = <int>[];
    final segments = _segments();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: FullTrackWaveform(
              peaks: const [0.2, 0.6, 0.4],
              segments: segments,
              totalDurationMs: 4000,
              selectedSegmentIndex: 0,
              draggingBoundaryIndex: 0,
              draggingPreviewMs: 2000,
              playheadMs: 1250,
              onSelectSegment: selected.add,
              onDragStart: (_) {},
              onDragUpdate: dragUpdates.add,
              onDragEnd: () {},
              onInsertBoundary: inserted.add,
              onRemoveBoundary: removed.add,
            ),
          ),
        ),
      ),
    );

    expect(find.text('0 ms'), findsOneWidget);
    expect(find.text('4000 ms'), findsOneWidget);
    expect(find.byTooltip('刪除第 1 條標籤線'), findsOneWidget);
    expect(find.byTooltip('在此段中間新增標籤線'), findsOneWidget);
    expect(find.byKey(const ValueKey('labeling-playhead')), findsOneWidget);

    final topLeft = tester.getTopLeft(find.byType(FullTrackWaveform));
    await tester.tapAt(topLeft + const Offset(100, 100));
    expect(selected, [0]);
    await tester.tap(find.byTooltip('在此段中間新增標籤線'));
    expect(inserted, [1000]);
    await tester.tap(find.byTooltip('刪除第 1 條標籤線'));
    expect(removed, [0]);

    await tester.dragFrom(
      topLeft + const Offset(300, 100),
      topLeft + const Offset(240, 100),
    );
    expect(dragUpdates, isNotEmpty);
  });

  testWidgets('SegmentList 可選取、試聽與刪除邊界', (tester) async {
    final selected = <int>[];
    final previews = <int>[];
    final removed = <int>[];
    final dispositions = <(int, SegmentDisposition)>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SegmentList(
            segments: _segments(),
            selectedSegmentIndex: null,
            previewingSegmentIndex: 0,
            previewStatus: LabelingPreviewStatus.playing,
            onSelect: selected.add,
            onPreview: previews.add,
            onStopPreview: () => previews.add(-1),
            onRemoveBoundary: removed.add,
            onDispositionChanged: (index, disposition) =>
                dispositions.add((index, disposition)),
          ),
        ),
      ),
    );

    await tester.tap(find.text('first'));
    expect(find.byTooltip('暫停第 1 段'), findsOneWidget);
    expect(find.byTooltip('停止第 1 段試聽'), findsOneWidget);
    await tester.tap(find.byTooltip('暫停第 1 段'));
    await tester.tap(find.byTooltip('停止第 1 段試聽'));
    await tester.tap(find.byTooltip('刪除第 1 條標籤線'));
    await tester.tap(find.byTooltip('第 1 段區間處置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('捨棄此區間'));
    expect(selected, [0]);
    expect(previews, [0, -1]);
    expect(removed, [0]);
    expect(dispositions, [(0, SegmentDisposition.discarded)]);
  });
}

List<Segment> _segments() => [
  Segment(
    id: 'segment-1',
    startMs: 0,
    endMs: 2000,
    text: 'first',
    language: 'en',
    confidence: 0.9,
  ),
  Segment(
    id: 'segment-2',
    startMs: 2000,
    endMs: 4000,
    text: 'second',
    language: 'en',
    confidence: 0.8,
  ),
];
