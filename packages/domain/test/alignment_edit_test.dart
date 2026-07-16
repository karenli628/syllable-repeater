// AI-Generate
// AlignmentEngine 切點增刪／改字 TDD（REQ-13、AT-13-01～06）。
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('AlignmentEngine.removeBoundary（REQ-13）', () {
    test('AT-13-01 刪除 420ms 切點後合併文字、時間與 needsReview', () {
      final result = AlignmentEngine().removeBoundary(_twoSyllables(), 0);

      expect(result.syllables, hasLength(1));
      expect(result.syllables.single.text, 'I dont');
      expect(result.syllables.single.startMs, 0);
      expect(result.syllables.single.endMs, 880);
      expect(result.syllables.single.needsReview, isTrue);
      expect(_twoSyllables().syllables, hasLength(2), reason: '輸入快照不可變');
    });

    test('AT-13-05 僅剩一音節時拒絕並回 ERR_SYLLABLE_MIN_COUNT', () {
      expect(
        () => AlignmentEngine().removeBoundary(_singleSyllable(), 0),
        _domainError(ErrorCodes.syllableMinCount),
      );
    });

    test('AT-13-01 boundaryIndex 越界時 ArgumentError 帶實際值', () {
      expect(
        () => AlignmentEngine().removeBoundary(_twoSyllables(), 2),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('got 2'),
          ),
        ),
      );
    });
  });

  group('AlignmentEngine.insertBoundary（REQ-13／DFT-10）', () {
    test('AT-13-02 由 PCM 吸附 425ms 零交越並產生空白待檢後半', () {
      final result = AlignmentEngine().insertBoundary(
        _singleSyllable(),
        0,
        420,
        pcm: _zeroCrossingAt(425, durationMs: 880),
      );

      expect(result.syllables, hasLength(2));
      expect(result.syllables[0].text, 'I dont');
      expect(result.syllables[0].startMs, 0);
      expect(result.syllables[0].endMs, 425);
      expect(result.syllables[1].text, isEmpty);
      expect(result.syllables[1].startMs, 425);
      expect(result.syllables[1].endMs, 880);
      expect(result.syllables[1].needsReview, isTrue);
    });

    test('AT-13-06 距既有切點 49ms 時拒絕 ERR_BOUNDARY_TOO_CLOSE', () {
      expect(
        () => AlignmentEngine().insertBoundary(
          _boundaryFixture(),
          1,
          2429,
          pcm: _flatPcm(durationMs: 3000),
        ),
        _domainError(ErrorCodes.boundaryTooClose),
      );
    });

    test('AT-13-06 距既有切點 51ms 時允許插入', () {
      final result = AlignmentEngine().insertBoundary(
        _boundaryFixture(),
        1,
        2431,
        pcm: _flatPcm(durationMs: 3000),
      );

      expect(result.syllables, hasLength(3));
      expect(result.syllables[1].endMs, 2431);
      expect(result.syllables[2].startMs, 2431);
    });

    test('AT-13-02 syllableIndex 越界時 ArgumentError 帶實際值', () {
      expect(
        () => AlignmentEngine().insertBoundary(
          _singleSyllable(),
          1,
          420,
          pcm: _flatPcm(durationMs: 880),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            contains('got 1'),
          ),
        ),
      );
    });
  });

  group('AlignmentEngine.updateSyllableText（REQ-13）', () {
    test('AT-13-03 首次改字保存 originalText，再改仍保留第一次原文', () {
      final engine = AlignmentEngine();
      final first = engine.updateSyllableText(_twoSyllables(), 1, "don't");
      final second = engine.updateSyllableText(first, 1, 'do not');

      expect(first.syllables[1].text, "don't");
      expect(first.syllables[1].originalText, 'dont');
      expect(second.syllables[1].text, 'do not');
      expect(second.syllables[1].originalText, 'dont');
    });

    test('AT-13-03 空字串允許暫存並強制 needsReview', () {
      final result =
          AlignmentEngine().updateSyllableText(_twoSyllables(), 1, '');

      expect(result.syllables[1].text, isEmpty);
      expect(result.syllables[1].originalText, 'dont');
      expect(result.syllables[1].needsReview, isTrue);
    });
  });

  test('AT-13-04 拖動→刪除→新增→改字保留四個不可變 undo 快照', () {
    final engine = AlignmentEngine();
    final original = _threeSyllables();
    final dragged = engine.updateSyllableBoundary(
      current: original.syllables,
      boundaryIndex: 0,
      newPositionMs: 450,
      pcm: _flatPcm(durationMs: 1300),
    );
    final afterDrag = _withSyllables(original, dragged.syllables);
    final afterRemove = engine.removeBoundary(afterDrag, 1);
    final afterInsert = engine.insertBoundary(
      afterRemove,
      1,
      900,
      pcm: _flatPcm(durationMs: 1300),
    );
    final afterText = engine.updateSyllableText(afterInsert, 2, 'again');

    expect(original.syllables.map((item) => item.endMs), [420, 880, 1300]);
    expect(afterDrag.syllables.map((item) => item.endMs), [450, 880, 1300]);
    expect(afterRemove.syllables, hasLength(2));
    expect(afterInsert.syllables, hasLength(3));
    expect(afterInsert.syllables[2].text, isEmpty);
    expect(afterText.syllables[2].text, 'again');

    final undoSnapshots = [afterInsert, afterRemove, afterDrag, original];
    expect(undoSnapshots.map((item) => item.syllables.length), [3, 2, 3, 3]);
    expect(undoSnapshots.last.syllables, original.syllables);
  });
}

