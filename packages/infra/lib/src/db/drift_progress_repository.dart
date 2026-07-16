// AI-Generate
import 'dart:convert';

import 'package:domain/domain.dart' as domain;
import 'package:drift/drift.dart';

import 'app_database.dart';
import 'drift_settings_service.dart';

/// ProgressRepository 的 Drift/SQLite adapter；所有批次寫入以 transaction 包住。
class DriftProgressRepository implements domain.ProgressRepository {
  DriftProgressRepository(this._db);

  static const _profileFallback = 'profile-local';
  static const _courseFallback = 'course-local';
  static const _minutesKey = 'reminder.minutes';
  static const _failCapKey = 'reminder.failCap';
  static const _dailySessionsKey = 'reminder.dailySessions';
  static const _sidecarTimeoutKey = 'sidecar.timeoutSec';

  final AppDatabase _db;

  @override
  Future<domain.PracticeGroup?> findGroup(String groupId) async {
    final row = await (_db.select(_db.practiceGroups)
          ..where((table) => table.id.equals(groupId)))
        .getSingleOrNull();
    return row == null ? null : _groupFromRow(row);
  }

  @override
  Future<void> saveGroup(domain.PracticeGroup group) async {
    await _ensureLessonRow(group);
    await _db.into(_db.practiceGroups).insertOnConflictUpdate(
          _groupCompanion(group),
        );
  }

  @override
  Future<domain.SrsState?> findSrsState(String groupId) async {
    final row = await (_db.select(_db.srsStates)
          ..where((table) => table.groupId.equals(groupId)))
        .getSingleOrNull();
    return row == null ? null : _srsStateFromRow(row);
  }

  @override
  Future<void> saveSrsState(domain.SrsState state) {
    return _db.into(_db.srsStates).insertOnConflictUpdate(
          SrsStatesCompanion.insert(
            groupId: state.groupId,
            intervalIndex: Value(state.intervalIndex),
            nextDue: _ms(state.nextDue),
            difficulty: Value(state.difficulty.value),
            updatedAt: _ms(state.updatedAt),
          ),
        );
  }

  @override
  Future<void> saveAttempt(domain.Attempt attempt) {
    return _db.into(_db.attempts).insertOnConflictUpdate(
          AttemptsCompanion.insert(
            id: attempt.id,
            groupId: attempt.groupId,
            stepIndex: attempt.stepIndex,
            rhythmDelta: attempt.rhythmDelta,
            intonationDelta: attempt.intonationDelta,
            overlayJson: attempt.overlayJson,
            createdAt: _ms(attempt.createdAt),
          ),
        );
  }

  @override
  Future<List<domain.ProgressDueCandidate>> dueCandidates(DateTime now) async {
    final stateRows = await (_db.select(_db.srsStates)
          ..where((table) => table.nextDue.isSmallerOrEqualValue(_ms(now))))
        .get();
    final candidates = <domain.ProgressDueCandidate>[];
    for (final stateRow in stateRows) {
      final groupRow = await (_db.select(_db.practiceGroups)
            ..where((table) => table.id.equals(stateRow.groupId)))
          .getSingleOrNull();
      if (groupRow == null) {
        continue;
      }
      final lessonRow = await (_db.select(_db.lessonRegistry)
            ..where((table) => table.id.equals(groupRow.lessonId)))
          .getSingleOrNull();
      candidates.add(
        domain.ProgressDueCandidate(
          group: _groupFromRow(groupRow),
          srsState: _srsStateFromRow(stateRow),
          lessonTitle: lessonRow?.title ?? groupRow.lessonId,
        ),
      );
    }
    return List.unmodifiable(candidates);
  }

  @override
  Future<List<domain.ProgressArchivedCandidate>> archivedCandidates() async {
    final groupRows = await (_db.select(_db.practiceGroups)
          ..where((table) =>
              table.status.equals(domain.GroupStatus.archived.value)))
        .get();
    final candidates = <domain.ProgressArchivedCandidate>[];
    for (final groupRow in groupRows) {
      final lessonRow = await (_db.select(_db.lessonRegistry)
            ..where((table) => table.id.equals(groupRow.lessonId)))
          .getSingleOrNull();
      candidates.add(
        domain.ProgressArchivedCandidate(
          group: _groupFromRow(groupRow),
          lessonTitle: lessonRow?.title ?? groupRow.lessonId,
        ),
      );
    }
    return List.unmodifiable(candidates);
  }

