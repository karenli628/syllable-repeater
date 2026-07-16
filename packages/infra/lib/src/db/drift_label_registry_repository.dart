// AI-Generate
import 'package:domain/domain.dart' as domain;

import 'app_database.dart';

/// LabelRegistryRepository 的 Drift adapter（backend-design.md §3.1.1、OQ-6）。
class DriftLabelRegistryRepository implements domain.LabelRegistryRepository {
  /// 建立只保存標籤索引的 repository；不接觸音訊內容（M10）。
  const DriftLabelRegistryRepository(this._db);

  final AppDatabase _db;

  @override
  Future<domain.LabelRegistryRecord?> findByFingerprint(
    String audioFingerprint,
  ) async {
    final row = await (_db.select(_db.labelRegistry)
          ..where(
            (table) => table.audioFingerprint.equals(audioFingerprint),
          ))
        .getSingleOrNull();
    if (row == null) {
      return null;
    }
    return domain.LabelRegistryRecord(
      audioFingerprint: row.audioFingerprint,
      labelPath: row.labelPath,
      segmentCount: row.segmentCount,
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
    );
  }

  @override
  Future<void> upsert(domain.LabelRegistryRecord record) {
    return _db.into(_db.labelRegistry).insertOnConflictUpdate(
          LabelRegistryCompanion.insert(
            audioFingerprint: record.audioFingerprint,
            labelPath: record.labelPath,
            segmentCount: record.segmentCount,
            updatedAt: record.updatedAt.toUtc().millisecondsSinceEpoch,
          ),
        );
  }
}
