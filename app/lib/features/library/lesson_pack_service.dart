// AI-Generate
import 'package:domain/domain.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infra/infra.dart';

import '../../shared/infra/sidecar_paths.dart';
import '../editor/editor_controller.dart';
import '../import_analysis/analysis_controller.dart';
import '../pack_translate/lesson_session_controller.dart';
import '../progress/progress_service.dart' show appDatabaseProvider;

typedef LessonDraftBuilder = Lesson Function(String manualTranslation);

final lessonPackFilePickerProvider = Provider<LessonPackFilePicker>(
  (ref) => const FileSelectorLessonPackFilePicker(),
);

final lessonPackServiceProvider = Provider<LessonPackService>((ref) {
  final paths = SidecarPaths.current();
  return AppLessonPackService(
    db: ref.watch(appDatabaseProvider),
    engine: LessonPackEngine(
      fileIo: AtomicFileIo(tempDirPath: paths.tempDirectory),
    ),
  );
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

class AppLessonPackService implements LessonPackService {
  const AppLessonPackService({required this.db, required this.engine});

  final AppDatabase db;
  final LessonPackEngine engine;

  @override
  Future<Lesson> open(String path) async {
    final lesson = await engine.read(path);
    decodeWav(lesson.originalAudioBytes, failureMessage: '課件 WAV 解碼失敗');
    await _registerLesson(lesson, path);
    return lesson;
  }

  @override
  Future<String> save(Lesson lesson, String path) async {
    final packedLesson = lesson.withContentHash();
    await engine.write(packedLesson, path);
    await _registerLesson(packedLesson, path);
    return path;
  }

  Future<void> _registerLesson(Lesson lesson, String packPath) {
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
}

Lesson _buildLessonDraft(Ref ref, String manualTranslation) {
  final session = ref.read(lessonSessionControllerProvider);
  final editor = ref.read(editorControllerProvider);
  final loadedLesson = session.lesson;
  if (loadedLesson != null && editor.sourceLessonId == loadedLesson.id) {
    return _buildDraftFromLesson(loadedLesson, editor, manualTranslation);
  }

  final analysis = ref.read(analysisControllerProvider);
  final result = analysis.result;
  final pcm = analysis.latestEvent?.decodedPcm;
  if (result == null || pcm == null) {
    throw const DomainException(ErrorCodes.decodeFailed, '尚無可儲存的課件');
  }
  final now = DateTime.now().toUtc();
  final source = analysis.selectedAudioPath ?? result.source;
  final title = _lessonTitle(source);
  final manualText = manualTranslation.trim();
  return Lesson(
    id: _lessonId(title),
    title: title,
    audioRelPath: 'audio/original.wav',
    originalAudioBytes: encodeWav(pcm),
    contentHash: '',
    words: result.words,
    syllables: editor.syllables.isEmpty ? result.syllables : editor.syllables,
    translations: manualText.isEmpty
        ? const []
        : [
            Translation(
              text: manualText,
              source: TranslationSource.manual,
              createdAt: now,
            ),
          ],
    prosody: editor.prosodyValue,
    practiceConfig: const PracticeConfig(repeatN: 3),
    updatedAt: now,
  );
}

Lesson _buildDraftFromLesson(
  Lesson lesson,
  EditorUiState editor,
  String manualTranslation,
) {
  final now = DateTime.now().toUtc();
  final manualText = manualTranslation.trim();
  return Lesson(
    id: lesson.id,
    title: lesson.title,
    audioRelPath: lesson.audioRelPath,
    originalAudioBytes: lesson.originalAudioBytes,
    contentHash: lesson.contentHash,
    words: lesson.words,
    syllables: editor.syllables.isEmpty ? lesson.syllables : editor.syllables,
    translations: manualText.isEmpty
        ? const []
        : [
            Translation(
              text: manualText,
              source: TranslationSource.manual,
              createdAt: now,
            ),
          ],
    prosody: editor.prosodyValue ?? lesson.prosody,
    practiceConfig: lesson.practiceConfig,
    updatedAt: now,
  );
}

String _lessonTitle(String source) {
  final fileName = source.replaceAll('\\', '/').split('/').last;
  final dot = fileName.lastIndexOf('.');
  final stem = dot <= 0 ? fileName : fileName.substring(0, dot);
  return stem.trim().isEmpty ? 'Untitled Lesson' : stem;
}

String _lessonId(String title) {
  final normalized = title
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return normalized.isEmpty ? 'untitled-lesson' : normalized;
}
