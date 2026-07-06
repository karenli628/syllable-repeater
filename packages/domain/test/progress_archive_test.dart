// AI-Generate
// ProgressEngine 7.5 TDD-red：歸檔 168h 狀態機與 M8/CT-08。
import 'package:domain/domain.dart';
import 'package:test/test.dart';

Matcher _domainError(String code) =>
    throwsA(isA<DomainException>().having((e) => e.code, 'code', code));

void main() {
  group('ProgressEngine archive/restore（task-split 7.5，M8/CT-08）', () {
    test('archive 將 ACTIVE PracticeGroup 轉為 ARCHIVED 並寫 archivedAt', () async {
      final repository = _MemoryProgressRepository(
        groups: [_group('group-a')],
        states: [
          _state('group-a', DateTime.utc(2026, 7, 5, 9), Difficulty.normal),
        ],
        lessonTitles: const {'lesson-a': 'Communication Skills'},
      );
      final engine = ProgressEngine(
        repository: repository,
        clock: _FakeClock(DateTime.utc(2026, 7, 1, 0)),
      );

      await engine.archive('group-a');

      final saved = repository.groups['group-a']!;
      expect(saved.status, GroupStatus.archived);
      expect(saved.archivedAt, DateTime.utc(2026, 7, 1, 0));
      expect(saved.updatedAt, DateTime.utc(2026, 7, 1, 0));
      expect(repository.savedGroups, hasLength(1));
      expect(repository.auditLogs.single.action, 'practice_group_archived');
    });

    test('AT-08-05 歸檔 167h 內 restore 成功，回 ACTIVE 並清 archivedAt', () async {
      final repository = _MemoryProgressRepository(
        groups: [
          _group(
            'group-a',
            status: GroupStatus.archived,
            archivedAt: DateTime.utc(2026, 7, 1, 0),
          ),
        ],
        states: [
          _state('group-a', DateTime.utc(2026, 7, 5, 9), Difficulty.normal),
        ],
        lessonTitles: const {'lesson-a': 'Communication Skills'},
      );
      final engine = ProgressEngine(
        repository: repository,
        clock: _FakeClock(DateTime.utc(2026, 7, 7, 23)),
      );

      await engine.restore('group-a');

      final saved = repository.groups['group-a']!;
      expect(saved.status, GroupStatus.active);
      expect(saved.archivedAt, isNull);
      expect(saved.updatedAt, DateTime.utc(2026, 7, 7, 23));
      expect(repository.savedGroups, hasLength(1));
      expect(repository.auditLogs.single.action, 'practice_group_restored');
    });

    test('AT-08-06 歸檔 169h 後 restore 拒絕，並惰性轉 EXPIRED', () async {
      final repository = _MemoryProgressRepository(
        groups: [
          _group(
            'group-a',
            status: GroupStatus.archived,
            archivedAt: DateTime.utc(2026, 7, 1, 0),
          ),
        ],
        states: [
          _state('group-a', DateTime.utc(2026, 7, 5, 9), Difficulty.normal),
        ],
        lessonTitles: const {'lesson-a': 'Communication Skills'},
      );
      final engine = ProgressEngine(
        repository: repository,
        clock: _FakeClock(DateTime.utc(2026, 7, 8, 1)),
      );

      await expectLater(
        engine.restore('group-a'),
        _domainError(ErrorCodes.archiveRestoreExpired),
      );

      final saved = repository.groups['group-a']!;
      expect(saved.status, GroupStatus.expired);
      expect(saved.archivedAt, DateTime.utc(2026, 7, 1, 0));
      expect(saved.updatedAt, DateTime.utc(2026, 7, 8, 1));
      expect(repository.savedGroups, hasLength(1));
      expect(
        repository.auditLogs.single.action,
        'practice_group_restore_expired',
      );
    });

    test('ARCHIVED 與 EXPIRED PracticeGroup 不出現在 dueList', () async {
      final repository = _MemoryProgressRepository(
        groups: [
          _group('active', lessonId: 'lesson-active'),
          _group(
            'archived',
            lessonId: 'lesson-archived',
            status: GroupStatus.archived,
            archivedAt: DateTime.utc(2026, 7, 1),
          ),
          _group(
            'expired',
            lessonId: 'lesson-expired',
            status: GroupStatus.expired,
            archivedAt: DateTime.utc(2026, 7, 1),
          ),
        ],
        states: [
          _state('active', DateTime.utc(2026, 7, 5, 9), Difficulty.normal),
          _state('archived', DateTime.utc(2026, 7, 5, 9), Difficulty.hard),
          _state('expired', DateTime.utc(2026, 7, 5, 9), Difficulty.hard),
        ],
        lessonTitles: const {
          'lesson-active': 'Active Lesson',
          'lesson-archived': 'Archived Lesson',
          'lesson-expired': 'Expired Lesson',
        },
      );
      final engine = ProgressEngine(
        repository: repository,
        clock: _FakeClock(DateTime.utc(2026, 7, 8, 1)),
      );

      final due = await engine.dueList(DateTime.utc(2026, 7, 8, 1));

      expect(due.map((item) => item.groupId), ['active']);
      expect(repository.savedGroups, isEmpty);
    });

    test('archivedGroups 回傳恢復倒數，EXPIRED 不列入', () async {
      final repository = _MemoryProgressRepository(
        groups: [
          _group('active', lessonId: 'lesson-active'),
          _group(
            'archived-a',
            lessonId: 'lesson-a',
            status: GroupStatus.archived,
            archivedAt: DateTime.utc(2026, 7, 1, 0),
          ),
          _group(
            'archived-b',
            lessonId: 'lesson-b',
            status: GroupStatus.archived,
            archivedAt: DateTime.utc(2026, 7, 1, 20),
          ),
          _group(
            'expired',
            lessonId: 'lesson-expired',
            status: GroupStatus.expired,
            archivedAt: DateTime.utc(2026, 7, 1, 0),
          ),
        ],
        states: const [],
        lessonTitles: const {
          'lesson-a': 'Archived A',
          'lesson-b': 'Archived B',
          'lesson-active': 'Active',
          'lesson-expired': 'Expired',
        },
      );
      final engine = ProgressEngine(
        repository: repository,
        clock: _FakeClock(DateTime.utc(2026, 7, 7, 0)),
      );

      final archived = await engine.archivedGroups(DateTime.utc(2026, 7, 7, 0));

      expect(
          archived.map((item) => item.groupId), ['archived-a', 'archived-b']);
      expect(archived.first.lessonTitle, 'Archived A');
      expect(archived.first.restoreExpiresAt, DateTime.utc(2026, 7, 8, 0));
      expect(archived.first.remainingRestoreWindow, const Duration(hours: 24));
      expect(archived.first.expired, isFalse);
      expect(archived.last.remainingRestoreWindow, const Duration(hours: 44));
      expect(repository.savedGroups, isEmpty);
    });
  });
}

