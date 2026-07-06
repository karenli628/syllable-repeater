// AI-Generate
// ProgressEngine 7.4 TDD-red：.aboprogress 匯入/匯出與 M6 合併防線。
import 'dart:convert';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

Matcher _domainError(String code) =>
    throwsA(isA<DomainException>().having((e) => e.code, 'code', code));

void main() {
  group('ProgressEngine export/import（task-split 7.4，M6/CT-06）', () {
    test('exportProgress 產出 schemaVersion=1 的 progress snapshot，且不含音訊或 key',
        () async {
      final fileIo = _MemoryFileIo();
      final repository = _MemoryProgressRepository(
        snapshot: ProgressSnapshot(
          profileId: 'profile-local',
          courseId: 'course-local',
          lessonContentHashes: const {'lesson-a': 'hash-a'},
          groups: [_group('group-a')],
          srsStates: [
            _state('group-a', DateTime.utc(2026, 7, 5, 9), Difficulty.normal),
          ],
          attempts: [_attempt('attempt-a', 'group-a')],
        ),
      );
      final engine = ProgressEngine(
        repository: repository,
        clock: _FakeClock(DateTime.utc(2026, 7, 6, 9)),
        fileIo: fileIo,
      );

      final path = await engine.exportProgress('/tmp/local.aboprogress');

      expect(path, '/tmp/local.aboprogress');
      final json =
          jsonDecode(utf8.decode(fileIo.bytesAt(path))) as Map<String, dynamic>;
      expect(json['schemaVersion'], 1);
      expect(json['progress']['profileId'], 'profile-local');
      expect(json['progress']['courseId'], 'course-local');
      expect(json['progress']['lessonContentHashes']['lesson-a'], 'hash-a');
      expect(json['progress']['groups'], hasLength(1));
      expect(json['progress']['srsStates'], hasLength(1));
      expect(json['progress']['attempts'], hasLength(1));

      final text = utf8.decode(fileIo.bytesAt(path), allowMalformed: true);
      expect(text.toLowerCase(), isNot(contains('api_key')));
      expect(text.toLowerCase(), isNot(contains('secret')));
      expect(text.toLowerCase(), isNot(contains('password')));
      expect(text.toLowerCase(), isNot(contains('credential')));
      expect(text.toLowerCase(), isNot(contains('audio')));
      expect(text, isNot(contains('/Users/')));
    });

    test('AT-08-03 incoming updatedAt 較新時覆寫本機版本', () async {
      final fileIo = _MemoryFileIo();
      final local = ProgressSnapshot(
        profileId: 'profile-local',
        courseId: 'course-local',
        lessonContentHashes: const {'lesson-a': 'hash-a'},
        groups: [
          _group('group-a',
              name: 'local older', updatedAt: DateTime.utc(2026, 7, 4, 10)),
        ],
        srsStates: [
          _state(
            'group-a',
            DateTime.utc(2026, 7, 5, 9),
            Difficulty.normal,
            updatedAt: DateTime.utc(2026, 7, 4, 10),
          ),
        ],
        attempts: const [],
      );
      final incoming = ProgressSnapshot(
        profileId: 'profile-local',
        courseId: 'course-local',
        lessonContentHashes: const {'lesson-a': 'hash-a'},
        groups: [
          _group('group-a',
              name: 'incoming newer', updatedAt: DateTime.utc(2026, 7, 4, 12)),
        ],
        srsStates: [
          _state(
            'group-a',
            DateTime.utc(2026, 7, 8, 9),
            Difficulty.easy,
            intervalIndex: 2,
            updatedAt: DateTime.utc(2026, 7, 4, 12),
          ),
        ],
        attempts: [_attempt('attempt-incoming', 'group-a')],
      );
      fileIo.store('/tmp/incoming.aboprogress', _progressFile(incoming));
      final repository = _MemoryProgressRepository(snapshot: local);
      final engine = ProgressEngine(
        repository: repository,
        clock: _FakeClock(DateTime.utc(2026, 7, 6, 9)),
        fileIo: fileIo,
      );

      final summary = await engine.importProgress('/tmp/incoming.aboprogress');

      expect(summary.applied, 3);
      expect(summary.skipped, 0);
      expect(summary.resetLessons, isEmpty);
      expect(repository.savedSnapshots, hasLength(1));
      expect(repository.snapshot.groups.single.name, 'incoming newer');
      expect(repository.snapshot.srsStates.single.intervalIndex, 2);
      expect(repository.snapshot.attempts.single.id, 'attempt-incoming');
    });

    test('重複匯入同檔為冪等；updatedAt 相等不覆寫', () async {
      final fileIo = _MemoryFileIo();
      final snapshot = ProgressSnapshot(
        profileId: 'profile-local',
        courseId: 'course-local',
        lessonContentHashes: const {'lesson-a': 'hash-a'},
        groups: [
          _group('group-a',
              name: 'same version', updatedAt: DateTime.utc(2026, 7, 4, 10)),
        ],
        srsStates: [
          _state(
            'group-a',
            DateTime.utc(2026, 7, 5, 9),
            Difficulty.normal,
            updatedAt: DateTime.utc(2026, 7, 4, 10),
          ),
        ],
        attempts: [_attempt('attempt-a', 'group-a')],
      );
      fileIo.store('/tmp/same.aboprogress', _progressFile(snapshot));
      final repository = _MemoryProgressRepository(snapshot: snapshot);
      final engine = ProgressEngine(
        repository: repository,
        clock: _FakeClock(DateTime.utc(2026, 7, 6, 9)),
        fileIo: fileIo,
      );

      final summary = await engine.importProgress('/tmp/same.aboprogress');

      expect(summary.applied, 0);
      expect(summary.skipped, 3);
      expect(summary.resetLessons, isEmpty);
      expect(repository.snapshot.groups.single.name, 'same version');
      expect(repository.savedSnapshots, hasLength(1));
    });

    test('AT-08-04 contentHash 變更只重置該 Lesson，不波及其他 Lesson', () async {
      final fileIo = _MemoryFileIo();
      final local = ProgressSnapshot(
        profileId: 'profile-local',
        courseId: 'course-local',
        lessonContentHashes: const {
          'lesson-x': 'local-hash-x',
          'lesson-y': 'hash-y',
        },
        groups: [
          _group('group-x', lessonId: 'lesson-x', name: 'Group X'),
          _group('group-y', lessonId: 'lesson-y', name: 'Group Y'),
        ],
        srsStates: [
          _state('group-x', DateTime.utc(2026, 7, 5, 9), Difficulty.normal),
          _state('group-y', DateTime.utc(2026, 7, 5, 9), Difficulty.hard),
        ],
        attempts: [
          _attempt('attempt-x', 'group-x'),
          _attempt('attempt-y', 'group-y'),
        ],
      );
      final incoming = ProgressSnapshot(
        profileId: 'profile-local',
        courseId: 'course-local',
        lessonContentHashes: const {
          'lesson-x': 'incoming-hash-x',
          'lesson-y': 'hash-y',
        },
        groups: [_group('incoming-x', lessonId: 'lesson-x')],
        srsStates: [
          _state('incoming-x', DateTime.utc(2026, 7, 8, 9), Difficulty.easy),
        ],
        attempts: [_attempt('incoming-attempt-x', 'incoming-x')],
      );
      fileIo.store('/tmp/hash-change.aboprogress', _progressFile(incoming));
      final repository = _MemoryProgressRepository(snapshot: local);
      final engine = ProgressEngine(
        repository: repository,
        clock: _FakeClock(DateTime.utc(2026, 7, 6, 9)),
        fileIo: fileIo,
      );

      final summary =
          await engine.importProgress('/tmp/hash-change.aboprogress');

      expect(summary.resetLessons, ['lesson-x']);
      expect(summary.applied, 0);
      expect(repository.snapshot.groups.map((g) => g.id), ['group-y']);
      expect(repository.snapshot.srsStates.map((s) => s.groupId), ['group-y']);
      expect(repository.snapshot.attempts.map((a) => a.id), ['attempt-y']);
      expect(
        repository.snapshot.lessonContentHashes,
        {'lesson-x': 'local-hash-x', 'lesson-y': 'hash-y'},
      );
    });

    test('AT-08-07 損毀 .aboprogress 拒絕且不部分套用', () {
      final fileIo = _MemoryFileIo()
        ..store('/tmp/broken.aboprogress', Uint8List.fromList([1, 2, 3, 4]));
      final repository = _MemoryProgressRepository(
        snapshot: ProgressSnapshot(
          profileId: 'profile-local',
          courseId: 'course-local',
          lessonContentHashes: const {'lesson-a': 'hash-a'},
          groups: [_group('group-a')],
          srsStates: [
            _state('group-a', DateTime.utc(2026, 7, 5, 9), Difficulty.normal),
          ],
          attempts: const [],
        ),
      );
      final engine = ProgressEngine(
        repository: repository,
        clock: _FakeClock(DateTime.utc(2026, 7, 6, 9)),
        fileIo: fileIo,
      );

      expect(
        engine.importProgress('/tmp/broken.aboprogress'),
        _domainError(ErrorCodes.progressCorrupted),
      );
      expect(repository.savedSnapshots, isEmpty);
      expect(repository.snapshot.groups.single.id, 'group-a');
    });
  });
}

