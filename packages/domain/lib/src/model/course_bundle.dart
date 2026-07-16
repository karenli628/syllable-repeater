// AI-Generate
import 'dart:typed_data';

import 'lesson.dart';
import 'practice_arrangement.dart';
import 'progress.dart';
import 'segment.dart';
import 'time_range.dart';

/// `.abopack v3` 內的可選段落標籤（backend-design.md §3.1.1；REQ-21）。
class CourseLabels {
  final String language;
  final bool separateVocals;
  final List<Segment> segments;

  CourseLabels({
    required this.language,
    required this.separateVocals,
    required List<Segment> segments,
  }) : segments = List.unmodifiable(segments) {
    if (language.trim().isEmpty) {
      throw ArgumentError('CourseLabels.language 不可空白');
    }
  }
}

/// 手機與本機皆可讀的最後一次練習摘要；刻意不含 attempt、錄音與顯示設定。
class PortableLatestProgress {
  final int lastCompletedUnitIndex;
  final Difficulty difficulty;
  final int intervalIndex;
  final DateTime nextDue;
  final DateTime updatedAt;
  final double? rhythmScore;
  final double? intonationScore;

  PortableLatestProgress({
    required this.lastCompletedUnitIndex,
    required this.difficulty,
    required this.intervalIndex,
    required DateTime nextDue,
    required DateTime updatedAt,
    this.rhythmScore,
    this.intonationScore,
  })  : nextDue = nextDue.toUtc(),
        updatedAt = updatedAt.toUtc() {
    if (lastCompletedUnitIndex < 1) {
      throw ArgumentError(
        'PortableLatestProgress.lastCompletedUnitIndex 必須 >= 1，got '
        '$lastCompletedUnitIndex',
      );
    }
    if (intervalIndex < 0 || intervalIndex > SrsState.maxIntervalIndex) {
      throw ArgumentError(
        'PortableLatestProgress.intervalIndex 必須介於 0..5，got $intervalIndex',
      );
    }
    _validateScore(rhythmScore, 'rhythmScore');
    _validateScore(intonationScore, 'intonationScore');
  }

  Map<String, dynamic> toJson() => {
        'lastCompletedUnitIndex': lastCompletedUnitIndex,
        'difficulty': difficulty.value,
        'intervalIndex': intervalIndex,
        'nextDue': nextDue.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (rhythmScore != null) 'rhythmScore': rhythmScore,
        if (intonationScore != null) 'intonationScore': intonationScore,
      };

  factory PortableLatestProgress.fromJson(Map<String, dynamic> json) =>
      PortableLatestProgress(
        lastCompletedUnitIndex: json['lastCompletedUnitIndex'] as int,
        difficulty: Difficulty.fromJson(json['difficulty'] as String),
        intervalIndex: json['intervalIndex'] as int,
        nextDue: DateTime.parse(json['nextDue'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        rhythmScore: (json['rhythmScore'] as num?)?.toDouble(),
        intonationScore: (json['intonationScore'] as num?)?.toDouble(),
      );
}

/// 課程複合封包聚合；完整來源原音必填，其餘內容皆可選（REQ-21）。
class CourseBundle {
  static const originalAudioRelPath = 'audio/source-original.bin';

  final String courseName;
  final String sourceAudioName;
  final String audioFingerprint;
  final int audioDurationMs;
  final Uint8List originalAudioBytes;
  final CourseLabels? labels;
  final Lesson? sentenceLesson;
  final TimeRange? sentenceSourceRange;
  final PracticeArrangement? arrangement;
  final PortableLatestProgress? latestProgress;

  CourseBundle({
    required this.courseName,
    required this.sourceAudioName,
    required this.audioFingerprint,
    required this.audioDurationMs,
    required Uint8List originalAudioBytes,
    this.labels,
    this.sentenceLesson,
    this.sentenceSourceRange,
    this.arrangement,
    this.latestProgress,
  }) : originalAudioBytes = Uint8List.fromList(originalAudioBytes) {
    if (courseName.trim().isEmpty) {
      throw ArgumentError('CourseBundle.courseName 不可空白');
    }
    if (sourceAudioName.trim().isEmpty ||
        sourceAudioName.contains('/') ||
        sourceAudioName.contains(r'\')) {
      throw ArgumentError('CourseBundle.sourceAudioName 必須是安全檔名');
    }
    if (audioFingerprint.trim().isEmpty) {
      throw ArgumentError('CourseBundle.audioFingerprint 不可空白');
    }
    if (audioDurationMs <= 0) {
      throw ArgumentError(
        'CourseBundle.audioDurationMs 必須 > 0，got $audioDurationMs',
      );
    }
    if (this.originalAudioBytes.isEmpty) {
      throw ArgumentError('CourseBundle.originalAudioBytes 不可為空');
    }
    if (arrangement != null &&
        sentenceLesson != null &&
        arrangement!.lessonId != sentenceLesson!.id) {
      throw ArgumentError('CourseBundle.arrangement 必須屬於 sentenceLesson');
    }
    if (sentenceSourceRange != null && sentenceLesson == null) {
      throw ArgumentError('CourseBundle.sentenceSourceRange 需要 sentenceLesson');
    }
    if (sentenceSourceRange != null &&
        sentenceSourceRange!.endMs > audioDurationMs) {
      throw ArgumentError(
        'CourseBundle.sentenceSourceRange 不可超過完整原音時長',
      );
    }
    for (final segment in labels?.segments ?? const <Segment>[]) {
      if (segment.endMs > audioDurationMs) {
        throw ArgumentError('CourseBundle.labels 區段不可超過完整原音時長');
      }
    }
  }
}

void _validateScore(double? value, String name) {
  if (value != null && (!value.isFinite || value < 0 || value > 1)) {
    throw ArgumentError('PortableLatestProgress.$name 必須介於 0..1，got $value');
  }
}
