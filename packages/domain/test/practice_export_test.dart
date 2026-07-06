// AI-Generate
// PracticeEngine export assembly TDD-red 測試（task-split 4.5）。
// 對應 requirement REQ-04 AT-04-02/03/06 與 CT-03/M3。
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

List<Syllable> _thankYouVeryMuchSyllables() => [
      Syllable(
          text: 'thank',
          startMs: 0,
          endMs: 200,
          wordIndex: 0,
          needsReview: false),
      Syllable(
          text: 'you',
          startMs: 200,
          endMs: 400,
          wordIndex: 1,
          needsReview: false),
      Syllable(
          text: 've',
          startMs: 400,
          endMs: 600,
          wordIndex: 2,
          needsReview: true),
      Syllable(
          text: 'ry',
          startMs: 600,
          endMs: 800,
          wordIndex: 2,
          needsReview: true),
      Syllable(
          text: 'much',
          startMs: 800,
          endMs: 1200,
          wordIndex: 3,
          needsReview: false),
    ];

Pcm _sourcePcm({int durationMs = 1200, int sampleRate = 1000}) {
  final samples = Int16List(durationMs * sampleRate ~/ 1000);
  for (var i = 0; i < samples.length; i++) {
    samples[i] = 1000 + i;
  }
  return Pcm(samples, sampleRate: sampleRate);
}

void _expectSilentRange(Pcm pcm, int startMs, int endMs) {
  final start = pcm.sampleIndexAtMs(startMs);
  final end = pcm.sampleIndexAtMs(endMs);
  expect(
    pcm.samples.sublist(start, end),
    everyElement(0),
    reason: 'silence range $startMs-$endMs ms must be sample-count zeroes',
  );
}

void main() {
  group('PracticeEngine export assembly（task-split 4.5，CT-03）', () {
    test('AT-04-02 thank you very much 全 5 步合併，靜音等於前一步總時長', () {
      final engine = PracticeEngine();
      final steps = engine.buildSteps(_thankYouVeryMuchSyllables(), 3);
      final original = _sourcePcm();

      final exported = engine.renderMergedExport(steps, original);

      expect(exported.silenceGapsMs, [1200, 1800, 2400, 3000]);
      expect(exported.totalDurationMs, 20400);
      expect(exported.pcm.durationMs, 20400);
      expect(exported.pcm.samples.length, 20400);

      _expectSilentRange(exported.pcm, 1200, 2400);
      _expectSilentRange(exported.pcm, 4200, 6000);
      _expectSilentRange(exported.pcm, 8400, 10800);
      _expectSilentRange(exported.pcm, 13800, 16800);
    });

    test('AT-04-03 單步合併成功且不補尾端靜音', () {
      final engine = PracticeEngine();
      final steps = engine.buildSteps(_thankYouVeryMuchSyllables(), 3);
      final original = _sourcePcm();

      final exported = engine.renderMergedExport([steps.first], original);

      expect(exported.silenceGapsMs, isEmpty);
      expect(exported.totalDurationMs, 1200);
      expect(exported.pcm.durationMs, 1200);
      expect(exported.pcm.samples.length, 1200);
    });
  });
}
