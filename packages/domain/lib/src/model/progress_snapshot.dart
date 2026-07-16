// AI-Generate
import 'progress.dart';
import 'settings.dart';

/// `.aboprogress` 的平台中立快照（backend-design.md §3.2.6 介面 15/16）。
///
/// 只保存 groups / srs / attempts 與 Lesson contentHash 摘要；不包含音訊、
/// API key、錄音路徑或平台檔案路徑。
class ProgressSnapshot {
  final String profileId;
  final String courseId;
  final Map<String, String> lessonContentHashes;

  /// 每 Lesson 顯示偏好；缺少 key 時由 [transcriptModeForLesson] 回傳 transcript。
  final Map<String, TranscriptDisplayMode> transcriptDisplayModes;
  final List<PracticeGroup> groups;
  final List<SrsState> srsStates;
  final List<Attempt> attempts;

  ProgressSnapshot({
    required this.profileId,
    required this.courseId,
    required Map<String, String> lessonContentHashes,
    Map<String, TranscriptDisplayMode> transcriptDisplayModes = const {},
    required List<PracticeGroup> groups,
    required List<SrsState> srsStates,
    required List<Attempt> attempts,
  })  : lessonContentHashes = Map.unmodifiable(lessonContentHashes),
        transcriptDisplayModes = Map.unmodifiable(transcriptDisplayModes),
        groups = List.unmodifiable(groups),
        srsStates = List.unmodifiable(srsStates),
        attempts = List.unmodifiable(attempts) {
    _requireNotBlank(profileId, 'ProgressSnapshot.profileId');
    _requireNotBlank(courseId, 'ProgressSnapshot.courseId');
    for (final entry in lessonContentHashes.entries) {
      _requireNotBlank(entry.key, 'ProgressSnapshot.lessonId');
      _requireNotBlank(entry.value, 'ProgressSnapshot.contentHash');
    }
    for (final lessonId in transcriptDisplayModes.keys) {
      _requireNotBlank(
        lessonId,
        'ProgressSnapshot.transcriptDisplayModes.lessonId',
      );
    }
  }

  /// 取得指定 Lesson 的顯示模式；未保存偏好沿用 transcript 預設。
  TranscriptDisplayMode transcriptModeForLesson(String lessonId) {
    _requireNotBlank(lessonId, 'ProgressSnapshot.lessonId');
    return transcriptDisplayModes[lessonId] ?? TranscriptDisplayMode.transcript;
  }

  Map<String, dynamic> toJson() => {
        'profileId': profileId,
        'courseId': courseId,
        'lessonContentHashes': lessonContentHashes,
        'transcriptDisplayModes': {
          for (final entry in transcriptDisplayModes.entries)
            entry.key: entry.value.value,
        },
        'groups': groups.map(_practiceGroupToJson).toList(growable: false),
        'srsStates': srsStates.map(_srsStateToJson).toList(growable: false),
        'attempts': attempts.map(_attemptToJson).toList(growable: false),
      };

