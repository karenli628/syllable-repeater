// AI-Generate
import '../model/progress.dart';
import '../model/progress_snapshot.dart';
import '../model/settings.dart';
import 'audit_log_sink.dart';

/// dueList 查詢候選資料；infra adapter 可由 Drift join 組出。
class ProgressDueCandidate {
  final PracticeGroup group;
  final SrsState srsState;
  final String lessonTitle;

  ProgressDueCandidate({
    required this.group,
    required this.srsState,
    required this.lessonTitle,
  }) {
    if (lessonTitle.trim().isEmpty) {
      throw ArgumentError('ProgressDueCandidate.lessonTitle 不可空白');
    }
  }
}

/// archivedGroups 查詢候選資料；infra adapter 可由 PracticeGroup + LessonRegistry 組出。
class ProgressArchivedCandidate {
  final PracticeGroup group;
  final String lessonTitle;

  ProgressArchivedCandidate({
    required this.group,
    required this.lessonTitle,
  }) {
    if (lessonTitle.trim().isEmpty) {
      throw ArgumentError('ProgressArchivedCandidate.lessonTitle 不可空白');
    }
  }
}

/// ProgressEngine 的持久化 port；Domain 不直接依賴 Drift/SQLite。
abstract interface class ProgressRepository implements AuditLogSink {
  Future<PracticeGroup?> findGroup(String groupId);

  Future<void> saveGroup(PracticeGroup group);

  Future<SrsState?> findSrsState(String groupId);

  Future<void> saveSrsState(SrsState state);

  Future<void> saveAttempt(Attempt attempt);

  Future<List<ProgressDueCandidate>> dueCandidates(DateTime now);

  Future<List<ProgressArchivedCandidate>> archivedCandidates();

  /// 匯出本機 `.aboprogress` 所需的完整快照。
  Future<ProgressSnapshot> loadProgressSnapshot();

  /// 交易保存已全檔驗證與合併完成的快照；infra adapter 必須原子套用。
  Future<void> saveProgressSnapshot(ProgressSnapshot snapshot);

  Future<ReminderConfig?> loadReminderConfig();

  Future<void> saveReminderConfig(ReminderConfig config);

  Future<SidecarConfig?> loadSidecarConfig();

  Future<void> saveSidecarConfig(SidecarConfig config);
}
