// AI-Generate
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../errors.dart';
import '../model/course_bundle.dart';
import '../model/lesson.dart';
import '../model/practice_arrangement.dart';
import '../model/segment.dart';
import '../model/time_range.dart';
import '../ports/file_io.dart';
import 'lesson_pack_engine.dart';

/// `.abopack v3` 複合封包讀寫器（backend-design.md §3.2.5；REQ-21）。
class CourseBundleEngine {
  static const schemaVersion = 3;
  static const manifestPath = 'manifest.json';

  final FileIo fileIo;

  const CourseBundleEngine({required this.fileIo});

  /// 原子寫入完整來源原音與所有存在的可選區塊（REQ-21／M10）。
  Future<void> write(CourseBundle bundle, String destPath) async {
    final lesson = bundle.sentenceLesson?.withContentHash();
    if (lesson?.audioRelPath == CourseBundle.originalAudioRelPath) {
      throw ArgumentError('sentenceLesson.audioRelPath 不可覆蓋完整來源原音');
    }
    final manifest = <String, dynamic>{
      'schemaVersion': schemaVersion,
      'course': {
        'courseName': bundle.courseName,
        'sourceAudioName': bundle.sourceAudioName,
      },
      'originalAudio': {
        'relPath': CourseBundle.originalAudioRelPath,
        'fingerprint': bundle.audioFingerprint,
        'durationMs': bundle.audioDurationMs,
      },
      if (bundle.labels != null) 'labels': _labelsToJson(bundle.labels!),
      if (lesson != null) 'sentenceLesson': lesson.toJson(),
      if (bundle.sentenceSourceRange != null)
        'sentenceSourceRange': {
          'startMs': bundle.sentenceSourceRange!.startMs,
          'endMs': bundle.sentenceSourceRange!.endMs,
        },
      if (bundle.arrangement != null)
        'arrangement': bundle.arrangement!.toJson(),
      if (bundle.latestProgress != null)
        'latestProgress': bundle.latestProgress!.toJson(),
    };
    final manifestBytes = utf8.encode(jsonEncode(manifest));
    final archive = Archive()
      ..addFile(ArchiveFile(
        manifestPath,
        manifestBytes.length,
        manifestBytes,
      ))
      ..addFile(ArchiveFile(
        CourseBundle.originalAudioRelPath,
        bundle.originalAudioBytes.length,
        bundle.originalAudioBytes,
      ));
    if (lesson != null) {
      archive.addFile(ArchiveFile(
        lesson.audioRelPath,
        lesson.originalAudioBytes.length,
        lesson.originalAudioBytes,
      ));
    }
    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw _packCorrupted();
    }
    await fileIo.writeBytesAtomic(destPath, Uint8List.fromList(encoded));
  }

  /// 全檔驗證後才回傳 v3 聚合，避免損毀封包部分套用（REQ-21）。
  Future<CourseBundle> read(String path) async {
    try {
      final archive = ZipDecoder().decodeBytes(await fileIo.readBytes(path));
      final manifestFile = archive.findFile(manifestPath);
      if (manifestFile == null || !manifestFile.isFile) {
        throw _packCorrupted();
      }
      final raw = jsonDecode(utf8.decode(_bytesOf(manifestFile)));
      if (raw is! Map<String, dynamic>) {
        throw _packCorrupted();
      }
      final readVersion = raw['schemaVersion'];
      if (readVersion == LessonPackEngine.legacySchemaVersion ||
          readVersion == LessonPackEngine.schemaVersion) {
        return _upgradeLegacyLesson(
            await LessonPackEngine(fileIo: fileIo).read(path));
      }
      if (readVersion != schemaVersion) throw _packCorrupted();
      final course = raw['course'];
      final original = raw['originalAudio'];
      if (course is! Map<String, dynamic> ||
          original is! Map<String, dynamic>) {
        throw _packCorrupted();
      }
      final originalPath = original['relPath'];
      if (originalPath != CourseBundle.originalAudioRelPath) {
        throw _packCorrupted();
      }
      final originalFile = archive.findFile(originalPath as String);
      if (originalFile == null || !originalFile.isFile) {
        throw _packCorrupted();
      }

      Lesson? lesson;
      final rawLesson = raw['sentenceLesson'];
      if (rawLesson != null) {
        if (rawLesson is! Map<String, dynamic>) {
          throw _packCorrupted();
        }
        final lessonPath = rawLesson['audioRelPath'];
        if (lessonPath is! String || lessonPath == originalPath) {
          throw _packCorrupted();
        }
        final lessonFile = archive.findFile(lessonPath);
        if (lessonFile == null || !lessonFile.isFile) {
          throw _packCorrupted();
        }
        lesson = Lesson.fromJson(
          rawLesson,
          originalAudioBytes: _bytesOf(lessonFile),
        );
        if (lesson.contentHash != lesson.recomputeContentHash()) {
          throw _packCorrupted();
        }
      }

      final labels = raw['labels'];
      final arrangement = raw['arrangement'];
      final progress = raw['latestProgress'];
      final sentenceRange = raw['sentenceSourceRange'];
      return CourseBundle(
        courseName: course['courseName'] as String,
        sourceAudioName: course['sourceAudioName'] as String,
        audioFingerprint: original['fingerprint'] as String,
        audioDurationMs: original['durationMs'] as int,
        originalAudioBytes: _bytesOf(originalFile),
        labels: labels == null
            ? null
            : _labelsFromJson(labels as Map<String, dynamic>),
        sentenceLesson: lesson,
        sentenceSourceRange: sentenceRange == null
            ? null
            : TimeRange(
                (sentenceRange as Map<String, dynamic>)['startMs'] as int,
                sentenceRange['endMs'] as int,
              ),
        arrangement: arrangement == null
            ? null
            : PracticeArrangement.fromJson(
                arrangement as Map<String, dynamic>,
              ),
        latestProgress: progress == null
            ? null
            : PortableLatestProgress.fromJson(
                progress as Map<String, dynamic>,
              ),
      );
    } on DomainException catch (error) {
      if (error.code == ErrorCodes.packCorrupted) rethrow;
      throw _packCorrupted();
    } catch (_) {
      throw _packCorrupted();
    }
  }
}

