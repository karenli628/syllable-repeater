// AI-Generate
import '../errors.dart';
import '../model/alignment_result.dart';
import '../model/pcm.dart';
import '../model/syllable.dart';
import '../model/word.dart';
import 'zero_crossing.dart';

/// updateSyllableBoundary 回傳值（backend-design §3.2.1 介面 2）。
class BoundaryUpdateResult {
  final List<Syllable> syllables;
  final int snappedMs;

  const BoundaryUpdateResult({
    required this.syllables,
    required this.snappedMs,
  });
}

/// CMUdict/規則音節查詢與等比例切分（task-split 3.1、3.3）。
class AlignmentEngine {
  final SyllableDictionary dictionary;

  AlignmentEngine({SyllableDictionary? dictionary})
      : dictionary = dictionary ?? SyllableDictionary.withBuiltIns();

  AlignmentResult alignWords(List<Word> words) {
    final syllables = <Syllable>[];

    for (final word in words) {
      final entry = dictionary.lookup(word.text);
      final plan = entry ??
          SyllableEntry(
            normalizedWord: _normalizeWord(word.text),
            syllableCount: _fallbackSyllableCount(word.text),
            parts: _fallbackParts(word.text),
            fromFallback: true,
          );

      syllables.addAll(_splitWord(word, plan));
    }

    return AlignmentResult(
      words: words,
      syllables: syllables,
      source: 'cmudict+vowel-group-fallback',
      confidence: syllables.any((s) => s.needsReview) ? 0.72 : 0.95,
    );
  }

  int syllableCount(String word) =>
      dictionary.lookup(word)?.syllableCount ?? _fallbackSyllableCount(word);

  /// 拖動邊界 [boundaryIndex]（分開 `current[i]` 與 `current[i+1]`）到
  /// [newPositionMs]，做開區間驗證後以 [findNearestZeroCrossingMs] 吸附
  /// 最近零交越（M1 允許的收尾處理，backend-design §3.2.1 介面 2）。
  ///
  /// 規則（requirement §3.2.7 AT-02-02/05）：
  /// - 開區間：`current[i].startMs < newPositionMs < current[i+1].endMs`
  /// - 違反 → `DomainException(ERR_BOUNDARY_INVALID)`，UI 端回彈原值
  ///
  /// 副作用（無）：純函式，回傳新 `List<Syllable>`＋吸附後 `snappedMs`；
  /// 撤銷堆疊由 UI 端持有回傳值歷史（Domain 無狀態，見 backend-design §3.2.1）。
  BoundaryUpdateResult updateSyllableBoundary({
    required List<Syllable> current,
    required int boundaryIndex,
    required int newPositionMs,
    required Pcm pcm,
  }) {
    if (boundaryIndex < 0 || boundaryIndex >= current.length - 1) {
      throw ArgumentError(
        'boundaryIndex 需介於 0..${current.length - 2}（got $boundaryIndex）',
      );
    }

    final prev = current[boundaryIndex];
    final next = current[boundaryIndex + 1];

    if (newPositionMs <= prev.startMs || newPositionMs >= next.endMs) {
      throw DomainException(
        ErrorCodes.boundaryInvalid,
        '邊界不可跨越相鄰音節（前起=${prev.startMs}ms、後止=${next.endMs}ms、目標=${newPositionMs}ms）',
      );
    }

    final rawSnapped =
        findNearestZeroCrossingMs(pcm, targetMs: newPositionMs);
    // 開區間 clamp：吸附後仍須嚴守 prev.startMs < snapped < next.endMs
    final snappedMs = rawSnapped
        .clamp(prev.startMs + 1, next.endMs - 1);

    final updated = <Syllable>[
      for (var i = 0; i < current.length; i++)
        if (i == boundaryIndex)
          Syllable(
            text: current[i].text,
            startMs: current[i].startMs,
            endMs: snappedMs,
            wordIndex: current[i].wordIndex,
            needsReview: false,
          )
        else if (i == boundaryIndex + 1)
          Syllable(
            text: current[i].text,
            startMs: snappedMs,
            endMs: current[i].endMs,
            wordIndex: current[i].wordIndex,
            needsReview: false,
          )
        else
          current[i],
    ];

    return BoundaryUpdateResult(syllables: updated, snappedMs: snappedMs);
  }

  List<Syllable> _splitWord(Word word, SyllableEntry plan) {
    final count = plan.syllableCount;
    if (word.range.durationMs < count) {
      throw ArgumentError('word duration must be >= syllable count');
    }

    final parts = _partsFor(word.text, plan, count);
    final syllables = <Syllable>[];
    for (var i = 0; i < count; i++) {
      final start = word.startMs + (word.range.durationMs * i) ~/ count;
      final end = i == count - 1
          ? word.endMs
          : word.startMs + (word.range.durationMs * (i + 1)) ~/ count;
      syllables.add(Syllable(
        text: parts[i],
        startMs: start,
        endMs: end,
        wordIndex: word.index,
        needsReview: plan.fromFallback || count > 1,
      ));
    }
    return syllables;
  }

