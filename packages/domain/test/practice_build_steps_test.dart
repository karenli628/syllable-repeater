// AI-Generate
// PracticeEngine.buildSteps TDD-red 測試（task-split 4.1）。
// 對應 requirement REQ-03 AT-03-01/03/04/06/07 與 CT-02。
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

Matcher _domainError(String code) =>
    throwsA(isA<DomainException>().having((e) => e.code, 'code', code));

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

List<Syllable> _thankYouVeryMuchSyllables() => [
      Syllable(
          text: 'thank',
          startMs: 0,
          endMs: 250,
          wordIndex: 0,
          needsReview: false),
      Syllable(
          text: 'you',
          startMs: 250,
          endMs: 500,
          wordIndex: 1,
          needsReview: false),
      Syllable(
          text: 've',
          startMs: 500,
          endMs: 650,
          wordIndex: 2,
          needsReview: true),
      Syllable(
          text: 'ry',
          startMs: 650,
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

List<String> _texts(PracticeStep step) =>
    step.syllables.map((s) => s.text).toList(growable: false);

TimeRange _coveredRange(PracticeStep step) =>
    TimeRange(step.sourceRanges.first.startMs, step.sourceRanges.last.endMs);

Pcm _indexedPcm({int durationMs = 4000, int sampleRate = 1000}) {
  final samples = Int16List(durationMs * sampleRate ~/ 1000);
  for (var i = 0; i < samples.length; i++) {
    samples[i] = i;
  }
  return Pcm(samples, sampleRate: sampleRate);
}

List<int> _samplesForRanges(Pcm pcm, List<TimeRange> ranges) {
  final copied = <int>[];
  for (final range in ranges) {
    copied.addAll(pcm.samples.sublist(
        pcm.sampleIndexAtMs(range.startMs), pcm.sampleIndexAtMs(range.endMs)));
  }
  return copied;
}

void _expectSourceSamplesExceptSegmentEdges({
  required Pcm rendered,
  required Pcm original,
  required List<TimeRange> ranges,
}) {
  final expected = _samplesForRanges(original, ranges);
  final fadeSamples =
      (kZeroCrossingSearchWindowMs * original.sampleRate / 1000).ceil();

  expect(rendered.sampleRate, original.sampleRate);
  expect(rendered.samples.length, expected.length);

  var outputOffset = 0;
  for (final range in ranges) {
    final segmentLength = original.sampleIndexAtMs(range.endMs) -
        original.sampleIndexAtMs(range.startMs);
    for (var i = fadeSamples; i < segmentLength - fadeSamples; i++) {
      expect(
        rendered.samples[outputOffset + i],
        expected[outputOffset + i],
        reason:
            'segment ${range.startMs}-${range.endMs}ms sample $i must come from original PCM',
      );
    }
    outputOffset += segmentLength;
  }
}

void main() {
  group('PracticeEngine.buildSteps（task-split 4.1，CT-02）', () {
    test('AT-03-01 金標準例句 repeatN=3 → 11 步、句尾倒數疊加', () {
      final engine = PracticeEngine();
      final steps = engine.buildSteps(_goldenSentenceSyllables(), 3);

      expect(steps, hasLength(11));
      expect(steps.map((s) => s.index), List.generate(11, (i) => i + 1));
      expect(_texts(steps[0]), ['skills']);
      expect(_texts(steps[1]), ['tion', 'skills']);
      expect(_texts(steps[10]), [
        'she',
        'has',
        'ex',
        'cel',
        'lent',
        'com',
        'mu',
        'ni',
        'ca',
        'tion',
        'skills',
      ]);
      expect(_coveredRange(steps[0]), TimeRange(2650, 3150));
      expect(steps[0].totalDurationMs, 500 * 3);
      expect(steps[10].totalDurationMs, 3150 * 3);
    });

    test('AT-03-03 第 2 步不得吸附單字邊界成 communication skills', () {
      final engine = PracticeEngine();
      final steps = engine.buildSteps(_goldenSentenceSyllables(), 3);
      final step2 = steps[1];

      expect(_texts(step2), ['tion', 'skills']);
      expect(_coveredRange(step2), TimeRange(2200, 3150),
          reason: '第 2 步必須從 communication 最後一音節 tion 開始，不得退回 com。');
      expect(step2.totalDurationMs, (2650 - 2200 + 3150 - 2650) * 3);
    });

    test('AT-03-06 repeatN 3→5 只改 totalDurationMs，不改 sourceRanges', () {
      final engine = PracticeEngine();
      final syllables = _goldenSentenceSyllables();

      final repeat3 = engine.buildSteps(syllables, 3);
      final repeat5 = engine.buildSteps(syllables, 5);

      expect(repeat5[1].sourceRanges, repeat3[1].sourceRanges);
      expect(repeat3[1].totalDurationMs, 950 * 3);
      expect(repeat5[1].totalDurationMs, 950 * 5);
    });

    test('AT-03-04 repeatN 0/11 拒絕並回 ERR_REPEATN_OUT_OF_RANGE', () {
      final engine = PracticeEngine();
      final syllables = _goldenSentenceSyllables();

      expect(() => engine.buildSteps(syllables, 0),
          _domainError(ErrorCodes.repeatNOutOfRange));
      expect(() => engine.buildSteps(syllables, 11),
          _domainError(ErrorCodes.repeatNOutOfRange));
    });

    test('AT-03-07 thank you very much → 恰 5 步', () {
      final engine = PracticeEngine();
      final steps = engine.buildSteps(_thankYouVeryMuchSyllables(), 3);

      expect(steps, hasLength(5));
      expect(_texts(steps[0]), ['much']);
      expect(_texts(steps[1]), ['ry', 'much']);
      expect(_texts(steps[2]), ['ve', 'ry', 'much']);
      expect(_texts(steps[3]), ['you', 've', 'ry', 'much']);
      expect(_texts(steps[4]), ['thank', 'you', 've', 'ry', 'much']);
    });
  });

  group('PracticeEngine.renderStep（task-split 4.3，CT-01）', () {
    test('AT-03-02 第 1 步輸出逐 sample 來自 skills 原音區間', () {
      final engine = PracticeEngine();
      final original = _indexedPcm();
      final step = PracticeStep(
        index: 1,
        syllables: [_goldenSentenceSyllables().last],
        sourceRanges: [TimeRange(2650, 3150)],
        totalDurationMs: 500,
      );

      final rendered = engine.renderStep(step, original);

      _expectSourceSamplesExceptSegmentEdges(
        rendered: rendered,
        original: original,
        ranges: step.sourceRanges,
      );
    });

    test('CT-01 多段 sourceRanges 依序串接，內部 sample 不可生成或重算', () {
      final engine = PracticeEngine();
      final original = _indexedPcm();
      final syllables = _goldenSentenceSyllables();
      final step = PracticeStep(
        index: 2,
        syllables: [syllables[8], syllables[10]],
        sourceRanges: [TimeRange(1900, 1950), TimeRange(2650, 2700)],
        totalDurationMs: 100,
      );

      final rendered = engine.renderStep(step, original);

      _expectSourceSamplesExceptSegmentEdges(
        rendered: rendered,
        original: original,
        ranges: step.sourceRanges,
      );
    });
  });

  group('PracticeEngine.singleSyllableStep（task-split 4.7）', () {
    test('單音節試聽 step 僅引用該音節原始區間', () {
      final engine = PracticeEngine();
      final syllable = _goldenSentenceSyllables().last;

      final step = engine.singleSyllableStep(syllable);

      expect(step.index, 1);
      expect(step.syllables, [syllable]);
      expect(step.sourceRanges, [TimeRange(2650, 3150)]);
      expect(step.totalDurationMs, 500);
    });
  });
}
