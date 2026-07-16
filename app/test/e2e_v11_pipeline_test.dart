// AI-Generate
// v1.1 跨切片 widget smoke：真 sidecar smoke 仍由 e2e_pipeline_test.dart 負責；
// 本檔鎖住 label→analysis→edit→arrange→practice→display 的 UI 接線。
import 'dart:async';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/features/editor/editor_controller.dart';
import 'package:syllable_repeater_app/features/import_analysis/analysis_controller.dart';
import 'package:syllable_repeater_app/main.dart';
import 'package:syllable_repeater_app/shared/navigation.dart';

class _Runner implements AnalysisRunner {
  const _Runner(this.pcm, this.syllables);

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
        source: request.audioPath,
        confidence: 1,
      ),
    );
  }
}

Pcm _pcm() =>
    Pcm(Int16List.fromList(List.generate(2000, (i) => i)), sampleRate: 1000);

List<Syllable> _syllables() => List.generate(
  3,
  (index) => Syllable(
    text: 's$index',
    startMs: index * 300,
    endMs: (index + 1) * 300,
    wordIndex: index,
    needsReview: false,
  ),
);

Lesson _lesson(Pcm pcm, List<Syllable> syllables) => Lesson(
  id: 'e2e-v11',
  title: 'v1.1 smoke',
  audioRelPath: 'audio/original.wav',
  originalAudioBytes: encodeWav(pcm),
  contentHash: 'hash',
  words: [Word(text: 's0 s1 s2', startMs: 0, endMs: 900, index: 0)],
  syllables: syllables,
  translations: const [],
  prosody: null,
  practiceConfig: const PracticeConfig(repeatN: 3),
  updatedAt: DateTime.utc(2026, 7, 14),
);

void main() {
  testWidgets('FE-QA.1 v1.1 跨切片 smoke 可到達排列、練習與顯示模式', (tester) async {
    tester.view.physicalSize = const Size(1100, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pcm = _pcm();
    final syllables = _syllables();
    await tester.pumpWidget(
      SyllableRepeaterApp(
        overrides: <Override>[
          analysisRunnerProvider.overrideWithValue(_Runner(pcm, syllables)),
        ],
      ),
    );
    final element = tester.element(find.byType(MaterialApp));
    final container = ProviderScope.containerOf(element);
    container
        .read(appShellSelectedIndexProvider.notifier)
        .select(AppSection.importAnalysis.sectionIndex);
    await tester.pump();
    final analysis = container.read(analysisControllerProvider.notifier);
    await analysis.selectAudioPath('e2e-v11.wav');
    await analysis.start();
    await tester.pump();

    final editor = container.read(editorControllerProvider.notifier);
    editor.loadLesson(_lesson(pcm, syllables), pcm: pcm);
    container
        .read(appShellSelectedIndexProvider.notifier)
        .select(AppSection.editor.sectionIndex);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('arrangement-generate')),
    );
    await tester.tap(find.byKey(const ValueKey('arrangement-generate')));
    await tester.pump();
    expect(find.byKey(const ValueKey('arrangement-row-3')), findsOneWidget);

    container
        .read(appShellSelectedIndexProvider.notifier)
        .select(AppSection.practice.sectionIndex);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('practice-mode-chip')), findsNothing);
    expect(
      find.textContaining('錄音暫存'),
      findsNothing,
      reason: 'AT-18-06 已移除暫存回聽面板',
    );
    expect(
      find.byKey(const ValueKey('transcript-display-mode')),
      findsOneWidget,
    );
    await tester.tap(find.text('隱藏'));
    await tester.pump();
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#1 s2'), findsNothing);
    expect(find.text('第 1 單元'), findsOneWidget);
    expect(find.textContaining('第 1 單元：'), findsNothing);
  });
}
