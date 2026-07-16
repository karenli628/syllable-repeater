// AI-Generate
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('AlignmentEngine（task-split 3.1/3.3）', () {
    test('AT-17-01 金標準回歸固定 11 音節、10 切點與時間戳', () {
      final result = AlignmentEngine().alignWords([
        Word(text: 'She', startMs: 0, endMs: 200, index: 0),
        Word(text: 'has', startMs: 200, endMs: 400, index: 1),
        Word(text: 'excellent', startMs: 400, endMs: 1000, index: 2),
        Word(text: 'communication', startMs: 1000, endMs: 2000, index: 3),
        Word(text: 'skills', startMs: 2000, endMs: 2300, index: 4),
      ]);

      expect(result.syllables, hasLength(11));
      expect(
        result.syllables.map((syllable) => syllable.text),
        [
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
          'skills'
        ],
      );
      expect(
        result.syllables.map((syllable) => [syllable.startMs, syllable.endMs]),
        [
          [0, 200],
          [200, 400],
          [400, 600],
          [600, 800],
          [800, 1000],
          [1000, 1200],
          [1200, 1400],
          [1400, 1600],
          [1600, 1800],
          [1800, 2000],
          [2000, 2300],
        ],
      );
      expect(
        result.syllables.take(10).map((syllable) => syllable.endMs),
        result.syllables.skip(1).map((syllable) => syllable.startMs),
        reason: '11 音節應形成 10 個連續切點，不能產生間隙或重疊',
      );
    });

    test('金標準句切出 11 音節，communication 內部需覆核', () {
      final engine = AlignmentEngine();
      final result = engine.alignWords([
        Word(text: 'She', startMs: 0, endMs: 200, index: 0),
        Word(text: 'has', startMs: 200, endMs: 400, index: 1),
        Word(text: 'excellent', startMs: 400, endMs: 1000, index: 2),
        Word(text: 'communication', startMs: 1000, endMs: 2000, index: 3),
        Word(text: 'skills', startMs: 2000, endMs: 2300, index: 4),
      ]);

      expect(result.syllables.map((s) => s.text), [
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
      expect(result.syllables, hasLength(11));
      expect(result.syllables.where((s) => s.wordIndex == 3),
          everyElement((Syllable s) => s.needsReview));
      expect(_isStrictlyIncreasing(result.syllables), isTrue);
    });

    test('使用者提供測試句 step up your coding skills to a new level 亦為 11 音節', () {
      final engine = AlignmentEngine();
      final words = _wordsFromTranscript(
        'step up your coding skills to a new level',
        const [0, 200, 400, 700, 1200, 1500, 1700, 1900, 2200, 2500],
      );

      final result = engine.alignWords(words);

      expect(result.syllables.map((s) => s.text), [
        'step',
        'up',
        'your',
        'cod',
        'ing',
        'skills',
        'to',
        'a',
        'new',
        'le',
        'vel',
      ]);
      expect(result.syllables, hasLength(11));
      expect(_isStrictlyIncreasing(result.syllables), isTrue);
    });

    test('CMUdict lines 可載入音節數；查無字走母音團 fallback 且 needsReview', () {
      final dictionary = SyllableDictionary.fromCmuDictLines([
        'HELLO  HH AH0 L OW1',
        'WORLD  W ER1 L D',
      ]);
      final engine = AlignmentEngine(dictionary: dictionary);

      expect(engine.syllableCount('hello'), 2);
      expect(engine.syllableCount('world'), 1);
      final result = engine.alignWords([
        Word(text: 'blorptastic', startMs: 0, endMs: 900, index: 0),
      ]);

      expect(result.syllables, hasLength(3));
      expect(result.syllables, everyElement((Syllable s) => s.needsReview));
    });
  });

  group('waveform peaks（task-split 3.5）', () {
    test('依 bucket 產出正規化 min/max', () {
      final pcm = Pcm(Int16List.fromList([-32768, -1000, 0, 32767]));
      final peaks = computeWaveformPeaks(pcm, bucketCount: 2);

      expect(peaks, hasLength(2));
      expect(peaks[0].min, closeTo(-1, 0.0001));
      expect(peaks[0].max, closeTo(-1000 / 32767, 0.0001));
      expect(peaks[1].min, 0);
      expect(peaks[1].max, 1);
    });
  });
}

List<Word> _wordsFromTranscript(String transcript, List<int> starts) {
  final parts = transcript.split(' ');
  return [
    for (var i = 0; i < parts.length; i++)
      Word(
        text: parts[i],
        startMs: starts[i],
        endMs: starts[i + 1],
        index: i,
      ),
  ];
}

bool _isStrictlyIncreasing(List<Syllable> syllables) {
  for (var i = 1; i < syllables.length; i++) {
    if (syllables[i - 1].endMs > syllables[i].startMs) {
      return false;
    }
  }
  return true;
}
