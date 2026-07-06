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
import 'package:syllable_repeater_app/features/practice/practice_controller.dart';
import 'package:syllable_repeater_app/features/practice/practice_player.dart';
import 'package:syllable_repeater_app/features/practice/practice_recording.dart';
import 'package:syllable_repeater_app/main.dart';
import 'package:syllable_repeater_app/shared/navigation.dart';

class _FakePlayback implements PracticePlayback {
  int playCount = 0;
  int stopCount = 0;
  int? lastRepeatN;
  PracticeStep? lastStep;

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
  Future<String?> stop() async {
    stopCount++;
    return '/tmp/attempt.wav';
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
  testWidgets('PracticeScreen 導航、repeatN 與播放呼叫 fake player', (tester) async {
    final playback = _FakePlayback();
    final container = await _pumpApp(tester, playback: playback, pcm: _pcm());

    container
        .read(appShellSelectedIndexProvider.notifier)
        .select(AppSection.practice.sectionIndex);
    await tester.pump();

    expect(find.text('句尾疊加練習'), findsOneWidget);
    expect(find.text('#1 much'), findsOneWidget);
    await tester.tap(find.byTooltip('重複次數 +1'));
    await tester.pump();
    expect(find.text('x4'), findsOneWidget);

    await tester.tap(find.text('#2 ry much'));
    await tester.pump();
    expect(playback.stopCount, 1);
    expect(find.text('第 2 步：ry much'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(playback.playCount, 1);
    expect(playback.lastRepeatN, 4);
    expect(playback.lastStep?.index, 2);
  });

  testWidgets('Editor syllable chip 呼叫 4.7 單音節播放', (tester) async {
    final playback = _FakePlayback();
    final container = await _pumpApp(tester, playback: playback, pcm: _pcm());

    container
        .read(appShellSelectedIndexProvider.notifier)
        .select(AppSection.editor.sectionIndex);
    await tester.pump();

    await tester.tap(find.text('much'));
    await tester.pump();

    expect(playback.playCount, 1);
    expect(playback.lastRepeatN, 1);
    expect(playback.lastStep?.syllables.single.text, 'much');
  });

  testWidgets('PracticeScreen 錄音時停用播放，停止後顯示差異疊圖摘要', (tester) async {
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
      find.widgetWithIcon(IconButton, Icons.play_arrow),
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
    await tester.pumpAndSettle();

    expect(find.text('請到系統設定開啟麥克風權限。'), findsOneWidget);
  });
}
