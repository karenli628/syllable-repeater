// AI-Generate
import 'time_range.dart';

/// 單一音節時間戳（backend-design.md §3.2.1 介面 1）。
class Syllable {
  final String text;
  final int startMs;
  final int endMs;
  final int wordIndex;
  final bool needsReview;

  Syllable({
    required this.text,
    required this.startMs,
    required this.endMs,
    required this.wordIndex,
    required this.needsReview,
  }) {
    if (text.trim().isEmpty) {
      throw ArgumentError('Syllable.text 不可空白');
    }
    if (startMs < 0 || endMs <= startMs) {
      throw ArgumentError(
          'Syllable 需滿足 0 <= startMs < endMs（got $startMs..$endMs）');
    }
  }

  TimeRange get range => TimeRange(startMs, endMs);

  @override
  bool operator ==(Object other) =>
      other is Syllable &&
      other.text == text &&
      other.startMs == startMs &&
      other.endMs == endMs &&
      other.wordIndex == wordIndex &&
      other.needsReview == needsReview;

  @override
  int get hashCode => Object.hash(text, startMs, endMs, wordIndex, needsReview);
}