  @override
  Future<domain.ProgressSnapshot> loadProgressSnapshot() async {
    final lessonRows = await _db.select(_db.lessonRegistry).get();
    final groupRows = await _db.select(_db.practiceGroups).get();
    final stateRows = await _db.select(_db.srsStates).get();
    final attemptRows = await _db.select(_db.attempts).get();
    final transcriptDisplayModes =
        await DriftSettingsService.readTranscriptDisplayModes(_db);
    final firstGroup = groupRows.isEmpty ? null : groupRows.first;
    return domain.ProgressSnapshot(
      profileId: firstGroup?.profileId ?? _profileFallback,
      courseId: firstGroup?.courseId ?? _courseFallback,
      lessonContentHashes: {
        for (final row in lessonRows) row.id: row.contentHash,
      },
      transcriptDisplayModes: transcriptDisplayModes,
      groups: groupRows.map(_groupFromRow).toList(growable: false),
      srsStates: stateRows.map(_srsStateFromRow).toList(growable: false),
      attempts: attemptRows.map(_attemptFromRow).toList(growable: false),
    );
  }

  @override
  Future<void> saveProgressSnapshot(domain.ProgressSnapshot snapshot) {
    return _db.transaction(() async {
      await _db.delete(_db.attempts).go();
      await _db.delete(_db.srsStates).go();
      await _db.delete(_db.practiceGroups).go();

      for (final entry in snapshot.lessonContentHashes.entries) {
        final existing = await (_db.select(_db.lessonRegistry)
              ..where((table) => table.id.equals(entry.key)))
            .getSingleOrNull();
        await _db.into(_db.lessonRegistry).insertOnConflictUpdate(
              LessonRegistryCompanion.insert(
                id: entry.key,
                packPath: existing?.packPath ?? '',
                title: existing?.title ?? entry.key,
                contentHash: entry.value,
                updatedAt: existing?.updatedAt ?? 0,
              ),
            );
      }
      await DriftSettingsService.writeTranscriptDisplayModes(
        _db,
        snapshot.transcriptDisplayModes,
      );
      for (final group in snapshot.groups) {
        await saveGroup(group);
      }
      for (final state in snapshot.srsStates) {
        await saveSrsState(state);
      }
      for (final attempt in snapshot.attempts) {
        await saveAttempt(attempt);
      }
    });
  }

  @override
  Future<domain.ReminderConfig?> loadReminderConfig() async {
    final values = {
      for (final row in await _db.select(_db.appSettings).get())
        row.key: row.value,
    };
    if (!values.containsKey(_minutesKey) &&
        !values.containsKey(_failCapKey) &&
        !values.containsKey(_dailySessionsKey)) {
      return null;
    }
    return domain.ReminderConfig(
      minutesPerSession: int.tryParse(values[_minutesKey] ?? '') ??
          domain.ReminderConfig.defaults.minutesPerSession,
      failCapPerSession: int.tryParse(values[_failCapKey] ?? '') ??
          domain.ReminderConfig.defaults.failCapPerSession,
      dailySessions: int.tryParse(values[_dailySessionsKey] ?? '') ??
          domain.ReminderConfig.defaults.dailySessions,
    );
  }

  @override
  Future<void> saveReminderConfig(domain.ReminderConfig config) {
    return _db.transaction(() async {
      await _saveSetting(_minutesKey, '${config.minutesPerSession}');
      await _saveSetting(_failCapKey, '${config.failCapPerSession}');
      await _saveSetting(_dailySessionsKey, '${config.dailySessions}');
    });
  }