PracticeGroup _group(
  String id, {
  String lessonId = 'lesson-a',
  GroupStatus status = GroupStatus.active,
  DateTime? archivedAt,
}) =>
    PracticeGroup(
      id: id,
      profileId: 'profile-local',
      courseId: 'course-local',
      lessonId: lessonId,
      name: id,
      stepRange: const StepRange(startStepIndex: 1, endStepIndex: 3),
      status: status,
      archivedAt: archivedAt,
      updatedAt: DateTime.utc(2026, 7, 1),
    );

SrsState _state(String groupId, DateTime nextDue, Difficulty difficulty) =>
    SrsState(
      groupId: groupId,
      intervalIndex: 1,
      nextDue: nextDue,
      difficulty: difficulty,
      updatedAt: DateTime.utc(2026, 7, 4, 9),
    );

class _MemoryProgressRepository implements ProgressRepository {
  _MemoryProgressRepository({
    required List<PracticeGroup> groups,
    required List<SrsState> states,
    required this.lessonTitles,
  })  : groups = {for (final group in groups) group.id: group},
        states = {for (final state in states) state.groupId: state};

  final Map<String, PracticeGroup> groups;
  final Map<String, SrsState> states;
  final Map<String, String> lessonTitles;
  final List<PracticeGroup> savedGroups = [];
  final List<AuditLogEntry> auditLogs = [];

  @override
  Future<PracticeGroup?> findGroup(String groupId) async => groups[groupId];

  @override
  Future<SrsState?> findSrsState(String groupId) async => states[groupId];

  @override
  Future<void> saveGroup(PracticeGroup group) async {
    groups[group.id] = group;
    savedGroups.add(group);
  }

  @override
  Future<void> appendAuditLog(AuditLogEntry entry) async {
    auditLogs.add(entry);
  }

  @override
  Future<void> saveSrsState(SrsState state) async {
    states[state.groupId] = state;
  }

  @override
  Future<void> saveAttempt(Attempt attempt) async {}

  @override
  Future<List<ProgressDueCandidate>> dueCandidates(DateTime now) async {
    return [
      for (final state in states.values)
        ProgressDueCandidate(
          group: groups[state.groupId]!,
          srsState: state,
          lessonTitle: lessonTitles[groups[state.groupId]!.lessonId]!,
        ),
    ];
  }

  @override
  Future<List<ProgressArchivedCandidate>> archivedCandidates() async => [
        for (final group in groups.values)
          ProgressArchivedCandidate(
            group: group,
            lessonTitle: lessonTitles[group.lessonId] ?? group.lessonId,
          ),
      ];

  @override
  Future<ProgressSnapshot> loadProgressSnapshot() async => ProgressSnapshot(
        profileId: 'profile-local',
        courseId: 'course-local',
        lessonContentHashes: const {},
        groups: groups.values.toList(growable: false),
        srsStates: states.values.toList(growable: false),
        attempts: const [],
      );

  @override
  Future<void> saveProgressSnapshot(ProgressSnapshot snapshot) async {}

  @override
  Future<ReminderConfig?> loadReminderConfig() async => null;

  @override
  Future<void> saveReminderConfig(ReminderConfig config) async {}

  @override
  Future<SidecarConfig?> loadSidecarConfig() async => null;

  @override
  Future<void> saveSidecarConfig(SidecarConfig config) async {}
}

class _FakeClock implements Clock {
  _FakeClock(this.current);

  DateTime current;

  @override
  DateTime now() => current;
}
