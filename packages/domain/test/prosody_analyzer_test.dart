// AI-Generate
// ProsodyAnalyzer TDD-red 測試（task-split 5.1/5.2）。
// 對應 requirement REQ-05 AT-05-01/02/03/04。
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

List<Syllable> _goldenSentenceSyllables() => [
      Syllable(
          text: 'she',
          startMs: 0,
          endMs: 200,
          wordIndex: 0,
          needsReview: false),
      Syllable(
          text: 'has',
          startMs: 200,
          endMs: 400,
          wordIndex: 1,
          needsReview: false),
      Syllable(
          text: 'ex',
          startMs: 400,
          endMs: 600,
          wordIndex: 2,
          needsReview: true),
      Syllable(
          text: 'cel',
          startMs: 600,
          endMs: 800,
          wordIndex: 2,
          needsReview: true),
      Syllable(
          text: 'lent',
          startMs: 800,
          endMs: 1000,
          wordIndex: 2,
          needsReview: true),
      Syllable(
          text: 'com',
          startMs: 1000,
          endMs: 1300,
          wordIndex: 3,
          needsReview: true),
      Syllable(
          text: 'mu',
          startMs: 1300,
          endMs: 1600,
          wordIndex: 3,
          needsReview: true),
      Syllable(
          text: 'ni',
          startMs: 1600,
          endMs: 1900,
          wordIndex: 3,
          needsReview: true),
      Syllable(
          text: 'ca',
          startMs: 1900,
          endMs: 2200,
          wordIndex: 3,
          needsReview: true),
      Syllable(
          text: 'tion',
          startMs: 2200,
          endMs: 2650,
          wordIndex: 3,
          needsReview: true),
      Syllable(
          text: 'skills',
          startMs: 2650,
          endMs: 3150,
          wordIndex: 4,
          needsReview: false),
    ];

Pcm _sinePcm({
  required int durationMs,
  int sampleRate = 1000,
  double hz = 100,
  int amplitude = 12000,
}) {
  final samples = Int16List(durationMs * sampleRate ~/ 1000);
  for (var i = 0; i < samples.length; i++) {
    final t = i / sampleRate;
    samples[i] = (math.sin(2 * math.pi * hz * t) * amplitude).round();
  }
  return Pcm(samples, sampleRate: sampleRate);
}

void main() {
  group('ProsodyAnalyzer（task-split 5.1/5.2，REQ-05）', () {
    test('AT-05-01 金標準 11 音節 rhythm/stress 長度正確且 pitch 可用', () {
      final pcm = _sinePcm(durationMs: 3150);
      final before = pcm.samples.toList(growable: false);

      final prosody =
          ProsodyAnalyzer().analyze(pcm, _goldenSentenceSyllables());

      expect(prosody.rhythm, hasLength(11));
      expect(prosody.stress, hasLength(11));
      expect(prosody.intensity, isNotEmpty);
      expect(prosody.pitchAvailable, isTrue);
      expect(prosody.pitchContour, isNotNull);
      expect(prosody.pitchContour!, isNotEmpty);
      expect(pcm.samples, before, reason: 'ProsodyAnalyzer 只讀，不可改寫原 PCM');
    });

    test('rhythm 使用音節時長 / 平均音節時長', () {
      final syllables = [
        Syllable(
            text: 'a',
            startMs: 0,
            endMs: 100,
            wordIndex: 0,
            needsReview: false),
        Syllable(
            text: 'b',
            startMs: 100,
            endMs: 300,
            wordIndex: 1,
            needsReview: false),
        Syllable(
            text: 'c',
            startMs: 300,
            endMs: 600,
            wordIndex: 2,
            needsReview: false),
      ];

      final prosody = ProsodyAnalyzer().analyze(
        _sinePcm(durationMs: 600),
        syllables,
      );

      expect(prosody.rhythm[0], closeTo(0.5, 0.0001));
      expect(prosody.rhythm[1], closeTo(1.0, 0.0001));
      expect(prosody.rhythm[2], closeTo(1.5, 0.0001));
    });

    test('AT-05-02 pitch 抽不到時降級，rhythm/intensity/stress 照常回傳', () {
      final pcm = Pcm(Int16List(1000), sampleRate: 1000);
      final syllables = _goldenSentenceSyllables().take(3).toList();

      final prosody = ProsodyAnalyzer().analyze(pcm, syllables);

      expect(prosody.pitchAvailable, isFalse);
      expect(prosody.pitchContour, isNull);
      expect(prosody.rhythm, hasLength(3));
      expect(prosody.intensity, isNotEmpty);
      expect(prosody.stress, hasLength(3));
      expect(prosody.stress, everyElement(0));
    });

    test('5.1 停頓偵測：低能量停頓保留於 intensity 曲線', () {
      final samples = Int16List(500);
      for (var i = 0; i < samples.length; i++) {
        if (i >= 200 && i < 300) {
          samples[i] = 0;
          continue;
        }
        final t = i / 1000;
        samples[i] = (math.sin(2 * math.pi * 100 * t) * 12000).round();
      }
      final pcm = Pcm(samples, sampleRate: 1000);
      final syllables = [
        Syllable(
            text: 'before',
            startMs: 0,
            endMs: 200,
            wordIndex: 0,
            needsReview: false),
        Syllable(
            text: 'after',
            startMs: 300,
            endMs: 500,
            wordIndex: 1,
            needsReview: false),
      ];

      final prosody =
          ProsodyAnalyzer(intensityWindowMs: 50).analyze(pcm, syllables);

      expect(prosody.intensity, hasLength(10));
      expect(prosody.intensity[3], greaterThan(0.05));
      expect(prosody.intensity[4], lessThan(0.001));
      expect(prosody.intensity[5], lessThan(0.001));
      expect(prosody.intensity[6], greaterThan(0.05));
    });

    test('AT-05-03 sample 換算後無有效樣本的音節標記 NaN 且整體不失敗', () {
      final pcm = _sinePcm(durationMs: 200, sampleRate: 10, hz: 2);
      final syllables = [
        Syllable(
            text: 'bad', startMs: 0, endMs: 1, wordIndex: 0, needsReview: true),
        Syllable(
            text: 'ok',
            startMs: 1,
            endMs: 200,
            wordIndex: 1,
            needsReview: false),
      ];

      final prosody = ProsodyAnalyzer().analyze(pcm, syllables);

      expect(prosody.rhythm[0].isNaN, isTrue);
      expect(prosody.stress[0].isNaN, isTrue);
      expect(prosody.rhythm[1].isFinite, isTrue);
      expect(prosody.stress[1].isFinite, isTrue);
    });
  });
}