Uint8List _progressFile(ProgressSnapshot snapshot) => Uint8List.fromList(
      utf8.encode(jsonEncode({
        'schemaVersion': 1,
        'exportedAt': DateTime.utc(2026, 7, 6, 9).toIso8601String(),
        'progress': snapshot.toJson(),
      })),
    );

PracticeGroup _group(
  String id, {
  String lessonId = 'lesson-a',
  String name = 'Group A',
  DateTime? updatedAt,
}) =>
    PracticeGroup(
      id: id,
      profileId: 'profile-local',
      courseId: 'course-local',
      lessonId: lessonId,
      name: name,
      stepRange: const StepRange(startStepIndex: 1, endStepIndex: 3),
      updatedAt: updatedAt ?? DateTime.utc(2026, 7, 4, 10),
    );

SrsState _state(
  String groupId,
  DateTime nextDue,
  Difficulty difficulty, {
  int intervalIndex = 1,
  DateTime? updatedAt,
}) =>
    SrsState(
      groupId: groupId,
      intervalIndex: intervalIndex,
      nextDue: nextDue,
      difficulty: difficulty,
      updatedAt: updatedAt ?? DateTime.utc(2026, 7, 4, 10),
    );

Attempt _attempt(String id, String groupId) => Attempt(
      id: id,
      groupId: groupId,
      stepIndex: 1,
      rhythmDelta: 0.1,
      intonationDelta: 0.2,
      overlayJson: '{"segments":[]}',
      createdAt: DateTime.utc(2026, 7, 4, 10),
    );

