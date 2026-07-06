// AI-Generate
import 'dart:convert';
import 'dart:typed_data';

import '../errors.dart';
import '../model/audit_log.dart';
import '../model/progress.dart';
import '../model/progress_snapshot.dart';
import '../model/settings.dart';
import '../ports/clock.dart';
import '../ports/file_io.dart';
import '../ports/progress_repository.dart';

/// ProgressEngine：SRS 結算、到期清單與進度匯入匯出
/// （backend-design.md §3.2.6 介面 13-16）。
class ProgressEngine {
  static const int progressSchemaVersion = 1;
  static const List<int> intervalDays = [0, 1, 3, 7, 14, 30];
  static const Duration archiveRestoreWindow = Duration(hours: 168);

  final ProgressRepository repository;
  final Clock clock;
  final FileIo? fileIo;

  const ProgressEngine({
    required this.repository,
    required this.clock,
    this.fileIo,
  });

  Future<SrsState> settle(
    String groupId,
    Difficulty difficulty, {
    Attempt? attempt,
  }) async {
    final group = await repository.findGroup(groupId);
    if (group == null) {
      throw ArgumentError('找不到 PracticeGroup: $groupId');
    }
    if (group.status != GroupStatus.active) {
      throw ArgumentError('只有 ACTIVE PracticeGroup 可結算');
    }
    if (attempt != null && attempt.groupId != groupId) {
      throw ArgumentError('Attempt.groupId 必須與 settle groupId 相同');
    }

    final current = await repository.findSrsState(groupId);
    final currentIndex = current?.intervalIndex ?? 0;
    final nextIndex = _nextIntervalIndex(currentIndex, difficulty);
    final now = clock.now().toUtc();
    final nextDue = now.add(Duration(days: intervalDays[nextIndex]));
    final updated = SrsState(
      groupId: groupId,
      intervalIndex: nextIndex,
      nextDue: nextDue,
      difficulty: difficulty,
      updatedAt: now,
    );

    await repository.saveSrsState(updated);
    if (attempt != null) {
      await repository.saveAttempt(attempt);
    }
    return updated;
  }

  Future<List<DueGroup>> dueList(DateTime now) async {
    final normalizedNow = now.toUtc();
    final candidates = await repository.dueCandidates(normalizedNow);
    final due = <DueGroup>[];

    for (final candidate in candidates) {
      if (candidate.group.status != GroupStatus.active) {
        continue;
      }
      if (candidate.srsState.nextDue.toUtc().isAfter(normalizedNow)) {
        continue;
      }
      due.add(
        DueGroup(
          groupId: candidate.group.id,
          lessonTitle: candidate.lessonTitle,
          nextDue: candidate.srsState.nextDue.toUtc(),
          priority: _priorityOf(candidate.srsState.difficulty),
        ),
      );
    }

    due.sort((a, b) {
      final byPriority = b.priority.compareTo(a.priority);
      if (byPriority != 0) {
        return byPriority;
      }
      return a.nextDue.compareTo(b.nextDue);
    });
    return List.unmodifiable(due);
  }

  Future<List<ArchivedGroup>> archivedGroups(DateTime now) async {
    final normalizedNow = now.toUtc();
    final candidates = await repository.archivedCandidates();
    final archived = <ArchivedGroup>[];

    for (final candidate in candidates) {
      final group = candidate.group;
      if (group.status != GroupStatus.archived || group.archivedAt == null) {
        continue;
      }
      final archivedAt = group.archivedAt!.toUtc();
      final expiresAt = archivedAt.add(archiveRestoreWindow);
      final remaining = expiresAt.difference(normalizedNow);
      archived.add(
        ArchivedGroup(
          groupId: group.id,
          lessonTitle: candidate.lessonTitle,
          groupName: group.name,
          archivedAt: archivedAt,
          restoreExpiresAt: expiresAt,
          remainingRestoreWindow:
              remaining.isNegative ? Duration.zero : remaining,
          expired: !normalizedNow.isBefore(expiresAt),
        ),
      );
    }

    archived.sort((a, b) => a.restoreExpiresAt.compareTo(b.restoreExpiresAt));
    return List.unmodifiable(archived);
  }

