// AI-Generate
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:domain/domain.dart' show TimeRange;

/// 從段落標籤頁交給單句分析頁的唯一待處理區段（REQ-11、REQ-12、AT-12-02）。
///
/// 這個 UI 狀態只攜帶來源路徑與時間範圍，不攜帶或複製 PCM；真正的原音
/// 切片由後續分析入口依此範圍處理，避免跨 feature 建立第二套音訊來源。
class PendingSegment {
  PendingSegment({
    required this.segmentId,
    required this.sourceAudioPath,
    required this.startMs,
    required this.endMs,
    required this.text,
    required this.language,
    this.segmentIndex,
  }) {
    if (segmentId.trim().isEmpty) {
      throw ArgumentError('PendingSegment.segmentId 不可空白');
    }
    if (sourceAudioPath.trim().isEmpty) {
      throw ArgumentError('PendingSegment.sourceAudioPath 不可空白');
    }
    if (startMs < 0 || endMs <= startMs) {
      throw ArgumentError(
        'PendingSegment 需滿足 0 <= startMs < endMs（got $startMs..$endMs）',
      );
    }
    if (language.trim().isEmpty) {
      throw ArgumentError('PendingSegment.language 不可空白');
    }
  }

  final String segmentId;
  final String sourceAudioPath;
  final int startMs;
  final int endMs;
  final String text;
  final String language;

  /// 原清單中的 zero-based index；缺少時 UI 退回顯示 [segmentId]。
  final int? segmentIndex;

  TimeRange get range => TimeRange(startMs, endMs);

  @override
  bool operator ==(Object other) =>
      other is PendingSegment &&
      other.segmentId == segmentId &&
      other.sourceAudioPath == sourceAudioPath &&
      other.startMs == startMs &&
      other.endMs == endMs &&
      other.text == text &&
      other.language == language &&
      other.segmentIndex == segmentIndex;

  @override
  int get hashCode => Object.hash(
    segmentId,
    sourceAudioPath,
    startMs,
    endMs,
    text,
    language,
    segmentIndex,
  );
}

/// 跨 labeling／import_analysis 的單一槽位；新的交接會明確替換舊的待處理區段。
final pendingSegmentProvider =
    NotifierProvider<PendingSegmentController, PendingSegment?>(
      PendingSegmentController.new,
    );

class PendingSegmentController extends Notifier<PendingSegment?> {
  @override
  PendingSegment? build() => null;

  /// 寫入唯一待處理區段；不建立佇列、不累積多個 Segment。
  void set(PendingSegment pending) {
    state = pending;
  }

  void clear() {
    state = null;
  }
}