  @override
  Future<domain.SidecarConfig?> loadSidecarConfig() async {
    final row = await (_db.select(_db.appSettings)
          ..where((table) => table.key.equals(_sidecarTimeoutKey)))
        .getSingleOrNull();
    if (row == null) {
      return null;
    }
    return domain.SidecarConfig(
      timeoutSeconds: int.tryParse(row.value) ??
          domain.SidecarConfig.defaults.timeoutSeconds,
    );
  }

  @override
  Future<void> saveSidecarConfig(domain.SidecarConfig config) {
    return _saveSetting(_sidecarTimeoutKey, '${config.timeoutSeconds}');
  }

  @override
  Future<void> appendAuditLog(domain.AuditLogEntry entry) async {
    final count =
        await _db.select(_db.auditLogs).get().then((rows) => rows.length);
    await _db.into(_db.auditLogs).insert(
          AuditLogsCompanion.insert(
            id: '${entry.occurredAt.microsecondsSinceEpoch}-${count + 1}',
            occurredAt: _ms(entry.occurredAt),
            actor: entry.actor,
            action: entry.action,
            targetType: entry.targetType,
            targetId: Value(entry.targetId),
            metadataJson: jsonEncode(entry.metadata),
          ),
        );
  }

  Future<void> _saveSetting(String key, String value) {
    return _db.into(_db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(key: key, value: value),
        );
  }

  Future<void> _ensureLessonRow(domain.PracticeGroup group) async {
    final existing = await (_db.select(_db.lessonRegistry)
          ..where((table) => table.id.equals(group.lessonId)))
        .getSingleOrNull();
    if (existing != null) {
      return;
    }
    await _db.into(_db.lessonRegistry).insert(
          LessonRegistryCompanion.insert(
            id: group.lessonId,
            packPath: '',
            title: group.lessonId,
            contentHash: '',
            updatedAt: _ms(group.updatedAt),
          ),
        );
  }
}

domain.PracticeGroup _groupFromRow(PracticeGroup row) {
  final config = jsonDecode(row.configJson) as Map<String, dynamic>;
  final stepRange = config['stepRange'] as Map<String, dynamic>? ?? const {};
  return domain.PracticeGroup(
    id: row.id,
    profileId: row.profileId,
    courseId: row.courseId,
    lessonId: row.lessonId,
    name: row.name,
    stepRange: domain.StepRange(
      startStepIndex: stepRange['startStepIndex'] as int? ?? 1,
      endStepIndex: stepRange['endStepIndex'] as int? ?? 1,
    ),
    status: domain.GroupStatus.fromJson(row.status),
    archivedAt: row.archivedAt == null ? null : _date(row.archivedAt!),
    updatedAt: _date(row.updatedAt),
  );
}

PracticeGroupsCompanion _groupCompanion(domain.PracticeGroup group) {
  return PracticeGroupsCompanion.insert(
    id: group.id,
    profileId: group.profileId,
    courseId: group.courseId,
    lessonId: group.lessonId,
    name: group.name,
    configJson: jsonEncode({
      'stepRange': {
        'startStepIndex': group.stepRange.startStepIndex,
        'endStepIndex': group.stepRange.endStepIndex,
      },
    }),
    status: Value(group.status.value),
    archivedAt: Value(group.archivedAt == null ? null : _ms(group.archivedAt!)),
    updatedAt: _ms(group.updatedAt),
  );
}

domain.SrsState _srsStateFromRow(SrsState row) => domain.SrsState(
      groupId: row.groupId,
      intervalIndex: row.intervalIndex,
      nextDue: _date(row.nextDue),
      difficulty: domain.Difficulty.fromJson(row.difficulty),
      updatedAt: _date(row.updatedAt),
    );

domain.Attempt _attemptFromRow(Attempt row) => domain.Attempt(
      id: row.id,
      groupId: row.groupId,
      stepIndex: row.stepIndex,
      rhythmDelta: row.rhythmDelta,
      intonationDelta: row.intonationDelta,
      overlayJson: row.overlayJson,
      createdAt: _date(row.createdAt),
    );

int _ms(DateTime value) => value.toUtc().millisecondsSinceEpoch;

DateTime _date(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
