// AI-Generate
// Drift schema V1 結構測試（task-split 1.2）：
// 五表齊備、attempt 表結構上無音訊欄位（CT-10 結構防線）、
// practice_group 無逾期/失敗欄位（M7 結構防線）。
import 'package:drift/native.dart';
import 'package:infra/infra.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<List<String>> tableNames() async {
    final rows = await db
        .customSelect(
            "SELECT name FROM sqlite_master WHERE type='table' "
            "AND name NOT LIKE 'sqlite_%'")
        .get();
    return rows.map((r) => r.read<String>('name')).toList();
  }

  Future<List<String>> columnsOf(String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return rows.map((r) => r.read<String>('name')).toList();
  }

  test('五張表齊備且表名與設計一致（backend-design §3.1.2）', () async {
    final names = await tableNames();
    expect(
        names,
        containsAll([
          'lesson_registry',
          'practice_group',
          'srs_state',
          'attempt',
          'app_settings',
        ]));
  });

  test('attempt 表結構上不存在音訊欄位（M10/CT-10 結構防線）', () async {
    final cols = await columnsOf('attempt');
    expect(
        cols,
        unorderedEquals([
          'id',
          'group_id',
          'step_index',
          'rhythm_delta',
          'intonation_delta',
          'overlay_json',
          'created_at',
        ]),
        reason: '欄位集固定——任何音訊/blob 欄位的加入都會使本測試失敗');
    for (final c in cols) {
      expect(c.toLowerCase(), isNot(contains('audio')));
      expect(c.toLowerCase(), isNot(contains('recording')));
    }
  });

  test('practice_group 無逾期/失敗/懲罰欄位（M7/CT-07 結構防線）', () async {
    final cols = await columnsOf('practice_group');
    for (final c in cols) {
      expect(c.toLowerCase(), isNot(contains('overdue')));
      expect(c.toLowerCase(), isNot(contains('fail')));
      expect(c.toLowerCase(), isNot(contains('penalty')));
    }
  });

  test('索引齊備（idx_pg_sync_key / idx_pg_status / idx_srs_due / idx_attempt_group）',
      () async {
    final rows = await db
        .customSelect(
            "SELECT name FROM sqlite_master WHERE type='index' "
            "AND name LIKE 'idx_%'")
        .get();
    final names = rows.map((r) => r.read<String>('name')).toList();
    expect(
        names,
        containsAll([
          'idx_pg_sync_key',
          'idx_pg_status',
          'idx_srs_due',
          'idx_attempt_group',
        ]));
  });

  test('app_settings 讀寫往返（Q9 三參數的儲存層）', () async {
    await db.into(db.appSettings).insert(
        AppSettingsCompanion.insert(key: 'reminder.minutes', value: '15'));
    final row = await (db.select(db.appSettings)
          ..where((t) => t.key.equals('reminder.minutes')))
        .getSingle();
    expect(row.value, '15');
  });

  test('practice_group 預設 status=ACTIVE（狀態機起點，§3.1.3）', () async {
    await db.into(db.lessonRegistry).insert(LessonRegistryCompanion.insert(
        id: 'L1',
        packPath: '/tmp/a.abopack',
        title: '金標準例句',
        contentHash: 'hash1',
        updatedAt: 0));
    await db.into(db.practiceGroups).insert(PracticeGroupsCompanion.insert(
        id: 'G1',
        profileId: 'P1',
        courseId: 'C1',
        lessonId: 'L1',
        name: '第一組',
        configJson: '{}',
        updatedAt: 0));
    final g = await (db.select(db.practiceGroups)
          ..where((t) => t.id.equals('G1')))
        .getSingle();
    expect(g.status, 'ACTIVE');
    expect(g.archivedAt, isNull);
  });
}