  Future<void> archive(String groupId) async {
    final group = await repository.findGroup(groupId);
    if (group == null) {
      throw ArgumentError('找不到 PracticeGroup: $groupId');
    }
    if (group.status != GroupStatus.active) {
      throw ArgumentError('只有 ACTIVE PracticeGroup 可歸檔');
    }

    final now = clock.now().toUtc();
    final archived = _groupWithStatus(
      group,
      GroupStatus.archived,
      archivedAt: now,
      updatedAt: now,
    );
    await repository.saveGroup(archived);
    await repository.appendAuditLog(
      _auditEntry(
        occurredAt: now,
        action: 'practice_group_archived',
        targetType: 'practice_group',
        targetId: group.id,
        metadata: {'lessonId': group.lessonId},
      ),
    );
  }

  Future<void> restore(String groupId) async {
    final group = await repository.findGroup(groupId);
    if (group == null) {
      throw ArgumentError('找不到 PracticeGroup: $groupId');
    }
    if (group.status == GroupStatus.expired) {
      throw _archiveRestoreExpired();
    }
    if (group.status != GroupStatus.archived) {
      throw ArgumentError('只有 ARCHIVED PracticeGroup 可恢復');
    }

    final now = clock.now().toUtc();
    final archivedAt = group.archivedAt!.toUtc();
    if (now.difference(archivedAt) >= archiveRestoreWindow) {
      final expired = _groupWithStatus(
        group,
        GroupStatus.expired,
        archivedAt: archivedAt,
        updatedAt: now,
      );
      await repository.saveGroup(expired);
      await repository.appendAuditLog(
        _auditEntry(
          occurredAt: now,
          action: 'practice_group_restore_expired',
          targetType: 'practice_group',
          targetId: group.id,
          metadata: {'lessonId': group.lessonId},
        ),
      );
      throw _archiveRestoreExpired();
    }

    final restored = _groupWithStatus(
      group,
      GroupStatus.active,
      updatedAt: now,
    );
    await repository.saveGroup(restored);
    await repository.appendAuditLog(
      _auditEntry(
        occurredAt: now,
        action: 'practice_group_restored',
        targetType: 'practice_group',
        targetId: group.id,
        metadata: {'lessonId': group.lessonId},
      ),
    );
  }

  Future<ReminderConfig> reminderConfig() async =>
      await repository.loadReminderConfig() ?? ReminderConfig.defaults;

  Future<ReminderConfig> setReminderConfig(ReminderConfig config) async {
    await repository.saveReminderConfig(config);
    await repository.appendAuditLog(
      _auditEntry(
        occurredAt: clock.now().toUtc(),
        action: 'reminder_config_changed',
        targetType: 'app_settings',
        targetId: 'reminder',
        metadata: {
          'minutesPerSession': '${config.minutesPerSession}',
          'failCapPerSession': '${config.failCapPerSession}',
          'dailySessions': '${config.dailySessions}',
        },
      ),
    );
    return config;
  }

  Future<SidecarConfig> sidecarConfig() async =>
      await repository.loadSidecarConfig() ?? SidecarConfig.defaults;

  Future<SidecarConfig> setSidecarConfig(SidecarConfig config) async {
    await repository.saveSidecarConfig(config);
    await repository.appendAuditLog(
      _auditEntry(
        occurredAt: clock.now().toUtc(),
        action: 'sidecar_config_changed',
        targetType: 'app_settings',
        targetId: 'sidecar',
        metadata: {'timeoutSeconds': '${config.timeoutSeconds}'},
      ),
    );
    return config;
  }

  Future<String> exportProgress(String destPath) async {
    final snapshot = await repository.loadProgressSnapshot();
    final document = {
      'schemaVersion': progressSchemaVersion,
      'exportedAt': clock.now().toUtc().toIso8601String(),
      'progress': snapshot.toJson(),
    };
    await _requireFileIo().writeBytesAtomic(
      destPath,
      Uint8List.fromList(utf8.encode(jsonEncode(document))),
    );
    return destPath;
  }

  Future<MergeSummary> importProgress(String path) async {
    final incoming = await _readProgressSnapshot(path);
    final local = await repository.loadProgressSnapshot();
    final result = _mergeSnapshots(local, incoming);
    await repository.saveProgressSnapshot(result.snapshot);
    return result.summary;
  }

  int _nextIntervalIndex(int currentIndex, Difficulty difficulty) {
    final boundedCurrent = currentIndex.clamp(0, intervalDays.length - 1);
    final next = switch (difficulty) {
      Difficulty.hard => boundedCurrent - 1,
      Difficulty.normal => boundedCurrent + 1,
      Difficulty.easy => boundedCurrent + 2,
    };
    return next.clamp(0, intervalDays.length - 1);
  }

