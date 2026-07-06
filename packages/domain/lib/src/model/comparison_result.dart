// AI-Generate
import 'time_range.dart';

/// 錄音比對結果（backend-design.md §3.2.4 介面 8）。
class ComparisonResult {
  final double rhythmDelta;
  final double intonationDelta;
  final OverlayData overlayData;
  final double? score;

  const ComparisonResult({
    required this.rhythmDelta,
    required this.intonationDelta,
    required this.overlayData,
    this.score,
  });
}

/// 雙波形/音高疊圖資料；App 端只渲染，不保存錄音檔（M10）。
class OverlayData {
  final List<double> userWave;
  final List<double> referenceWave;
  final List<double> userPitch;
  final List<double> referencePitch;
  final List<TimeRange> diffRanges;

  OverlayData({
    required List<double> userWave,
    required List<double> referenceWave,
    required List<double> userPitch,
    required List<double> referencePitch,
    required List<TimeRange> diffRanges,
  })  : userWave = List.unmodifiable(userWave),
        referenceWave = List.unmodifiable(referenceWave),
        userPitch = List.unmodifiable(userPitch),
        referencePitch = List.unmodifiable(referencePitch),
        diffRanges = List.unmodifiable(diffRanges);
}
