// AI-Generate
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../errors.dart';
import '../labeling/label_session.dart';
import '../model/segment.dart';
import '../ports/clock.dart';
import '../ports/file_io.dart';
import '../ports/label_registry_repository.dart';

/// `.abolabel` 原子讀寫與全檔驗證引擎（backend-design.md 介面 22/23）。
class LabelPackEngine {
  static const int schemaVersion = 2;
  static const String labelJsonPath = 'label.json';

  final FileIo fileIo;
  final LabelRegistryRepository repository;
  final Clock clock;

  /// 注入檔案、索引與時間 ports，維持 Domain 純 Dart（REQ-11/M5）。
  const LabelPackEngine({
    required this.fileIo,
    required this.repository,
    required this.clock,
  });

  /// 原子寫入標籤檔；成功更新索引後才將 session 標成 CLEAN（AT-11-03）。
  Future<String> writeLabel(LabelSession session, String destPath) async {
    if (destPath.trim().isEmpty) {
      throw ArgumentError('destPath 不可空白');
    }
    final jsonBytes = utf8.encode(jsonEncode({
      'schemaVersion': schemaVersion,
      'audioFingerprint': session.audioFingerprint,
      'audioDurationMs': session.audioDurationMs,
      'language': session.language,
      'separateVocals': session.separateVocals,
      'segments': [
        for (final segment in session.segments)
          {
            'id': segment.id,
            'startMs': segment.startMs,
            'endMs': segment.endMs,
            'text': segment.text,
            'userAdjusted': segment.userAdjusted,
            'disposition': segment.disposition.name,
            if (segment.note != null) 'note': segment.note,
          },
      ],
    }));
    final archive = Archive()
      ..addFile(
        ArchiveFile(labelJsonPath, jsonBytes.length, jsonBytes),
      );
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw _labelCorrupted();
    }

    await fileIo.writeBytesAtomic(destPath, Uint8List.fromList(encoded));
    await repository.upsert(LabelRegistryRecord(
      audioFingerprint: session.audioFingerprint,
      labelPath: destPath,
      segmentCount: session.keptSegments.length,
      updatedAt: clock.now().toUtc(),
    ));
    session.markSaved();
    return destPath;
  }

  /// 全檔驗證 `.abolabel` 後回傳 CLEAN session（AT-11-03、#49）。
  Future<LabelSession> readLabel(
    String path, {
    required String expectedFingerprint,
  }) async {
    late LabelSession session;
    try {
      final bytes = await fileIo.readBytes(path);
      final archive = ZipDecoder().decodeBytes(bytes);
      if (archive.files.length != 1) {
        throw _labelCorrupted();
      }
      final labelFile = archive.findFile(labelJsonPath);
      if (labelFile == null || !labelFile.isFile) {
        throw _labelCorrupted();
      }
      final decoded = jsonDecode(utf8.decode(_bytesOf(labelFile)));
      if (decoded is! Map<String, dynamic>) {
        throw _labelCorrupted();
      }
      final readSchemaVersion = decoded['schemaVersion'];
      if (readSchemaVersion != 1 && readSchemaVersion != schemaVersion) {
        throw _labelCorrupted();
      }

      final fingerprint = decoded['audioFingerprint'];
      final durationMs = decoded['audioDurationMs'];
      final language = decoded['language'];
      final separateVocals = decoded['separateVocals'];
      final rawSegments = decoded['segments'];
      if (fingerprint is! String ||
          durationMs is! int ||
          language is! String ||
          separateVocals is! bool ||
          rawSegments is! List<dynamic>) {
        throw _labelCorrupted();
      }

      final segments = <Segment>[];
      for (final raw in rawSegments) {
        if (raw is! Map<String, dynamic>) {
          throw _labelCorrupted();
        }
        final id = raw['id'];
        final startMs = raw['startMs'];
        final endMs = raw['endMs'];
        final text = raw['text'];
        final userAdjusted = raw['userAdjusted'];
        final dispositionName = raw['disposition'];
        final note = raw['note'];
        if (id is! String ||
            startMs is! int ||
            endMs is! int ||
            text is! String ||
            userAdjusted is! bool ||
            (readSchemaVersion == schemaVersion &&
                dispositionName is! String) ||
            (note != null && note is! String)) {
          throw _labelCorrupted();
        }
        final disposition = readSchemaVersion == 1
            ? SegmentDisposition.kept
            : SegmentDisposition.values.firstWhere(
                (value) => value.name == dispositionName,
                orElse: () => throw _labelCorrupted(),
              );
        segments.add(Segment(
          id: id,
          startMs: startMs,
          endMs: endMs,
          text: text,
          language: language,
          confidence: 0,
          userAdjusted: userAdjusted,
          disposition: disposition,
          note: note as String?,
        ));
      }
      session = LabelSession(
        audioFingerprint: fingerprint,
        audioDurationMs: durationMs,
        language: language,
        separateVocals: separateVocals,
        segments: segments,
      );
    } on DomainException catch (error) {
      if (error.code == ErrorCodes.labelCorrupted) {
        rethrow;
      }
      throw _labelCorrupted();
    } catch (_) {
      throw _labelCorrupted();
    }

    if (session.audioFingerprint != expectedFingerprint) {
      throw const DomainException(
        ErrorCodes.labelFingerprintMismatch,
        '此標籤檔屬於另一個音檔',
      );
    }
    return session;
  }
}

Uint8List _bytesOf(ArchiveFile file) =>
    Uint8List.fromList(List<int>.from(file.content as Iterable<dynamic>));

DomainException _labelCorrupted() => const DomainException(
      ErrorCodes.labelCorrupted,
      '標籤檔損毀，未載入任何內容',
    );
