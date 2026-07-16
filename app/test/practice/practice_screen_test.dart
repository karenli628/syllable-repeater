// AI-Generate
import 'dart:async';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart' hide ComparisonResult;
import 'package:syllable_repeater_app/features/editor/editor_controller.dart';
import 'package:syllable_repeater_app/features/import_analysis/analysis_controller.dart';
import 'package:syllable_repeater_app/features/pack_translate/lesson_session_controller.dart';
import 'package:syllable_repeater_app/features/practice/practice_controller.dart';
import 'package:syllable_repeater_app/features/practice/practice_player.dart';
import 'package:syllable_repeater_app/features/practice/practice_recording.dart';
import 'package:syllable_repeater_app/features/progress/progress_service.dart';
import 'package:syllable_repeater_app/main.dart';
import 'package:syllable_repeater_app/shared/navigation.dart';

class _FakePlayback implements PracticePlayback {
  int playCount = 0;
  int playPcmCount = 0;
  int playRowCount = 0;
  int stopCount = 0;
  int? lastRepeatN;
  PracticeStep? lastStep;
  PracticeRow? lastRow;

  @override
  Future<void> playPcm(Pcm pcm, {void Function()? onReady}) async {
    playPcmCount++;
    onReady?.call();
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
    playRowCount++;
    lastRow = row;
    onReady?.call();
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }
}

class _FakeAudioSession implements PracticeAudioSessionCoordinator {
  @override
  Future<void> finishPlayback() async {}

  @override
  Future<void> finishRecording() async {}

  @override
  Future<void> prepareForPlayback() async {}

