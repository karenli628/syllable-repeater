// AI-Generate
import '../errors.dart';
import 'syllable.dart';
import 'time_range.dart';

/// 自由排列中的原音積木（backend-design.md §3.1.1；REQ-15/M1）。
///
/// 積木只保存本課音節與其原音範圍；型別中刻意沒有音訊、路徑或來源課件欄位。
class PracticeBlock {
  /// 自訂積木初始重複次數（REQ-15 AT-15-11；M3）。
  static const defaultRepeatN = 1;

  /// 自訂積木初始靜音倍數（REQ-15 AT-15-11；M3）。
  static const defaultSilenceFactor = 1.0;
  static const minRepeatN = 1;
  static const maxRepeatN = 10;
  static const minSilenceFactor = 0.0;
  static const maxSilenceFactor = 20.0;

  /// 自訂積木靜音倍數刻度（REQ-15 AT-15-06；M3）。
  static const silenceFactorStep = 0.5;

  final List<Syllable> syllables;
  final List<TimeRange> sourceRanges;
  final int repeatN;
  final double silenceFactor;
  final bool isGrouped;

  PracticeBlock({
    required List<Syllable> syllables,
    this.repeatN = defaultRepeatN,
    this.silenceFactor = defaultSilenceFactor,
    this.isGrouped = false,
  })  : syllables = List.unmodifiable(syllables),
        sourceRanges = List.unmodifiable(
          syllables.map((syllable) => syllable.range),
        ) {
    if (syllables.isEmpty) {
      throw ArgumentError('PracticeBlock.syllables 不可為空');
    }
    _validateConfig(repeatN, silenceFactor);
    if (isGrouped && syllables.length < 2) {
      throw ArgumentError(
        '成組 PracticeBlock 至少需要 2 個音節，got ${syllables.length}',
      );
    }
  }

  /// 原音範圍總長（backend-design.md 介面 28）。
  int get sourceDurationMs => sourceRanges.fold(
        0,
        (total, range) => total + range.durationMs,
      );

  /// 積木後數位零靜音長度（REQ-15／M3 自訂軌）。
  int get silenceDurationMs => (sourceDurationMs * silenceFactor).round();

  PracticeBlock copyWith({
    List<Syllable>? syllables,
    int? repeatN,
    double? silenceFactor,
    bool? isGrouped,
  }) =>
      PracticeBlock(
        syllables: syllables ?? this.syllables,
        repeatN: repeatN ?? this.repeatN,
        silenceFactor: silenceFactor ?? this.silenceFactor,
        isGrouped: isGrouped ?? this.isGrouped,
      );

  /// `.abopack` schemaVersion 2 的排列欄位序列化。
  Map<String, dynamic> toJson() => {
        'syllables': syllables.map(_syllableToJson).toList(growable: false),
        'repeatN': repeatN,
        'silenceFactor': silenceFactor,
        'isGrouped': isGrouped,
        'sourceRanges': sourceRanges
            .map((range) => {
                  'startMs': range.startMs,
                  'endMs': range.endMs,
                })
            .toList(growable: false),
      };

  /// 讀取已驗證的 `.abopack` schemaVersion 2 積木。
  factory PracticeBlock.fromJson(Map<String, dynamic> json) => PracticeBlock(
        syllables: (json['syllables'] as List<dynamic>)
            .map((item) => _syllableFromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        repeatN: json['repeatN'] as int,
        silenceFactor: (json['silenceFactor'] as num).toDouble(),
        isGrouped: json['isGrouped'] as bool,
      );

  static void _validateConfig(int repeatN, double silenceFactor) {
    if (repeatN < minRepeatN || repeatN > maxRepeatN) {
      throw DomainException(
        ErrorCodes.blockConfigOutOfRange,
        'PracticeBlock.repeatN 須為 $minRepeatN–$maxRepeatN，got $repeatN',
      );
    }
    if (!silenceFactor.isFinite ||
        silenceFactor < minSilenceFactor ||
        silenceFactor > maxSilenceFactor ||
        !_isSilenceFactorStepAligned(silenceFactor)) {
      throw DomainException(
        ErrorCodes.blockConfigOutOfRange,
        'PracticeBlock.silenceFactor 須為 '
        '$minSilenceFactor–$maxSilenceFactor 且每次 '
        '$silenceFactorStep，got $silenceFactor',
      );
    }
  }

  static bool _isSilenceFactorStepAligned(double value) {
    final steps = value / silenceFactorStep;
    return (steps - steps.round()).abs() < 0.000000001;
  }
}

/// 自由排列中的一列（backend-design.md §3.1.1；REQ-15）。
class PracticeRow {
  /// 整列外層預設重複次數（REQ-15 AT-15-13；M3）。
  static const defaultRepeatN = 3;

