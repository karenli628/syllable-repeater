// AI-Generate
import 'dart:convert';

import 'package:domain/domain.dart' as domain;

import 'app_database.dart';

/// Drift adapter for the per-Lesson display preference contract
/// (backend-design.md §3.2.6 interface 34).
///
/// The value is stored as one JSON map in the local settings table so that
/// [DriftProgressRepository] can include the same map in the `.aboprogress`
/// snapshot. It is never part of a Lesson or `.abopack` row.
class DriftSettingsService implements domain.SettingsService {
  static const transcriptDisplayModesSettingKey =
      'progress.transcriptDisplayModes';

  DriftSettingsService(this._db);

  final AppDatabase _db;

  @override
  Future<domain.TranscriptDisplayMode> getTranscriptMode(
    String lessonId,
  ) async {
    _requireLessonId(lessonId);
    final modes = await readTranscriptDisplayModes(_db);
    return modes[lessonId] ?? domain.TranscriptDisplayMode.transcript;
  }

  @override
  Future<void> setTranscriptMode(
    String lessonId,
    domain.TranscriptDisplayMode mode,
  ) async {
    _requireLessonId(lessonId);
    await _db.transaction(() async {
      final modes = await readTranscriptDisplayModes(_db);
      modes[lessonId] = mode;
      await writeTranscriptDisplayModes(_db, modes);
    });
  }

  /// 讀取供 ProgressRepository 組裝 `.aboprogress` 的顯示偏好欄位。
  static Future<Map<String, domain.TranscriptDisplayMode>>
      readTranscriptDisplayModes(AppDatabase db) async {
    final row = await (db.select(db.appSettings)
          ..where(
            (table) => table.key.equals(transcriptDisplayModesSettingKey),
          ))
        .getSingleOrNull();
    if (row == null || row.value.trim().isEmpty) {
      return <String, domain.TranscriptDisplayMode>{};
    }

    final decoded = jsonDecode(row.value);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('transcriptDisplayModes 儲存值格式錯誤');
    }
    final modes = <String, domain.TranscriptDisplayMode>{};
    for (final entry in decoded.entries) {
      if (entry.key.trim().isEmpty || entry.value is! String) {
        throw const FormatException('transcriptDisplayModes 儲存值格式錯誤');
      }
      modes[entry.key] =
          domain.TranscriptDisplayMode.fromJson(entry.value as String);
    }
    return modes;
  }

  /// 以原子 upsert 寫入快照的完整顯示偏好欄位；空 map 會清除舊偏好。
  static Future<void> writeTranscriptDisplayModes(
    AppDatabase db,
    Map<String, domain.TranscriptDisplayMode> modes,
  ) {
    return db.into(db.appSettings).insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: transcriptDisplayModesSettingKey,
            value: jsonEncode({
              for (final entry in modes.entries) entry.key: entry.value.value,
            }),
          ),
        );
  }
}

void _requireLessonId(String lessonId) {
  if (lessonId.trim().isEmpty) {
    throw ArgumentError('lessonId 不可空白');
  }
}
