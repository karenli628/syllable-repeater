// AI-Generate
import 'dart:async';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide ComparisonResult;
import 'package:syllable_repeater_app/features/editor/editor_controller.dart';
import 'package:syllable_repeater_app/features/import_analysis/analysis_controller.dart';
import 'package:syllable_repeater_app/features/pack_translate/lesson_session_controller.dart';
import 'package:syllable_repeater_app/features/practice/practice_controller.dart';
import 'package:syllable_repeater_app/features/practice/practice_player.dart';
import 'package:syllable_repeater_app/features/practice/practice_recording.dart';
import 'package:syllable_repeater_app/shared/navigation.dart';

class _FakePlayback implements PracticePlayback {
  int playCount = 0;
  int playPcmCount = 0;
  int stopCount = 0;
  int rowPlayCount = 0;
  PracticeRow? lastRow;
  PracticeStep? lastStep;
  Pcm? lastPcm;
  int? lastRepeatN;
  Completer<void>? playPcmPending;

  @override
  Future<void> playPcm(Pcm pcm, {void Function()? onReady}) async {
    playPcmCount++;
    lastPcm = pcm;
    onReady?.call();
    await playPcmPending?.future;
  }

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
  Future<String> renderRowToFile(PracticeRow row, Pcm originalPcm) async =>
      '/tmp/fake-row.wav';

  @override
  Future<void> playRow(
    PracticeRow row,
    Pcm originalPcm, {
    void Function()? onReady,
  }) async {
    rowPlayCount++;
    lastRow = row;
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
  _FakeRecorder({this.events});

  final List<String>? events;
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
    events?.add('recorder.start');
    startCount++;
    return recordingPath;
  }