  /// 整列外層預設靜音倍數（REQ-15 AT-15-13；M3）。
  static const defaultSilenceFactor = 1.0;

  final int index;
  final List<PracticeBlock> blocks;
  final int repeatN;
  final double silenceFactor;

  PracticeRow({
    required this.index,
    required List<PracticeBlock> blocks,
    this.repeatN = defaultRepeatN,
    this.silenceFactor = defaultSilenceFactor,
  }) : blocks = List.unmodifiable(blocks) {
    if (index < 1) {
      throw ArgumentError('PracticeRow.index 須從 1 開始，got $index');
    }
    PracticeBlock._validateConfig(repeatN, silenceFactor);
  }

  /// 列內每個擺放積木的原始音訊長度各算一次（AT-15-13）。
  int get sourceDurationMs => blocks.fold(
        0,
        (total, block) => total + block.sourceDurationMs,
      );

  /// 整列兩次重複之間的數位零長度；最後一次後不使用。
  int get silenceDurationMs => (sourceDurationMs * silenceFactor).round();

  PracticeRow copyWith({
    int? index,
    List<PracticeBlock>? blocks,
    int? repeatN,
    double? silenceFactor,
  }) =>
      PracticeRow(
        index: index ?? this.index,
        blocks: blocks ?? this.blocks,
        repeatN: repeatN ?? this.repeatN,
        silenceFactor: silenceFactor ?? this.silenceFactor,
      );

  Map<String, dynamic> toJson() => {
        'index': index,
        'blocks': blocks.map((block) => block.toJson()).toList(growable: false),
        'repeatN': repeatN,
        'silenceFactor': silenceFactor,
      };

  factory PracticeRow.fromJson(Map<String, dynamic> json) => PracticeRow(
        index: json['index'] as int,
        blocks: (json['blocks'] as List<dynamic>)
            .map((item) => PracticeBlock.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        repeatN: (json['repeatN'] as int?) ?? defaultRepeatN,
        silenceFactor:
            (json['silenceFactor'] as num?)?.toDouble() ?? defaultSilenceFactor,
      );
}

/// 單一 Lesson 的自由排列聚合根（backend-design.md §3.1.1、介面 28）。
///
/// 所有操作回傳新快照並保留獨立 undo 歷史；不會修改原物件。
class PracticeArrangement {
  final String lessonId;
  final List<PracticeRow> rows;
  final bool staleFlag;
  final DateTime updatedAt;
  final List<List<PracticeRow>> _undoStack;

  PracticeArrangement({
    required this.lessonId,
    required List<PracticeRow> rows,
    this.staleFlag = false,
    required DateTime updatedAt,
  })  : rows = List.unmodifiable(_renumber(rows)),
        updatedAt = updatedAt.toUtc(),
        _undoStack = const [] {
    _validateLessonId(lessonId);
  }

  PracticeArrangement._({
    required this.lessonId,
    required List<PracticeRow> rows,
    required this.staleFlag,
    required DateTime updatedAt,
    required List<List<PracticeRow>> undoStack,
  })  : rows = List.unmodifiable(_renumber(rows)),
        updatedAt = updatedAt.toUtc(),
        _undoStack = List.unmodifiable(
          undoStack.map((snapshot) => List<PracticeRow>.unmodifiable(snapshot)),
        ) {
    _validateLessonId(lessonId);
  }

  /// 可撤銷的排列操作數（REQ-15；與校正 undo 分離）。
  int get undoDepth => _undoStack.length;

