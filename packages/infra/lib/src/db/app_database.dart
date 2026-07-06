// AI-Generate
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'app_database.g.dart';

/// Drift schema V1（task-split 1.2；backend-design §3.1.2；OQ-3 已由使用者核可）。
/// 等效 SQL 見 packages/infra/lib/db/schema/V1__create_all.sql。
/// 時間欄位一律 epoch ms（UTC）之 INTEGER。

/// 課件註冊表：pack 位置與 content hash（M6 局部重置依據）。
class LessonRegistry extends Table {
  TextColumn get id => text()();
  TextColumn get packPath => text()();
  TextColumn get title => text()();
  TextColumn get contentHash => text()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 練習分組：進度/SRS 結算最小單位（限單一 Lesson 內）。
/// M7 結構防線：本表**沒有**任何逾期/失敗/懲罰欄位。
@TableIndex(
    name: 'idx_pg_sync_key', columns: {#profileId, #courseId, #lessonId})
@TableIndex(name: 'idx_pg_status', columns: {#status})
class PracticeGroups extends Table {
  @override
  String get tableName => 'practice_group';

  TextColumn get id => text()();
  TextColumn get profileId => text()();
  TextColumn get courseId => text()();
  TextColumn get lessonId => text().references(LessonRegistry, #id)();
  TextColumn get name => text()();
  TextColumn get configJson => text()();

  /// ACTIVE | ARCHIVED | EXPIRED（狀態機見 backend-design §3.1.3）。
  TextColumn get status => text().withDefault(const Constant('ACTIVE'))();

  /// M8：168h 恢復期限起算點。
  IntColumn get archivedAt => integer().nullable()();

  /// M6：upsert 比較鍵（較新覆寫）。
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// SRS 排程狀態：間隔序列 [0,1,3,7,14,30] 天之索引與下次到期。
@TableIndex(name: 'idx_srs_due', columns: {#nextDue})
class SrsStates extends Table {
  @override
  String get tableName => 'srs_state';

  TextColumn get groupId => text().references(PracticeGroups, #id)();
  IntColumn get intervalIndex => integer().withDefault(const Constant(0))();
  IntColumn get nextDue => integer()();

  /// HARD | NORMAL | EASY。
  TextColumn get difficulty => text().withDefault(const Constant('NORMAL'))();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {groupId};
}

/// 錄音嘗試紀錄。
/// M10 結構防線：只存參數與 overlay 快照——本表**結構上不存在**音訊欄位，
/// 使「保留錄音」在 schema 層即不可能（CT-10）。
@TableIndex(name: 'idx_attempt_group', columns: {#groupId, #createdAt})
class Attempts extends Table {
  @override
  String get tableName => 'attempt';

  TextColumn get id => text()();
  TextColumn get groupId => text().references(PracticeGroups, #id)();
  IntColumn get stepIndex => integer()();
  RealColumn get rhythmDelta => real()();
  RealColumn get intonationDelta => real()();
  TextColumn get overlayJson => text()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// 使用者可調設定（Q9 提醒三參數、sidecar 逾時等），key-value。
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// #22 Audit Log：本機自審用設定/狀態操作紀錄，非 immutable 稽核級。
/// M10/C6 結構防線：不存 API key、音訊 bytes、錄音路徑或檔案路徑。
@TableIndex(name: 'idx_audit_log_time', columns: {#occurredAt})
@TableIndex(name: 'idx_audit_log_action', columns: {#action})
class AuditLogs extends Table {
  @override
  String get tableName => 'audit_log';

  TextColumn get id => text()();
  IntColumn get occurredAt => integer()();
  TextColumn get actor => text()();
  TextColumn get action => text()();
  TextColumn get targetType => text()();
  TextColumn get targetId => text().nullable()();
  TextColumn get metadataJson => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    LessonRegistry,
    PracticeGroups,
    SrsStates,
    Attempts,
    AppSettings,
    AuditLogs,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(auditLogs);
          }
        },
      );
}

AppDatabase createInMemoryAppDatabase() => AppDatabase(NativeDatabase.memory());
