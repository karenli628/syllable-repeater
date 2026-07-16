// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/features/labeling/labeling_controller.dart';
import 'package:syllable_repeater_app/features/labeling/labeling_screen.dart';
import 'package:syllable_repeater_app/shared/pending_segment.dart';

void main() {
  testWidgets('勾選一個 Segment 後可送到單句分析且只交接該段', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          labelingControllerProvider.overrideWith(
            () => _HandoffScreenController(_state()),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: LabelingScreen())),
      ),
    );
    await tester.pump();

    expect(find.byType(Checkbox), findsNWidgets(2));
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();
    expect(find.text('送到單句分析'), findsOneWidget);

    await tester.tap(find.text('送到單句分析'));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final pending = container.read(pendingSegmentProvider);
    expect(pending?.segmentId, 'segment-2');
    expect(pending?.sourceAudioPath, '/tmp/full-track.wav');
    expect(pending?.startMs, 1800);
    expect(pending?.endMs, 3200);
  });
}

LabelingUiState _state() => LabelingUiState(
  audioPath: '/tmp/full-track.wav',
  status: LabelingRunStatus.ready,
  session: LabelSession(
    audioFingerprint: 'a' * 64,
    audioDurationMs: 3200,
    language: 'en',
    segments: [
      Segment(
        id: 'segment-1',
        startMs: 0,
        endMs: 1800,
        text: 'first sentence',
        language: 'en',
        confidence: 0.9,
      ),
      Segment(
        id: 'segment-2',
        startMs: 1800,
        endMs: 3200,
        text: 'second sentence',
        language: 'en',
        confidence: 0.8,
      ),
    ],
  ),
);

class _HandoffScreenController extends LabelingController {
  _HandoffScreenController(this.initial);

  final LabelingUiState initial;

  @override
  LabelingUiState build() => initial;
}
