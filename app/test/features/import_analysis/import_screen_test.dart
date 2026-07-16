// AI-Generate
import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/features/import_analysis/analysis_controller.dart';
import 'package:syllable_repeater_app/features/import_analysis/import_screen.dart';
import 'package:syllable_repeater_app/features/editor/editor_controller.dart';
import 'package:syllable_repeater_app/shared/pending_segment.dart';

void main() {
  testWidgets('pending Segment 進入分析頁後預填字稿並顯示來源徽章', (tester) async {
    final container = ProviderContainer(
      overrides: [
        pendingSegmentProvider.overrideWith(
          () => _PendingController(
            PendingSegment(
              segmentId: 'segment-5',
              segmentIndex: 4,
              sourceAudioPath: '/tmp/full-track.wav',
              startMs: 42300,
              endMs: 45100,
              text: "I don't wanna talk",
              language: 'en',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: ImportScreen())),
      ),
    );
    await tester.pump();
    await tester.pump();

    final state = container.read(analysisControllerProvider);
    expect(state.selectedAudioPath, '/tmp/full-track.wav');
    expect(state.transcript, "I don't wanna talk");
    expect(state.pendingSegment?.startMs, 42300);
    expect(find.text('來自段落標籤：第 5 段'), findsOneWidget);
    expect(find.text('開始分析'), findsOneWidget);
    expect(find.text('音檔已就緒'), findsOneWidget);
    expect(find.text('選擇音檔後，這裡會顯示音節切分結果。'), findsNothing);
    expect(find.textContaining('11 音節預覽'), findsNothing);
  });

  test('pending Segment 的 language 會傳進 AnalysisRunner request', () async {
    final runner = _CapturingRunner();
    final container = ProviderContainer(
      overrides: [
        analysisRunnerProvider.overrideWithValue(runner),
        pendingSegmentProvider.overrideWith(
          () => _PendingController(
            PendingSegment(
              segmentId: 'segment-1',
              segmentIndex: 0,
              sourceAudioPath: '/tmp/one.wav',
              startMs: 10,
              endMs: 1010,
              text: 'bonjour',
              language: 'fr',
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(analysisControllerProvider.notifier);
    expect(controller.consumePendingSegment(), isTrue);
    await controller.start();

    expect(runner.request?.audioPath, '/tmp/one.wav');
    expect(runner.request?.transcript, 'bonjour');
    expect(runner.request?.language, 'fr');
    expect(runner.request?.sourceRange, TimeRange(10, 1010));
    expect(container.read(analysisControllerProvider).isAudioReady, isTrue);
  });

  test('AT-12-06/07：直接匯入收到 ready 前不可開始分析', () async {
    final reader = _ControlledAudioImportReader();
    final container = ProviderContainer(
      overrides: [audioImportReaderProvider.overrideWithValue(reader)],
    );
    addTearDown(container.dispose);
    final controller = container.read(analysisControllerProvider.notifier);

    final selecting = controller.selectAudioPath('/tmp/direct.wav');
    reader.add(
      const AudioImportEvent(
        progress: AudioImportProgress(
          stage: AudioImportStage.readingBytes,
          bytesRead: 50,
          totalBytes: 100,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(container.read(analysisControllerProvider).isLoading, isTrue);
    expect(container.read(analysisControllerProvider).canStart, isFalse);
    expect(
      container.read(analysisControllerProvider).importProgress?.ratio,
      .5,
    );

    reader.add(
      const AudioImportEvent(
        progress: AudioImportProgress(
          stage: AudioImportStage.ready,
          bytesRead: 100,
          totalBytes: 100,
        ),
        readySource: AudioReadySource(
          path: '/tmp/direct.wav',
          bytesRead: 100,
          durationMs: 2000,
        ),
      ),
    );
    await reader.close();
    await selecting;

    expect(container.read(analysisControllerProvider).isAudioReady, isTrue);
    expect(container.read(analysisControllerProvider).canStart, isTrue);
  });

  test('分析完成時空白字稿改由同一份結果 words 回填', () async {
    final container = ProviderContainer(
      overrides: [analysisRunnerProvider.overrideWithValue(_ResultRunner())],
    );
    addTearDown(container.dispose);
    final controller = container.read(analysisControllerProvider.notifier);
    await controller.selectAudioPath('/tmp/direct.wav');
    await controller.start();

    expect(
      container.read(analysisControllerProvider).transcript,
      'same source',
    );
  });

  test('AT-15-12 分析成功建立一次 draft id，editor 沿用且下一檔換新 id', () async {
    final ids = _SequenceDraftIdentityGenerator(['draft-one', 'draft-two']);
    final container = ProviderContainer(
      overrides: [
        analysisRunnerProvider.overrideWithValue(_ResultRunner()),
        draftLessonIdentityGeneratorProvider.overrideWithValue(ids),
      ],
    );
    addTearDown(container.dispose);
    container.read(editorControllerProvider);
    final controller = container.read(analysisControllerProvider.notifier);

    await controller.selectAudioPath('/tmp/one.wav');
    await controller.start();

    expect(
      container.read(analysisControllerProvider).draftIdentity?.lessonId,
      'draft-one',
    );
    expect(
      container.read(editorControllerProvider).sourceLessonId,
      'draft-one',
    );

    await controller.selectAudioPath('/tmp/two.wav');
    expect(container.read(analysisControllerProvider).draftIdentity, isNull);
    await controller.start();

    expect(
      container.read(analysisControllerProvider).draftIdentity?.lessonId,
      'draft-two',
    );
    expect(
      container.read(editorControllerProvider).sourceLessonId,
      'draft-two',
    );
  });
}

class _PendingController extends PendingSegmentController {
  _PendingController(this.initial);

  final PendingSegment? initial;

  @override
  PendingSegment? build() => initial;
}

class _CapturingRunner implements AnalysisRunner {
  ImportRequest? request;

  @override
  Stream<AnalysisEvent> analyze(
    ImportRequest request, {
    PipelineCheckpoint? resume,
  }) async* {
    this.request = request;
    yield AnalysisEvent(
      stage: AnalysisStage.done,
      progress: 1,
      result: AlignmentResult(
        words: const [],
        syllables: const [],
        source: 'test',
        confidence: 1,
      ),
    );
  }
}

class _ResultRunner implements AnalysisRunner {
  @override
  Stream<AnalysisEvent> analyze(
    ImportRequest request, {
    PipelineCheckpoint? resume,
  }) async* {
    yield AnalysisEvent(
      stage: AnalysisStage.done,
      progress: 1,
      result: AlignmentResult(
        words: [
          Word(text: 'same', startMs: 0, endMs: 200, index: 0),
          Word(text: 'source', startMs: 200, endMs: 400, index: 1),
        ],
        syllables: [
          Syllable(
            text: 'same',
            startMs: 0,
            endMs: 200,
            wordIndex: 0,
            needsReview: false,
          ),
        ],
        source: 'test',
        confidence: 1,
      ),
    );
  }
}

class _SequenceDraftIdentityGenerator implements DraftLessonIdentityGenerator {
  _SequenceDraftIdentityGenerator(this.ids);

  final List<String> ids;
  var _index = 0;

  @override
  DraftLessonIdentity create() => DraftLessonIdentity(lessonId: ids[_index++]);
}

class _ControlledAudioImportReader implements AudioImportReader {
  final _controller = StreamController<AudioImportEvent>();

  void add(AudioImportEvent event) => _controller.add(event);

  Future<void> close() => _controller.close();

  @override
  Stream<AudioImportEvent> readAndValidate(String path) => _controller.stream;
}
