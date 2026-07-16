// AI-Generate
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('LabelPackEngine（AT-11-03／#49）', () {
    test('AT-11-13 v2 round-trip 保留 kept／discarded／note', () async {
      final fileIo = _MemoryFileIo();
      final repository = _FakeRepository();
      final session = _session();
      session.moveBoundary(0, 1200);
      session.markDiscarded(TimeRange(1200, 1800), note: '狀聲詞');
      final engine = LabelPackEngine(
        fileIo: fileIo,
        repository: repository,
        clock: _FixedClock(),
      );

      final path = await engine.writeLabel(session, '/labels/song.abolabel');
      final restored = await engine.readLabel(
        path,
        expectedFingerprint: _fingerprint,
      );

      expect(path, '/labels/song.abolabel');
      expect(fileIo.atomicWriteCount, 1);
      expect(session.dirty, isFalse, reason: '成功寫入後才可 markSaved');
      expect(restored.audioFingerprint, _fingerprint);
      expect(restored.audioDurationMs, 3000);
      expect(restored.language, 'en');
      expect(restored.separateVocals, isTrue);
      expect(restored.keptSegments, hasLength(2));
      expect(restored.discardedSegments.single.note, '狀聲詞');
      expect(
        restored.segments
            .map((item) => [
                  item.id,
                  item.startMs,
                  item.endMs,
                  item.text,
                  item.userAdjusted,
                ])
            .toList(),
        session.segments
            .map((item) => [
                  item.id,
                  item.startMs,
                  item.endMs,
                  item.text,
                  item.userAdjusted,
                ])
            .toList(),
      );
      expect(restored.dirty, isFalse);

      final json = _labelJson(fileIo.bytesAt(path));
      expect(json['schemaVersion'], 2);
      expect(json['language'], 'en');
      expect(json['separateVocals'], isTrue);
      expect(json['segments'], hasLength(3));
      expect(repository.upserts, hasLength(1));
      expect(repository.upserts.single.segmentCount, 2,
          reason: '索引段數只計可送分析的 kept segments');
      expect(repository.upserts.single.updatedAt, DateTime.utc(2026, 7, 13));
    });

    test('AT-11-13 讀 v1 時既有 segments 全投影為 kept', () async {
      final fileIo = _MemoryFileIo()
        ..store('/labels/v1.abolabel', _v1Pack());
      final engine = LabelPackEngine(
        fileIo: fileIo,
        repository: _FakeRepository(),
        clock: _FixedClock(),
      );

      final restored = await engine.readLabel(
        '/labels/v1.abolabel',
        expectedFingerprint: _fingerprint,
      );

      expect(restored.keptSegments, hasLength(2));
      expect(restored.discardedSegments, isEmpty);
      expect(restored.segments,
          everyElement(isA<Segment>().having(
            (item) => item.disposition,
            'disposition',
            SegmentDisposition.kept,
          )));
    });

    test('損毀 zip 回 ERR_LABEL_CORRUPTED，且不寫 repository', () async {
      final fileIo = _MemoryFileIo()
        ..store('/labels/broken.abolabel', Uint8List.fromList([1, 2, 3]));
      final repository = _FakeRepository();
      final engine = LabelPackEngine(
        fileIo: fileIo,
        repository: repository,
        clock: _FixedClock(),
      );

      await expectLater(
        engine.readLabel(
          '/labels/broken.abolabel',
          expectedFingerprint: _fingerprint,
        ),
        _domainError(ErrorCodes.labelCorrupted),
      );
      expect(repository.upserts, isEmpty);
      expect(fileIo.atomicWriteCount, 0);
    });

    test('全檔驗證：任一 segment 重疊即拒絕，不回部分 session', () async {
      final fileIo = _MemoryFileIo()
        ..store('/labels/overlap.abolabel', _overlappingPack());
      final engine = LabelPackEngine(
        fileIo: fileIo,
        repository: _FakeRepository(),
        clock: _FixedClock(),
      );

      await expectLater(
        engine.readLabel(
          '/labels/overlap.abolabel',
          expectedFingerprint: _fingerprint,
        ),
        _domainError(ErrorCodes.labelCorrupted),
      );
    });

    test('指紋不符回 ERR_LABEL_FINGERPRINT_MISMATCH', () async {
      final fileIo = _MemoryFileIo();
      final engine = LabelPackEngine(
        fileIo: fileIo,
        repository: _FakeRepository(),
        clock: _FixedClock(),
      );
      await engine.writeLabel(_session(), '/labels/song.abolabel');

      await expectLater(
        engine.readLabel(
          '/labels/song.abolabel',
          expectedFingerprint:
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        ),
        _domainError(ErrorCodes.labelFingerprintMismatch),
      );
    });

    test('原子寫入失敗不 markSaved、不 upsert、也不留下目的檔', () async {
      final fileIo = _MemoryFileIo()..failAtomicWrite = true;
      final repository = _FakeRepository();
      final session = _session()..moveBoundary(0, 1200);
      final engine = LabelPackEngine(
        fileIo: fileIo,
        repository: repository,
        clock: _FixedClock(),
      );

      await expectLater(
        engine.writeLabel(session, '/labels/fail.abolabel'),
        throwsStateError,
      );
      expect(session.dirty, isTrue);
      expect(repository.upserts, isEmpty);
      expect(await fileIo.exists('/labels/fail.abolabel'), isFalse);
    });
  });
}

