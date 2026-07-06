// AI-Generate
import '../model/pcm.dart';

/// 匯出前的純音訊組裝結果（backend-design.md §3.2.2 介面 5/6 的 domain 部分）。
///
/// M3：合併匯出段落間靜音長度必須等於前一步 totalDurationMs。
class PracticeExportAudio {
  final Pcm pcm;
  final int totalDurationMs;
  final List<int> silenceGapsMs;

  PracticeExportAudio({
    required this.pcm,
    required this.totalDurationMs,
    required List<int> silenceGapsMs,
  }) : silenceGapsMs = List.unmodifiable(silenceGapsMs);
}
