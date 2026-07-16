// AI-Generate
import 'time_range.dart';

const _unsetSegmentField = Object();

/// 段落區間的人工處置（REQ-11 AT-11-12）。
enum SegmentDisposition { kept, discarded }

/// 句子級音訊區段（backend-design.md §3.1.1 Segment）。
class Segment {
  final String id;
  final int startMs;
  final int endMs;
  final String text;
  final String language;
  final double confidence;
  final bool userAdjusted;
  final SegmentDisposition disposition;
  final String? note;

  /// 建立不可變的句子區段（REQ-11、M14）。
  Segment({
    required this.id,
    required this.startMs,
    required this.endMs,
    required this.text,
    required this.language,
    required this.confidence,
    this.userAdjusted = false,
    this.disposition = SegmentDisposition.kept,
    this.note,
  }) {
    if (id.trim().isEmpty) {
      throw ArgumentError('Segment.id 不可空白');
    }
    if (startMs < 0 || endMs <= startMs) {
      throw ArgumentError(
        'Segment 需滿足 0 <= startMs < endMs（got $startMs..$endMs）',
      );
    }
    if (language.trim().isEmpty) {
      throw ArgumentError('Segment.language 不可空白');
    }
    if (confidence < 0 || confidence > 1) {
      throw ArgumentError(
        'Segment.confidence 需介於 0..1（got $confidence）',
      );
    }
    if (note != null && note!.trim().isEmpty) {
      throw ArgumentError('Segment.note 若提供則不可空白');
    }
  }

  /// 區段的半開時間範圍（backend-design.md §3.1.1）。
  TimeRange get range => TimeRange(startMs, endMs);

  /// 複製區段並替換指定欄位（REQ-11 介面 21）。
  Segment copyWith({
    String? id,
    int? startMs,
    int? endMs,
    String? text,
    String? language,
    double? confidence,
    bool? userAdjusted,
    SegmentDisposition? disposition,
    Object? note = _unsetSegmentField,
  }) =>
      Segment(
        id: id ?? this.id,
        startMs: startMs ?? this.startMs,
        endMs: endMs ?? this.endMs,
        text: text ?? this.text,
        language: language ?? this.language,
        confidence: confidence ?? this.confidence,
        userAdjusted: userAdjusted ?? this.userAdjusted,
        disposition: disposition ?? this.disposition,
        note: identical(note, _unsetSegmentField) ? this.note : note as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is Segment &&
      other.id == id &&
      other.startMs == startMs &&
      other.endMs == endMs &&
      other.text == text &&
      other.language == language &&
      other.confidence == confidence &&
      other.userAdjusted == userAdjusted &&
      other.disposition == disposition &&
      other.note == note;

  @override
  int get hashCode => Object.hash(
        id,
        startMs,
        endMs,
        text,
        language,
        confidence,
        userAdjusted,
        disposition,
        note,
      );
}
