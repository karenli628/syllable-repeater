// AI-Generate
import 'dart:async';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide ComparisonResult;
import 'package:syllable_repeater_app/features/editor/editor_controller.dart';
import 'package:syllable_repeater_app/features/import_analysis/analysis_controller.dart';
import 'package:syllable_repeater_app/features/practice/practice_controller.dart';
import 'package:syllable_repeater_app/features/practice/practice_player.dart';
import 'package:syllable_repeater_app/features/practice/practice_recording.dart';

class _FakePlayback implements PracticePlayback {
  int playCount = 0;
  int stopCount = 0;
  PracticeStep? lastStep;
  Pcm? lastPcm;
  int? lastRepeatN;

  @override
  Future<String> renderStepToFile(
    PracticeStep step,
    Pcm originalPcm, {
    required int repeatN,
  }) async => '/tmp/fake.wav';

  @override
  Future<void> playStep(
    PracticeStep step,
    Pcm originalPcm, {
    required int repeatN,
    void Function()? onReady,
  }) async {
    playCount++;
    lastStep = step;
    lastPcm = originalPcm;
    lastRepeatN = repeatN;
    onReady?.call();
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

class _FakeAnalysisRunner implements AnalysisRunner {
  const _FakeAnalysisRunner(this.pcm, this.syllables);

  final Pcm pcm;
  final List<Syllable> syllables;

  @override
  Stream<AnalysisEvent> analyze(
    ImportRequest request, {
    PipelineCheckpoint? resume,
  }) async* {
    yield AnalysisEvent(
      stage: AnalysisStage.done,
      progress: 1,
      decodedPcm: pcm,
      result: AlignmentResult(
        words: const [],
        syllables: syllables,
        source: 'test',
        confidence: 1,
      ),
    );
  }
}

class _FakeRecorder implements PracticeRecorder {
  final _levels = StreamController<double>.broadcast();
  int startCount = 0;
  int stopCount = 0;
  int cancelCount = 0;
  String recordingPath = '/tmp/attempt.wav';
  DomainException? startError;

  @override
  Stream<double> get levels => _levels.stream;

  @override
  Future<String> start() async {
    final error = startError;
    if (error != null) {
      throw error;
    }
    startCount++;
    return recordingPath;
  }

  @override
  Future<String?> stop() async {
    stopCount++;
    return recordingPath;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
  }

  @override
  Future<void> dispose() => _levels.close();

  void emitLevel(double level) {
    _levels.add(level);
  }
}

class _FakeComparisonService implements PracticeComparisonService {
  _FakeComparisonService({ComparisonResult? result})
    : result = result ?? _comparison();

  ComparisonResult result;
  DomainException? error;
  Completer<ComparisonResult>? pending;
  int compareCount = 0;
  String? lastPath;
  List<Syllable>? lastSyllables;
  PracticeStep? lastStep;
  Pcm? lastOriginalPcm;

  @override
  Future<ComparisonResult> compare({
    required String userRecordingPath,
    required List<Syllable> syllables,
    required PracticeStep step,
    required Pcm originalPcm,
  }) {
    compareCount++;
    lastPath = userRecordingPath;
    lastSyllables = syllables;
    lastStep = step;
    lastOriginalPcm = originalPcm;
    final thrown = error;
    if (thrown != null) {
      throw thrown;
    }
    final completer = pending;
    if (completer != null) {
      return completer.future;
    }
    return Future.value(result);
  }
}

Pcm _pcm() =>
    Pcm(Int16List.fromList(List.generate(2000, (i) => i)), sampleRate: 1000);

List<Syllable> _syllables() => [
  Syllable(
    text: 'thank',
    startMs: 0,
    endMs: 250,
    wordIndex: 0,
    needsReview: false,
  ),
  Syllable(
    text: 'you',
    startMs: 250,
    endMs: 500,
    wordIndex: 1,
    needsReview: false,
  ),
  Syllable(
    text: 've',
    startMs: 500,
    endMs: 650,
    wordIndex: 2,
    needsReview: true,
  ),
  Syllable(
    text: 'ry',
    startMs: 650,
    endMs: 800,
    wordIndex: 2,
    needsReview: true,
  ),
  Syllable(
    text: 'much',
    startMs: 800,
    endMs: 1200,
    wordIndex: 3,
    needsReview: false,
  ),
];

ComparisonResult _comparison() => ComparisonResult(
  rhythmDelta: 0.12,
  intonationDelta: 0.24,
  overlayData: OverlayData(
    userWave: const [0, 0.4, -0.2],
    referenceWave: const [0, 0.3, -0.1],
    userPitch: const [180, 182],
    referencePitch: const [176, 181],
    diffRanges: [TimeRange(100, 180)],
  ),
  score: 88,
);

ProviderContainer _container({
  required _FakePlayback playback,
  Pcm? pcm,
  _FakeRecorder? recorder,
  _FakeComparisonService? comparisonService,
}) {
  return ProviderContainer(
    overrides: [
      practicePlayerProvider.overrideWithValue(playback),
      practiceRecorderProvider.overrideWithValue(recorder ?? _FakeRecorder()),
      practiceComparisonServiceProvider.overrideWithValue(
        comparisonService ?? _FakeComparisonService(),
      ),
      if (pcm != null)
        analysisRunnerProvider.overrideWithValue(
          _FakeAnalysisRunner(pcm, _syllables()),
        ),
    ],
  );
}

Future<void> _preparePractice(ProviderContainer container) async {
  container.read(editorControllerProvider.notifier).loadFrom(_syllables());
  final analysis = container.read(analysisControllerProvider.notifier);
  await analysis.selectAudioPath('test.mp3');
  await analysis.start();
}

void main() {
  group('PracticeController', () {
    test('從 EditorController syllables 建立 5 個句尾疊加步驟', () {
      final playback = _FakePlayback();
      final container = _container(playback: playback);
      addTearDown(container.dispose);

      container.read(editorControllerProvider.notifier).loadFrom(_syllables());
      final state = container.read(practiceControllerProvider);

      expect(state.steps, hasLength(5));
      expect(state.steps.first.syllables.map((s) => s.text), ['much']);
      expect(state.steps.last.syllables.map((s) => s.text), [
        'thank',
        'you',
        've',
        'ry',
        'much',
      ]);
      expect(state.repeatN, 3);
    });

    test('setRepeatN 重建 totalDurationMs，但 sourceRanges 不變', () {
      final playback = _FakePlayback();
      final container = _container(playback: playback);
      addTearDown(container.dispose);
      container.read(editorControllerProvider.notifier).loadFrom(_syllables());
      final controller = container.read(practiceControllerProvider.notifier);

      final before = container.read(practiceControllerProvider).steps[1];
      controller.setRepeatN(5);
      final after = container.read(practiceControllerProvider).steps[1];

      expect(after.sourceRanges, before.sourceRanges);
      expect(after.totalDurationMs, 550 * 5);
      controller.setRepeatN(0);
      final error = container.read(practiceControllerProvider).error;
      expect(error?.code, ErrorCodes.repeatNOutOfRange);
    });

    test('selectStep 會先 stop，再切換 currentIndex（AT-03-05）', () async {
      final playback = _FakePlayback();
      final container = _container(playback: playback);
      addTearDown(container.dispose);
      container.read(editorControllerProvider.notifier).loadFrom(_syllables());
      final controller = container.read(practiceControllerProvider.notifier);

      await controller.selectStep(3);

      expect(playback.stopCount, 1);
      expect(container.read(practiceControllerProvider).currentIndex, 3);
    });

    test('play 呼叫 PracticePlayback，onReady 後回到 idle', () async {
      final playback = _FakePlayback();
      final pcm = _pcm();
      final container = _container(playback: playback, pcm: pcm);
      addTearDown(container.dispose);
      container.read(editorControllerProvider.notifier).loadFrom(_syllables());
      final analysis = container.read(analysisControllerProvider.notifier);
      await analysis.selectAudioPath('test.mp3');
      await analysis.start();
      final controller = container.read(practiceControllerProvider.notifier);

      await controller.play();

      expect(playback.playCount, 1);
      expect(playback.lastStep?.index, 1);
      expect(playback.lastRepeatN, 3);
      expect(playback.lastPcm, same(pcm));
      expect(
        container.read(practiceControllerProvider).playStatus,
        PracticePlayStatus.idle,
      );
    });

    test('無 decoded PCM 時 play 回錯誤，不呼叫播放器', () async {
      final playback = _FakePlayback();
      final container = _container(playback: playback);
      addTearDown(container.dispose);
      container.read(editorControllerProvider.notifier).loadFrom(_syllables());
      final controller = container.read(practiceControllerProvider.notifier);

      await controller.play();

      expect(playback.playCount, 0);
      expect(
        container.read(practiceControllerProvider).error?.code,
        ErrorCodes.decodeFailed,
      );
    });

    test('startRecording 先 stop 播放並鎖住原音播放，level meter 會更新', () async {
      final playback = _FakePlayback();
      final recorder = _FakeRecorder();
      final container = _container(
        playback: playback,
        pcm: _pcm(),
        recorder: recorder,
      );
      addTearDown(container.dispose);
      await _preparePractice(container);
      final controller = container.read(practiceControllerProvider.notifier);

      await controller.startRecording();
      recorder.emitLevel(0.64);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(practiceControllerProvider);
      expect(playback.stopCount, 1);
      expect(recorder.startCount, 1);
      expect(state.recordStatus, PracticeRecordStatus.recording);
      expect(state.recordingLevel, 0.64);
      expect(state.canPlay, isFalse);
    });

    test('stopRecording 呼叫比對服務並保存 ComparisonResult', () async {
      final playback = _FakePlayback();
      final recorder = _FakeRecorder();
      final comparison = _FakeComparisonService();
      comparison.pending = Completer<ComparisonResult>();
      final pcm = _pcm();
      final container = _container(
        playback: playback,
        pcm: pcm,
        recorder: recorder,
        comparisonService: comparison,
      );
      addTearDown(container.dispose);
      await _preparePractice(container);
      final controller = container.read(practiceControllerProvider.notifier);

      await controller.startRecording();
      final stopFuture = controller.stopRecording();
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(practiceControllerProvider).recordStatus,
        PracticeRecordStatus.comparing,
      );

      comparison.pending!.complete(comparison.result);
      await stopFuture;

      final state = container.read(practiceControllerProvider);
      expect(recorder.stopCount, 1);
      expect(comparison.compareCount, 1);
      expect(comparison.lastPath, '/tmp/attempt.wav');
      expect(comparison.lastOriginalPcm, same(pcm));
      expect(comparison.lastSyllables?.map((s) => s.text), [
        'thank',
        'you',
        've',
        'ry',
        'much',
      ]);
      expect(state.recordStatus, PracticeRecordStatus.idle);
      expect(state.comparison, same(comparison.result));
      expect(state.error, isNull);
    });

    test('AT-06-02 過短錄音錯誤不留下 comparison', () async {
      final playback = _FakePlayback();
      final recorder = _FakeRecorder();
      final comparison = _FakeComparisonService()
        ..error = const DomainException(
          ErrorCodes.recordingTooShort,
          '錄音過短，請重錄（至少 0.2 秒）',
        );
      final container = _container(
        playback: playback,
        pcm: _pcm(),
        recorder: recorder,
        comparisonService: comparison,
      );
      addTearDown(container.dispose);
      await _preparePractice(container);
      final controller = container.read(practiceControllerProvider.notifier);

      await controller.startRecording();
      await controller.stopRecording();

      final state = container.read(practiceControllerProvider);
      expect(state.recordStatus, PracticeRecordStatus.idle);
      expect(state.comparison, isNull);
      expect(state.error?.code, ErrorCodes.recordingTooShort);
    });

    test('AT-06-03 錄音中切步會中止並丟棄錄音', () async {
      final playback = _FakePlayback();
      final recorder = _FakeRecorder();
      final container = _container(
        playback: playback,
        pcm: _pcm(),
        recorder: recorder,
      );
      addTearDown(container.dispose);
      await _preparePractice(container);
      final controller = container.read(practiceControllerProvider.notifier);

      await controller.startRecording();
      await controller.selectStep(2);

      final state = container.read(practiceControllerProvider);
      expect(recorder.cancelCount, 1);
      expect(playback.stopCount, 2);
      expect(state.currentIndex, 2);
      expect(state.recordStatus, PracticeRecordStatus.idle);
      expect(state.comparison, isNull);
    });

    test('AT-06-05 麥克風權限拒絕時回 ERR_MIC_PERMISSION_DENIED', () async {
      final playback = _FakePlayback();
      final recorder = _FakeRecorder()
        ..startError = const DomainException(
          ErrorCodes.micPermissionDenied,
          '請至系統設定開啟麥克風權限',
        );
      final container = _container(
        playback: playback,
        pcm: _pcm(),
        recorder: recorder,
      );
      addTearDown(container.dispose);
      await _preparePractice(container);
      final controller = container.read(practiceControllerProvider.notifier);

      await controller.startRecording();

      final state = container.read(practiceControllerProvider);
      expect(state.recordStatus, PracticeRecordStatus.idle);
      expect(state.error?.code, ErrorCodes.micPermissionDenied);
    });
  });
}