  int _priorityOf(Difficulty difficulty) => switch (difficulty) {
        Difficulty.hard => 3,
        Difficulty.normal => 2,
        Difficulty.easy => 1,
      };

  FileIo _requireFileIo() {
    final current = fileIo;
    if (current == null) {
      throw StateError('ProgressEngine export/import 需要 FileIo');
    }
    return current;
  }

  Future<ProgressSnapshot> _readProgressSnapshot(String path) async {
    try {
      final bytes = await _requireFileIo().readBytes(path);
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw _progressCorrupted();
      }
      if (decoded['schemaVersion'] != progressSchemaVersion) {
        throw _progressCorrupted();
      }
      final progress = decoded['progress'];
      if (progress is! Map<String, dynamic>) {
        throw _progressCorrupted();
      }
      return ProgressSnapshot.fromJson(progress);
    } on DomainException catch (error) {
      if (error.code == ErrorCodes.progressCorrupted) {
        rethrow;
      }
      throw _progressCorrupted();
    } catch (_) {
      throw _progressCorrupted();
    }
  }

  _ProgressMergeResult _mergeSnapshots(
    ProgressSnapshot local,
    ProgressSnapshot incoming,
  ) {
    if (local.profileId != incoming.profileId ||
        local.courseId != incoming.courseId) {
      throw _progressCorrupted();
    }

    final resetLessons = _resetLessonIds(local, incoming);
    final resetLessonSet = resetLessons.toSet();

    final groupMerge = _mergeGroups(local, incoming, resetLessonSet);
    final liveGroupIds = groupMerge.groups.map((group) => group.id).toSet();
    final stateMerge =
        _mergeSrsStates(local, incoming, liveGroupIds, resetLessonSet);
    final attemptMerge =
        _mergeAttempts(local, incoming, liveGroupIds, resetLessonSet);

    final hashes = <String, String>{...local.lessonContentHashes};
    for (final entry in incoming.lessonContentHashes.entries) {
      if (!resetLessonSet.contains(entry.key)) {
        hashes[entry.key] = entry.value;
      }
    }

    return _ProgressMergeResult(
      snapshot: ProgressSnapshot(
        profileId: local.profileId,
        courseId: local.courseId,
        lessonContentHashes: hashes,
        groups: groupMerge.groups,
        srsStates: stateMerge.states,
        attempts: attemptMerge.attempts,
      ),
      summary: MergeSummary(
        applied: groupMerge.applied + stateMerge.applied + attemptMerge.applied,
        skipped: groupMerge.skipped + stateMerge.skipped + attemptMerge.skipped,
        resetLessons: resetLessons,
      ),
    );
  }

  List<String> _resetLessonIds(
    ProgressSnapshot local,
    ProgressSnapshot incoming,
  ) {
    final reset = <String>[];
    for (final entry in incoming.lessonContentHashes.entries) {
      final localHash = local.lessonContentHashes[entry.key];
      if (localHash != null && localHash != entry.value) {
        reset.add(entry.key);
      }
    }
    reset.sort();
    return reset;
  }

  _GroupMerge _mergeGroups(
    ProgressSnapshot local,
    ProgressSnapshot incoming,
    Set<String> resetLessons,
  ) {
    var applied = 0;
    var skipped = 0;
    final merged = <String, PracticeGroup>{};

    for (final group in local.groups) {
      if (!resetLessons.contains(group.lessonId)) {
        merged[_groupKey(group)] = group;
      }
    }

    for (final group in incoming.groups) {
      if (resetLessons.contains(group.lessonId)) {
        continue;
      }
      final key = _groupKey(group);
      final existing = merged[key];
      if (existing == null) {
        merged[key] = group;
        applied++;
        continue;
      }
      if (group.updatedAt.isAfter(existing.updatedAt)) {
        merged[key] = group;
        applied++;
      } else {
        skipped++;
      }
    }

    return _GroupMerge(
      groups: List.unmodifiable(merged.values),
      applied: applied,
      skipped: skipped,
    );
  }

  _SrsStateMerge _mergeSrsStates(
    ProgressSnapshot local,
    ProgressSnapshot incoming,
    Set<String> liveGroupIds,
    Set<String> resetLessons,
  ) {
    var applied = 0;
    var skipped = 0;
    final merged = <String, SrsState>{};
    final incomingGroupLessons = {
      for (final group in incoming.groups) group.id: group.lessonId,
    };

    for (final state in local.srsStates) {
      if (liveGroupIds.contains(state.groupId)) {
        merged[state.groupId] = state;
      }
    }

    for (final state in incoming.srsStates) {
      final lessonId = incomingGroupLessons[state.groupId];
      if (lessonId != null && resetLessons.contains(lessonId)) {
        continue;
      }
      if (!liveGroupIds.contains(state.groupId)) {
        continue;
      }
      final existing = merged[state.groupId];
      if (existing == null) {
        merged[state.groupId] = state;
        applied++;
        continue;
      }
      if (state.updatedAt.isAfter(existing.updatedAt)) {
        merged[state.groupId] = state;
        applied++;
      } else {
        skipped++;
      }
    }

    return _SrsStateMerge(
      states: List.unmodifiable(merged.values),
      applied: applied,
      skipped: skipped,
    );
  }

  _AttemptMerge _mergeAttempts(
    ProgressSnapshot local,
    ProgressSnapshot incoming,
    Set<String> liveGroupIds,
    Set<String> resetLessons,
  ) {
    var applied = 0;
    var skipped = 0;
    final merged = <String, Attempt>{};
    final incomingGroupLessons = {
      for (final group in incoming.groups) group.id: group.lessonId,
    };

    for (final attempt in local.attempts) {
      if (liveGroupIds.contains(attempt.groupId)) {
        merged[attempt.id] = attempt;
      }
    }

    for (final attempt in incoming.attempts) {
      final lessonId = incomingGroupLessons[attempt.groupId];
      if (lessonId != null && resetLessons.contains(lessonId)) {
        continue;
      }
      if (!liveGroupIds.contains(attempt.groupId)) {
        continue;
      }
      if (merged.containsKey(attempt.id)) {
        skipped++;
      } else {
        merged[attempt.id] = attempt;
        applied++;
      }
    }

    return _AttemptMerge(
      attempts: List.unmodifiable(merged.values),
      applied: applied,
      skipped: skipped,
    );
  }

  String _groupKey(PracticeGroup group) =>
      '${group.profileId}|${group.courseId}|${group.lessonId}|${group.id}';
}

