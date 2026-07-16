// AI-Generate
// ProgressEngine 7.6 TDD-red：reminderConfig 預設值、設定往返與 #22 audit log。
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('ProgressEngine reminderConfig（task-split 7.6 / #22）', () {
    test('預設值為 15/5/2；設定不存在時不硬編碼在 UI', () async {
      final repository = _SettingsRepository();
      final engine = ProgressEngine(
        repository: repository,
        clock: _FakeClock(DateTime.utc(2026, 7, 6, 10)),
      );

      final config = await engine.reminderConfig();

      expect(config.minutesPerSession, 15);
      expect(config.failCapPerSession, 5);
      expect(config.dailySessions, 2);
    });

    test('設定寫入後可往返，且寫入一筆不含敏感資料的 audit log', () async {
      final repository = _SettingsRepository();
      final engine = ProgressEngine(
        repository: repository,
        clock: _FakeClock(DateTime.utc(2026, 7, 6, 10)),
      );
      const next = ReminderConfig(
        minutesPerSession: 20,
        failCapPerSession: 4,
        dailySessions: 3,
      );

      await engine.setReminderConfig(next);
      final loaded = await engine.reminderConfig();

      expect(loaded.minutesPerSession, 20);
      expect(loaded.failCapPerSession, 4);
      expect(loaded.dailySessions, 3);
      expect(repository.auditLogs, hasLength(1));
      final audit = repository.auditLogs.single;
      expect(audit.action, 'reminder_config_changed');
      expect(audit.targetType, 'app_settings');
      final auditText = '${audit.action} ${audit.targetId} ${audit.metadata}';
      expect(auditText.toLowerCase(), isNot(contains('api_key')));
      expect(auditText.toLowerCase(), isNot(contains('secret')));
      expect(auditText.toLowerCase(), isNot(contains('password')));
      expect(auditText.toLowerCase(), isNot(contains('audio')));
      expect(auditText.toLowerCase(), isNot(contains('recording')));
    });
  });

  group('ProgressEngine sidecarConfig（FP7 settings / #22）', () {
    test('預設 sidecar timeout 為 120 秒', () async {
      final repository = _SettingsRepository();
      final engine = ProgressEngine(
        repository: repository,
        clock: _FakeClock(DateTime.utc(2026, 7, 6, 10)),
      );

      final config = await engine.sidecarConfig();

      expect(config.timeoutSeconds, 120);
    });

    test('sidecar timeout 寫入 app_settings 並寫 audit log', () async {
      final repository = _SettingsRepository();
      final engine = ProgressEngine(
        repository: repository,
        clock: _FakeClock(DateTime.utc(2026, 7, 6, 10)),
      );
      const next = SidecarConfig(timeoutSeconds: 180);

      await engine.setSidecarConfig(next);
      final loaded = await engine.sidecarConfig();

      expect(loaded.timeoutSeconds, 180);
      expect(repository.auditLogs, hasLength(1));
      final audit = repository.auditLogs.single;
      expect(audit.action, 'sidecar_config_changed');
      expect(audit.targetType, 'app_settings');
      expect(audit.targetId, 'sidecar');
      expect(audit.metadata, {'timeoutSeconds': '180'});
    });
  });

  group('TranscriptDisplayMode（Task 7.1 / AT-19-03/04）', () {
    test('缺少 lesson 偏好時預設 transcript，且不同 lesson 相互隔離', () {
      final snapshot = ProgressSnapshot(
        profileId: 'profile-local',
        courseId: 'course-local',
        lessonContentHashes: const {'lesson-a': 'hash-a'},
        groups: const [],
        srsStates: const [],
        attempts: const [],
        transcriptDisplayModes: const {
          'lesson-a': TranscriptDisplayMode.translationOnly,
        },
      );

      expect(
        snapshot.transcriptModeForLesson('lesson-a'),
        TranscriptDisplayMode.translationOnly,
      );
      expect(
        snapshot.transcriptModeForLesson('lesson-b'),
        TranscriptDisplayMode.transcript,
      );
    });

    test('偏好欄位可隨 ProgressSnapshot JSON 往返，舊檔缺欄仍預設 transcript', () {
      final snapshot = ProgressSnapshot(
        profileId: 'profile-local',
        courseId: 'course-local',
        lessonContentHashes: const {'lesson-a': 'hash-a'},
        groups: const [],
        srsStates: const [],
        attempts: const [],
        transcriptDisplayModes: const {
          'lesson-a': TranscriptDisplayMode.transcriptWithTranslation,
          'lesson-b': TranscriptDisplayMode.hidden,
        },
      );

      final decoded = ProgressSnapshot.fromJson(snapshot.toJson());
      expect(decoded.transcriptDisplayModes, {
        'lesson-a': TranscriptDisplayMode.transcriptWithTranslation,
        'lesson-b': TranscriptDisplayMode.hidden,
      });

      final legacyJson = snapshot.toJson()..remove('transcriptDisplayModes');
      final legacy = ProgressSnapshot.fromJson(legacyJson);
      expect(
        legacy.transcriptModeForLesson('lesson-a'),
        TranscriptDisplayMode.transcript,
      );
    });

    test('SettingsService 契約可設定並讀回每課件模式', () async {
      final service = _MemorySettingsService();

      expect(
        await service.getTranscriptMode('lesson-a'),
        TranscriptDisplayMode.transcript,
      );
      await service.setTranscriptMode(
        'lesson-a',
        TranscriptDisplayMode.translationOnly,
      );

      expect(
        await service.getTranscriptMode('lesson-a'),
        TranscriptDisplayMode.translationOnly,
      );
      expect(
        await service.getTranscriptMode('lesson-b'),
        TranscriptDisplayMode.transcript,
      );
    });
  });
}