  @override
  Future<void> prepareForRecording() async {}
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
  final _levels = StreamController<double>.broadcast(sync: true);
  int startCount = 0;
  int stopCount = 0;
  int cancelCount = 0;
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
    return '/tmp/attempt.wav';
  }

  @override
  Future<CompletedPracticeRecording?> stop() async {
    stopCount++;
    return CompletedPracticeRecording(path: '/tmp/attempt.wav', pcm: _pcm());
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
  int compareCount = 0;

  @override
  Future<ComparisonResult> compare({
    required String userRecordingPath,
    required List<Syllable> syllables,
    required PracticeStep step,
    required Pcm originalPcm,
  }) async {
    compareCount++;
    return ComparisonResult(
      rhythmDelta: 0.12,
      intonationDelta: 0.24,
      overlayData: OverlayData(
        userWave: const [0, 0.4, -0.2, 0.1],
        referenceWave: const [0, 0.2, -0.1, 0.1],
        userPitch: const [180, 182],
        referencePitch: const [176, 181],
        diffRanges: [TimeRange(100, 180)],
      ),
      score: 88,
    );
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

Lesson _customLesson() {
  final syllables = _syllables();
  return Lesson(
    id: 'screen-custom',
    title: 'Screen custom',
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
    arrangement: PracticeEngine().generateArrangement(
      syllables,
      lessonId: 'screen-custom',
      updatedAt: DateTime.utc(2026, 7, 14),
    ),
    updatedAt: DateTime.utc(2026, 7, 14),
  );
}

Future<ProviderContainer> _pumpApp(
  WidgetTester tester, {
  required _FakePlayback playback,
  required Pcm pcm,
  _FakeRecorder? recorder,
  _FakeComparisonService? comparisonService,
}) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    SyllableRepeaterApp(
      overrides: <Override>[
        practicePlayerProvider.overrideWithValue(playback),
        practiceAudioSessionProvider.overrideWithValue(_FakeAudioSession()),
        practiceRecorderProvider.overrideWithValue(recorder ?? _FakeRecorder()),
        practiceComparisonServiceProvider.overrideWithValue(
          comparisonService ?? _FakeComparisonService(),
        ),
        analysisRunnerProvider.overrideWithValue(
          _FakeAnalysisRunner(pcm, _syllables()),
        ),
      ],
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  container.read(editorControllerProvider.notifier).loadFrom(_syllables());
  final analysis = container.read(analysisControllerProvider.notifier);
  await analysis.selectAudioPath('test.mp3');
  await analysis.start();
  return container;
}

void main() {
  testWidgets('AT-16-01 自由排列 0 列時只練整個單句', (tester) async {
    final playback = _FakePlayback();
    final container = await _pumpApp(tester, playback: playback, pcm: _pcm());

    container
        .read(appShellSelectedIndexProvider.notifier)
        .select(AppSection.practice.sectionIndex);
    await tester.pump();

    expect(find.text('句尾疊加練習'), findsOneWidget);
    expect(find.text('共 1 單元；目前第 1 單元。'), findsOneWidget);
    expect(find.text('#1 thank you ve ry much'), findsOneWidget);
    expect(find.textContaining('#2 '), findsNothing);
    await tester.tap(find.byTooltip('目前單元整列重複次數 +1'));
    await tester.pump();
    expect(find.text('×4'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(playback.playPcmCount, 1);
    expect(playback.playCount, 0);
  });

  testWidgets('AT-16-02 多列時單元數與整列重複設定即時連動', (tester) async {
    final playback = _FakePlayback();
    final container = await _pumpApp(tester, playback: playback, pcm: _pcm());
    await container
        .read(lessonSessionControllerProvider.notifier)
        .hydrateLesson(_customLesson());
    await tester.pumpAndSettle();
    container
        .read(appShellSelectedIndexProvider.notifier)
        .select(AppSection.practice.sectionIndex);
    await tester.pump();

    expect(find.byKey(const ValueKey('practice-mode-chip')), findsNothing);
    expect(find.text('自訂排列'), findsNothing);
    expect(find.text('每列沿用各積木設定'), findsNothing);
    expect(find.text('共 5 單元；目前第 1 單元。'), findsOneWidget);
    expect(find.byTooltip('目前單元整列重複次數 +1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('practice-remove-arrangement')),
      findsNothing,
    );

    await tester.tap(find.text('#2 ry much'));
    await tester.pump();
    await tester.tap(find.byTooltip('目前單元整列重複次數 +1'));
    await tester.pump();

    expect(find.text('×4'), findsOneWidget);
    expect(
      container.read(editorControllerProvider).arrangement!.rows[1].repeatN,
      4,
    );
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(playback.playRowCount, 1);
    expect(playback.lastRow?.index, 2);
    expect(playback.lastRow?.repeatN, 4);
  });

  testWidgets('FP16.1 四態 SegmentedButton 可切換，無譯文仍顯示引導', (tester) async {
    final playback = _FakePlayback();
    final container = await _pumpApp(tester, playback: playback, pcm: _pcm());
    container
        .read(appShellSelectedIndexProvider.notifier)
        .select(AppSection.practice.sectionIndex);
    await tester.pump();

    expect(find.byKey(const ValueKey('transcript-text')), findsOneWidget);
    await tester.tap(find.text('僅譯文'));
    await tester.pump();
    expect(find.byKey(const ValueKey('translation-guidance')), findsOneWidget);
    expect(find.byKey(const ValueKey('transcript-text')), findsNothing);
    await tester.tap(find.text('隱藏'));
    await tester.pump();
    expect(find.byKey(const ValueKey('transcript-text')), findsNothing);
    expect(find.byKey(const ValueKey('translation-guidance')), findsNothing);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#1 much'), findsNothing);
    expect(find.text('第 1 單元'), findsOneWidget);
    expect(find.textContaining('第 1 單元：'), findsNothing);
  });

  testWidgets('FP16.2 每 Lesson 顯示偏好寫入 progress settings 並可讀回', (tester) async {
    final playback = _FakePlayback();
    final container = await _pumpApp(tester, playback: playback, pcm: _pcm());
    await container
        .read(lessonSessionControllerProvider.notifier)
        .hydrateLesson(_customLesson());
    await tester.pumpAndSettle();
    container
        .read(appShellSelectedIndexProvider.notifier)
        .select(AppSection.practice.sectionIndex);
    await tester.pump();

    await tester.tap(find.text('僅譯文'));
    await tester.pumpAndSettle();
    expect(
      await container
          .read(transcriptSettingsServiceProvider)
          .getTranscriptMode('screen-custom'),
      TranscriptDisplayMode.translationOnly,
    );
  });

  testWidgets('Editor syllable chip 呼叫 4.7 單音節播放', (tester) async {
    final playback = _FakePlayback();
    final container = await _pumpApp(tester, playback: playback, pcm: _pcm());

    container
        .read(appShellSelectedIndexProvider.notifier)
        .select(AppSection.editor.sectionIndex);
    await tester.pump();

    await tester.tap(find.text('much'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(playback.playCount, 1);
    expect(playback.lastRepeatN, 1);
    expect(playback.lastStep?.syllables.single.text, 'much');
    expect(playback.lastStep?.sourceRanges, [
      TimeRange(800, 2000),
    ], reason: '最後一塊試聽要播到原始 PCM 結尾');
  });

  testWidgets('AT-18-09 錄音後可播放並可用垃圾桶清除整筆結果', (tester) async {
    final playback = _FakePlayback();
    final recorder = _FakeRecorder();
    final comparison = _FakeComparisonService();
    final container = await _pumpApp(
      tester,
      playback: playback,
      pcm: _pcm(),
      recorder: recorder,
      comparisonService: comparison,
    );

    container
        .read(appShellSelectedIndexProvider.notifier)
        .select(AppSection.practice.sectionIndex);
    await tester.pump();

    final recordButton = find.widgetWithText(FilledButton, '錄音');
    await tester.ensureVisible(recordButton);
    await tester.tap(recordButton);
    await tester.pumpAndSettle();
    recorder.emitLevel(0.7);
    await tester.pump();

    final playButton = tester.widget<IconButton>(
      find.descendant(
        of: find.byKey(const ValueKey('practice-player-bar')),
        matching: find.byType(IconButton),
      ),
    );
    expect(playButton.onPressed, isNull);
    expect(find.text('停止'), findsOneWidget);
    expect(recorder.startCount, 1);
    expect(
      container.read(practiceControllerProvider).recordStatus,
      PracticeRecordStatus.recording,
    );

    final stopButton = find.widgetWithText(FilledButton, '停止');
    await tester.ensureVisible(stopButton);
    final stopWidget = tester.widget<FilledButton>(stopButton);
    expect(stopWidget.onPressed, isNotNull);
    await container.read(practiceControllerProvider.notifier).stopRecording();
    await tester.pumpAndSettle();

    expect(recorder.stopCount, 1);
    expect(comparison.compareCount, 1);
    expect(find.textContaining('節奏差異'), findsOneWidget);
    expect(find.textContaining('語調差異'), findsOneWidget);
    expect(find.text('差異疊圖'), findsOneWidget);
    final recordingPlayback = find.widgetWithText(OutlinedButton, '播放錄音');
    expect(recordingPlayback, findsOneWidget);
    await tester.tap(recordingPlayback);
    await tester.pumpAndSettle();
    expect(playback.playPcmCount, 1);
    expect(find.textContaining('暫存'), findsNothing);
    final clearButton = find.byTooltip('刪除本次錄音比對');
    expect(clearButton, findsOneWidget);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();
    expect(find.text('差異疊圖'), findsNothing);
    expect(find.text('播放錄音'), findsNothing);
    expect(container.read(practiceControllerProvider).recordedPcm, isNull);
  });

  testWidgets('麥克風權限拒絕時顯示設定指引', (tester) async {
    final playback = _FakePlayback();
    final recorder = _FakeRecorder()
      ..startError = const DomainException(
        ErrorCodes.micPermissionDenied,
        '請至系統設定開啟麥克風權限',
      );
    final container = await _pumpApp(
      tester,
      playback: playback,
      pcm: _pcm(),
      recorder: recorder,
    );

    container
        .read(appShellSelectedIndexProvider.notifier)
        .select(AppSection.practice.sectionIndex);
    await tester.pump();

    final recordButton = find.widgetWithText(FilledButton, '錄音');
    await tester.ensureVisible(recordButton);
    await tester.tap(recordButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('請到系統設定開啟麥克風權限。'), findsOneWidget);
    expect(find.textContaining('請至系統設定開啟麥克風權限'), findsOneWidget);
  });
}
