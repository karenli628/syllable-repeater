// AI-Generate
/// 原音檔上的時間區間（毫秒），值物件（backend-design.md §3.1.1）。
/// §0.1/M1：PracticeStep.sourceRanges 只允許存本型別——型別層面排除任何衍生音訊。
class TimeRange {
  final int startMs;
  final int endMs;

  TimeRange(this.startMs, this.endMs) {
    if (startMs < 0 || endMs <= startMs) {
      throw ArgumentError(
          'TimeRange 需滿足 0 <= startMs < endMs（got $startMs..$endMs）');
    }
  }

  int get durationMs => endMs - startMs;

  @override
  bool operator ==(Object other) =>
      other is TimeRange && other.startMs == startMs && other.endMs == endMs;

  @override
  int get hashCode => Object.hash(startMs, endMs);

  @override
  String toString() => 'TimeRange($startMs..$endMs)';
}
