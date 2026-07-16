// AI-Generate
// M12 唯一模式判定入口 TDD-red（REQ-16、guardrails #40）。
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('PracticeEngine.effectiveUnits（backend-design.md 介面 30）', () {
    test('AT-16-01 arrangement=null 回傳完整 PCM 的 1 個隱含列單元', () {
      final effective = _effective();

      expect(effective.mode, PracticeMode.wholeSentence);
      expect(effective.stale, isFalse);
      expect(effective.units, hasLength(1));
      final unit = effective.units.single as WholeSentencePracticeUnit;
      expect(unit.step.syllables, _goldenSyllables());
      expect(unit.step.sourceRanges, [TimeRange(0, 3500)]);
      expect(unit.repeatN, 3);
      expect(unit.silenceFactor, 1);
      expect(
        () => effective.units.clear(),
        throwsUnsupportedError,
        reason: '對外單元清單不可修改',
      );
    });

    test('AT-16-03 arrangement 為空列也回傳完整單句 1 單元', () {
      final empty = PracticeArrangement(
        lessonId: _lessonId,
        rows: const [],
        updatedAt: _t0,
      );

      final effective = _effective(arrangement: empty);

      expect(effective.mode, PracticeMode.wholeSentence);
      expect(effective.units, hasLength(1));
      expect(effective.units.single, isA<WholeSentencePracticeUnit>());
    });

    test('AT-16-02 有 3 列排列時只回 custom 3 單元並透傳 stale', () {
      final arrangement = _threeRowsArrangement().markStale(updatedAt: _t1);
      final effective = _effective(arrangement: arrangement);

      expect(effective.mode, PracticeMode.custom);
      expect(effective.stale, isTrue);
      expect(effective.units, hasLength(3));
      expect(effective.units, everyElement(isA<CustomPracticeUnit>()));
      expect(
        effective.units.map((unit) => (unit as CustomPracticeUnit).row.index),
        [1, 2, 3],
      );
    });

    test('AT-16-03 刪除自訂排列後由同一入口回落完整單句', () {
      final custom = _effective(arrangement: _threeRowsArrangement());
      final fallback = _effective();

      expect(custom.mode, PracticeMode.custom);
      expect(fallback.mode, PracticeMode.wholeSentence);
      expect(fallback.units, hasLength(1));
    });

    test('AT-16-04 一鍵生成仍為 11 列，第二單元是 tion skills', () {
      final effective = _effective(
        arrangement: PracticeEngine().generateArrangement(
          _goldenSyllables(),
          lessonId: _lessonId,
          updatedAt: _t0,
        ),
      );

      expect(effective.mode, PracticeMode.custom);
      expect(effective.units, hasLength(11));
      final second = effective.units[1] as CustomPracticeUnit;
      expect(
        second.row.blocks
            .expand((block) => block.syllables)
            .map((syllable) => syllable.text),
        ['tion', 'skills'],
      );
    });
  });
}

PracticeUnits _effective({PracticeArrangement? arrangement}) =>
    PracticeEngine().effectiveUnits(
      _goldenSyllables(),
      arrangement: arrangement,
      fullSentenceRange: TimeRange(0, 3500),
    );

PracticeArrangement _threeRowsArrangement() {
  final generated = PracticeEngine().generateArrangement(
    _goldenSyllables(),
    lessonId: _lessonId,
    updatedAt: _t0,
  );
  return PracticeArrangement(
    lessonId: _lessonId,
    rows: generated.rows.take(3).toList(growable: false),
    updatedAt: _t0,
  );
}

List<Syllable> _goldenSyllables() => [
      _syllable('she', 0, 200, 0),
      _syllable('has', 200, 400, 1),
      _syllable('ex', 400, 600, 2),
      _syllable('cel', 600, 800, 2),
      _syllable('lent', 800, 1000, 2),
      _syllable('com', 1000, 1300, 3),
      _syllable('mu', 1300, 1600, 3),
      _syllable('ni', 1600, 1900, 3),
      _syllable('ca', 1900, 2200, 3),
      _syllable('tion', 2200, 2730, 3),
      _syllable('skills', 2730, 3150, 4),
    ];

Syllable _syllable(String text, int startMs, int endMs, int wordIndex) =>
    Syllable(
      text: text,
      startMs: startMs,
      endMs: endMs,
      wordIndex: wordIndex,
      needsReview: false,
    );

const _lessonId = 'lesson-a';
final _t0 = DateTime.utc(2026, 7, 13, 13);
final _t1 = DateTime.utc(2026, 7, 13, 13, 1);
