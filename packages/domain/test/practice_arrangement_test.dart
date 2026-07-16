// AI-Generate
// PracticeArrangement TDD-red（REQ-15、M1/M3/M11、guardrails #47/#51）。
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('PracticeEngine.generateArrangement（介面 27）', () {
    test('AT-15-01 金標準 11 音節產生 11 列句尾疊加積木', () {
      final arrangement = _generate(_goldenSyllables());

      expect(arrangement.lessonId, _lessonId);
      expect(arrangement.rows, hasLength(11));
      expect(arrangement.rows.map((row) => row.index),
          List.generate(11, (index) => index + 1));
      expect(_rowTexts(arrangement.rows[0]), ['skills']);
      expect(_rowTexts(arrangement.rows[1]), ['tion', 'skills']);
      expect(_rowTexts(arrangement.rows[10]), [
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
      expect(arrangement.updatedAt, _t0);
      expect(arrangement.staleFlag, isFalse);
      expect(arrangement.undoDepth, 0);
      expect(
        arrangement.rows.map(_rowConfigOf),
        everyElement((3, 1.0)),
        reason: 'AT-15-13 每列外層預設 3／1',
      );
    });

    test('AT-15-01 公開 rows／blocks／syllables 皆不可修改', () {
      final arrangement = _generate(_goldenSyllables());

      expect(() => arrangement.rows.add(arrangement.rows.first),
          throwsUnsupportedError);
      expect(
          () => arrangement.rows.first.blocks.clear(), throwsUnsupportedError);
      expect(() => arrangement.rows.first.blocks.first.syllables.clear(),
          throwsUnsupportedError);
    });
  });

  group('PracticeArrangement 列與積木操作（介面 28）', () {
    test('AT-15-02 在第 1、2 列間插空列，刪除後重新編號', () {
      final original = _generate(_goldenSyllables());
      final inserted = original.insertRow(1, updatedAt: _t1);

      expect(inserted.rows, hasLength(12));
      expect(inserted.rows[1].blocks, isEmpty);
      expect(inserted.rows.map((row) => row.index),
          List.generate(12, (index) => index + 1));
      expect(inserted.updatedAt, _t1);
      expect(original.rows, hasLength(11), reason: '原排列不可變');

      final removed = inserted.removeRow(1, updatedAt: _t2);
      expect(removed.rows, hasLength(11));
      expect(removed.rows.map((row) => row.index),
          List.generate(11, (index) => index + 1));
      expect(_rowTexts(removed.rows[1]), ['tion', 'skills']);
    });

    test('AT-15-02 可重複放置並在同列改序為 itll rain itll rain', () {
      final syllables = _itllRain();
      var arrangement = _generate(syllables)
          .insertRow(0, updatedAt: _t1)
          .placeBlock(0, 0, syllables[1],
              sourceLessonId: _lessonId, updatedAt: _t2)
          .placeBlock(0, 1, syllables[0],
              sourceLessonId: _lessonId, updatedAt: _t3)
          .placeBlock(0, 2, syllables[0],
              sourceLessonId: _lessonId, updatedAt: _t4)
          .placeBlock(0, 3, syllables[1],
              sourceLessonId: _lessonId, updatedAt: _t5);

      arrangement = arrangement.moveBlock(
        fromRowIndex: 0,
        fromPosition: 0,
        toRowIndex: 0,
        toPosition: 1,
        updatedAt: _t6,
      );

      expect(_rowTexts(arrangement.rows[0]), ['itll', 'rain', 'itll', 'rain']);
    });

    test('AT-15-17 頂層積木跨列移動被拒絕且原排列不變', () {
      final arrangement = _generate(_itllRain());
      final beforeRows = arrangement.rows;
      final beforeUndoDepth = arrangement.undoDepth;

      expect(
        () => arrangement.moveBlock(
          fromRowIndex: 0,
          fromPosition: 0,
          toRowIndex: 1,
          toPosition: 0,
          updatedAt: _t1,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => '$error',
            'message',
            contains('跨列'),
          ),
        ),
      );
      expect(arrangement.rows, same(beforeRows));
      expect(arrangement.undoDepth, beforeUndoDepth);
    });

    test('AT-15-03 同列相鄰積木成組，undo 回復後可重新成組', () {
      final beforeGroup = _customRowArrangement();
      final firstGroup = beforeGroup.groupBlocks(
        0,
        1,
        3,
        updatedAt: _t6,
      );

      expect(_blockTexts(firstGroup.rows[0]), [
        ['itll'],
        ['rain', 'itll', 'rain'],
      ]);
      expect(firstGroup.rows[0].blocks[1].isGrouped, isTrue);

      final undone = firstGroup.undoArrangement(updatedAt: _t7);
      expect(_rowTexts(undone.rows[0]), ['itll', 'rain', 'itll', 'rain']);
      expect(undone.undoDepth, beforeGroup.undoDepth);

      final corrected = undone.groupBlocks(0, 2, 3, updatedAt: _t8);
      expect(_blockTexts(corrected.rows[0]), [
        ['itll'],
        ['rain'],
        ['itll', 'rain'],
      ]);
    });

    test('AT-15-03 組塊內可重新排序', () {
      final grouped =
          _customRowArrangement().groupBlocks(0, 2, 3, updatedAt: _t6);
      final reordered = grouped.reorderGroupedSyllable(
        rowIndex: 0,
        blockPosition: 2,
        fromPosition: 1,
        toPosition: 0,
        updatedAt: _t7,
      );

      expect(reordered.rows[0].blocks[2].syllables.map((item) => item.text),
          ['rain', 'itll']);
    });

    test('AT-15-17 可刪除單一積木或整個組塊，undo 可復原', () {
      final grouped = _customRowArrangement().groupBlocks(
        0,
        1,
        2,
        updatedAt: _t6,
      );

      final withoutSingle = grouped.removeBlock(
        0,
        0,
        updatedAt: _t7,
      );
      expect(_blockTexts(withoutSingle.rows.first), [
        ['rain', 'itll'],
        ['rain'],
      ]);

      final withoutGroup = grouped.removeBlock(
        0,
        1,
        updatedAt: _t7,
      );
      expect(_blockTexts(withoutGroup.rows.first), [
        ['itll'],
        ['rain'],
      ]);
      expect(
        _blockTexts(withoutGroup.undoArrangement(updatedAt: _t8).rows.first),
        _blockTexts(grouped.rows.first),
      );
    });

    test('AT-15-18 刪除組內成員，剩一項時自動轉為單一積木', () {
      final three = _customRowArrangement().groupBlocks(
        0,
        1,
        3,
        updatedAt: _t6,
      );
      final two = three.removeGroupedSyllable(
        rowIndex: 0,
        blockPosition: 1,
        syllablePosition: 1,
        updatedAt: _t7,
      );
      expect(two.rows.first.blocks[1].syllables.map((item) => item.text), [
        'rain',
        'rain',
      ]);
      expect(two.rows.first.blocks[1].isGrouped, isTrue);

      final one = two.removeGroupedSyllable(
        rowIndex: 0,
        blockPosition: 1,
        syllablePosition: 0,
        updatedAt: _t8,
      );
      expect(one.rows.first.blocks[1].syllables.single.text, 'rain');
      expect(one.rows.first.blocks[1].isGrouped, isFalse);
    });

    test('AT-15-18 組內成員可抽出至指定列間位置', () {
      final grouped = _customRowArrangement().groupBlocks(
        0,
        1,
        3,
        updatedAt: _t6,
      );
      final extracted = grouped.extractGroupedSyllable(
        fromRowIndex: 0,
        fromBlockPosition: 1,
        syllablePosition: 1,
        toRowIndex: 0,
        toPosition: 0,
        updatedAt: _t7,
      );

      expect(_blockTexts(extracted.rows.first), [
        ['itll'],
        ['itll'],
        ['rain', 'rain'],
      ]);
      expect(extracted.rows.first.blocks.first.isGrouped, isFalse);
    });

    test('AT-15-18 單一積木可插入組內指定序位', () {
      final grouped = _customRowArrangement().groupBlocks(
        0,
        1,
        2,
        updatedAt: _t6,
      );
      final inserted = grouped.moveSingleBlockIntoGroup(
        fromRowIndex: 0,
        fromBlockPosition: 0,
        toRowIndex: 0,
        toBlockPosition: 1,
        toSyllablePosition: 1,
        updatedAt: _t7,
      );

      expect(_blockTexts(inserted.rows.first), [
        ['rain', 'itll', 'itll'],
        ['rain'],
      ]);
      expect(inserted.rows.first.blocks.first.isGrouped, isTrue);
    });

    test('AT-15-18 組員抽出與單一併組都拒絕跨列', () {
      final grouped = _generate(_itllRain()).groupBlocks(
        1,
        0,
        1,
        updatedAt: _t1,
      );

      expect(
        () => grouped.extractGroupedSyllable(
          fromRowIndex: 1,
          fromBlockPosition: 0,
          syllablePosition: 0,
          toRowIndex: 0,
          toPosition: 0,
          updatedAt: _t2,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => '$error',
            'message',
            contains('跨列'),
          ),
        ),
      );
      expect(
        () => grouped.moveSingleBlockIntoGroup(
          fromRowIndex: 0,
          fromBlockPosition: 0,
          toRowIndex: 1,
          toBlockPosition: 0,
          toSyllablePosition: 1,
          updatedAt: _t2,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => '$error',
            'message',
            contains('跨列'),
          ),
        ),
      );
      expect(grouped.undoDepth, 1);
      expect(_blockTexts(grouped.rows[1]), [
        ['itll', 'rain'],
      ]);
    });

    test('AT-15-11 新積木、成組與拆組都重置為 1 次／1 倍', () {
      var arrangement = _customRowArrangement()
          .setBlockConfig(
            0,
            0,
            repeatN: 7,
            silenceFactor: 12.5,
            updatedAt: _t6,
          )
          .setBlockConfig(
            0,
            1,
            repeatN: 2,
            silenceFactor: 1.5,
            updatedAt: _t7,
          );

      expect(
        arrangement.rows[0].blocks.skip(2).map(_configOf),
        everyElement((1, 1.0)),
        reason: '新積木預設值必須是 1／1',
      );

      arrangement = arrangement.groupBlocks(0, 0, 1, updatedAt: _t8);
      expect(_configOf(arrangement.rows[0].blocks.first), (1, 1.0),
          reason: '不同設定成組後不得偏向任一原積木');

      arrangement = arrangement.ungroup(0, 0, updatedAt: _t9);
      expect(
        arrangement.rows[0].blocks.take(2).map(_configOf),
        everyElement((1, 1.0)),
        reason: '拆組後每塊回到初始預設值',
      );
    });

    test('AT-15-11 resetBlockConfig 原子回到 1 次／1 倍', () {
      final reset = _generate(_itllRain())
          .setBlockConfig(
            0,
            0,
            repeatN: 8,
            silenceFactor: 19.5,
            updatedAt: _t8,
          )
          .resetBlockConfig(0, 0, updatedAt: _t9);

      expect(_configOf(reset.rows[0].blocks[0]), (1, 1.0));
    });

    test('AT-15-04 預設與自訂 repeatN／silenceFactor 產生正確靜音長度', () {
      var arrangement =
          _customRowArrangement().groupBlocks(0, 2, 3, updatedAt: _t6);
      arrangement = arrangement
          .setBlockConfig(0, 1, repeatN: 4, updatedAt: _t7)
          .setBlockConfig(0, 2, repeatN: 4, silenceFactor: 3, updatedAt: _t8);

      final itll = arrangement.rows[0].blocks[0];
      final rain = arrangement.rows[0].blocks[1];
      final group = arrangement.rows[0].blocks[2];
      expect((itll.repeatN, itll.sourceDurationMs, itll.silenceDurationMs),
          (1, 300, 300));
      expect((rain.repeatN, rain.sourceDurationMs, rain.silenceDurationMs),
          (4, 350, 350));
      expect((group.repeatN, group.sourceDurationMs, group.silenceDurationMs),
          (4, 650, 1950));
    });

    test('AT-15-13 set/reset row config 並以原始積木長度計算靜音', () {
      final configured = _customRowArrangement().setRowConfig(
        0,
        repeatN: 5,
        silenceFactor: 2.5,
        updatedAt: _t8,
      );

      final row = configured.rows.first;
      expect(_rowConfigOf(row), (5, 2.5));
      expect(row.sourceDurationMs, 1300, reason: '四個擺放積木各算一次');
      expect(row.silenceDurationMs, 3250);

      final reset = configured.resetRowConfig(0, updatedAt: _t9);
      expect(_rowConfigOf(reset.rows.first), (3, 1.0));
    });

    test('#47 跨 Lesson 音節注入以 ArgumentError 拒絕且原排列不變', () {
      final syllable = _itllRain().first;
      final arrangement = _generate(_itllRain()).insertRow(0, updatedAt: _t1);

      expect(
        () => arrangement.placeBlock(
          0,
          0,
          syllable,
          sourceLessonId: 'lesson-other',
          updatedAt: _t2,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.message,
            'message',
            allOf(contains('lesson-other'), contains(_lessonId)),
          ),
        ),
      );
      expect(arrangement.rows[0].blocks, isEmpty);
    });
  });

  group('AT-15-06 設定邊界兩側', () {
    test('repeatN=0 拒絕', () {
      expect(() => _setConfig(repeatN: 0), _blockConfigError);
    });

    test('repeatN=1 接受', () {
      expect(_setConfig(repeatN: 1).rows[0].blocks[0].repeatN, 1);
    });

    test('repeatN=10 接受', () {
      expect(_setConfig(repeatN: 10).rows[0].blocks[0].repeatN, 10);
    });

    test('repeatN=11 拒絕', () {
      expect(() => _setConfig(repeatN: 11), _blockConfigError);
    });

    test('silenceFactor=-0.5 拒絕', () {
      expect(() => _setConfig(silenceFactor: -0.5), _blockConfigError);
    });

    test('silenceFactor=0 接受', () {
      expect(_setConfig(silenceFactor: 0).rows[0].blocks[0].silenceFactor, 0);
    });

    test('silenceFactor=0.25 拒絕（step 0.5 邊界外）', () {
      expect(() => _setConfig(silenceFactor: 0.25), _blockConfigError);
    });

    test('silenceFactor=0.5 接受（step 0.5 邊界內）', () {
      expect(
        _setConfig(silenceFactor: 0.5).rows[0].blocks[0].silenceFactor,
        0.5,
      );
    });

    test('silenceFactor=20 接受', () {
      expect(
        _setConfig(silenceFactor: 20).rows[0].blocks[0].silenceFactor,
        20,
      );
    });

    test('silenceFactor=20.5 拒絕', () {
      expect(() => _setConfig(silenceFactor: 20.5), _blockConfigError);
    });

    test('整列設定使用相同邊界驗證', () {
      final arrangement = _generate(_itllRain());
      expect(
        () => arrangement.setRowConfig(
          0,
          repeatN: 11,
          silenceFactor: 3,
          updatedAt: _t1,
        ),
        _blockConfigError,
      );
      expect(
        () => arrangement.setRowConfig(
          0,
          repeatN: 3,
          silenceFactor: 3.25,
          updatedAt: _t1,
        ),
        _blockConfigError,
      );
    });
  });

  group('AT-15-08 音節數變更後的過期契約', () {
    test('markStale 只置旗標，不改 rows 或排列 undo', () {
      final arrangement = _customRowArrangement();
      final rowTexts = _rowTexts(arrangement.rows.first);

      final stale = arrangement.markStale(updatedAt: _t7);

      expect(stale.staleFlag, isTrue);
      expect(_rowTexts(stale.rows.first), rowTexts);
      expect(stale.rows.length, arrangement.rows.length);
      expect(stale.undoDepth, arrangement.undoDepth);
      expect(stale.updatedAt, _t7);
    });

    test('明示保留只清 staleFlag，不改手動排列', () {
      final stale = _customRowArrangement().markStale(updatedAt: _t7);

      final kept = stale.keepCurrentArrangement(updatedAt: _t8);

      expect(kept.staleFlag, isFalse);
      expect(_rowTexts(kept.rows.first), _rowTexts(stale.rows.first));
      expect(kept.undoDepth, stale.undoDepth);
    });
  });
}

