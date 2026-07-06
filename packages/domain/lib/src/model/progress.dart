// AI-Generate

/// 練習難度三檔（backend-design.md §3.1.3）。
enum Difficulty {
  hard('HARD'),
  normal('NORMAL'),
  easy('EASY');

  final String value;

  const Difficulty(this.value);

  static Difficulty fromJson(String value) {
    for (final difficulty in values) {
      if (difficulty.value == value) {
        return difficulty;
      }
    }
    throw ArgumentError('未知 Difficulty: $value');
  }
}

/// PracticeGroup 歸檔狀態（backend-design.md §3.1.3）。
enum GroupStatus {
  active('ACTIVE'),
  archived('ARCHIVED'),
  expired('EXPIRED');

  final String value;

  const GroupStatus(this.value);

  static GroupStatus fromJson(String value) {
    for (final status in values) {
      if (status.value == value) {
        return status;
      }
    }
    throw ArgumentError('未知 GroupStatus: $value');
  }
}

/// PracticeGroup 對應的步驟範圍（1 起算，閉區間）。
class StepRange {
  final int startStepIndex;
  final int endStepIndex;

  const StepRange({
    required this.startStepIndex,
    required this.endStepIndex,
  })  : assert(startStepIndex >= 1),
        assert(endStepIndex >= startStepIndex);
}

/// 進度 / SRS 結算最小單位（backend-design.md §3.1.1 PracticeGroup）。
class PracticeGroup {
  final String id;
  final String profileId;
  final String courseId;
  final String lessonId;
  final String name;
  final StepRange stepRange;
  final GroupStatus status;
  final DateTime? archivedAt;
  final DateTime updatedAt;

  PracticeGroup({
    required this.id,
    required this.profileId,
    required this.courseId,
    required this.lessonId,
    required this.name,
    required this.stepRange,
    this.status = GroupStatus.active,
    this.archivedAt,
    required this.updatedAt,
  }) {
    _requireNotBlank(id, 'PracticeGroup.id');
    _requireNotBlank(profileId, 'PracticeGroup.profileId');
    _requireNotBlank(courseId, 'PracticeGroup.courseId');
    _requireNotBlank(lessonId, 'PracticeGroup.lessonId');
    _requireNotBlank(name, 'PracticeGroup.name');
    if (status == GroupStatus.archived && archivedAt == null) {
      throw ArgumentError('archived PracticeGroup 必須帶 archivedAt');
    }
  }
}

/// SRS 排程狀態（backend-design.md §3.2.6 介面 13）。
class SrsState {
  static const int maxIntervalIndex = 5;

  final String groupId;
  final int intervalIndex;
  final DateTime nextDue;
  final Difficulty difficulty;
  final DateTime updatedAt;

  SrsState({
    required this.groupId,
    required this.intervalIndex,
    required this.nextDue,
    required this.difficulty,
    required this.updatedAt,
  }) {
    _requireNotBlank(groupId, 'SrsState.groupId');
    if (intervalIndex < 0 || intervalIndex > maxIntervalIndex) {
      throw ArgumentError('SrsState.intervalIndex 必須介於 0..5');
    }
  }
}

/// dueList 的輸出項目（backend-design.md §3.2.6 介面 14）。
class DueGroup {
  final String groupId;
  final String lessonTitle;
  final DateTime nextDue;

  /// 排序優先值：數字越大越優先，HARD 最高。
  final int priority;

  DueGroup({
    required this.groupId,
    required this.lessonTitle,
    required this.nextDue,
    required this.priority,
  }) {
    _requireNotBlank(groupId, 'DueGroup.groupId');
    _requireNotBlank(lessonTitle, 'DueGroup.lessonTitle');
  }
}

/// 歸檔管理 UI 的輸出項目（frontend-design 功能點 7）。
class ArchivedGroup {
  final String groupId;
  final String lessonTitle;
  final String groupName;
  final DateTime archivedAt;
  final DateTime restoreExpiresAt;
  final Duration remainingRestoreWindow;
  final bool expired;

  ArchivedGroup({
    required this.groupId,
    required this.lessonTitle,
    required this.groupName,
    required this.archivedAt,
    required this.restoreExpiresAt,
    required this.remainingRestoreWindow,
    required this.expired,
  }) {
    _requireNotBlank(groupId, 'ArchivedGroup.groupId');
    _requireNotBlank(lessonTitle, 'ArchivedGroup.lessonTitle');
    _requireNotBlank(groupName, 'ArchivedGroup.groupName');
  }
}

/// 一次練習嘗試的參數與 overlay 快照；不含音訊（M10）。
class Attempt {
  final String id;
  final String groupId;
  final int stepIndex;
  final double rhythmDelta;
  final double intonationDelta;
  final String overlayJson;
  final DateTime createdAt;

  Attempt({
    required this.id,
    required this.groupId,
    required this.stepIndex,
    required this.rhythmDelta,
    required this.intonationDelta,
    required this.overlayJson,
    required this.createdAt,
  }) {
    _requireNotBlank(id, 'Attempt.id');
    _requireNotBlank(groupId, 'Attempt.groupId');
    if (stepIndex < 1) {
      throw ArgumentError('Attempt.stepIndex 必須 >= 1');
    }
    _requireNotBlank(overlayJson, 'Attempt.overlayJson');
  }
}

void _requireNotBlank(String value, String fieldName) {
  if (value.trim().isEmpty) {
    throw ArgumentError('$fieldName 不可空白');
  }
}
