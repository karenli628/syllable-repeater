// AI-Generate
// ProgressEngine 7.3 TDD-red：settle / dueList 與 M7 跨日零懲罰。
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('ProgressEngine.settle（task-split 7.3，REQ-08）', () {
    test('AT-08-01 NORMAL 依序進入 1 天與 3 天段', () async {
      final clock = _FakeClock(DateTime.utc(2026, 7, 4, 9));
      final repository = _MemoryProgressRepository(
        groups: [_group('group-a')],
        lessonTitles: {'lesson-a': 'Communication Skills'},
      );
      final engine = ProgressEngine(repository: repository, clock: clock);

      final first = await engine.settle('group-a', Difficulty.normal);

      expect(first.intervalIndex, 1);
      expect(first.nextDue, DateTime.utc(2026, 7, 5, 9));
      expect(first.difficulty, Difficulty.normal);

      clock.current = DateTime.utc(2026, 7, 5, 9);
      final second = await engine.settle('group-a', Difficulty.normal);

      expect(second.intervalIndex, 2);
      expect(second.nextDue, DateTime.utc(2026, 7, 8, 9));
      expect(repository.savedStates, hasLength(2));
    });

    test('HARD 縮短 intervalIndex；EASY 延長兩段但不超過上限', () async {
      final clock = _FakeClock(DateTime.utc(2026, 7, 4, 9));
      final repository = _MemoryProgressRepository(
        groups: [_group('group-a')],
        states: [
          SrsState(
            groupId: 'group-a',
            intervalIndex: 3,
            nextDue: DateTime.utc(2026, 7, 11, 9),
            difficulty: Difficulty.normal,
            updatedAt: DateTime.utc(2026, 7, 3, 9),
          ),
        ],
        lessonTitles: {'lesson-a': 'Communication Skills'},
      );
      final engine = ProgressEngine(repository: repository, clock: clock);

      final hard = await engine.settle('group-a', Difficulty.hard);
      expect(hard.intervalIndex, 2);
      expect(hard.nextDue, DateTime.utc(2026, 7, 7, 9));

      final easy = await engine.settle('group-a', Difficulty.easy);
      expect(easy.intervalIndex, 4);
      expect(easy.nextDue, DateTime.utc(2026, 7, 18, 9));
    });
  });

  group('ProgressEngine.dueList（task-split 7.3，M7/CT-07）', () {
    test('AT-08-02 逾期一天只列入可練清單，不寫失敗或懲罰', () async {
      final repository = _MemoryProgressRepository(
        groups: [_group('group-a')],
        states: [
          SrsState(
            groupId: 'group-a',
            intervalIndex: 1,
            nextDue: DateTime.utc(2026, 7, 5, 9),
            difficulty: Difficulty.normal,
            updatedAt: DateTime.utc(2026, 7, 4, 9),
          ),
        ],
        lessonTitles: {'lesson-a': 'Communication Skills'},
      );
      final engine = ProgressEngine(
        repository: repository,
        clock: _FakeClock(DateTime.utc(2026, 7, 6, 9)),
      );

      final due = await engine.dueList(DateTime.utc(2026, 7, 6, 9));

      expect(due, hasLength(1));
      expect(due.single.groupId, 'group-a');
      expect(due.single.lessonTitle, 'Communication Skills');
      expect(due.single.nextDue, DateTime.utc(2026, 7, 5, 9));
      expect(repository.savedStates, isEmpty);
      expect(repository.savedAttempts, isEmpty);
      expect(repository.states['group-a']!.intervalIndex, 1);
    });

    test('HARD 最高優先；同級依 nextDue 早者先；未到期與 archived 不列出', () async {
      final repository = _MemoryProgressRepository(
        groups: [
          _group('hard-later', lessonId: 'lesson-hard'),
          _group('normal-earlier', lessonId: 'lesson-normal'),
          _group('normal-later', lessonId: 'lesson-normal-2'),
          _group('future', lessonId: 'lesson-future'),
          _group(
            'archived',
            lessonId: 'lesson-archived',
            status: GroupStatus.archived,
            archivedAt: DateTime.utc(2026, 7, 4, 9),
          ),
        ],
        states: [
          _state('hard-later', DateTime.utc(2026, 7, 6, 12), Difficulty.hard),
          _state(
              'normal-earlier', DateTime.utc(2026, 7, 5, 9), Difficulty.normal),
          _state(
              'normal-later', DateTime.utc(2026, 7, 6, 8), Difficulty.normal),
          _state('future', DateTime.utc(2026, 7, 7, 9), Difficulty.hard),
          _state('archived', DateTime.utc(2026, 7, 5, 9), Difficulty.hard),
        ],
        lessonTitles: {
          'lesson-hard': 'Hard Lesson',
          'lesson-normal': 'Normal Lesson',
          'lesson-normal-2': 'Normal Lesson 2',
          'lesson-future': 'Future Lesson',
          'lesson-archived': 'Archived Lesson',
        },
      );
      final engine = ProgressEngine(
        repository: repository,
        clock: _FakeClock(DateTime.utc(2026, 7, 6, 12)),
      );

      final due = await engine.dueList(DateTime.utc(2026, 7, 6, 12));

      expect(due.map((item) => item.groupId), [
        'hard-later',
        'normal-earlier',
        'normal-later',
      ]);
      expect(due.first.priority, greaterThan(due[1].priority));
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
      updatedAt: DateTime.utc(2026, 7, 4),
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
    List<SrsState> states = const [],
    required this.lessonTitles,
  })  : groups = {for (final group in groups) group.id: group},
        states = {for (final state in states) state.groupId: state};

  final Map<String, PracticeGroup> groups;
  final Map<String, SrsState> states;
  final Map<String, String> lessonTitles;
  final List<SrsState> savedStates = [];
  final List<Attempt> savedAttempts = [];
  final List<AuditLogEntry> auditLogs = [];

  @override
  Future<PracticeGroup?> findGroup(String groupId) async => groups[groupId];

  @override
  Future<SrsState?> findSrsState(String groupId) async => states[groupId];

  @override
  Future<void> saveGroup(PracticeGroup group) async {
    groups[group.id] = group;
  }

  @override
  Future<void> appendAuditLog(AuditLogEntry entry) async {
    auditLogs.add(entry);
  }

  @override
  Future<void> saveSrsState(SrsState state) async {
    states[state.groupId] = state;
    savedStates.add(state);
  }

  @override
  Future<void> saveAttempt(Attempt attempt) async {
    savedAttempts.add(attempt);
  }

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
        lessonContentHashes: {
          for (final group in groups.values)
            group.lessonId: '${group.lessonId}-hash',
        },
        groups: groups.values.toList(growable: false),
        srsStates: states.values.toList(growable: false),
        attempts: savedAttempts,
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
