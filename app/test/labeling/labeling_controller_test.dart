// AI-Generate
import 'dart:async';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syllable_repeater_app/features/labeling/labeling_controller.dart';

void main() {
  test('AT-11-14 第 1 至第 N 段都把完整起訖範圍交給播放器', () async {
    final preview = _ControllablePreview();
    final container = _previewContainer(preview);
    addTearDown(container.dispose);
    final controller = container.read(labelingControllerProvider.notifier);

    for (var index = 0; index < _previewSegments().length; index++) {
      final playback = controller.previewSegment(index);
      await Future<void>.delayed(Duration.zero);
      expect(
        preview.playedSegments[index].range,
        _previewSegments()[index].range,
      );
      preview.completePlay(index);
      await playback;
      expect(
        container.read(labelingControllerProvider).previewStatus,
        LabelingPreviewStatus.idle,
      );
    }
  });

  test('AT-11-15 暫停保留游標且續播完成前不被舊 Future 清除', () async {
    final preview = _ControllablePreview();
    final container = _previewContainer(preview);
    addTearDown(container.dispose);
    final controller = container.read(labelingControllerProvider.notifier);

    final firstPlayback = controller.previewSegment(1);
    await Future<void>.delayed(Duration.zero);
    preview.emitPosition(2450);
    await Future<void>.delayed(Duration.zero);
    await controller.previewSegment(1);

    var state = container.read(labelingControllerProvider);
    expect(state.previewStatus, LabelingPreviewStatus.paused);
    expect(state.playheadMs, 2450);
    preview.completePlay(0);
    await firstPlayback;
    state = container.read(labelingControllerProvider);
    expect(state.previewStatus, LabelingPreviewStatus.paused);
    expect(state.playheadMs, 2450);

    final resumed = controller.previewSegment(1);
    await Future<void>.delayed(Duration.zero);
    expect(preview.resumeCount, 1);
    preview.emitPosition(2700);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(labelingControllerProvider).playheadMs, 2700);
    preview.completeResume();
    await resumed;
    expect(
      container.read(labelingControllerProvider).previewStatus,
      LabelingPreviewStatus.idle,
    );
  });

  test('AT-11-15 停止清除游標，停止後重播才從該段起點開始', () async {
    final preview = _ControllablePreview();
    final container = _previewContainer(preview);
    addTearDown(container.dispose);
    final controller = container.read(labelingControllerProvider.notifier);

    final firstPlayback = controller.previewSegment(2);
    await Future<void>.delayed(Duration.zero);
    preview.emitPosition(3400);
    await Future<void>.delayed(Duration.zero);
    await controller.stopPreview();
    preview.completePlay(0);
    await firstPlayback;
    expect(container.read(labelingControllerProvider).playheadMs, isNull);

    final replay = controller.previewSegment(2);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(labelingControllerProvider).playheadMs, 2000);
    preview.completePlay(1);
    await replay;
  });

  test('介面20開啟音檔保留 session、peaks 與 ASR warning', () async {
    final session = LabelSession(
      audioFingerprint: 'a' * 64,
      audioDurationMs: 4000,
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
      ],
    );
    final result = LabelOpenResult(
      session: session,
      peaks: const [0.1, 0.5, 0.9],
      warning: const LabelOpenWarning(
        code: ErrorCodes.transcribeFailed,
        message: '切段失敗，可重試或手動切段',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        labelingEngineProvider.overrideWithValue(_FakeSegmentEngine(result)),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(labelingControllerProvider.notifier);
    await controller.openAudio('/tmp/track.wav');

    final state = container.read(labelingControllerProvider);
    expect(state.status, LabelingRunStatus.ready);
    expect(state.audioPath, '/tmp/track.wav');
    expect(state.session?.segments, hasLength(1));
    expect(state.peaks, [0.1, 0.5, 0.9]);
    expect(state.warning?.code, ErrorCodes.transcribeFailed);

    controller.selectSegment(0);
    expect(container.read(labelingControllerProvider).selectedSegmentIndex, 0);
  });

  test('不支援格式在入口拒絕且不呼叫 SegmentEngine', () async {
    final container = ProviderContainer(
      overrides: [
        labelingEngineProvider.overrideWithValue(
          _FakeSegmentEngine(
            LabelOpenResult(session: _session(), peaks: const []),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(labelingControllerProvider.notifier)
        .openAudio('/tmp/track.ogg');

    final state = container.read(labelingControllerProvider);
    expect(state.status, LabelingRunStatus.failed);
    expect(state.error?.code, ErrorCodes.unsupportedFormat);
  });

  test('拖曳、插入與移除標籤線都透過 LabelSession domain API', () async {
    final original = LabelSession(
      audioFingerprint: 'c' * 64,
      audioDurationMs: 4000,
      segments: [
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
      ],
    );
    final container = ProviderContainer(
      overrides: [
        labelingEngineProvider.overrideWithValue(
          _FakeSegmentEngine(
            LabelOpenResult(session: original, peaks: const [0.2]),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(labelingControllerProvider.notifier);
    await controller.openAudio('/tmp/track.wav');

    controller.dragStart(0);
    controller.dragUpdate(1500);
    controller.dragEnd();
    var state = container.read(labelingControllerProvider);
    expect(state.session!.segments[0].endMs, 1500);
    expect(state.session!.segments[1].startMs, 1500);
    expect(state.dirty, isTrue);

    controller.insertBoundary(750);
    state = container.read(labelingControllerProvider);
    expect(state.session!.segments, hasLength(3));
    controller.removeBoundary(0);
    expect(
      container.read(labelingControllerProvider).session!.segments,
      hasLength(2),
    );
  });

  test('AT-11-12 標記捨棄後不得送入單句分析', () async {
    final container = ProviderContainer(
      overrides: [
        labelingEngineProvider.overrideWithValue(
          _FakeSegmentEngine(
            LabelOpenResult(session: _editableSession(), peaks: const []),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(labelingControllerProvider.notifier);
    await controller.openAudio('/tmp/track.wav');

    controller.setSegmentDisposition(0, SegmentDisposition.discarded);
    controller.selectSegment(0);

    final state = container.read(labelingControllerProvider);
    expect(
      state.session!.segments.first.disposition,
      SegmentDisposition.discarded,
    );
    expect(state.dirty, isTrue);
    expect(controller.handoffSelectedSegment(), isFalse);
  });

  test('儲存標籤只有 pack store 成功才清除 dirty', () async {
    final session = _editableSession();
    final store = _FakePackStore();
    final container = ProviderContainer(
      overrides: [
        labelingEngineProvider.overrideWithValue(
          _FakeSegmentEngine(
            LabelOpenResult(session: session, peaks: const []),
          ),
        ),
        labelingPackStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(labelingControllerProvider.notifier);
    await controller.openAudio('/tmp/track.wav');
    controller.dragStart(0);
    controller.dragUpdate(1500);
    controller.dragEnd();
    expect(container.read(labelingControllerProvider).dirty, isTrue);

    expect(await controller.saveLabel('/tmp/track.abolabel'), isTrue);
    final state = container.read(labelingControllerProvider);
    expect(state.dirty, isFalse);
    expect(store.writtenPaths, ['/tmp/track.abolabel']);
  });

  test('pack store 寫入失敗時保留 dirty 與目前 session', () async {
    final store = _FakePackStore(failWrite: true);
    final container = ProviderContainer(
      overrides: [
        labelingEngineProvider.overrideWithValue(
          _FakeSegmentEngine(
            LabelOpenResult(session: _editableSession(), peaks: const []),
          ),
        ),
        labelingPackStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(labelingControllerProvider.notifier);
    await controller.openAudio('/tmp/track.wav');
    controller.dragStart(0);
    controller.dragUpdate(1500);
    controller.dragEnd();

    expect(await controller.saveLabel('/tmp/track.abolabel'), isFalse);
    final state = container.read(labelingControllerProvider);
    expect(state.dirty, isTrue);
    expect(state.error?.code, ErrorCodes.exportDestUnwritable);
  });

  test('既有標籤載入以 audio fingerprint 驗證並替換 session', () async {
    final detected = _editableSession();
    final loaded = LabelSession(
      audioFingerprint: detected.audioFingerprint,
      audioDurationMs: detected.audioDurationMs,
      segments: [
        Segment(
          id: 'saved-1',
          startMs: 0,
          endMs: 3000,
          text: 'saved label',
          language: 'en',
          confidence: 0,
        ),
      ],
    );
    final store = _FakePackStore(readResult: loaded);
    final container = ProviderContainer(
      overrides: [
        labelingEngineProvider.overrideWithValue(
          _FakeSegmentEngine(
            LabelOpenResult(
              session: detected,
              peaks: const [0.2],
              existingLabelPath: '/tmp/track.abolabel',
            ),
          ),
        ),
        labelingPackStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(labelingControllerProvider.notifier);
    await controller.openAudio('/tmp/track.wav');
    expect(
      container.read(labelingControllerProvider).existingLabelPath,
      '/tmp/track.abolabel',
    );

    expect(await controller.loadExistingLabel(), isTrue);
    final state = container.read(labelingControllerProvider);
    expect(state.existingLabelPath, isNull);
    expect(state.session!.segments.single.text, 'saved label');
    expect(store.readFingerprints, [detected.audioFingerprint]);
  });

  test('AT-21-01 v3 labels 還原為段落工作階段', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final bundle = CourseBundle(
      courseName: 'Labels only',
      sourceAudioName: 'source.m4a',
      audioFingerprint: 'e' * 64,
      audioDurationMs: 4000,
      originalAudioBytes: Uint8List.fromList([1, 2, 3]),
      labels: CourseLabels(
        language: 'en',
        separateVocals: true,
        segments: [
          Segment(
            id: 'kept-1',
            startMs: 500,
            endMs: 2500,
            text: 'keep this',
            language: 'en',
            confidence: 0.9,
          ),
        ],
      ),
    );

    container
        .read(labelingControllerProvider.notifier)
        .hydrateCourseBundleLabels(
          bundle,
          extractedAudioPath: '/tmp/source.m4a',
        );

    final state = container.read(labelingControllerProvider);
    expect(state.status, LabelingRunStatus.ready);
    expect(state.audioPath, '/tmp/source.m4a');
    expect(state.session!.audioFingerprint, 'e' * 64);
    expect(state.session!.segments.single.text, 'keep this');
    expect(state.dirty, isFalse);
  });
}

ProviderContainer _previewContainer(_ControllablePreview preview) {
  final container = ProviderContainer(
    overrides: [labelingSegmentPreviewProvider.overrideWithValue(preview)],
  );
  container
      .read(labelingControllerProvider.notifier)
      .hydrateCourseBundleLabels(
        CourseBundle(
          courseName: 'Preview',
          sourceAudioName: 'preview.wav',
          audioFingerprint: 'f' * 64,
          audioDurationMs: 4000,
          originalAudioBytes: Uint8List.fromList([1]),
          labels: CourseLabels(
            language: 'en',
            separateVocals: false,
            segments: _previewSegments(),
          ),
        ),
        extractedAudioPath: '/tmp/preview.wav',
      );
  return container;
}

List<Segment> _previewSegments() => List.generate(
  4,
  (index) => Segment(
    id: 'preview-$index',
    startMs: index * 1000,
    endMs: (index + 1) * 1000,
    text: 'segment ${index + 1}',
    language: 'en',
    confidence: 1,
  ),
);

class _ControllablePreview implements LabelingSegmentPreview {
  final _positions = StreamController<int>.broadcast();
  final List<Segment> playedSegments = [];
  final List<Completer<void>> _playCompletions = [];
  Completer<void>? _resumeCompletion;
  int pauseCount = 0;
  int resumeCount = 0;
  int stopCount = 0;

  @override
  Stream<int> get positionsMs => _positions.stream;

  @override
  Future<void> play(String audioPath, Segment segment) {
    playedSegments.add(segment);
    final completer = Completer<void>();
    _playCompletions.add(completer);
    return completer.future;
  }

  @override
  Future<void> pause() async {
    pauseCount++;
  }

  @override
  Future<void> resume() {
    resumeCount++;
    _resumeCompletion = Completer<void>();
    return _resumeCompletion!.future;
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  void emitPosition(int positionMs) => _positions.add(positionMs);

  void completePlay(int index) => _playCompletions[index].complete();

  void completeResume() => _resumeCompletion!.complete();
}

LabelSession _session() => LabelSession(
  audioFingerprint: 'b' * 64,
  audioDurationMs: 1000,
  segments: const [],
);

class _FakeSegmentEngine extends SegmentEngine {
  _FakeSegmentEngine(this.result)
    : super(
        decoder: _FakeDecoder(),
        fileIo: _FakeFileIo(),
        transcriberRegistry: TranscriberRegistry([_FakeTranscriber()]),
        syllabifierRegistry: SyllabifierRegistry([_FakeSyllabifier()]),
      );

  final LabelOpenResult result;

  @override
  Future<LabelOpenResult> openAudio(
    String path, {
    bool separateVocals = true,
    String language = 'en',
    void Function(LabelOpenProgress progress)? onProgress,
  }) async {
    onProgress?.call(
      const LabelOpenProgress(
        stage: LabelOpenStage.completed,
        completedUnits: 1,
        totalUnits: 1,
      ),
    );
    return result;
  }
}

class _FakeDecoder implements AnalysisAudioDecoder {
  @override
  Future<Pcm> decode(String audioPath) async =>
      Pcm(Int16List(44100), sampleRate: 44100);
}

class _FakeFileIo implements FileIo {
  @override
  Future<void> clearTemp() async {}

  @override
  Future<String> createTempFilePath(String suffix) async => '/tmp/fake$suffix';

  @override
  Future<void> delete(String path) async {}

  @override
  Future<bool> exists(String path) async => false;

  @override
  Future<Uint8List> readBytes(String path) async => Uint8List(0);

  @override
  Future<void> writeBytesAtomic(String path, Uint8List bytes) async {}
}

class _FakeTranscriber implements TranscriberEngine {
  @override
  String get engineName => 'fake';

  @override
  Set<String> get supportedLanguages => const {'en'};

  @override
  Future<List<Segment>> segment(Pcm pcm, {required String language}) async =>
      const [];

  @override
  Future<List<Word>> transcribe(
    Pcm pcm, {
    required String language,
    String? transcript,
  }) async => const [];
}

class _FakeSyllabifier implements Syllabifier {
  @override
  Set<String> get supportedLanguages => const {'en'};

  @override
  SyllabifyResult syllabify(Word word, {required String language}) =>
      SyllabifyResult(
        syllables: [
          Syllable(
            text: word.text,
            startMs: word.startMs,
            endMs: word.endMs,
            wordIndex: word.index,
            needsReview: false,
          ),
        ],
      );
}

LabelSession _editableSession() => LabelSession(
  audioFingerprint: 'd' * 64,
  audioDurationMs: 3000,
  segments: [
    Segment(
      id: 'segment-1',
      startMs: 0,
      endMs: 1000,
      text: 'one',
      language: 'en',
      confidence: 0.8,
    ),
    Segment(
      id: 'segment-2',
      startMs: 1000,
      endMs: 3000,
      text: 'two',
      language: 'en',
      confidence: 0.8,
    ),
  ],
);

class _FakePackStore implements LabelingPackStore {
  _FakePackStore({this.readResult, this.failWrite = false});

  final LabelSession? readResult;
  final bool failWrite;
  final List<String> writtenPaths = [];
  final List<String> readFingerprints = [];

  @override
  Future<String> writeLabel(LabelSession session, String destPath) async {
    if (failWrite) {
      throw const DomainException(
        ErrorCodes.exportDestUnwritable,
        'fixture cannot write',
      );
    }
    writtenPaths.add(destPath);
    session.markSaved();
    return destPath;
  }

  @override
  Future<LabelSession> readLabel(
    String path, {
    required String expectedFingerprint,
  }) async {
    readFingerprints.add(expectedFingerprint);
    return readResult!;
  }
}
