// AI-Generate
import 'syllable.dart';
import 'word.dart';

/// AnalysisPipeline.analyze 的完成結果（backend-design.md §3.2.1 介面 1）。
class AlignmentResult {
  final List<Word> words;
  final List<Syllable> syllables;
  final String source;
  final double confidence;

  AlignmentResult({
    required List<Word> words,
    required List<Syllable> syllables,
    required this.source,
    required this.confidence,
  })  : words = List.unmodifiable(words),
        syllables = List.unmodifiable(syllables) {
    if (source.trim().isEmpty) {
      throw ArgumentError('AlignmentResult.source 不可空白');
    }
    if (confidence < 0 || confidence > 1) {
      throw ArgumentError('AlignmentResult.confidence 需介於 0..1');
    }
  }

  bool get needsReview => syllables.any((s) => s.needsReview);

  /// 建立對齊結果不可變快照（backend-design.md §3.2.1 介面 24～26）。
  AlignmentResult copyWith({
    List<Word>? words,
    List<Syllable>? syllables,
    String? source,
    double? confidence,
  }) =>
      AlignmentResult(
        words: words ?? this.words,
        syllables: syllables ?? this.syllables,
        source: source ?? this.source,
        confidence: confidence ?? this.confidence,
      );
}
