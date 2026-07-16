// AI-Generate
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infra/infra.dart'
    show
        AppDatabase,
        AtomicFileIo,
        FfmpegDecoder,
        LessonRegistryCompanion,
        SidecarRunner;

import '../../shared/infra/sidecar_paths.dart';
import '../editor/editor_controller.dart';
import '../import_analysis/analysis_controller.dart';
import '../labeling/labeling_controller.dart';
import '../pack_translate/lesson_session_controller.dart';
import '../progress/progress_service.dart'
    show appDatabaseProvider, progressRepositoryProvider;

typedef LessonDraftBuilder = Lesson Function(String manualTranslation);

final lessonPackFilePickerProvider = Provider<LessonPackFilePicker>(
  (ref) => const FileSelectorLessonPackFilePicker(),
);

final lessonPackServiceProvider = Provider<LessonPackService>((ref) {
  final paths = SidecarPaths.current();
  return AppLessonPackService(
    db: ref.watch(appDatabaseProvider),
    engine: CourseBundleEngine(
      fileIo: AtomicFileIo(tempDirPath: paths.tempDirectory),
    ),
  );
});

final courseBundleOpenServiceProvider = Provider<CourseBundleOpenService>((
  ref,
) {
  final paths = SidecarPaths.current();
  final fileIo = AtomicFileIo(tempDirPath: paths.tempDirectory);
  final service = AppCourseBundleOpenService(
    db: ref.watch(appDatabaseProvider),
    engine: CourseBundleEngine(fileIo: fileIo),
    fileIo: fileIo,
    progressRepository: ref.watch(progressRepositoryProvider),
    decoder: FfmpegDecoder(
      runner: const SidecarRunner(),
      ffmpegPath: paths.ffmpegPath,
    ),
  );
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

final courseBundleSaveServiceProvider = Provider<CourseBundleSaveService>((
  ref,
) {
  final paths = SidecarPaths.current();
  return AppCourseBundleSaveService(
    db: ref.watch(appDatabaseProvider),
    engine: CourseBundleEngine(
      fileIo: AtomicFileIo(tempDirPath: paths.tempDirectory),
    ),
  );
});

typedef CourseBundleDraftBuilder = Future<CourseBundle> Function();

/// 彙整目前原音、標籤、單句與排列為 v3 草稿；沒有練習進度仍可保存。
final currentCourseBundleDraftBuilderProvider =
    Provider<CourseBundleDraftBuilder>((ref) {
      return () => _buildCourseBundleDraft(ref);
    });

final currentLessonDraftBuilderProvider = Provider<LessonDraftBuilder>(
  (ref) =>
      (manualTranslation) => _buildLessonDraft(ref, manualTranslation),
);

abstract interface class LessonPackFilePicker {
  Future<String?> pickOpenPath();

  Future<String?> pickSavePath();
}

class FileSelectorLessonPackFilePicker implements LessonPackFilePicker {
  const FileSelectorLessonPackFilePicker();

  static const _packType = XTypeGroup(
    label: 'AboPack',
    extensions: ['abopack'],
  );

  @override
  Future<String?> pickOpenPath() async {
    final file = await openFile(
      acceptedTypeGroups: const [_packType],
      confirmButtonText: '開啟',
    );
    return file?.path;
  }

  @override
  Future<String?> pickSavePath() async {
    final location = await getSaveLocation(
      acceptedTypeGroups: const [_packType],
      suggestedName: 'syllable-lesson.abopack',
      confirmButtonText: '儲存',
      canCreateDirectories: true,
    );
    final path = location?.path;
    if (path == null || path.toLowerCase().endsWith('.abopack')) {
      return path;
    }
    return '$path.abopack';
  }
}

abstract interface class LessonPackService {
  Future<Lesson> open(String path);

  Future<String> save(Lesson lesson, String path);
}

/// 已完整驗證的 v3 封包，以及供本機播放器使用的原始音訊暫存路徑（REQ-21）。
class OpenedCourseBundle {
  const OpenedCourseBundle({
    required this.bundle,
    required this.extractedOriginalAudioPath,
    required this.originalPcm,
  });

  final CourseBundle bundle;
  final String extractedOriginalAudioPath;
  final Pcm originalPcm;
}

abstract interface class CourseBundleOpenService {
  Future<OpenedCourseBundle> open(String path);
}

abstract interface class CourseBundleSaveService {
  Future<String> save(CourseBundle bundle, String path);
}

class AppCourseBundleSaveService implements CourseBundleSaveService {
  const AppCourseBundleSaveService({required this.db, required this.engine});

  final AppDatabase db;
  final CourseBundleEngine engine;

  @override
  Future<String> save(CourseBundle bundle, String path) async {
    await engine.write(bundle, path);
    final lesson = bundle.sentenceLesson;
    if (lesson != null) {
      final packed = lesson.withContentHash();
      await db
          .into(db.lessonRegistry)
          .insertOnConflictUpdate(
            LessonRegistryCompanion.insert(
              id: packed.id,
              packPath: path,
              title: packed.title,
              contentHash: packed.contentHash,
              updatedAt: packed.updatedAt.millisecondsSinceEpoch,
            ),
          );
    }
    return path;
  }
}

/// 讀取 `.abopack v3`，並將完整來源原音抽到受管理暫存區供標籤試聽。
class AppCourseBundleOpenService implements CourseBundleOpenService {
  AppCourseBundleOpenService({
    required this.db,
    required this.engine,
    required this.fileIo,
    required this.progressRepository,
    required this.decoder,
  });

  final AppDatabase db;
  final CourseBundleEngine engine;
  final FileIo fileIo;
  final ProgressRepository progressRepository;
  final AnalysisAudioDecoder decoder;
  String? _extractedPath;

  @override
  Future<OpenedCourseBundle> open(String path) async {
    final bundle = await engine.read(path);
    final extension = _supportedAudioExtension(bundle.sourceAudioName);
    final extractedPath = await fileIo.createTempFilePath('.$extension');
    try {
      await fileIo.writeBytesAtomic(extractedPath, bundle.originalAudioBytes);
      final originalPcm = await decoder.decode(extractedPath);
      final lesson = bundle.sentenceLesson;
      if (lesson != null) {
        await _upsertLessonRegistry(db, lesson, path);
        final latestProgress = bundle.latestProgress;
        if (latestProgress != null) {
          await _mergeLatestProgress(lesson, latestProgress);
        }
      }
      final previousPath = _extractedPath;
      if (previousPath != null && previousPath != extractedPath) {
        await fileIo.delete(previousPath);
      }
      _extractedPath = extractedPath;
      return OpenedCourseBundle(
        bundle: bundle,
        extractedOriginalAudioPath: extractedPath,
        originalPcm: originalPcm,
      );
    } catch (_) {
      await fileIo.delete(extractedPath);
      rethrow;
    }
  }

  /// 切課／離頁後清除目前解包原音；使用者 `.abopack` 不在此路徑內。
  Future<void> dispose() async {
    final path = _extractedPath;
    _extractedPath = null;
    if (path != null) await fileIo.delete(path);
  }

  Future<void> _mergeLatestProgress(
    Lesson lesson,
    PortableLatestProgress incoming,
  ) async {
    final groupId = '${lesson.id}-step-${incoming.lastCompletedUnitIndex}';
    final localSrs = await progressRepository.findSrsState(groupId);
    if (localSrs != null && !incoming.updatedAt.isAfter(localSrs.updatedAt)) {
      return;
    }
    final localGroup = await progressRepository.findGroup(groupId);
    if (localGroup == null) {
      await progressRepository.saveGroup(
        PracticeGroup(
          id: groupId,
          profileId: 'profile-local',
          courseId: 'course-local',
          lessonId: lesson.id,
          name: '第 ${incoming.lastCompletedUnitIndex} 單元',
          stepRange: StepRange(
            startStepIndex: incoming.lastCompletedUnitIndex,
            endStepIndex: incoming.lastCompletedUnitIndex,
          ),
          updatedAt: incoming.updatedAt,
        ),
      );
    }
    await progressRepository.saveSrsState(
      SrsState(
        groupId: groupId,
        intervalIndex: incoming.intervalIndex,
        nextDue: incoming.nextDue,
        difficulty: incoming.difficulty,
        updatedAt: incoming.updatedAt,
      ),
    );
  }
}

class AppLessonPackService implements LessonPackService {
  const AppLessonPackService({required this.db, required this.engine});

  final AppDatabase db;
  final CourseBundleEngine engine;

  @override
  Future<Lesson> open(String path) async {
    final bundle = await engine.read(path);
    final lesson = bundle.sentenceLesson;
    if (lesson == null) {
      throw const DomainException(
        ErrorCodes.packCorrupted,
        '此課程封包尚未包含可練習的單句課件',
      );
    }
    decodeWav(lesson.originalAudioBytes, failureMessage: '課件 WAV 解碼失敗');
    await _registerLesson(lesson, path);
    return lesson;
  }

  @override
  Future<String> save(Lesson lesson, String path) async {
    final packedLesson = lesson.withContentHash();
    final durationMs = decodeWav(
      packedLesson.originalAudioBytes,
      failureMessage: '課件 WAV 解碼失敗',
    ).durationMs;
    await engine.write(
      CourseBundle(
        courseName: packedLesson.title,
        sourceAudioName: '${packedLesson.id}.wav',
        audioFingerprint: packedLesson.contentHash,
        audioDurationMs: durationMs,
        originalAudioBytes: packedLesson.originalAudioBytes,
        sentenceLesson: packedLesson,
        sentenceSourceRange: TimeRange(0, durationMs),
        arrangement: packedLesson.arrangement,
      ),
      path,
    );
    await _registerLesson(packedLesson, path);
    return path;
  }

  Future<void> _registerLesson(Lesson lesson, String packPath) {
    return _upsertLessonRegistry(db, lesson, packPath);
  }
}

Future<void> _upsertLessonRegistry(
  AppDatabase db,
  Lesson lesson,
  String packPath,
) {
  return db
      .into(db.lessonRegistry)
      .insertOnConflictUpdate(
        LessonRegistryCompanion.insert(
          id: lesson.id,
          packPath: packPath,
          title: lesson.title,
          contentHash: lesson.contentHash,
          updatedAt: lesson.updatedAt.millisecondsSinceEpoch,
        ),
      );
}

String _supportedAudioExtension(String sourceAudioName) {
  final dot = sourceAudioName.lastIndexOf('.');
  final extension = dot < 0
      ? ''
      : sourceAudioName.substring(dot + 1).toLowerCase();
  return const {'mp3', 'wav', 'm4a', 'flac'}.contains(extension)
      ? extension
      : 'bin';
}

Lesson _buildLessonDraft(Ref ref, String manualTranslation) {
  final session = ref.read(lessonSessionControllerProvider);
  final editor = ref.read(editorControllerProvider);
  final loadedLesson = session.lesson;
  final aiTranslation = ref.read(analysisControllerProvider).aiTranslation;
  if (loadedLesson != null && editor.sourceLessonId == loadedLesson.id) {
    return _buildDraftFromLesson(
      loadedLesson,
      editor,
      manualTranslation,
      aiTranslation: aiTranslation,
    );
  }

  final analysis = ref.read(analysisControllerProvider);
  final result = analysis.result;
  final pcm = analysis.latestEvent?.decodedPcm;
  final draftLessonId =
      editor.sourceLessonId ?? analysis.draftIdentity?.lessonId;
  if (result == null || pcm == null || draftLessonId == null) {
    throw const DomainException(ErrorCodes.decodeFailed, '尚無可儲存的課件');
  }
  final now = DateTime.now().toUtc();
  final source = analysis.selectedAudioPath ?? result.source;
  final title = _lessonTitle(source);
  final manualText = manualTranslation.trim();
  final translations = manualText.isNotEmpty
      ? [
          Translation(
            text: manualText,
            source: TranslationSource.manual,
            createdAt: now,
          ),
        ]
      : aiTranslation == null
      ? const <Translation>[]
      : [aiTranslation];
  return Lesson(
    id: draftLessonId,
    title: title,
    audioRelPath: 'audio/original.wav',
    originalAudioBytes: encodeWav(pcm),
    contentHash: '',
    words: result.words,
    syllables: editor.syllables.isEmpty ? result.syllables : editor.syllables,
    translations: translations,
    prosody: editor.prosodyValue,
    practiceConfig: const PracticeConfig(repeatN: 3),
    arrangement: editor.arrangement,
    updatedAt: now,
  );
}

Lesson _buildDraftFromLesson(
  Lesson lesson,
  EditorUiState editor,
  String manualTranslation, {
  Translation? aiTranslation,
}) {
  final now = DateTime.now().toUtc();
  final manualText = manualTranslation.trim();
  final translations = manualText.isNotEmpty
      ? [
          Translation(
            text: manualText,
            source: TranslationSource.manual,
            createdAt: now,
          ),
        ]
      : aiTranslation == null
      ? lesson.translations
      : [aiTranslation];
  return Lesson(
    id: lesson.id,
    title: lesson.title,
    audioRelPath: lesson.audioRelPath,
    originalAudioBytes: lesson.originalAudioBytes,
    contentHash: lesson.contentHash,
    words: lesson.words,
    syllables: editor.syllables.isEmpty ? lesson.syllables : editor.syllables,
    translations: translations,
    prosody: editor.prosodyValue ?? lesson.prosody,
    practiceConfig: lesson.practiceConfig,
    arrangement: editor.arrangement,
    updatedAt: now,
  );
}

String _lessonTitle(String source) {
  final fileName = source.replaceAll('\\', '/').split('/').last;
  final dot = fileName.lastIndexOf('.');
  final stem = dot <= 0 ? fileName : fileName.substring(0, dot);
  return stem.trim().isEmpty ? 'Untitled Lesson' : stem;
}

Future<CourseBundle> _buildCourseBundleDraft(Ref ref) async {
  Lesson? lesson;
  try {
    lesson = ref.read(currentLessonDraftBuilderProvider)('').withContentHash();
  } on Object {
    lesson = ref
        .read(lessonSessionControllerProvider)
        .lesson
        ?.withContentHash();
  }
  final labeling = ref.read(labelingControllerProvider);
  final analysis = ref.read(analysisControllerProvider);
  final labelSession = labeling.session;
  final sourcePath =
      _audioSourcePath(labeling.audioPath) ??
      _audioSourcePath(analysis.selectedAudioPath);

  late Uint8List sourceBytes;
  if (sourcePath != null) {
    sourceBytes = Uint8List.fromList(await File(sourcePath).readAsBytes());
  } else if (lesson != null) {
    sourceBytes = lesson.originalAudioBytes;
  } else {
    throw const DomainException(ErrorCodes.decodeFailed, '目前沒有可封裝的原始音訊');
  }
  final sourceName = sourcePath == null
      ? '${lesson!.title}.wav'
      : sourcePath.replaceAll('\\', '/').split('/').last;
  final pcmDuration =
      analysis.latestEvent?.decodedPcm?.durationMs ??
      ref.read(lessonSessionControllerProvider).pcm?.durationMs;
  final durationMs =
      labelSession?.audioDurationMs ??
      pcmDuration ??
      (lesson == null ? 0 : lesson.syllables.last.endMs);
  if (durationMs <= 0) {
    throw const DomainException(ErrorCodes.decodeFailed, '無法確認原始音訊長度');
  }
  final fingerprint =
      labelSession?.audioFingerprint ??
      lesson?.contentHash ??
      'local-${sourceBytes.length}-$durationMs';
  final latestProgress = lesson == null
      ? null
      : await _portableLatestProgress(ref, lesson.id);
  return CourseBundle(
    courseName: lesson?.title ?? _lessonTitle(sourceName),
    sourceAudioName: sourceName,
    audioFingerprint: fingerprint,
    audioDurationMs: durationMs,
    originalAudioBytes: sourceBytes,
    labels: labelSession == null
        ? null
        : CourseLabels(
            language: labelSession.language,
            separateVocals: labelSession.separateVocals,
            segments: labelSession.segments,
          ),
    sentenceLesson: lesson,
    sentenceSourceRange: lesson == null
        ? null
        : analysis.pendingSegment?.range ??
              TimeRange(0, lesson.syllables.last.endMs),
    arrangement: lesson?.arrangement,
    latestProgress: latestProgress,
  );
}

Future<PortableLatestProgress?> _portableLatestProgress(
  Ref ref,
  String lessonId,
) async {
  final snapshot = await ref
      .read(progressRepositoryProvider)
      .loadProgressSnapshot();
  final groups =
      snapshot.groups.where((group) => group.lessonId == lessonId).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  for (final group in groups) {
    final states =
        snapshot.srsStates.where((item) => item.groupId == group.id).toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final attempts =
        snapshot.attempts.where((item) => item.groupId == group.id).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (states.isEmpty) continue;
    final srs = states.first;
    final attempt = attempts.isEmpty ? null : attempts.first;
    return PortableLatestProgress(
      lastCompletedUnitIndex:
          attempt?.stepIndex ?? group.stepRange.endStepIndex,
      difficulty: srs.difficulty,
      intervalIndex: srs.intervalIndex,
      nextDue: srs.nextDue,
      updatedAt: srs.updatedAt,
      rhythmScore: attempt == null
          ? null
          : (1 - attempt.rhythmDelta).clamp(0.0, 1.0),
      intonationScore: attempt == null
          ? null
          : (1 - attempt.intonationDelta).clamp(0.0, 1.0),
    );
  }
  return null;
}

String? _audioSourcePath(String? path) {
  if (path == null) return null;
  final extension = path.split('.').last.toLowerCase();
  return const {'mp3', 'wav', 'm4a', 'flac'}.contains(extension) ? path : null;
}
