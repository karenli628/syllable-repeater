// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syllable_repeater_app/features/import_analysis/analysis_controller.dart';
import 'package:syllable_repeater_app/features/labeling/labeling_controller.dart';
import 'package:syllable_repeater_app/shared/pending_segment.dart';

void main() {
  test('pending provider 只保留一個 Segment，後一次明確替換前一次', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final pending = container.read(pendingSegmentProvider.notifier);
    final first = _pending(id: 'first', text: 'first sentence');
    final second = _pending(id: 'second', text: 'second sentence');

    pending.set(first);
    expect(container.read(pendingSegmentProvider), first);
    pending.set(second);
    expect(container.read(pendingSegmentProvider), second);
  });

  test('LabelingController handoff 傳遞原音來源、起訖、文字與 language', () {
    final container = ProviderContainer(
      overrides: [
        labelingControllerProvider.overrideWith(
          () => _HandoffLabelingController(_labelingState()),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(labelingControllerProvider.notifier);

    expect(controller.handoffSelectedSegment(), isTrue);
    final pending = container.read(pendingSegmentProvider);
    expect(pending, isNotNull);
    expect(pending!.segmentId, 'segment-2');
    expect(pending.segmentIndex, 1);
    expect(pending.sourceAudioPath, '/tmp/full-track.wav');
    expect(pending.startMs, 1800);
    expect(pending.endMs, 3200);
    expect(pending.text, 'second sentence');
    expect(pending.language, 'en');
  });

  test('AnalysisController consume pending 預填單句輸入並清空 pending', () {
    final container = ProviderContainer(
      overrides: [
        pendingSegmentProvider.overrideWith(
          () => _PendingController(_pending()),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(analysisControllerProvider.notifier);

    final consumed = controller.consumePendingSegment();
    expect(consumed, isTrue);
    final state = container.read(analysisControllerProvider);
    expect(state.selectedAudioPath, '/tmp/full-track.wav');
    expect(state.transcript, 'hello world');
    expect(state.language, 'en');
    expect(state.pendingSegment?.startMs, 100);
    expect(state.pendingSegment?.endMs, 1600);
    expect(container.read(pendingSegmentProvider), isNull);
  });
}

PendingSegment _pending({
  String id = 'segment-1',
  String text = 'hello world',
}) => PendingSegment(
  segmentId: id,
  sourceAudioPath: '/tmp/full-track.wav',
  startMs: 100,
  endMs: 1600,
  text: text,
  language: 'en',
);

LabelingUiState _labelingState() => LabelingUiState(
  audioPath: '/tmp/full-track.wav',
  status: LabelingRunStatus.ready,
  selectedSegmentIndex: 1,
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

class _HandoffLabelingController extends LabelingController {
  _HandoffLabelingController(this.initial);

  final LabelingUiState initial;

  @override
  LabelingUiState build() => initial;
}

class _PendingController extends PendingSegmentController {
  _PendingController(this.initial);

  final PendingSegment? initial;

  @override
  PendingSegment? build() => initial;
}