CourseBundle _upgradeLegacyLesson(Lesson lesson) => CourseBundle(
      courseName: lesson.title,
      sourceAudioName: '${lesson.id}.wav',
      audioFingerprint: lesson.contentHash,
      audioDurationMs: lesson.syllables
          .map((syllable) => syllable.endMs)
          .reduce((a, b) => a > b ? a : b),
      originalAudioBytes: lesson.originalAudioBytes,
      sentenceLesson: lesson,
      arrangement: lesson.arrangement,
    );

Map<String, dynamic> _labelsToJson(CourseLabels labels) => {
      'language': labels.language,
      'separateVocals': labels.separateVocals,
      'segments': [
        for (final segment in labels.segments)
          {
            'id': segment.id,
            'startMs': segment.startMs,
            'endMs': segment.endMs,
            'text': segment.text,
            'confidence': segment.confidence,
            'userAdjusted': segment.userAdjusted,
            'disposition': segment.disposition.name,
            if (segment.note != null) 'note': segment.note,
          },
      ],
    };

CourseLabels _labelsFromJson(Map<String, dynamic> json) {
  final language = json['language'] as String;
  return CourseLabels(
    language: language,
    separateVocals: json['separateVocals'] as bool,
    segments: (json['segments'] as List<dynamic>).map((raw) {
      final item = raw as Map<String, dynamic>;
      return Segment(
        id: item['id'] as String,
        startMs: item['startMs'] as int,
        endMs: item['endMs'] as int,
        text: item['text'] as String,
        language: language,
        confidence: (item['confidence'] as num).toDouble(),
        userAdjusted: item['userAdjusted'] as bool,
        disposition: SegmentDisposition.values.byName(
          item['disposition'] as String,
        ),
        note: item['note'] as String?,
      );
    }).toList(growable: false),
  );
}

Uint8List _bytesOf(ArchiveFile file) =>
    Uint8List.fromList(List<int>.from(file.content as Iterable<dynamic>));

DomainException _packCorrupted() =>
    const DomainException(ErrorCodes.packCorrupted, '課件損毀，無法開啟');
