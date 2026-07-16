// AI-Generate
// Drift schema V1 結構測試（task-split 1.2）：
// 表齊備、attempt 表結構上無音訊欄位（CT-10 結構防線）、
// practice_group 無逾期/失敗欄位（M7 結構防線）。
import 'dart:io';

import 'package:drift/native.dart';
import 'package:infra/infra.dart';
import 'package:sqlite3/sqlite3.dart' as raw_sqlite;
import 'package:test/test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<List<String>> tableNames() async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table' "
            "AND name NOT LIKE 'sqlite_%'")
        .get();
    return rows.map((r) => r.read<String>('name')).toList();
  }

  Future<List<String>> columnsOf(String table) async {
    final rows = await db.customSelect('PRAGMA table_info($table)').get();
    return rows.map((r) => r.read<String>('name')).toList();
  }

  // AT-11-03：V3 必須建立 label_registry，且不移除任何既有表。
  test('七張表齊備且表名與設計一致（backend-design §3.1.2 / #22）', () async {
    final names = await tableNames();
    expect(
        names,
        containsAll([
          'lesson_registry',
          'practice_group',
          'srs_state',
          'attempt',
          'app_settings',
          'audit_log',
          'label_registry',
        ]));
  });

  // AT-11-03／M10：label_registry 僅能保存索引，不得保存音訊或錄音。
  test('label_registry 固定四欄且無音訊／錄音欄位（#43/#49）', () async {
    final cols = await columnsOf('label_registry');
    expect(
      cols,
      unorderedEquals([
        'audio_fingerprint',
        'label_path',
        'segment_count',
        'updated_at',
      ]),
      reason: '標籤索引只存指紋、路徑、段落數與時間，不得保存音訊內容',
    );
    for (final column in cols) {
      expect(column.toLowerCase(), isNot(contains('audio_bytes')));
      expect(column.toLowerCase(), isNot(contains('recording')));
      expect(column.toLowerCase(), isNot(contains('pcm')));
      expect(column.toLowerCase(), isNot(contains('blob')));
    }
  });

  test('所有持久表均沒有 RecordingBuffer 表或錄音／PCM 欄位（M10/#43）', () async {
    final names = await tableNames();
    expect(
      names.where((name) => name.toLowerCase().contains('recording')),
      isEmpty,
      reason: 'RecordingBuffer 只能存在 OS temp，不得建立 Drift 持久表',
    );

    const forbiddenFragments = [
      'recording',
      'pcm',
      'audio_bytes',
      'audio_blob',
      'audio_path',
      'recording_path',
      'pcm_path',
    ];
    for (final table in names) {
      final columns = await columnsOf(table);
      for (final column in columns) {
        final lower = column.toLowerCase();
        expect(
          forbiddenFragments.any(lower.contains),
          isFalse,
          reason: '$table.$column 不得持久化錄音或 PCM',
        );
      }
    }
  });

  // AT-11-03：V2→V3 migration 必須建立新表並保留既有 audit_log 資料。
  test('V2 升級 V3 建立 label_registry 且不破壞既有資料', () async {
    await db.close();
    final dir = await Directory.systemTemp.createTemp('db-v2-v3-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/migration.sqlite');
    final raw = raw_sqlite.sqlite3.open(file.path);
    raw.execute('''
      CREATE TABLE audit_log (
        id TEXT PRIMARY KEY,
        occurred_at INTEGER NOT NULL,
        actor TEXT NOT NULL,
        action TEXT NOT NULL,
        target_type TEXT NOT NULL,
        target_id TEXT,
        metadata_json TEXT NOT NULL
      )
    ''');
    raw.execute('''
      INSERT INTO audit_log
        (id, occurred_at, actor, action, target_type, target_id, metadata_json)
      VALUES
        ('audit-before-v3', 1, 'local-user', 'fixture', 'test', NULL, '{}')
    ''');
    raw.execute('PRAGMA user_version = 2');
    raw.dispose();

    final migrated = AppDatabase(NativeDatabase(file));
    addTearDown(migrated.close);
    final tables = await migrated
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    expect(
      tables.map((row) => row.read<String>('name')),
      contains('label_registry'),
    );
    final preserved = await migrated
        .customSelect("SELECT id FROM audit_log WHERE id='audit-before-v3'")
        .getSingle();
    expect(preserved.read<String>('id'), 'audit-before-v3');
    expect(migrated.schemaVersion, 3);
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

  test('audit_log 表結構不含 key/audio/recording/path 欄位（#22/M10/C6）', () async {
    final cols = await columnsOf('audit_log');
    expect(
        cols,
        unorderedEquals([
          'id',
          'occurred_at',
          'actor',
          'action',
          'target_type',
          'target_id',
          'metadata_json',
        ]));
    for (final c in cols) {
      expect(c.toLowerCase(), isNot(contains('api_key')));
      expect(c.toLowerCase(), isNot(contains('secret')));
      expect(c.toLowerCase(), isNot(contains('password')));
      expect(c.toLowerCase(), isNot(contains('audio')));
      expect(c.toLowerCase(), isNot(contains('recording')));
      expect(c.toLowerCase(), isNot(contains('path')));
    }
  });

  test('索引齊備（progress + audit log）', () async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='index' "
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
          'idx_audit_log_time',
          'idx_audit_log_action',
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
