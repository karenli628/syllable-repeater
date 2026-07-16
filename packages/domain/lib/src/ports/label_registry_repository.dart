// AI-Generate
/// 標籤索引記錄（backend-design.md §3.1.1、OQ-6）。
class LabelRegistryRecord {
  final String audioFingerprint;
  final String labelPath;
  final int segmentCount;
  final DateTime updatedAt;

  /// 建立不可變的最近標籤檔索引記錄（REQ-11）。
  LabelRegistryRecord({
    required this.audioFingerprint,
    required this.labelPath,
    required this.segmentCount,
    required this.updatedAt,
  }) {
    if (audioFingerprint.trim().isEmpty || labelPath.trim().isEmpty) {
      throw ArgumentError('audioFingerprint 與 labelPath 不可空白');
    }
    if (segmentCount < 0) {
      throw ArgumentError('segmentCount 必須 >= 0（got $segmentCount）');
    }
  }
}

/// Label Registry 持久化插座；Domain 不接觸 Drift（backend-design.md §3.1.1）。
abstract interface class LabelRegistryRepository {
  /// 依音檔指紋找最近標籤檔（REQ-11、OQ-6）。
  Future<LabelRegistryRecord?> findByFingerprint(String audioFingerprint);

  /// 新增或更新標籤檔索引（REQ-11、OQ-6）。
  Future<void> upsert(LabelRegistryRecord record);
}
