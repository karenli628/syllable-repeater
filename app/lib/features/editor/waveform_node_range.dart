// AI-Generate
import 'package:domain/domain.dart';

/// 以波形左右邊緣與內部切點定義音節可視區段（REQ-17／AT-17-09）。
///
/// 第一段從 0 ms 開始；最後一段延伸至原始 PCM 結尾。內部
/// 區段仍以相鄰音節間的切點線為邊界。
TimeRange waveformNodeRange({
  required List<Syllable> syllables,
  required int syllableIndex,
  required int totalDurationMs,
}) {
  if (syllables.isEmpty) {
    throw ArgumentError('syllables 不可為空');
  }
  if (syllableIndex < 0 || syllableIndex >= syllables.length) {
    throw RangeError.range(
      syllableIndex,
      0,
      syllables.length - 1,
      'syllableIndex',
    );
  }
  if (totalDurationMs <= 0) {
    throw ArgumentError('totalDurationMs 必須 > 0，got $totalDurationMs');
  }

  final startMs = syllableIndex == 0 ? 0 : syllables[syllableIndex - 1].endMs;
  final endMs = syllableIndex == syllables.length - 1
      ? totalDurationMs
      : syllables[syllableIndex].endMs;
  if (startMs < 0 || endMs <= startMs || endMs > totalDurationMs) {
    throw ArgumentError(
      '波形節點區間無效：index=$syllableIndex、'
      'range=$startMs..$endMs、total=$totalDurationMs',
    );
  }
  return TimeRange(startMs, endMs);
}