class _MemorySettingsService implements SettingsService {
  final Map<String, TranscriptDisplayMode> values = {};

  @override
  Future<TranscriptDisplayMode> getTranscriptMode(String lessonId) async =>
      values[lessonId] ?? TranscriptDisplayMode.transcript;

  @override
  Future<void> setTranscriptMode(
    String lessonId,
    TranscriptDisplayMode mode,
  ) async {
    values[lessonId] = mode;
  }
}

class _SettingsRepository implements ProgressRepository {
  ReminderConfig? config;
  SidecarConfig? sidecarConfig;
  final List<AuditLogEntry> auditLogs = [];

  @override
  Future<void> appendAuditLog(AuditLogEntry entry) async {
    auditLogs.add(entry);
  }

  @override
  Future<ReminderConfig?> loadReminderConfig() async => config;

  @override
  Future<SidecarConfig?> loadSidecarConfig() async => sidecarConfig;

  @override
  Future<void> saveReminderConfig(ReminderConfig config) async {
    this.config = config;
  }

  @override
  Future<void> saveSidecarConfig(SidecarConfig config) async {
    sidecarConfig = config;
  }

  @override
  Future<List<ProgressDueCandidate>> dueCandidates(DateTime now) async => [];

  @override
  Future<List<ProgressArchivedCandidate>> archivedCandidates() async => [];

  @override
  Future<PracticeGroup?> findGroup(String groupId) async => null;

  @override
  Future<SrsState?> findSrsState(String groupId) async => null;

  @override
  Future<ProgressSnapshot> loadProgressSnapshot() async => ProgressSnapshot(
        profileId: 'profile-local',
        courseId: 'course-local',
        lessonContentHashes: const {},
        groups: const [],
        srsStates: const [],
        attempts: const [],
      );

  @override
  Future<void> saveAttempt(Attempt attempt) async {}

  @override
  Future<void> saveGroup(PracticeGroup group) async {}

  @override
  Future<void> saveProgressSnapshot(ProgressSnapshot snapshot) async {}

  @override
  Future<void> saveSrsState(SrsState state) async {}
}

class _FakeClock implements Clock {
  _FakeClock(this.current);

  DateTime current;

  @override
  DateTime now() => current;
}
