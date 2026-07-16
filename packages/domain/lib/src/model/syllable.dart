// AI-Generate
import 'time_range.dart';

/// 單一音節時間戳（backend-design.md §3.2.1 介面 1）。
class Syllable {
  final String text;
  final String? originalText;
  final int startMs;
  final int endMs;
  final int wordIndex;
  final bool needsReview;

  Syllable({
    required this.text,
    this.originalText,
    required this.startMs,
    required this.endMs,
    required this.wordIndex,
    required this.needsReview,
  }) {
    if (text.trim().isEmpty && !needsReview) {
      throw ArgumentError('Syllable.text 空白時 needsReview 必須為 true');
    }
    if (startMs < 0 || endMs <= startMs) {
      throw ArgumentError(
          'Syllable 需滿足 0 <= startMs < endMs（got $startMs..$endMs）');
    }
  }

  TimeRange get range => TimeRange(startMs, endMs);

  /// 建立音節不可變快照（backend-design.md §3.2.1 介面 24～26）。
  Syllable copyWith({
    String? text,
    String? originalText,
    int? startMs,
    int? endMs,
    int? wordIndex,
    bool? needsReview,
  }) =>
      Syllable(
        text: text ?? this.text,
        originalText: originalText ?? this.originalText,
        startMs: startMs ?? this.startMs,
        endMs: endMs ?? this.endMs,
        wordIndex: wordIndex ?? this.wordIndex,
        needsReview: needsReview ?? this.needsReview,
      );

  @override
  bool operator ==(Object other) =>
      other is Syllable &&
      other.text == text &&
      other.originalText == originalText &&
      other.startMs == startMs &&
      other.endMs == endMs &&
      other.wordIndex == wordIndex &&
      other.needsReview == needsReview;

  @override
  int get hashCode =>
      Object.hash(text, originalText, startMs, endMs, wordIndex, needsReview);
}
