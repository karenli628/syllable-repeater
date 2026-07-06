// AI-Generate
// DriftProgressRepository：ProgressEngine 持久化 adapter 與 #22 audit log。
import 'package:domain/domain.dart' as domain;
import 'package:drift/native.dart';
import 'package:infra/infra.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftProgressRepository repository;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftProgressRepository(db);
    await _seedLesson(db);
  });

  tearDown(() => db.close());

  test('saveGroup/findGroup 保存 PracticeGroup 狀態與 stepRange', () async {
    final group = _group(
      status: domain.GroupStatus.archived,
      archivedAt: DateTime.utc(2026, 7, 1),
    );

    await repository.saveGroup(group);
    final loaded = await repository.findGroup('group-a');

    expect(loaded?.status, domain.GroupStatus.archived);
    expect(loaded?.archivedAt, DateTime.utc(2026, 7, 1));
    expect(loaded?.stepRange.startStepIndex, 1);
    expect(loaded?.stepRange.endStepIndex, 3);
  });

  test('saveGroup 會替未註冊 lesson 建立最小 registry row', () async {
    await repository.saveGroup(_group(id: 'group-b', lessonId: 'lesson-b'));

    final lesson = await (db.select(db.lessonRegistry)
          ..where((table) => table.id.equals('lesson-b')))
        .getSingle();
    expect(lesson.title, 'lesson-b');
    expect(lesson.packPath, isEmpty);
  });

  test('dueCandidates 由 Drift join 資料組出 lessonTitle', () async {
    await repository.saveGroup(_group());
    await repository.saveSrsState(
      domain.SrsState(
        groupId: 'group-a',
        intervalIndex: 1,
        nextDue: DateTime.utc(2026, 7, 5, 9),
        difficulty: domain.Difficulty.hard,
        updatedAt: DateTime.utc(2026, 7, 4, 9),
      ),
    );

    final due = await repository.dueCandidates(DateTime.utc(2026, 7, 6));

    expect(due, hasLength(1));
    expect(due.single.group.id, 'group-a');
    expect(due.single.lessonTitle, 'Communication Skills');
  });

  test('archivedCandidates 只列 ARCHIVED 並帶 lessonTitle', () async {
    await repository.saveGroup(
      _group(
        status: domain.GroupStatus.archived,
        archivedAt: DateTime.utc(2026, 7, 1),
      ),
    );
    await repository.saveGroup(_group(id: 'group-active'));

    final archived = await repository.archivedCandidates();

    expect(archived, hasLength(1));
    expect(archived.single.group.id, 'group-a');
    expect(archived.single.lessonTitle, 'Communication Skills');
  });

  test('reminderConfig 讀寫 app_settings，未設定時回 null 交 Domain 套預設', () async {
    expect(await repository.loadReminderConfig(), isNull);

    await repository.saveReminderConfig(
      const domain.ReminderConfig(
        minutesPerSession: 20,
        failCapPerSession: 4,
        dailySessions: 3,
      ),
    );
    final config = await repository.loadReminderConfig();

    expect(config?.minutesPerSession, 20);
    expect(config?.failCapPerSession, 4);
    expect(config?.dailySessions, 3);
  });

  test('sidecarConfig 讀寫 app_settings，未設定時回 null 交 Domain 套預設', () async {
    expect(await repository.loadSidecarConfig(), isNull);

    await repository.saveSidecarConfig(
      const domain.SidecarConfig(timeoutSeconds: 180),
    );
    final config = await repository.loadSidecarConfig();

    expect(config?.timeoutSeconds, 180);
  });

  test('appendAuditLog 寫 audit_log，metadata 不含 key/audio/recording/path',
      () async {
    await repository.appendAuditLog(
      domain.AuditLogEntry(
        occurredAt: DateTime.utc(2026, 7, 6, 10),
        actor: domain.AuditLogEntry.localActor,
        action: 'reminder_config_changed',
        targetType: 'app_settings',
        targetId: 'reminder',
        metadata: const {'minutesPerSession': '20'},
      ),
    );

    final row = await db.select(db.auditLogs).getSingle();
    expect(row.action, 'reminder_config_changed');
    final text = '${row.targetId} ${row.metadataJson}'.toLowerCase();
    expect(text, isNot(contains('api_key')));
    expect(text, isNot(contains('secret')));
    expect(text, isNot(contains('password')));
    expect(text, isNot(contains('audio')));
    expect(text, isNot(contains('recording')));
    expect(text, isNot(contains('/users/')));
  });

  test('saveProgressSnapshot 以 transaction 套用 snapshot', () async {
    final snapshot = domain.ProgressSnapshot(
      profileId: 'profile-local',
      courseId: 'course-local',
      lessonContentHashes: const {'lesson-a': 'hash-a2'},
      groups: [_group()],
      srsStates: [
        domain.SrsState(
          groupId: 'group-a',
          intervalIndex: 2,
          nextDue: DateTime.utc(2026, 7, 8, 9),
          difficulty: domain.Difficulty.easy,
          updatedAt: DateTime.utc(2026, 7, 6, 9),
        ),
      ],
      attempts: [
        domain.Attempt(
          id: 'attempt-a',
          groupId: 'group-a',
          stepIndex: 1,
          rhythmDelta: 0.1,
          intonationDelta: 0.2,
          overlayJson: '{"segments":[]}',
          createdAt: DateTime.utc(2026, 7, 6, 9),
        ),
      ],
    );

    await repository.saveProgressSnapshot(snapshot);
    final loaded = await repository.loadProgressSnapshot();

    expect(loaded.lessonContentHashes['lesson-a'], 'hash-a2');
    expect(loaded.groups.single.id, 'group-a');
    expect(loaded.srsStates.single.intervalIndex, 2);
    expect(loaded.attempts.single.id, 'attempt-a');
  });
}

Future<void> _seedLesson(AppDatabase db) {
  return db.into(db.lessonRegistry).insert(
        LessonRegistryCompanion.insert(
          id: 'lesson-a',
          packPath: '/tmp/a.abopack',
          title: 'Communication Skills',
          contentHash: 'hash-a',
          updatedAt: 0,
        ),
      );
}

domain.PracticeGroup _group({
  String id = 'group-a',
  String lessonId = 'lesson-a',
  domain.GroupStatus status = domain.GroupStatus.active,
  DateTime? archivedAt,
}) =>
    domain.PracticeGroup(
      id: id,
      profileId: 'profile-local',
      courseId: 'course-local',
      lessonId: lessonId,
      name: 'Group A',
      stepRange: const domain.StepRange(startStepIndex: 1, endStepIndex: 3),
      status: status,
      archivedAt: archivedAt,
      updatedAt: DateTime.utc(2026, 7, 4, 9),
    );
