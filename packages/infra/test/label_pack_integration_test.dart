// AI-Generate
// `.abolabel` 真檔案＋Drift V3 跨層整合（AT-11-03/04、#48/#49）。
import 'dart:io';

import 'package:domain/domain.dart' as domain;
import 'package:drift/native.dart';
import 'package:infra/infra.dart';
import 'package:test/test.dart';

void main() {
  late Directory workDir;
  late AppDatabase db;
  late DriftLabelRegistryRepository repository;
  late AtomicFileIo fileIo;
  late domain.LabelPackEngine engine;

  setUp(() async {
    workDir = await Directory.systemTemp.createTemp('label-pack-integration-');
    await Directory('${workDir.path}/labels').create();
    db = AppDatabase(NativeDatabase(File('${workDir.path}/registry.sqlite')));
    repository = DriftLabelRegistryRepository(db);
    fileIo = AtomicFileIo(tempDirPath: '${workDir.path}/temp');
    engine = domain.LabelPackEngine(
      fileIo: fileIo,
      repository: repository,
      clock: FixedClock(DateTime.utc(2026, 7, 13, 10)),
    );
  });

  tearDown(() async {
    await db.close();
    await workDir.delete(recursive: true);
  });

  test('AT-11-03 真檔原子寫入、Drift 索引與完整讀回串接成功', () async {
    final session = _session()..moveBoundary(0, 1200);
    final path = '${workDir.path}/labels/song.abolabel';

    await engine.writeLabel(session, path);

    expect(await File(path).exists(), isTrue);
    expect(session.dirty, isFalse);
    final record = await repository.findByFingerprint(_fingerprint);
    expect(record?.labelPath, path);
    expect(record?.segmentCount, 2);
    expect(record?.updatedAt, DateTime.utc(2026, 7, 13, 10));

    final restored = await engine.readLabel(
      record!.labelPath,
      expectedFingerprint: _fingerprint,
    );
    expect(
      restored.segments
          .map((segment) => [
                segment.id,
                segment.startMs,
                segment.endMs,
                segment.text,
                segment.userAdjusted,
              ])
          .toList(),
      session.segments
          .map((segment) => [
                segment.id,
                segment.startMs,
                segment.endMs,
                segment.text,
                segment.userAdjusted,
              ])
          .toList(),
    );
    expect(restored.dirty, isFalse);
  });

  test('AT-11-04 索引指向遺失檔案時 fail-closed，不變更現有 session', () async {
    final current = _session()..moveBoundary(0, 1200);
    final before = List<domain.Segment>.of(current.segments);
    final missingPath = '${workDir.path}/labels/missing.abolabel';
    await repository.upsert(
      domain.LabelRegistryRecord(
        audioFingerprint: _fingerprint,
        labelPath: missingPath,
        segmentCount: 2,
        updatedAt: DateTime.utc(2026, 7, 13, 10),
      ),
    );

    await expectLater(
      engine.readLabel(
        missingPath,
        expectedFingerprint: _fingerprint,
      ),
      _domainError(domain.ErrorCodes.labelCorrupted),
    );
    expect(current.segments, before);
    expect(current.dirty, isTrue);
  });

  test('AT-11-03 索引指向損毀檔案時拒絕，不回傳部分 session', () async {
    final path = '${workDir.path}/labels/corrupt.abolabel';
    await File(path).writeAsBytes([1, 2, 3], flush: true);
    await repository.upsert(
      domain.LabelRegistryRecord(
        audioFingerprint: _fingerprint,
        labelPath: path,
        segmentCount: 99,
        updatedAt: DateTime.utc(2026, 7, 13, 10),
      ),
    );

    await expectLater(
      engine.readLabel(path, expectedFingerprint: _fingerprint),
      _domainError(domain.ErrorCodes.labelCorrupted),
    );
  });
}

domain.LabelSession _session() => domain.LabelSession(
      audioFingerprint: _fingerprint,
      audioDurationMs: 3000,
      language: 'en',
      separateVocals: true,
      segments: [
        domain.Segment(
          id: 'segment-1',
          startMs: 0,
          endMs: 1000,
          text: 'one',
          language: 'en',
          confidence: 0.9,
        ),
        domain.Segment(
          id: 'segment-2',
          startMs: 1000,
          endMs: 3000,
          text: 'two',
          language: 'en',
          confidence: 0.8,
        ),
      ],
    );

Matcher _domainError(String code) => throwsA(
      isA<domain.DomainException>().having(
        (error) => error.code,
        'code',
        code,
      ),
    );

const _fingerprint =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