AlignmentResult _singleSyllable() => AlignmentResult(
      words: [_word('I dont', 0, 880, 0)],
      syllables: [_syllable('I dont', 0, 880, 0)],
      source: 'fixture',
      confidence: 0.9,
    );

AlignmentResult _twoSyllables() => AlignmentResult(
      words: [_word('I', 0, 420, 0), _word('dont', 420, 880, 1)],
      syllables: [
        _syllable('I', 0, 420, 0),
        _syllable('dont', 420, 880, 1),
      ],
      source: 'fixture',
      confidence: 0.9,
    );

AlignmentResult _threeSyllables() => AlignmentResult(
      words: [
        _word('I', 0, 420, 0),
        _word('dont', 420, 880, 1),
        _word('know', 880, 1300, 2),
      ],
      syllables: [
        _syllable('I', 0, 420, 0),
        _syllable('dont', 420, 880, 1),
        _syllable('know', 880, 1300, 2),
      ],
      source: 'fixture',
      confidence: 0.9,
    );

AlignmentResult _boundaryFixture() => AlignmentResult(
      words: [
        _word('before', 0, 2380, 0),
        _word('after', 2380, 3000, 1),
      ],
      syllables: [
        _syllable('before', 0, 2380, 0),
        _syllable('after', 2380, 3000, 1),
      ],
      source: 'fixture',
      confidence: 0.9,
    );

AlignmentResult _withSyllables(
  AlignmentResult source,
  List<Syllable> syllables,
) =>
    AlignmentResult(
      words: source.words,
      syllables: syllables,
      source: source.source,
      confidence: source.confidence,
    );

Word _word(String text, int startMs, int endMs, int index) => Word(
      text: text,
      startMs: startMs,
      endMs: endMs,
      index: index,
    );

Syllable _syllable(
  String text,
  int startMs,
  int endMs,
  int wordIndex,
) =>
    Syllable(
      text: text,
      startMs: startMs,
      endMs: endMs,
      wordIndex: wordIndex,
      needsReview: false,
    );

Pcm _flatPcm({required int durationMs}) => Pcm(
      Int16List((_sampleRate * durationMs) ~/ 1000)
        ..fillRange(
          0,
          (_sampleRate * durationMs) ~/ 1000,
          100,
        ),
    );

Pcm _zeroCrossingAt(int crossingMs, {required int durationMs}) {
  final samples = Int16List((_sampleRate * durationMs) ~/ 1000);
  final crossingSample = ((_sampleRate * crossingMs) + 999) ~/ 1000;
  for (var index = 0; index < samples.length; index++) {
    samples[index] = index < crossingSample ? 100 : -100;
  }
  return Pcm(samples);
}

Matcher _domainError(String code) => throwsA(
      isA<DomainException>().having((error) => error.code, 'code', code),
    );

const _sampleRate = 44100;