PracticeGroup _groupWithStatus(
  PracticeGroup group,
  GroupStatus status, {
  DateTime? archivedAt,
  required DateTime updatedAt,
}) =>
    PracticeGroup(
      id: group.id,
      profileId: group.profileId,
      courseId: group.courseId,
      lessonId: group.lessonId,
      name: group.name,
      stepRange: group.stepRange,
      status: status,
      archivedAt: archivedAt,
      updatedAt: updatedAt,
    );

class _ProgressMergeResult {
  final ProgressSnapshot snapshot;
  final MergeSummary summary;

  _ProgressMergeResult({
    required this.snapshot,
    required this.summary,
  });
}

class _GroupMerge {
  final List<PracticeGroup> groups;
  final int applied;
  final int skipped;

  _GroupMerge({
    required this.groups,
    required this.applied,
    required this.skipped,
  });
}

class _SrsStateMerge {
  final List<SrsState> states;
  final int applied;
  final int skipped;

  _SrsStateMerge({
    required this.states,
    required this.applied,
    required this.skipped,
  });
}

class _AttemptMerge {
  final List<Attempt> attempts;
  final int applied;
  final int skipped;

  _AttemptMerge({
    required this.attempts,
    required this.applied,
    required this.skipped,
  });
}

DomainException _progressCorrupted() => const DomainException(
      ErrorCodes.progressCorrupted,
      '進度檔損毀，未套用任何變更',
    );

DomainException _archiveRestoreExpired() => const DomainException(
      ErrorCodes.archiveRestoreExpired,
      '已超過 7 日（168 小時）恢復期限',
    );

AuditLogEntry _auditEntry({
  required DateTime occurredAt,
  required String action,
  required String targetType,
  String? targetId,
  Map<String, String> metadata = const {},
}) =>
    AuditLogEntry(
      occurredAt: occurredAt,
      actor: AuditLogEntry.localActor,
      action: action,
      targetType: targetType,
      targetId: targetId,
      metadata: metadata,
    );