  factory ProgressSnapshot.fromJson(Map<String, dynamic> json) {
    final hashes = json['lessonContentHashes'];
    if (hashes is! Map<String, dynamic>) {
      throw const FormatException('lessonContentHashes missing');
    }
    final rawModes = json['transcriptDisplayModes'];
    final modes = <String, TranscriptDisplayMode>{};
    if (rawModes != null) {
      if (rawModes is! Map<String, dynamic>) {
        throw const FormatException('transcriptDisplayModes invalid');
      }
      for (final entry in rawModes.entries) {
        if (entry.value is! String) {
          throw const FormatException('transcriptDisplayModes value invalid');
        }
        modes[entry.key] =
            TranscriptDisplayMode.fromJson(entry.value as String);
      }
    }

    return ProgressSnapshot(
      profileId: json['profileId'] as String,
      courseId: json['courseId'] as String,
      lessonContentHashes: {
        for (final entry in hashes.entries) entry.key: entry.value as String,
      },
      transcriptDisplayModes: modes,
      groups: (json['groups'] as List<dynamic>)
          .map((item) => _practiceGroupFromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      srsStates: (json['srsStates'] as List<dynamic>)
          .map((item) => _srsStateFromJson(item as Map<String, dynamic>))
          .toList(growable: false),
      attempts: (json['attempts'] as List<dynamic>)
          .map((item) => _attemptFromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

/// 進度匯入合併摘要，供 FP7 MergeSummary 對話框顯示。
class MergeSummary {
  final int applied;
  final int skipped;
  final List<String> resetLessons;

  MergeSummary({
    required this.applied,
    required this.skipped,
    required List<String> resetLessons,
  }) : resetLessons = List.unmodifiable(resetLessons) {
    if (applied < 0) {
      throw ArgumentError('MergeSummary.applied 不可為負數');
    }
    if (skipped < 0) {
      throw ArgumentError('MergeSummary.skipped 不可為負數');
    }
  }
}

Map<String, dynamic> _practiceGroupToJson(PracticeGroup group) => {
      'id': group.id,
      'profileId': group.profileId,
      'courseId': group.courseId,
      'lessonId': group.lessonId,
      'name': group.name,
      'stepRange': {
        'startStepIndex': group.stepRange.startStepIndex,
        'endStepIndex': group.stepRange.endStepIndex,
      },
      'status': group.status.value,
      'archivedAt': group.archivedAt?.toUtc().toIso8601String(),
      'updatedAt': group.updatedAt.toUtc().toIso8601String(),
    };

PracticeGroup _practiceGroupFromJson(Map<String, dynamic> json) {
  final range = json['stepRange'] as Map<String, dynamic>;
  return PracticeGroup(
    id: json['id'] as String,
    profileId: json['profileId'] as String,
    courseId: json['courseId'] as String,
    lessonId: json['lessonId'] as String,
    name: json['name'] as String,
    stepRange: StepRange(
      startStepIndex: range['startStepIndex'] as int,
      endStepIndex: range['endStepIndex'] as int,
    ),
    status: GroupStatus.fromJson(json['status'] as String),
    archivedAt: json['archivedAt'] == null
        ? null
        : DateTime.parse(json['archivedAt'] as String).toUtc(),
    updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
  );
}

Map<String, dynamic> _srsStateToJson(SrsState state) => {
      'groupId': state.groupId,
      'intervalIndex': state.intervalIndex,
      'nextDue': state.nextDue.toUtc().toIso8601String(),
      'difficulty': state.difficulty.value,
      'updatedAt': state.updatedAt.toUtc().toIso8601String(),
    };

SrsState _srsStateFromJson(Map<String, dynamic> json) => SrsState(
      groupId: json['groupId'] as String,
      intervalIndex: json['intervalIndex'] as int,
      nextDue: DateTime.parse(json['nextDue'] as String).toUtc(),
      difficulty: Difficulty.fromJson(json['difficulty'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
    );

Map<String, dynamic> _attemptToJson(Attempt attempt) => {
      'id': attempt.id,
      'groupId': attempt.groupId,
      'stepIndex': attempt.stepIndex,
      'rhythmDelta': attempt.rhythmDelta,
      'intonationDelta': attempt.intonationDelta,
      'overlayJson': attempt.overlayJson,
      'createdAt': attempt.createdAt.toUtc().toIso8601String(),
    };

Attempt _attemptFromJson(Map<String, dynamic> json) => Attempt(
      id: json['id'] as String,
      groupId: json['groupId'] as String,
      stepIndex: json['stepIndex'] as int,
      rhythmDelta: (json['rhythmDelta'] as num).toDouble(),
      intonationDelta: (json['intonationDelta'] as num).toDouble(),
      overlayJson: json['overlayJson'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
    );

void _requireNotBlank(String value, String fieldName) {
  if (value.trim().isEmpty) {
    throw ArgumentError('$fieldName 不可空白');
  }
}
