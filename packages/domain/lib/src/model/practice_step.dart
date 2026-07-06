// AI-Generate
import 'syllable.dart';
import 'time_range.dart';

/// 句尾疊加練習的一步（backend-design.md §3.2.2 介面 3）。
/// M1：只保存原音檔 sourceRanges，不保存衍生音訊資料。
class PracticeStep {
  final int index;
  final List<Syllable> syllables;
  final List<TimeRange> sourceRanges;
  final int totalDurationMs;

  PracticeStep({
    required this.index,
    required List<Syllable> syllables,
    required List<TimeRange> sourceRanges,
    required this.totalDurationMs,
  })  : syllables = List.unmodifiable(syllables),
        sourceRanges = List.unmodifiable(sourceRanges) {
    if (index < 1) {
      throw ArgumentError('PracticeStep.index 必須從 1 起算');
    }
    if (syllables.isEmpty) {
      throw ArgumentError('PracticeStep.syllables 不可為空');
    }
    if (sourceRanges.isEmpty) {
      throw ArgumentError('PracticeStep.sourceRanges 不可為空');
    }
    if (totalDurationMs <= 0) {
      throw ArgumentError('PracticeStep.totalDurationMs 必須大於 0');
    }
  }
}