class _MemoryProgressRepository implements ProgressRepository {
  _MemoryProgressRepository({required this.snapshot});

  ProgressSnapshot snapshot;
  final List<ProgressSnapshot> savedSnapshots = [];
  final List<AuditLogEntry> auditLogs = [];

  @override
  Future<PracticeGroup?> findGroup(String groupId) async =>
      snapshot.groups.where((group) => group.id == groupId).firstOrNull;

  @override
  Future<SrsState?> findSrsState(String groupId) async =>
      snapshot.srsStates.where((state) => state.groupId == groupId).firstOrNull;

  @override
  Future<void> saveGroup(PracticeGroup group) async {}

  @override
  Future<void> appendAuditLog(AuditLogEntry entry) async {
    auditLogs.add(entry);
  }

  @override
  Future<void> saveSrsState(SrsState state) async {}

  @override
  Future<void> saveAttempt(Attempt attempt) async {}

  @override
  Future<List<ProgressDueCandidate>> dueCandidates(DateTime now) async => [];

  @override
  Future<List<ProgressArchivedCandidate>> archivedCandidates() async => [];

  @override
  Future<ProgressSnapshot> loadProgressSnapshot() async => snapshot;

  @override
  Future<void> saveProgressSnapshot(ProgressSnapshot next) async {
    snapshot = next;
    savedSnapshots.add(next);
  }

  @override
  Future<ReminderConfig?> loadReminderConfig() async => null;

  @override
  Future<void> saveReminderConfig(ReminderConfig config) async {}

  @override
  Future<SidecarConfig?> loadSidecarConfig() async => null;

  @override
  Future<void> saveSidecarConfig(SidecarConfig config) async {}
}

class _MemoryFileIo implements FileIo {
  final _files = <String, Uint8List>{};

  void store(String path, Uint8List bytes) {
    _files[path] = Uint8List.fromList(bytes);
  }

  Uint8List bytesAt(String path) => _files[path]!;

  @override
  Future<void> clearTemp() async {}

  @override
  Future<String> createTempFilePath(String suffix) async => '/tmp/fake$suffix';

  @override
  Future<void> delete(String path) async {
    _files.remove(path);
  }

  @override
  Future<bool> exists(String path) async => _files.containsKey(path);

  @override
  Future<Uint8List> readBytes(String path) async => _files[path]!;

  @override
  Future<void> writeBytesAtomic(String path, Uint8List bytes) async {
    _files[path] = Uint8List.fromList(bytes);
  }
}

class _FakeClock implements Clock {
  _FakeClock(this.current);

  DateTime current;

  @override
  DateTime now() => current;
}