PracticeArrangement _generate(List<Syllable> syllables) =>
    PracticeEngine().generateArrangement(
      syllables,
      lessonId: _lessonId,
      updatedAt: _t0,
    );

PracticeArrangement _customRowArrangement() {
  final syllables = _itllRain();
  return _generate(syllables)
      .insertRow(0, updatedAt: _t1)
      .placeBlock(0, 0, syllables[0], sourceLessonId: _lessonId, updatedAt: _t2)
      .placeBlock(0, 1, syllables[1], sourceLessonId: _lessonId, updatedAt: _t3)
      .placeBlock(0, 2, syllables[0], sourceLessonId: _lessonId, updatedAt: _t4)
      .placeBlock(0, 3, syllables[1],
          sourceLessonId: _lessonId, updatedAt: _t5);
}

PracticeArrangement _setConfig({int? repeatN, double? silenceFactor}) {
  final arrangement = _generate(_itllRain());
  return arrangement.setBlockConfig(
    0,
    0,
    repeatN: repeatN,
    silenceFactor: silenceFactor,
    updatedAt: _t1,
  );
}

List<String> _rowTexts(PracticeRow row) => row.blocks
    .expand((block) => block.syllables)
    .map((syllable) => syllable.text)
    .toList(growable: false);

List<List<String>> _blockTexts(PracticeRow row) => row.blocks
    .map((block) => block.syllables
        .map((syllable) => syllable.text)
        .toList(growable: false))
    .toList(growable: false);