  List<String> _partsFor(String word, SyllableEntry plan, int count) {
    if (plan.parts.length == count) {
      return plan.parts;
    }
    return _fallbackParts(word, expectedCount: count);
  }

  static String _normalizeWord(String word) =>
      word.toLowerCase().replaceAll(RegExp('[^a-z]'), '');

  static int _fallbackSyllableCount(String word) {
    final normalized = _normalizeWord(word);
    if (normalized.isEmpty) {
      return 1;
    }

    final matches = RegExp('[aeiouy]+').allMatches(normalized).toList();
    var count = matches.length;
    if (normalized.endsWith('e') && !normalized.endsWith('le') && count > 1) {
      count -= 1;
    }
    return count < 1 ? 1 : count;
  }

  static List<String> _fallbackParts(String word, {int? expectedCount}) {
    final normalized = _normalizeWord(word);
    final count = expectedCount ?? _fallbackSyllableCount(normalized);
    if (count <= 1 || normalized.length <= 1) {
      return [normalized.isEmpty ? word : normalized];
    }

    final parts = <String>[];
    for (var i = 0; i < count; i++) {
      final start = (normalized.length * i) ~/ count;
      final end = i == count - 1
          ? normalized.length
          : (normalized.length * (i + 1)) ~/ count;
      parts.add(normalized.substring(start, end));
    }
    return parts;
  }
}

class SyllableDictionary {
  final Map<String, SyllableEntry> _entries;

  SyllableDictionary(Iterable<SyllableEntry> entries)
      : _entries = {
          for (final entry in entries) entry.normalizedWord: entry,
        };

  factory SyllableDictionary.withBuiltIns() =>
      SyllableDictionary(_builtInEntries);

  factory SyllableDictionary.fromCmuDictLines(Iterable<String> lines) {
    final entries = <SyllableEntry>[];
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith(';;;')) {
        continue;
      }

      final chunks = line.split(RegExp(r'\s+'));
      if (chunks.length < 2) {
        continue;
      }
      final word = chunks.first.replaceFirst(RegExp(r'\(\d+\)$'), '');
      final phonemes = chunks.skip(1).toList();
      final count = phonemes.where((p) => RegExp(r'\d').hasMatch(p)).length;
      if (count < 1) {
        continue;
      }
      entries.add(SyllableEntry(
        normalizedWord: AlignmentEngine._normalizeWord(word),
        syllableCount: count,
        parts: const [],
      ));
    }
    return SyllableDictionary([..._builtInEntries, ...entries]);
  }

  SyllableEntry? lookup(String word) =>
      _entries[AlignmentEngine._normalizeWord(word)];
}

class SyllableEntry {
  final String normalizedWord;
  final int syllableCount;
  final List<String> parts;
  final bool fromFallback;

  SyllableEntry({
    required this.normalizedWord,
    required this.syllableCount,
    required List<String> parts,
    this.fromFallback = false,
  }) : parts = List.unmodifiable(parts) {
    if (normalizedWord.isEmpty) {
      throw ArgumentError('normalizedWord 不可空白');
    }
    if (syllableCount < 1) {
      throw ArgumentError('syllableCount 必須 >= 1');
    }
  }
}

final List<SyllableEntry> _builtInEntries = [
  SyllableEntry(normalizedWord: 'she', syllableCount: 1, parts: ['she']),
  SyllableEntry(normalizedWord: 'has', syllableCount: 1, parts: ['has']),
  SyllableEntry(
      normalizedWord: 'excellent',
      syllableCount: 3,
      parts: ['ex', 'cel', 'lent']),
  SyllableEntry(
      normalizedWord: 'communication',
      syllableCount: 5,
      parts: ['com', 'mu', 'ni', 'ca', 'tion']),
  SyllableEntry(normalizedWord: 'skills', syllableCount: 1, parts: ['skills']),
  SyllableEntry(normalizedWord: 'step', syllableCount: 1, parts: ['step']),
  SyllableEntry(normalizedWord: 'up', syllableCount: 1, parts: ['up']),
  SyllableEntry(normalizedWord: 'your', syllableCount: 1, parts: ['your']),
  SyllableEntry(
      normalizedWord: 'coding', syllableCount: 2, parts: ['cod', 'ing']),
  SyllableEntry(normalizedWord: 'to', syllableCount: 1, parts: ['to']),
  SyllableEntry(normalizedWord: 'a', syllableCount: 1, parts: ['a']),
  SyllableEntry(normalizedWord: 'new', syllableCount: 1, parts: ['new']),
  SyllableEntry(
      normalizedWord: 'level', syllableCount: 2, parts: ['le', 'vel']),
];
