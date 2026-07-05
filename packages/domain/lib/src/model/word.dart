// AI-Generate
import 'time_range.dart';

/// Whisper 詞級時間戳（backend-design.md §3.2.1 介面 1）。
class Word {
  final String text;
  final int startMs;
  final int endMs;
  final int index;

  Word({
    required this.text,
    required this.startMs,
    required this.endMs,
    required this.index,
  }) {
    if (text.trim().isEmpty) {
      throw ArgumentError('Word.text 不可空白');
    }
    if (startMs < 0 || endMs <= startMs) {
      throw ArgumentError(
          'Word 需滿足 0 <= startMs < endMs（got $startMs..$endMs）');
    }
  }

  TimeRange get range => TimeRange(startMs, endMs);

  @override
  bool operator ==(Object other) =>
      other is Word &&
      other.text == text &&
      other.startMs == startMs &&
      other.endMs == endMs &&
      other.index == index;

  @override
  int get hashCode => Object.hash(text, startMs, endMs, index);
}