(int, double) _configOf(PracticeBlock block) =>
    (block.repeatN, block.silenceFactor);

(int, double) _rowConfigOf(PracticeRow row) => (row.repeatN, row.silenceFactor);

List<Syllable> _itllRain() => [
      _syllable('itll', 0, 300, 0),
      _syllable('rain', 300, 650, 1),
    ];

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
      _syllable('tion', 2200, 2650, 3),
      _syllable('skills', 2650, 3150, 4),
    ];

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

final Matcher _blockConfigError = throwsA(
  isA<DomainException>().having(
    (error) => error.code,
    'code',
    ErrorCodes.blockConfigOutOfRange,
  ),
);

const _lessonId = 'lesson-a';
final _t0 = DateTime.utc(2026, 7, 13, 10);
final _t1 = DateTime.utc(2026, 7, 13, 10, 1);
final _t2 = DateTime.utc(2026, 7, 13, 10, 2);
final _t3 = DateTime.utc(2026, 7, 13, 10, 3);
final _t4 = DateTime.utc(2026, 7, 13, 10, 4);
final _t5 = DateTime.utc(2026, 7, 13, 10, 5);
final _t6 = DateTime.utc(2026, 7, 13, 10, 6);
final _t7 = DateTime.utc(2026, 7, 13, 10, 7);
final _t8 = DateTime.utc(2026, 7, 13, 10, 8);
final _t9 = DateTime.utc(2026, 7, 13, 10, 9);
