// AI-Generate
// DriftSettingsService：每 Lesson 顯示偏好與 `.aboprogress` 快照欄位（Task 7.1）。
import 'package:domain/domain.dart' as domain;
import 'package:drift/native.dart';
import 'package:infra/infra.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase db;
  late DriftSettingsService service;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    service = DriftSettingsService(db);
  });

  tearDown(() => db.close());

  test('缺少設定時回 transcript，且每 Lesson 隔離', () async {
    expect(
      await service.getTranscriptMode('lesson-a'),
      domain.TranscriptDisplayMode.transcript,
    );

    await service.setTranscriptMode(
      'lesson-a',
      domain.TranscriptDisplayMode.translationOnly,
    );

    expect(
      await service.getTranscriptMode('lesson-a'),
      domain.TranscriptDisplayMode.translationOnly,
    );
    expect(
      await service.getTranscriptMode('lesson-b'),
      domain.TranscriptDisplayMode.transcript,
    );
  });

  test('偏好進入 ProgressSnapshot，並可由快照保存後讀回', () async {
    await service.setTranscriptMode(
      'lesson-a',
      domain.TranscriptDisplayMode.hidden,
    );
    final repository = DriftProgressRepository(db);

    final loaded = await repository.loadProgressSnapshot();
    expect(
      loaded.transcriptDisplayModes['lesson-a'],
      domain.TranscriptDisplayMode.hidden,
    );

    await repository.saveProgressSnapshot(
      domain.ProgressSnapshot(
        profileId: loaded.profileId,
        courseId: loaded.courseId,
        lessonContentHashes: loaded.lessonContentHashes,
        groups: loaded.groups,
        srsStates: loaded.srsStates,
        attempts: loaded.attempts,
        transcriptDisplayModes: const {
          'lesson-b': domain.TranscriptDisplayMode.transcriptWithTranslation,
        },
      ),
    );

    final afterSave = await repository.loadProgressSnapshot();
    expect(afterSave.transcriptDisplayModes, {
      'lesson-b': domain.TranscriptDisplayMode.transcriptWithTranslation,
    });
    expect(
      await service.getTranscriptMode('lesson-a'),
      domain.TranscriptDisplayMode.transcript,
    );
    expect(
      await service.getTranscriptMode('lesson-b'),
      domain.TranscriptDisplayMode.transcriptWithTranslation,
    );
  });
}
