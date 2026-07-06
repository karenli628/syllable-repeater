// AI-Generate
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/features/editor/editor_controller.dart';
import 'package:syllable_repeater_app/features/pack_translate/lesson_session_controller.dart';
import 'package:syllable_repeater_app/features/practice/practice_controller.dart';

void main() {
  test('hydrateLesson 會同步 editor syllables 與 practice PCM/steps', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // 啟動 listener；hydrate 後兩邊都應接收到同一份 lesson。
    container.read(editorControllerProvider);
    container.read(practiceControllerProvider);

    final pcm = Pcm(
      Int16List.fromList(List.generate(1200, (i) => i)),
      sampleRate: 1000,
    );
    final lesson = _lesson(pcm: pcm);

    await container
        .read(lessonSessionControllerProvider.notifier)
        .hydrateLesson(lesson, sourcePath: '/tmp/saved.abopack');

    final session = container.read(lessonSessionControllerProvider);
    expect(session.lesson?.id, 'lesson-a');
    expect(session.sourcePath, '/tmp/saved.abopack');
    expect(session.pcm?.sampleRate, 1000);
    expect(session.waveformPeaks, isNotEmpty);

    final editor = container.read(editorControllerProvider);
    expect(editor.syllables.map((item) => item.text), ['hello', 'there']);

    final practice = container.read(practiceControllerProvider);
    expect(practice.decodedPcm?.samples.take(3), [0, 1, 2]);
    expect(practice.steps, hasLength(2));
    expect(practice.steps.first.syllables.single.text, 'there');
  });

  test('hydrateLesson 解碼失敗不覆蓋既有 session/editor/practice', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(editorControllerProvider);
    container.read(practiceControllerProvider);
    await container
        .read(lessonSessionControllerProvider.notifier)
        .hydrateLesson(_lesson(pcm: Pcm(Int16List.fromList([1, 2, 3]))));
    final beforeSession = container.read(lessonSessionControllerProvider);
    final beforeEditor = container.read(editorControllerProvider);

    await expectLater(
      container
          .read(lessonSessionControllerProvider.notifier)
          .hydrateLesson(_lesson(originalAudioBytes: Uint8List.fromList([1]))),
      throwsA(
        isA<DomainException>().having(
          (e) => e.code,
          'code',
          ErrorCodes.decodeFailed,
        ),
      ),
    );

    expect(
      container.read(lessonSessionControllerProvider),
      same(beforeSession),
    );
    expect(container.read(editorControllerProvider), same(beforeEditor));
    expect(container.read(practiceControllerProvider).decodedPcm?.samples, [
      1,
      2,
      3,
    ]);
  });
}

Lesson _lesson({Pcm? pcm, Uint8List? originalAudioBytes}) {
  return Lesson(
    id: 'lesson-a',
    title: 'Saved Lesson',
    audioRelPath: 'audio/original.wav',
    originalAudioBytes: originalAudioBytes ?? encodeWav(pcm!),
    contentHash: '',
    words: [
      Word(text: 'hello', startMs: 0, endMs: 500, index: 0),
      Word(text: 'there', startMs: 500, endMs: 1000, index: 1),
    ],
    syllables: [
      Syllable(
        text: 'hello',
        startMs: 0,
        endMs: 500,
        wordIndex: 0,
        needsReview: false,
      ),
      Syllable(
        text: 'there',
        startMs: 500,
        endMs: 1000,
        wordIndex: 1,
        needsReview: false,
      ),
    ],
    translations: const [],
    prosody: null,
    practiceConfig: const PracticeConfig(repeatN: 3),
    updatedAt: DateTime.utc(2026, 7, 6),
  );
}
