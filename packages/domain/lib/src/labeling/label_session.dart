// AI-Generate
import '../errors.dart';
import '../model/segment.dart';
import '../model/time_range.dart';

const _minimumSegmentSpacingMs = 500;

/// 單一音檔的標籤聚合根（backend-design.md §3.1.1、REQ-11）。
class LabelSession {
  final String audioFingerprint;
  final int audioDurationMs;
  final String language;
  final bool separateVocals;
  List<Segment> _segments;
  bool _dirty = false;
  final List<_LabelSnapshot> _undoHistory = [];
  int _nextGeneratedId = 1;

  /// 建立已完整驗證且初始為 CLEAN 的標籤工作階段（AT-11-04）。
  LabelSession({
    required this.audioFingerprint,
    required this.audioDurationMs,
    this.language = 'en',
    this.separateVocals = false,
    required List<Segment> segments,
  }) : _segments = List.unmodifiable(segments) {
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(audioFingerprint)) {
      throw ArgumentError('audioFingerprint 必須是 64 位 SHA-256 十六進位字串');
    }
    if (audioDurationMs < 1) {
      throw ArgumentError(
        'audioDurationMs 必須 >= 1（got $audioDurationMs）',
      );
    }
    if (language.trim().isEmpty) {
      throw ArgumentError('LabelSession.language 不可空白');
    }
    _validateSegments(_segments, audioDurationMs);
    if (_segments.any((segment) =>
        segment.language.toLowerCase() != language.trim().toLowerCase())) {
      throw ArgumentError('所有 Segment.language 必須與 LabelSession.language 一致');
    }
  }

  /// 目前不可變的段落快照（REQ-11）。
  List<Segment> get segments => _segments;

  /// 可送往單句分析的保留段落（REQ-11 AT-11-12）。
  List<Segment> get keptSegments => List.unmodifiable(
        _segments.where(
          (segment) => segment.disposition == SegmentDisposition.kept,
        ),
      );

  /// 明示捨棄且保留註記的區間（REQ-11 AT-11-12）。
  List<Segment> get discardedSegments => List.unmodifiable(
        _segments.where(
          (segment) => segment.disposition == SegmentDisposition.discarded,
        ),
      );

  /// 是否有尚未儲存的變更（guardrails #48）。
  bool get dirty => _dirty;

  /// 將任意音檔區間標為保留；未涵蓋處維持未標記（AT-11-12）。
  void markKept(TimeRange range, {String text = ''}) {
    _markRange(
      range,
      disposition: SegmentDisposition.kept,
      text: text,
    );
  }

  /// 將任意音檔區間標為捨棄並可附註原因（AT-11-12）。
  void markDiscarded(TimeRange range, {String? note}) {
    _markRange(
      range,
      disposition: SegmentDisposition.discarded,
      text: '',
      note: note,
    );
  }

  /// 清除一段人工處置，使該時間回到未標記；不自動合併相鄰段（AT-11-15）。
  void clearDisposition(String regionId) {
    final index = _segments.indexWhere((segment) => segment.id == regionId);
    if (index < 0) {
      throw ArgumentError('找不到 Segment id=$regionId');
    }
    _recordUndo();
    _replaceSegments([
      for (var i = 0; i < _segments.length; i++)
        if (i != index) _segments[i],
    ]);
  }

  /// 移動第 [index] 條相鄰段落邊界（backend-design.md 介面 21）。
  void moveBoundary(int index, int newMs) {
    _validateBoundaryIndex(index);
    final left = _segments[index];
    final right = _segments[index + 1];
    if (newMs <= left.startMs || newMs >= right.endMs) {
      throw DomainException(
        ErrorCodes.boundaryInvalid,
        '段落邊界不可跨越相鄰區段（左起=${left.startMs}ms、右止=${right.endMs}ms、目標=${newMs}ms）',
      );
    }
    _recordUndo();
    _replaceSegments([
      for (var i = 0; i < _segments.length; i++)
        if (i == index)
          _segments[i].copyWith(endMs: newMs, userAdjusted: true)
        else if (i == index + 1)
          _segments[i].copyWith(startMs: newMs, userAdjusted: true)
        else
          _segments[i],
    ]);
  }

  /// 插入段落邊界；距既有邊界不得小於 500ms（AT-11-02）。
  void insertBoundary(int atMs) {
    final boundaries = <int>{
      0,
      audioDurationMs,
      for (final segment in _segments) segment.startMs,
      for (final segment in _segments) segment.endMs,
    };
    final nearest = boundaries
        .map((boundary) => (boundary - atMs).abs())
        .reduce((a, b) => a < b ? a : b);
    if (nearest < _minimumSegmentSpacingMs) {
      throw DomainException(
        ErrorCodes.segmentTooClose,
        '距離相鄰標籤線太近（至少 500ms；目標=${atMs}ms、最近距離=${nearest}ms）',
      );
    }

    if (_segments.isEmpty) {
      _recordUndo();
      _replaceSegments([
        Segment(
          id: _newSegmentId(),
          startMs: 0,
          endMs: atMs,
          text: '',
          language: language,
          confidence: 0,
          userAdjusted: true,
        ),
        Segment(
          id: _newSegmentId(),
          startMs: atMs,
          endMs: audioDurationMs,
          text: '',
          language: language,
          confidence: 0,
          userAdjusted: true,
        ),
      ]);
      return;
    }

    final targetIndex = _segments.indexWhere(
      (segment) => atMs > segment.startMs && atMs < segment.endMs,
    );
    if (targetIndex < 0) {
      throw DomainException(
        ErrorCodes.boundaryInvalid,
        '插入點不在任何段落內（got ${atMs}ms）',
      );
    }
    final target = _segments[targetIndex];
    _recordUndo();
    _replaceSegments([
      for (var i = 0; i < _segments.length; i++)
        if (i != targetIndex)
          _segments[i]
        else ...[
          target.copyWith(endMs: atMs, userAdjusted: true),
          target.copyWith(
            id: _newSegmentId(),
            startMs: atMs,
            text: '',
            userAdjusted: true,
          ),
        ],
    ]);
  }

  /// 移除第 [index] 條邊界並合併左右段落（AT-11-02/09）。
  void removeBoundary(int index) {
    if (_segments.length <= 1) {
      throw const DomainException(
        ErrorCodes.boundaryInvalid,
        '至少須保留一個段落，無法再刪除標籤線',
      );
    }
    _validateBoundaryIndex(index);
    final left = _segments[index];
    final right = _segments[index + 1];
    final mergedText = [left.text.trim(), right.text.trim()]
        .where((text) => text.isNotEmpty)
        .join(' ');
    _recordUndo();
    _replaceSegments([
      for (var i = 0; i < _segments.length; i++)
        if (i == index)
          left.copyWith(
            endMs: right.endMs,
            text: mergedText,
            confidence: left.confidence < right.confidence
                ? left.confidence
                : right.confidence,
            userAdjusted: true,
          )
        else if (i != index + 1)
          _segments[i],
    ]);
  }

  /// 撤銷最近一次聚合操作；無歷史時回 false（REQ-11）。
  bool undo() {
    if (_undoHistory.isEmpty) {
      return false;
    }
    final snapshot = _undoHistory.removeLast();
    _segments = snapshot.segments;
    _dirty = snapshot.dirty;
    return true;
  }

  /// 標記已成功匯出並清除跨儲存點的 undo 歷史（AT-11-04）。
  void markSaved() {
    _dirty = false;
    _undoHistory.clear();
  }

  void _recordUndo() {
    _undoHistory.add(_LabelSnapshot(_segments, _dirty));
  }

  void _markRange(
    TimeRange range, {
    required SegmentDisposition disposition,
    required String text,
    String? note,
  }) {
    if (range.endMs > audioDurationMs) {
      throw ArgumentError(
        '標記區間超出音檔時長（end=${range.endMs}、duration=$audioDurationMs）',
      );
    }
    _recordUndo();
    final next = <Segment>[];
    for (final segment in _segments) {
      final overlaps =
          segment.startMs < range.endMs && segment.endMs > range.startMs;
      if (!overlaps) {
        next.add(segment);
        continue;
      }
      if (segment.startMs < range.startMs) {
        next.add(segment.copyWith(
          endMs: range.startMs,
          userAdjusted: true,
        ));
      }
      if (segment.endMs > range.endMs) {
        next.add(segment.copyWith(
          id: _newSegmentId(),
          startMs: range.endMs,
          userAdjusted: true,
        ));
      }
    }
    next.add(Segment(
      id: _newSegmentId(),
      startMs: range.startMs,
      endMs: range.endMs,
      text: text,
      language: language,
      confidence: 0,
      userAdjusted: true,
      disposition: disposition,
      note: note,
    ));
    next.sort((left, right) => left.startMs.compareTo(right.startMs));
    _replaceSegments(next);
  }

  void _replaceSegments(List<Segment> next) {
    _validateSegments(next, audioDurationMs);
    _segments = List.unmodifiable(next);
    _dirty = true;
  }

  void _validateBoundaryIndex(int index) {
    if (index < 0 || index >= _segments.length - 1) {
      throw ArgumentError(
        'index 需介於 0..${_segments.length - 2}（got $index）',
      );
    }
  }

  String _newSegmentId() {
    while (_segments
        .any((segment) => segment.id == 'manual-segment-$_nextGeneratedId')) {
      _nextGeneratedId++;
    }
    return 'manual-segment-${_nextGeneratedId++}';
  }

  static void _validateSegments(List<Segment> segments, int durationMs) {
    Segment? previous;
    for (final segment in segments) {
      if (segment.endMs > durationMs) {
        throw ArgumentError(
          'Segment ${segment.id} 超出音檔時長（end=${segment.endMs}ms、duration=${durationMs}ms）',
        );
      }
      if (previous != null && segment.startMs < previous.endMs) {
        throw ArgumentError(
          'Segments 必須單調且不重疊（${previous.id}.end=${previous.endMs}、${segment.id}.start=${segment.startMs}）',
        );
      }
      previous = segment;
    }
  }
}

class _LabelSnapshot {
  final List<Segment> segments;
  final bool dirty;

  _LabelSnapshot(List<Segment> segments, this.dirty)
      : segments = List.unmodifiable(segments);
}
