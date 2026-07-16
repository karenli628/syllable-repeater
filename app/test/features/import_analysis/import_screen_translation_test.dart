// AI-Generate
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/features/import_analysis/analysis_controller.dart';
import 'package:syllable_repeater_app/features/import_analysis/import_screen.dart';
import 'package:syllable_repeater_app/features/arrangement/arrangement_controller.dart';
import 'package:syllable_repeater_app/features/library/lesson_pack_service.dart';
import 'package:syllable_repeater_app/features/progress/ai_settings_service.dart';
import 'package:syllable_repeater_app/features/library/library_screen.dart';

void main() {
  testWidgets('未有課件草稿時譯文欄位與 AI／儲存入口置灰', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: ImportScreen())),
      ),
    );
    await tester.pump();

    final translationFinder = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '手動譯文',
    );
    final translationField = tester.widget<TextField>(translationFinder);
    expect(translationField.enabled, isFalse);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'AI 翻譯'))
          .onPressed,
      isNull,
    );
    expect(find.text('儲存課件'), findsNothing);
  });

  testWidgets('匯入頁 AI 譯文可預覽，保存入口已移至課程設定', (tester) async {
    final runner = _DoneRunner();
    final ai = _FakeAiSettingsService();
    final packService = _FakeLessonPackService();
    final container = ProviderContainer(
      overrides: [
        analysisRunnerProvider.overrideWithValue(runner),
        draftLessonIdentityGeneratorProvider.overrideWithValue(
          const _FixedDraftIdentityGenerator('draft-same-source'),
        ),
        aiSettingsServiceProvider.overrideWithValue(ai),
        lessonPackServiceProvider.overrideWithValue(packService),
        lessonPackFilePickerProvider.overrideWithValue(
          const _FakeLessonPackFilePicker('/tmp/translated.abopack'),
        ),
        libraryLessonEntriesProvider.overrideWith((ref) async => const []),
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

    final analysis = container.read(analysisControllerProvider.notifier);
    await analysis.selectAudioPath('/tmp/hello.wav');
    await analysis.start();
    await tester.pumpAndSettle();
    final draftId = container
        .read(analysisControllerProvider)
        .draftIdentity!
        .lessonId;
    container
        .read(arrangementControllerProvider.notifier)
        .generate(lessonId: draftId);

    final aiButton = find.widgetWithText(OutlinedButton, 'AI 翻譯');
    await tester.ensureVisible(aiButton);
    await tester.tap(aiButton);
    await tester.pumpAndSettle();
    expect(ai.requests, [('same source', 'zh-TW')]);
    expect(find.text('AI 譯文預覽：她有出色的溝通能力'), findsOneWidget);

    final translationField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.labelText == '手動譯文',
    );
    await tester.ensureVisible(translationField);
    await tester.enterText(translationField, '手動覆蓋譯文');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    expect(packService.savedPaths, isEmpty);
    expect(find.text('儲存課件'), findsNothing);
  });
}

class _DoneRunner implements AnalysisRunner {
  @override
  Stream<AnalysisEvent> analyze(
    ImportRequest request, {
    PipelineCheckpoint? resume,
  }) async* {
    yield AnalysisEvent(
      stage: AnalysisStage.done,
      progress: 1,
      decodedPcm: Pcm(Int16List.fromList([0, 1, 2, 3]), sampleRate: 1000),
      result: AlignmentResult(
        words: [
          Word(text: 'same', startMs: 0, endMs: 100, index: 0),
          Word(text: 'source', startMs: 100, endMs: 200, index: 1),
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
        source: request.audioPath,
        confidence: 1,
      ),
    );
  }
}

class _FakeAiSettingsService implements AiSettingsService {
  final requests = <(String, String)>[];

  @override
  Future<void> configureCredential(String credential) async {}

  @override
  Future<Translation> translate(String text, String targetLang) async {
    requests.add((text, targetLang));
    return Translation(
      text: '她有出色的溝通能力',
      source: TranslationSource.ai,
      modelName: 'fake-model',
      createdAt: DateTime.utc(2026, 7, 14),
    );
  }
}

class _FakeLessonPackService implements LessonPackService {
  final savedLessons = <Lesson>[];
  final savedPaths = <String>[];

  @override
  Future<Lesson> open(String path) => throw UnimplementedError();

  @override
  Future<String> save(Lesson lesson, String path) async {
    savedLessons.add(lesson);
    savedPaths.add(path);
    return path;
  }
}

class _FakeLessonPackFilePicker implements LessonPackFilePicker {
  const _FakeLessonPackFilePicker(this.path);

  final String path;

  @override
  Future<String?> pickOpenPath() async => null;

  @override
  Future<String?> pickSavePath() async => path;
}

class _FixedDraftIdentityGenerator implements DraftLessonIdentityGenerator {
  const _FixedDraftIdentityGenerator(this.lessonId);

  final String lessonId;

  @override
  DraftLessonIdentity create() => DraftLessonIdentity(lessonId: lessonId);
}