  @override
  Future<CompletedPracticeRecording?> stop() async {
    events?.add('recorder.stop');
    stopCount++;
    return CompletedPracticeRecording(path: recordingPath, pcm: _pcm());
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
  _FakePracticeAudioSessionCoordinator? audioSession,
}) {
  return ProviderContainer(
    overrides: [
      practicePlayerProvider.overrideWithValue(playback),
      practiceAudioSessionProvider.overrideWithValue(
        audioSession ?? _FakePracticeAudioSessionCoordinator(),
      ),
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

class _FakePracticeAudioSessionCoordinator
    implements PracticeAudioSessionCoordinator {
  _FakePracticeAudioSessionCoordinator({List<String>? events})
    : events = events ?? [];

  final List<String> events;

  @override
  Future<void> finishPlayback() async => events.add('session.playback.finish');

  @override
  Future<void> finishRecording() async => events.add('session.record.finish');

  @override
  Future<void> prepareForPlayback() async =>
      events.add('session.playback.prepare');

  @override
  Future<void> prepareForRecording() async =>
      events.add('session.record.prepare');
}

Future<void> _preparePractice(ProviderContainer container) async {
  container.read(editorControllerProvider.notifier).loadFrom(_syllables());
  final analysis = container.read(analysisControllerProvider.notifier);
  await analysis.selectAudioPath('test.mp3');
  await analysis.start();
}

Future<void> _prepareGeneratedPractice(ProviderContainer container) async {
  await _preparePractice(container);
  final arrangement = PracticeEngine().generateArrangement(
    _syllables(),
    lessonId: 'practice-test',
    updatedAt: DateTime.utc(2026, 7, 14),
  );
  container.read(editorControllerProvider.notifier).setArrangement(arrangement);
  await Future<void>.delayed(Duration.zero);
}

Lesson _customLesson() {
  final syllables = _syllables();
  final arrangement = PracticeEngine().generateArrangement(
    syllables,
    lessonId: 'practice-custom',
    updatedAt: DateTime.utc(2026, 7, 14),
  );
  return Lesson(
    id: 'practice-custom',
    title: 'Custom practice',
    audioRelPath: 'audio/original.wav',
    originalAudioBytes: encodeWav(_pcm()),
    contentHash: 'hash',
    words: [
      Word(text: 'thank you very much', startMs: 0, endMs: 1200, index: 0),
    ],
    syllables: syllables,
    translations: const [],
    prosody: null,
    practiceConfig: const PracticeConfig(repeatN: 3),
    arrangement: arrangement,
    updatedAt: DateTime.utc(2026, 7, 14),
  );
}

void main() {
  group('PracticeController', () {
    test('AT-16-01 自由排列 0 列時建立完整單句 1 單元', () {
      final playback = _FakePlayback();
      final container = _container(playback: playback);
      addTearDown(container.dispose);

      container.read(editorControllerProvider.notifier).loadFrom(_syllables());
      final state = container.read(practiceControllerProvider);

      expect(state.mode, PracticeMode.wholeSentence);
      expect(state.steps, hasLength(1));
      expect(state.steps.single.syllables.map((s) => s.text), [
        'thank',
        'you',
        've',
        'ry',
        'much',
      ]);
      expect(state.repeatN, 3);
    });

    test('FP14.1 Lesson 有排列時由 effectiveUnits 提供 custom mode 並播放 row', () async {
      final playback = _FakePlayback();
      final container = _container(playback: playback);
      addTearDown(container.dispose);
      container
          .read(lessonSessionControllerProvider.notifier)
          .hydrateLesson(_customLesson());
      await Future<void>.delayed(Duration.zero);

      final state = container.read(practiceControllerProvider);
      expect(state.mode, PracticeMode.custom);
      expect(state.units, everyElement(isA<CustomPracticeUnit>()));
      expect(state.steps, hasLength(5));

      await container.read(practiceControllerProvider.notifier).play();
      expect(playback.rowPlayCount, 1);
      expect(playback.lastRow?.index, 1);
    });

    test('AT-16-09 setRepeatN 同步目前排列列，不額外乘第三層', () async {
      final playback = _FakePlayback();
      final container = _container(playback: playback, pcm: _pcm());
      addTearDown(container.dispose);
      await _prepareGeneratedPractice(container);
      final controller = container.read(practiceControllerProvider.notifier);

      final before = container.read(practiceControllerProvider).steps[1];
      await controller.selectStep(1);
      controller.setRepeatN(5);
      final after = container.read(practiceControllerProvider).steps[1];

      expect(after.sourceRanges, before.sourceRanges);
      expect(after.totalDurationMs, 7700);
      expect(
        container.read(editorControllerProvider).arrangement!.rows[1].repeatN,
        5,
      );
      controller.setRepeatN(0);
      final error = container.read(practiceControllerProvider).error;
      expect(error?.code, ErrorCodes.blockConfigOutOfRange);
    });

    test('selectStep 會先 stop，再切換 currentIndex（AT-03-05）', () async {
      final playback = _FakePlayback();
      final container = _container(playback: playback);
      addTearDown(container.dispose);
      await _prepareGeneratedPractice(container);
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
      await _preparePractice(container);
      final controller = container.read(practiceControllerProvider.notifier);

      await controller.play();

      expect(playback.playPcmCount, 1);
      expect(playback.lastPcm?.samples, hasLength(10000));
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
      await _prepareGeneratedPractice(container);
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
      final events = <String>[];
      final recorder = _FakeRecorder(events: events);
      final audioSession = _FakePracticeAudioSessionCoordinator(events: events);
      final comparison = _FakeComparisonService();
      comparison.pending = Completer<ComparisonResult>();
      final pcm = _pcm();
      final container = _container(
        playback: playback,
        pcm: pcm,
        recorder: recorder,
        comparisonService: comparison,
        audioSession: audioSession,
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
      expect(events.take(4), [
        'session.record.prepare',
        'recorder.start',
        'recorder.stop',
        'session.record.finish',
      ]);
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
      expect(state.recordedPcm?.samples, _pcm().samples);
      expect(state.error, isNull);
    });

    test('AT-18-01 自訂積木與整列重複只產生各來源一次的比對參考', () async {
      final comparison = _FakeComparisonService();
      final pcm = _pcm();
      final container = _container(
        playback: _FakePlayback(),
        pcm: pcm,
        recorder: _FakeRecorder(),
        comparisonService: comparison,
      );
      addTearDown(container.dispose);
      await _preparePractice(container);
      final editor = container.read(editorControllerProvider);
      final syllables = editor.syllables;
      container
          .read(editorControllerProvider.notifier)
          .setArrangement(
            PracticeArrangement(
              lessonId: editor.sourceLessonId!,
              rows: [
                PracticeRow(
                  index: 1,
                  blocks: [
                    PracticeBlock(
                      syllables: [syllables[0]],
                      repeatN: 3,
                      silenceFactor: 2,
                    ),
                    PracticeBlock(
                      syllables: [syllables[1], syllables[2]],
                      repeatN: 2,
                      silenceFactor: 3,
                      isGrouped: true,
                    ),
                  ],
                  repeatN: 4,
                  silenceFactor: 2,
                ),
              ],
              updatedAt: DateTime.utc(2026, 7, 16),
            ),
          );
      await Future<void>.delayed(Duration.zero);
      final controller = container.read(practiceControllerProvider.notifier);

      await controller.startRecording();
      await controller.stopRecording();

      final reference = PracticeEngine().renderStep(comparison.lastStep!, pcm);
      expect(comparison.lastStep!.syllables.map((item) => item.text), [
        'thank',
        'you',
        've',
      ]);
      expect(reference.durationMs, 650);
    });

    test('AT-18-08 比對失敗仍保留目前單元錄音並可播放', () async {
      final playback = _FakePlayback();
      final comparison = _FakeComparisonService()
        ..error = const DomainException(ErrorCodes.decodeFailed, '比對失敗');
      final container = _container(
        playback: playback,
        pcm: _pcm(),
        recorder: _FakeRecorder(),
        comparisonService: comparison,
      );
      addTearDown(container.dispose);
      await _preparePractice(container);
      final controller = container.read(practiceControllerProvider.notifier);

      await controller.startRecording();
      await controller.stopRecording();

      var state = container.read(practiceControllerProvider);
      expect(state.comparison, isNull);
      expect(state.recordedPcm, isNotNull);
      expect(state.error?.message, '比對失敗');

      await controller.playRecording();

      state = container.read(practiceControllerProvider);
      expect(playback.playPcmCount, 1);
      expect(playback.lastPcm?.samples, _pcm().samples);
      expect(state.recordedPlaybackStatus, PracticeRecordedPlaybackStatus.idle);
    });

    test('AT-06-09 錄音播放中可停止，停止後再播會重新呼叫播放器', () async {
      final playback = _FakePlayback()..playPcmPending = Completer<void>();
      final container = _container(
        playback: playback,
        pcm: _pcm(),
        recorder: _FakeRecorder(),
      );
      addTearDown(container.dispose);
      await _preparePractice(container);
      final controller = container.read(practiceControllerProvider.notifier);
      await controller.startRecording();
      await controller.stopRecording();

      final firstPlay = controller.playRecording();
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(practiceControllerProvider).recordedPlaybackStatus,
        PracticeRecordedPlaybackStatus.playing,
      );

      await controller.stopRecordingPlayback();
      playback.playPcmPending!.complete();
      await firstPlay;
      expect(
        container.read(practiceControllerProvider).recordedPlaybackStatus,
        PracticeRecordedPlaybackStatus.idle,
      );

      playback.playPcmPending = null;
      await controller.playRecording();
      expect(playback.playPcmCount, 2);
    });

    test('AT-18-05／09 切單元、重錄與垃圾桶都清除舊錄音結果', () async {
      final playback = _FakePlayback();
      final container = _container(
        playback: playback,
        pcm: _pcm(),
        recorder: _FakeRecorder(),
      );
      addTearDown(container.dispose);
      await _prepareGeneratedPractice(container);
      final controller = container.read(practiceControllerProvider.notifier);

      await controller.startRecording();
      await controller.stopRecording();
      expect(container.read(practiceControllerProvider).recordedPcm, isNotNull);

      await controller.selectStep(1);
      expect(container.read(practiceControllerProvider).recordedPcm, isNull);
      expect(container.read(practiceControllerProvider).comparison, isNull);

      await controller.startRecording();
      expect(container.read(practiceControllerProvider).recordedPcm, isNull);
      await controller.stopRecording();
      expect(container.read(practiceControllerProvider).recordedPcm, isNotNull);

      await controller.clearRecordingResult();
      final state = container.read(practiceControllerProvider);
      expect(state.recordedPcm, isNull);
      expect(state.comparison, isNull);
      expect(state.recordedPlaybackStatus, PracticeRecordedPlaybackStatus.idle);
    });

    test('AT-18-09 離開錄音練習頁會停止回放並清除記憶體錄音', () async {
      final playback = _FakePlayback()..playPcmPending = Completer<void>();
      final container = _container(
        playback: playback,
        pcm: _pcm(),
        recorder: _FakeRecorder(),
      );
      addTearDown(container.dispose);
      container
          .read(appShellSelectedIndexProvider.notifier)
          .select(AppSection.practice.sectionIndex);
      await _preparePractice(container);
      final controller = container.read(practiceControllerProvider.notifier);
      await controller.startRecording();
      await controller.stopRecording();
      final playFuture = controller.playRecording();
      await Future<void>.delayed(Duration.zero);
      expect(container.read(practiceControllerProvider).recordedPcm, isNotNull);

      container
          .read(appShellSelectedIndexProvider.notifier)
          .select(AppSection.library.sectionIndex);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(practiceControllerProvider);
      expect(state.recordedPcm, isNull);
      expect(state.comparison, isNull);
      expect(state.recordedPlaybackStatus, PracticeRecordedPlaybackStatus.idle);
      expect(playback.stopCount, greaterThanOrEqualTo(3));

      playback.playPcmPending!.complete();
      await playFuture;
    });

    test('AT-18-03 切換單元後丟棄背景 isolate 晚到比對結果', () async {
      final comparison = _FakeComparisonService();
      comparison.pending = Completer<ComparisonResult>();
      final container = _container(
        playback: _FakePlayback(),
        pcm: _pcm(),
        recorder: _FakeRecorder(),
        comparisonService: comparison,
      );
      addTearDown(container.dispose);
      await _prepareGeneratedPractice(container);
      final controller = container.read(practiceControllerProvider.notifier);

      await controller.startRecording();
      final stopFuture = controller.stopRecording();
      await Future<void>.delayed(Duration.zero);
      await controller.selectStep(1);
      comparison.pending!.complete(comparison.result);
      await stopFuture;

      final state = container.read(practiceControllerProvider);
      expect(state.currentIndex, 1);
      expect(state.recordStatus, PracticeRecordStatus.idle);
      expect(state.comparison, isNull);
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

    test('AT-18-02 錄音中切步會取消並丟棄錄音', () async {
      final playback = _FakePlayback();
      final recorder = _FakeRecorder();
      final container = _container(
        playback: playback,
        pcm: _pcm(),
        recorder: recorder,
      );
      addTearDown(container.dispose);
      await _prepareGeneratedPractice(container);
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