LabelSession _session() => LabelSession(
      audioFingerprint: _fingerprint,
      audioDurationMs: 3000,
      language: 'en',
      separateVocals: true,
      segments: [
        Segment(
          id: 's1',
          startMs: 0,
          endMs: 1000,
          text: 'one',
          language: 'en',
          confidence: 0.9,
        ),
        Segment(
          id: 's2',
          startMs: 1000,
          endMs: 3000,
          text: 'two',
          language: 'en',
          confidence: 0.8,
        ),
      ],
    );

Uint8List _overlappingPack() {
  final jsonBytes = utf8.encode(jsonEncode({
    'schemaVersion': 1,
    'audioFingerprint': _fingerprint,
    'audioDurationMs': 3000,
    'language': 'en',
    'separateVocals': false,
    'segments': [
      {
        'id': 's1',
        'startMs': 0,
        'endMs': 1600,
        'text': 'one',
        'userAdjusted': false,
      },
      {
        'id': 's2',
        'startMs': 1500,
        'endMs': 3000,
        'text': 'two',
        'userAdjusted': false,
      },
    ],
  }));
  final archive = Archive()
    ..addFile(ArchiveFile('label.json', jsonBytes.length, jsonBytes));
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

Uint8List _v1Pack() {
  final jsonBytes = utf8.encode(jsonEncode({
    'schemaVersion': 1,
    'audioFingerprint': _fingerprint,
    'audioDurationMs': 3000,
    'language': 'en',
    'separateVocals': false,
    'segments': [
      {
        'id': 'v1-1',
        'startMs': 0,
        'endMs': 1000,
        'text': 'one',
        'userAdjusted': false,
      },
      {
        'id': 'v1-2',
        'startMs': 1500,
        'endMs': 3000,
        'text': 'two',
        'userAdjusted': true,
      },
    ],
  }));
  final archive = Archive()
    ..addFile(ArchiveFile('label.json', jsonBytes.length, jsonBytes));
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

Map<String, dynamic> _labelJson(Uint8List bytes) {
  final file = ZipDecoder().decodeBytes(bytes).findFile('label.json')!;
  final content = Uint8List.fromList(
    List<int>.from(file.content as Iterable<dynamic>),
  );
  return jsonDecode(utf8.decode(content)) as Map<String, dynamic>;
}

Matcher _domainError(String code) => throwsA(
      isA<DomainException>().having((error) => error.code, 'code', code),
    );

class _MemoryFileIo implements FileIo {
  final _files = <String, Uint8List>{};
  bool failAtomicWrite = false;
  int atomicWriteCount = 0;

  void store(String path, Uint8List bytes) {
    _files[path] = Uint8List.fromList(bytes);
  }

  Uint8List bytesAt(String path) => _files[path]!;

  @override
  Future<void> clearTemp() async {}

  @override
  Future<String> createTempFilePath(String suffix) async => '/tmp/label$suffix';

  @override
  Future<void> delete(String path) async => _files.remove(path);

  @override
  Future<bool> exists(String path) async => _files.containsKey(path);

  @override
  Future<Uint8List> readBytes(String path) async => _files[path]!;

  @override
  Future<void> writeBytesAtomic(String path, Uint8List bytes) async {
    atomicWriteCount++;
    if (failAtomicWrite) {
      throw StateError('fixture atomic write failure');
    }
    _files[path] = Uint8List.fromList(bytes);
  }
}

class _FakeRepository implements LabelRegistryRepository {
  final upserts = <LabelRegistryRecord>[];

  @override
  Future<LabelRegistryRecord?> findByFingerprint(
          String audioFingerprint) async =>
      null;

  @override
  Future<void> upsert(LabelRegistryRecord record) async {
    upserts.add(record);
  }
}

class _FixedClock implements Clock {
  @override
  DateTime now() => DateTime.utc(2026, 7, 13);
}

const _fingerprint =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
