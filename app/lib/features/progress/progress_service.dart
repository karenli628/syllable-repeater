// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infra/infra.dart'
    show
        AppDatabase,
        AtomicFileIo,
        DriftProgressRepository,
        createInMemoryAppDatabase;

import '../../shared/infra/sidecar_paths.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = createInMemoryAppDatabase();
  ref.onDispose(db.close);
  return db;
});

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  return DriftProgressRepository(ref.watch(appDatabaseProvider));
});

final progressServiceProvider = Provider<ProgressService>((ref) {
  final repository = ref.watch(progressRepositoryProvider);
  final paths = SidecarPaths.current();
  return DomainProgressService(
    repository,
    ProgressEngine(
      repository: repository,
      clock: const SystemClock(),
      fileIo: AtomicFileIo(tempDirPath: paths.tempDirectory),
    ),
  );
});

abstract interface class ProgressService {
  Future<void> ensurePracticeGroup(PracticeGroup group);

  Future<List<DueGroup>> dueList(DateTime now);

  Future<List<ArchivedGroup>> archivedGroups(DateTime now);

  Future<SrsState> settle(String groupId, Difficulty difficulty);

  Future<ReminderConfig> reminderConfig();

  Future<ReminderConfig> saveReminderConfig(ReminderConfig config);

  Future<SidecarConfig> sidecarConfig();

  Future<SidecarConfig> saveSidecarConfig(SidecarConfig config);

  Future<void> archive(String groupId);

  Future<void> restore(String groupId);

  Future<String> exportProgress(String destPath);

  Future<MergeSummary> importProgress(String path);
}

class DomainProgressService implements ProgressService {
  const DomainProgressService(this._repository, this._engine);

  final ProgressRepository _repository;
  final ProgressEngine _engine;

  @override
  Future<void> ensurePracticeGroup(PracticeGroup group) async {
    final existing = await _repository.findGroup(group.id);
    if (existing == null) {
      await _repository.saveGroup(group);
    }
  }

  @override
  Future<void> archive(String groupId) => _engine.archive(groupId);

  @override
  Future<List<ArchivedGroup>> archivedGroups(DateTime now) =>
      _engine.archivedGroups(now);

  @override
  Future<List<DueGroup>> dueList(DateTime now) => _engine.dueList(now);

  @override
  Future<String> exportProgress(String destPath) =>
      _engine.exportProgress(destPath);

  @override
  Future<MergeSummary> importProgress(String path) =>
      _engine.importProgress(path);

  @override
  Future<ReminderConfig> reminderConfig() => _engine.reminderConfig();

  @override
  Future<void> restore(String groupId) => _engine.restore(groupId);

  @override
  Future<ReminderConfig> saveReminderConfig(ReminderConfig config) =>
      _engine.setReminderConfig(config);

  @override
  Future<SidecarConfig> sidecarConfig() => _engine.sidecarConfig();

  @override
  Future<SidecarConfig> saveSidecarConfig(SidecarConfig config) =>
      _engine.setSidecarConfig(config);

  @override
  Future<SrsState> settle(String groupId, Difficulty difficulty) =>
      _engine.settle(groupId, difficulty);
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}
