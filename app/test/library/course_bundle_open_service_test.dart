// AI-Generate
import 'dart:io';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infra/infra.dart'
    show AtomicFileIo, DriftProgressRepository, createInMemoryAppDatabase;
import 'package:syllable_repeater_app/features/library/lesson_pack_service.dart';

void main() {
  test('AT-21-02 v3 latestProgress 以 updatedAt 較新者合併', () async {
    final workDir = await Directory.systemTemp.createTemp(
      'course-bundle-open-',
    );
    final db = createInMemoryAppDatabase();
    addTearDown(() async {
      await db.close();
      await workDir.delete(recursive: true);
    });
    final fileIo = AtomicFileIo(tempDirPath: workDir.path);
    final engine = CourseBundleEngine(fileIo: fileIo);
    final repository = DriftProgressRepository(db);
    final packPath = '${workDir.path}/course.abopack';
    final lesson = _lesson().withContentHash();
    final incomingUpdatedAt = DateTime.utc(2026, 7, 15, 10);
    await engine.write(
      CourseBundle(
        courseName: lesson.title,
        sourceAudioName: 'source.m4a',
        audioFingerprint: 'f' * 64,
        audioDurationMs: 1200,
        originalAudioBytes: Uint8List.fromList([1, 2, 3]),
        sentenceLesson: lesson,
        latestProgress: PortableLatestProgress(
          lastCompletedUnitIndex: 2,
          difficulty: Difficulty.normal,
          intervalIndex: 3,
          nextDue: DateTime.utc(2026, 7, 22),
          updatedAt: incomingUpdatedAt,
        ),
      ),
      packPath,
    );

    await AppCourseBundleOpenService(
      db: db,
      engine: engine,
      fileIo: fileIo,
      progressRepository: repository,
      decoder: const _FakeDecoder(),
    ).open(packPath);

    final group = await repository.findGroup('lesson-progress-step-2');
    final srs = await repository.findSrsState('lesson-progress-step-2');
    expect(group?.stepRange.startStepIndex, 2);
    expect(srs?.difficulty, Difficulty.normal);
    expect(srs?.intervalIndex, 3);
    expect(srs?.updatedAt, incomingUpdatedAt);

    final localNewerAt = DateTime.utc(2026, 7, 16, 10);
    await repository.saveSrsState(
      SrsState(
        groupId: 'lesson-progress-step-2',
        intervalIndex: 4,
        nextDue: DateTime.utc(2026, 7, 30),
        difficulty: Difficulty.easy,
        updatedAt: localNewerAt,
      ),
    );
    await AppCourseBundleOpenService(
      db: db,
      engine: engine,
      fileIo: fileIo,
      progressRepository: repository,
      decoder: const _FakeDecoder(),
    ).open(packPath);
    final preserved = await repository.findSrsState('lesson-progress-step-2');
    expect(preserved?.difficulty, Difficulty.easy);
    expect(preserved?.updatedAt, localNewerAt);
  });

  test('guardrails #62 切換課程清前一份解包音訊且不刪使用者 pack', () async {
    final workDir = await Directory.systemTemp.createTemp(
      'course-bundle-switch-',
    );
    final tempDir = Directory('${workDir.path}/session')..createSync();
    final db = createInMemoryAppDatabase();
    addTearDown(() async {
      await db.close();
      if (await workDir.exists()) await workDir.delete(recursive: true);
    });
    final fileIo = AtomicFileIo(tempDirPath: tempDir.path);
    final engine = CourseBundleEngine(fileIo: fileIo);
    final packPath = '${workDir.path}/user-course.abopack';
    await engine.write(
      CourseBundle(
        courseName: 'Course',
        sourceAudioName: 'source.m4a',
        audioFingerprint: 'a' * 64,
        audioDurationMs: 1200,
        originalAudioBytes: Uint8List.fromList([1, 2, 3]),
      ),
      packPath,
    );
    final service = AppCourseBundleOpenService(
      db: db,
      engine: engine,
      fileIo: fileIo,
      progressRepository: DriftProgressRepository(db),
      decoder: const _FakeDecoder(),
    );

    final first = await service.open(packPath);
    expect(File(first.extractedOriginalAudioPath).existsSync(), isTrue);
    final second = await service.open(packPath);
    expect(File(first.extractedOriginalAudioPath).existsSync(), isFalse);
    expect(File(second.extractedOriginalAudioPath).existsSync(), isTrue);
    expect(File(packPath).existsSync(), isTrue);

    await service.dispose();
    expect(File(second.extractedOriginalAudioPath).existsSync(), isFalse);
    expect(File(packPath).existsSync(), isTrue);
  });

  test('AT-10-07 解包後續失敗仍清除本次原音中介檔', () async {
    final workDir = await Directory.systemTemp.createTemp(
      'course-bundle-failure-',
    );
    final tempDir = Directory('${workDir.path}/session')..createSync();
    final db = createInMemoryAppDatabase();
    addTearDown(() async {
      await db.close();
      if (await workDir.exists()) await workDir.delete(recursive: true);
    });
    final fileIo = AtomicFileIo(tempDirPath: tempDir.path);
    final engine = CourseBundleEngine(fileIo: fileIo);
    final packPath = '${workDir.path}/user-course.abopack';
    final lesson = _lesson().withContentHash();
    await engine.write(
      CourseBundle(
        courseName: lesson.title,
        sourceAudioName: 'source.m4a',
        audioFingerprint: 'b' * 64,
        audioDurationMs: 1200,
        originalAudioBytes: Uint8List.fromList([1, 2, 3]),
        sentenceLesson: lesson,
        latestProgress: PortableLatestProgress(
          lastCompletedUnitIndex: 1,
          difficulty: Difficulty.normal,
          intervalIndex: 0,
          nextDue: DateTime.utc(2026, 7, 15),
          updatedAt: DateTime.utc(2026, 7, 15),
        ),
      ),
      packPath,
    );
    final service = AppCourseBundleOpenService(
      db: db,
      engine: engine,
      fileIo: fileIo,
      progressRepository: _ThrowingProgressRepository(db),
      decoder: const _FakeDecoder(),
    );

    await expectLater(service.open(packPath), throwsA(anything));

    expect(tempDir.listSync(), isEmpty);
    expect(File(packPath).existsSync(), isTrue);
  });
}

class _FakeDecoder implements AnalysisAudioDecoder {
  const _FakeDecoder();

  @override
  Future<Pcm> decode(String audioPath) async =>
      Pcm(Int16List(1200), sampleRate: 1000);
}

class _ThrowingProgressRepository extends DriftProgressRepository {
  _ThrowingProgressRepository(super.db);

  @override
  Future<SrsState?> findSrsState(String groupId) {
    throw StateError('故障注入');
  }
}

Lesson _lesson() => Lesson(
  id: 'lesson-progress',
  title: 'Progress Lesson',
  audioRelPath: 'audio/sentence.wav',
  originalAudioBytes: encodeWav(
    Pcm(Int16List.fromList([0, 1, 2, 3]), sampleRate: 1000),
  ),
  contentHash: '',
  words: [Word(text: 'progress', startMs: 0, endMs: 4, index: 0)],
  syllables: [
    Syllable(
      text: 'progress',
      startMs: 0,
      endMs: 4,
      wordIndex: 0,
      needsReview: false,
    ),
  ],
  translations: const [],
  prosody: null,
  practiceConfig: const PracticeConfig(repeatN: 3),
  updatedAt: DateTime.utc(2026, 7, 15),
);