  /// `.abopack` schemaVersion 2 的自訂排列序列化；undo 歷史不持久化。
  Map<String, dynamic> toJson() => {
        'lessonId': lessonId,
        'rows': rows.map((row) => row.toJson()).toList(growable: false),
        'staleFlag': staleFlag,
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// 讀取已驗證的 `.abopack` schemaVersion 2 自訂排列。
  factory PracticeArrangement.fromJson(Map<String, dynamic> json) =>
      PracticeArrangement(
        lessonId: json['lessonId'] as String,
        rows: (json['rows'] as List<dynamic>)
            .map((item) => PracticeRow.fromJson(item as Map<String, dynamic>))
            .toList(growable: false),
        staleFlag: json['staleFlag'] as bool,
        updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      );

  /// 音節總數變更後只標記過期，不改列內容或排列 undo（AT-15-08）。
  PracticeArrangement markStale({required DateTime updatedAt}) =>
      _withStaleFlag(true, updatedAt);

  /// 使用者明示保留目前手動排列時只清除過期旗標（AT-15-08）。
  PracticeArrangement keepCurrentArrangement({required DateTime updatedAt}) =>
      _withStaleFlag(false, updatedAt);

  PracticeArrangement insertRow(
    int atIndex, {
    required DateTime updatedAt,
  }) {
    _validateInsertIndex(atIndex, rows.length, 'atIndex');
    final nextRows = rows.toList()
      ..insert(
        atIndex,
        PracticeRow(index: atIndex + 1, blocks: const []),
      );
    return _changed(nextRows, updatedAt);
  }

  PracticeArrangement removeRow(
    int index, {
    required DateTime updatedAt,
  }) {
    _validateExistingIndex(index, rows.length, 'row index');
    final nextRows = rows.toList()..removeAt(index);
    return _changed(nextRows, updatedAt);
  }

  /// 放置入口先驗證來源 Lesson，且不把來源資訊寫進 block（#47）。
  PracticeArrangement placeBlock(
    int rowIndex,
    int position,
    Syllable syllable, {
    required String sourceLessonId,
    required DateTime updatedAt,
  }) {
    if (sourceLessonId != lessonId) {
      throw ArgumentError(
        '不可把來源 Lesson $sourceLessonId 的音節放入 Lesson $lessonId 的排列',
      );
    }
    _validateExistingIndex(rowIndex, rows.length, 'rowIndex');
    final blocks = rows[rowIndex].blocks.toList();
    _validateInsertIndex(position, blocks.length, 'position');
    blocks.insert(position, PracticeBlock(syllables: [syllable]));
    return _replaceRowBlocks(rowIndex, blocks, updatedAt);
  }

  PracticeArrangement moveBlock({
    required int fromRowIndex,
    required int fromPosition,
    required int toRowIndex,
    required int toPosition,
    required DateTime updatedAt,
  }) {
    _validateExistingIndex(fromRowIndex, rows.length, 'fromRowIndex');
    _validateExistingIndex(toRowIndex, rows.length, 'toRowIndex');
    if (fromRowIndex != toRowIndex) {
      throw ArgumentError(
        '跨列移動不支援，fromRowIndex=$fromRowIndex, toRowIndex=$toRowIndex',
      );
    }
    final nextRows = rows.toList();
    final fromBlocks = nextRows[fromRowIndex].blocks.toList();
    _validateExistingIndex(fromPosition, fromBlocks.length, 'fromPosition');
    final moving = fromBlocks.removeAt(fromPosition);
    _validateInsertIndex(toPosition, fromBlocks.length, 'toPosition');
    fromBlocks.insert(toPosition, moving);
    nextRows[fromRowIndex] = nextRows[fromRowIndex].copyWith(
      blocks: fromBlocks,
    );
    return _changed(nextRows, updatedAt);
  }

  /// 刪除單一積木或整個組塊（backend-design.md 介面 28；AT-15-17）。
  PracticeArrangement removeBlock(
    int rowIndex,
    int blockPosition, {
    required DateTime updatedAt,
  }) {
    _validateExistingIndex(rowIndex, rows.length, 'rowIndex');
    final blocks = rows[rowIndex].blocks.toList();
    _validateExistingIndex(blockPosition, blocks.length, 'blockPosition');
    blocks.removeAt(blockPosition);
    return _replaceRowBlocks(rowIndex, blocks, updatedAt);
  }

  PracticeArrangement groupBlocks(
    int rowIndex,
    int fromPos,
    int toPos, {
    required DateTime updatedAt,
  }) {
    _validateExistingIndex(rowIndex, rows.length, 'rowIndex');
    final blocks = rows[rowIndex].blocks.toList();
    _validateExistingIndex(fromPos, blocks.length, 'fromPos');
    _validateExistingIndex(toPos, blocks.length, 'toPos');
    if (fromPos >= toPos) {
      throw ArgumentError(
        'groupBlocks 須選至少 2 個相鄰積木，got $fromPos..$toPos',
      );
    }
    final syllables = blocks
        .sublist(fromPos, toPos + 1)
        .expand((block) => block.syllables)
        .toList(growable: false);
    blocks.replaceRange(
      fromPos,
      toPos + 1,
      [PracticeBlock(syllables: syllables, isGrouped: true)],
    );
    return _replaceRowBlocks(rowIndex, blocks, updatedAt);
  }

  PracticeArrangement reorderGroupedSyllable({
    required int rowIndex,
    required int blockPosition,
    required int fromPosition,
    required int toPosition,
    required DateTime updatedAt,
  }) {
    _validateExistingIndex(rowIndex, rows.length, 'rowIndex');
    final blocks = rows[rowIndex].blocks.toList();
    _validateExistingIndex(blockPosition, blocks.length, 'blockPosition');
    final block = blocks[blockPosition];
    if (!block.isGrouped) {
      throw ArgumentError('blockPosition $blockPosition 不是成組積木');
    }
    final syllables = block.syllables.toList();
    _validateExistingIndex(fromPosition, syllables.length, 'fromPosition');
    final moving = syllables.removeAt(fromPosition);
    _validateInsertIndex(toPosition, syllables.length, 'toPosition');
    syllables.insert(toPosition, moving);
    blocks[blockPosition] = block.copyWith(syllables: syllables);
    return _replaceRowBlocks(rowIndex, blocks, updatedAt);
  }

  /// 刪除組塊內單一音節；剩一項時自動降級（AT-15-18）。
  PracticeArrangement removeGroupedSyllable({
    required int rowIndex,
    required int blockPosition,
    required int syllablePosition,
    required DateTime updatedAt,
  }) {
    _validateExistingIndex(rowIndex, rows.length, 'rowIndex');
    final blocks = rows[rowIndex].blocks.toList();
    _validateExistingIndex(blockPosition, blocks.length, 'blockPosition');
    final block = blocks[blockPosition];
    if (!block.isGrouped) {
      throw ArgumentError('blockPosition $blockPosition 不是成組積木');
    }
    final remaining = block.syllables.toList();
    _validateExistingIndex(
      syllablePosition,
      remaining.length,
      'syllablePosition',
    );
    remaining.removeAt(syllablePosition);
    blocks[blockPosition] = block.copyWith(
      syllables: remaining,
      isGrouped: remaining.length > 1,
    );
    return _replaceRowBlocks(rowIndex, blocks, updatedAt);
  }

  /// 把組內音節抽出為指定列位置的單一積木（AT-15-18）。
  PracticeArrangement extractGroupedSyllable({
    required int fromRowIndex,
    required int fromBlockPosition,
    required int syllablePosition,
    required int toRowIndex,
    required int toPosition,
    required DateTime updatedAt,
  }) {
    _validateExistingIndex(fromRowIndex, rows.length, 'fromRowIndex');
    _validateExistingIndex(toRowIndex, rows.length, 'toRowIndex');
    if (fromRowIndex != toRowIndex) {
      throw ArgumentError(
        '跨列抽出不支援，fromRowIndex=$fromRowIndex, toRowIndex=$toRowIndex',
      );
    }
    final nextRows = rows.toList();
    final fromBlocks = nextRows[fromRowIndex].blocks.toList();
    _validateExistingIndex(
      fromBlockPosition,
      fromBlocks.length,
      'fromBlockPosition',
    );
    final source = fromBlocks[fromBlockPosition];
    if (!source.isGrouped) {
      throw ArgumentError('fromBlockPosition $fromBlockPosition 不是成組積木');
    }
    final remaining = source.syllables.toList();
    _validateExistingIndex(
      syllablePosition,
      remaining.length,
      'syllablePosition',
    );
    final extracted = remaining.removeAt(syllablePosition);
    fromBlocks[fromBlockPosition] = source.copyWith(
      syllables: remaining,
      isGrouped: remaining.length > 1,
    );

    _validateInsertIndex(toPosition, fromBlocks.length, 'toPosition');
    fromBlocks.insert(toPosition, PracticeBlock(syllables: [extracted]));
    nextRows[fromRowIndex] = nextRows[fromRowIndex].copyWith(
      blocks: fromBlocks,
    );
    return _changed(nextRows, updatedAt);
  }

  /// 把既有單一積木移入另一組塊的指定成員位置（AT-15-18）。
  PracticeArrangement moveSingleBlockIntoGroup({
    required int fromRowIndex,
    required int fromBlockPosition,
    required int toRowIndex,
    required int toBlockPosition,
    required int toSyllablePosition,
    required DateTime updatedAt,
  }) {
    _validateExistingIndex(fromRowIndex, rows.length, 'fromRowIndex');
    _validateExistingIndex(toRowIndex, rows.length, 'toRowIndex');
    if (fromRowIndex != toRowIndex) {
      throw ArgumentError(
        '跨列組合不支援，fromRowIndex=$fromRowIndex, toRowIndex=$toRowIndex',
      );
    }
    if (fromBlockPosition == toBlockPosition) {
      throw ArgumentError('來源積木不可同時是目標組塊');
    }
    final nextRows = rows.toList();
    final fromBlocks = nextRows[fromRowIndex].blocks.toList();
    _validateExistingIndex(
      fromBlockPosition,
      fromBlocks.length,
      'fromBlockPosition',
    );
    final source = fromBlocks[fromBlockPosition];
    if (source.isGrouped || source.syllables.length != 1) {
      throw ArgumentError('只有單一積木可插入組塊');
    }
    final moving = source.syllables.single;

    fromBlocks.removeAt(fromBlockPosition);
    final adjustedTarget = fromBlockPosition < toBlockPosition
        ? toBlockPosition - 1
        : toBlockPosition;
    _validateExistingIndex(
        adjustedTarget, fromBlocks.length, 'toBlockPosition');
    final target = fromBlocks[adjustedTarget];
    if (!target.isGrouped) {
      throw ArgumentError('toBlockPosition $toBlockPosition 不是成組積木');
    }
    final syllables = target.syllables.toList();
    _validateInsertIndex(
      toSyllablePosition,
      syllables.length,
      'toSyllablePosition',
    );
    syllables.insert(toSyllablePosition, moving);
    fromBlocks[adjustedTarget] = target.copyWith(syllables: syllables);
    nextRows[fromRowIndex] = nextRows[fromRowIndex].copyWith(
      blocks: fromBlocks,
    );
    return _changed(nextRows, updatedAt);
  }

  PracticeArrangement ungroup(
    int rowIndex,
    int blockPosition, {
    required DateTime updatedAt,
  }) {
    _validateExistingIndex(rowIndex, rows.length, 'rowIndex');
    final blocks = rows[rowIndex].blocks.toList();
    _validateExistingIndex(blockPosition, blocks.length, 'blockPosition');
    final block = blocks[blockPosition];
    if (!block.isGrouped) {
      throw ArgumentError('blockPosition $blockPosition 不是成組積木');
    }
    blocks.replaceRange(
      blockPosition,
      blockPosition + 1,
      block.syllables.map((syllable) => PracticeBlock(syllables: [syllable])),
    );
    return _replaceRowBlocks(rowIndex, blocks, updatedAt);
  }

  PracticeArrangement setBlockConfig(
    int rowIndex,
    int blockPosition, {
    int? repeatN,
    double? silenceFactor,
    required DateTime updatedAt,
  }) {
    _validateExistingIndex(rowIndex, rows.length, 'rowIndex');
    final blocks = rows[rowIndex].blocks.toList();
    _validateExistingIndex(blockPosition, blocks.length, 'blockPosition');
    blocks[blockPosition] = blocks[blockPosition].copyWith(
      repeatN: repeatN,
      silenceFactor: silenceFactor,
    );
    return _replaceRowBlocks(rowIndex, blocks, updatedAt);
  }

  /// 原子重置指定積木為 1 次／3 倍（backend-design.md 介面 28；AT-15-11）。
  PracticeArrangement resetBlockConfig(
    int rowIndex,
    int blockPosition, {
    required DateTime updatedAt,
  }) =>
      setBlockConfig(
        rowIndex,
        blockPosition,
        repeatN: PracticeBlock.defaultRepeatN,
        silenceFactor: PracticeBlock.defaultSilenceFactor,
        updatedAt: updatedAt,
      );

  /// 設定指定列的外層重複與靜音（backend-design.md 介面 28；AT-15-13）。
  PracticeArrangement setRowConfig(
    int rowIndex, {
    int? repeatN,
    double? silenceFactor,
    required DateTime updatedAt,
  }) {
    _validateExistingIndex(rowIndex, rows.length, 'rowIndex');
    final nextRows = rows.toList();
    nextRows[rowIndex] = nextRows[rowIndex].copyWith(
      repeatN: repeatN,
      silenceFactor: silenceFactor,
    );
    return _changed(nextRows, updatedAt);
  }

  /// 原子重置指定列為 3 次／3 倍（REQ-15 AT-15-13）。
  PracticeArrangement resetRowConfig(
    int rowIndex, {
    required DateTime updatedAt,
  }) =>
      setRowConfig(
        rowIndex,
        repeatN: PracticeRow.defaultRepeatN,
        silenceFactor: PracticeRow.defaultSilenceFactor,
        updatedAt: updatedAt,
      );

  PracticeArrangement undoArrangement({required DateTime updatedAt}) {
    if (_undoStack.isEmpty) {
      throw StateError('PracticeArrangement 沒有可撤銷的操作');
    }
    return PracticeArrangement._(
      lessonId: lessonId,
      rows: _undoStack.last,
      staleFlag: staleFlag,
      updatedAt: updatedAt,
      undoStack: _undoStack.sublist(0, _undoStack.length - 1),
    );
  }

  PracticeArrangement _replaceRowBlocks(
    int rowIndex,
    List<PracticeBlock> blocks,
    DateTime updatedAt,
  ) {
    final nextRows = rows.toList();
    nextRows[rowIndex] = nextRows[rowIndex].copyWith(blocks: blocks);
    return _changed(nextRows, updatedAt);
  }

  PracticeArrangement _changed(List<PracticeRow> nextRows, DateTime changedAt) {
    return PracticeArrangement._(
      lessonId: lessonId,
      rows: nextRows,
      staleFlag: staleFlag,
      updatedAt: changedAt,
      undoStack: [..._undoStack, rows],
    );
  }

  PracticeArrangement _withStaleFlag(bool value, DateTime changedAt) {
    return PracticeArrangement._(
      lessonId: lessonId,
      rows: rows,
      staleFlag: value,
      updatedAt: changedAt,
      undoStack: _undoStack,
    );
  }

  static List<PracticeRow> _renumber(List<PracticeRow> rows) => List.generate(
        rows.length,
        (index) => rows[index].copyWith(index: index + 1),
        growable: false,
      );

  static void _validateLessonId(String lessonId) {
    if (lessonId.trim().isEmpty) {
      throw ArgumentError('PracticeArrangement.lessonId 不可空白');
    }
  }

  static void _validateExistingIndex(int index, int length, String name) {
    if (index < 0 || index >= length) {
      throw ArgumentError('$name 超出範圍 0..${length - 1}，got $index');
    }
  }

  static void _validateInsertIndex(int index, int length, String name) {
    if (index < 0 || index > length) {
      throw ArgumentError('$name 超出插入範圍 0..$length，got $index');
    }
  }
}

Map<String, dynamic> _syllableToJson(Syllable syllable) => {
      'text': syllable.text,
      if (syllable.originalText != null) 'originalText': syllable.originalText,
      'startMs': syllable.startMs,
      'endMs': syllable.endMs,
      'wordIndex': syllable.wordIndex,
      'needsReview': syllable.needsReview,
    };

Syllable _syllableFromJson(Map<String, dynamic> json) => Syllable(
      text: json['text'] as String,
      originalText: json['originalText'] as String?,
      startMs: json['startMs'] as int,
      endMs: json['endMs'] as int,
      wordIndex: json['wordIndex'] as int,
      needsReview: json['needsReview'] as bool,
    );
