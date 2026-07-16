// AI-Generate
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../errors.dart';
import '../model/lesson.dart';
import '../ports/file_io.dart';

/// `.abopack` 讀寫與全檔結構驗證（backend-design.md §3.2.5 介面 9/10）。
class LessonPackEngine {
  static const int schemaVersion = 2;
  static const int legacySchemaVersion = 1;
  static const String manifestPath = 'manifest.json';

  final FileIo fileIo;

  const LessonPackEngine({required this.fileIo});

  Future<void> write(Lesson lesson, String destPath) async {
    final packedLesson = lesson.withContentHash();
    final manifestBytes = utf8.encode(jsonEncode({
      'schemaVersion': schemaVersion,
      'lesson': packedLesson.toJson(),
    }));

    final archive = Archive()
      ..addFile(ArchiveFile(manifestPath, manifestBytes.length, manifestBytes))
      ..addFile(ArchiveFile(
        packedLesson.audioRelPath,
        packedLesson.originalAudioBytes.length,
        packedLesson.originalAudioBytes,
      ));

    final bytes = ZipEncoder().encode(archive);
    if (bytes == null) {
      throw const DomainException(ErrorCodes.packCorrupted, '課件損毀，無法開啟');
    }
    await fileIo.writeBytesAtomic(destPath, Uint8List.fromList(bytes));
  }

  Future<Lesson> read(String path) async {
    try {
      final bytes = await fileIo.readBytes(path);
      final archive = ZipDecoder().decodeBytes(bytes);
      final manifest = archive.findFile(manifestPath);
      if (manifest == null || !manifest.isFile) {
        throw _packCorrupted();
      }

      final manifestJson = jsonDecode(utf8.decode(_bytesOf(manifest)));
      if (manifestJson is! Map<String, dynamic>) {
        throw _packCorrupted();
      }
      final version = manifestJson['schemaVersion'];
      if (version != schemaVersion && version != legacySchemaVersion) {
        throw _packCorrupted();
      }

      final lessonJson = manifestJson['lesson'];
      if (lessonJson is! Map<String, dynamic>) {
        throw _packCorrupted();
      }

      final audioRelPath = lessonJson['audioRelPath'];
      if (audioRelPath is! String) {
        throw _packCorrupted();
      }
      final audioFile = archive.findFile(audioRelPath);
      if (audioFile == null || !audioFile.isFile) {
        throw _packCorrupted();
      }

      final lesson = Lesson.fromJson(
        lessonJson,
        originalAudioBytes: _bytesOf(audioFile),
      );
      if (lesson.contentHash != lesson.recomputeContentHash()) {
        throw _packCorrupted();
      }
      return lesson;
    } on DomainException catch (error) {
      if (error.code == ErrorCodes.packCorrupted) {
        rethrow;
      }
      throw _packCorrupted();
    } catch (_) {
      throw _packCorrupted();
    }
  }
}

Uint8List _bytesOf(ArchiveFile file) =>
    Uint8List.fromList(List<int>.from(file.content as List<dynamic>));

DomainException _packCorrupted() =>
    const DomainException(ErrorCodes.packCorrupted, '課件損毀，無法開啟');
