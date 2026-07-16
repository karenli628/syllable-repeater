// AI-Generate
// LessonPackEngine .abopack TDD-red 測試（task-split 7.1）。
// 對應 REQ-07 AT-07-01/03/05 與 M5/M10。
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:domain/domain.dart';
import 'package:test/test.dart';

Matcher _domainError(String code) =>
    throwsA(isA<DomainException>().having((e) => e.code, 'code', code));

void main() {
  group('LessonPackEngine（task-split 7.1，REQ-07）', () {
    test('AT-07-01 write/read 金標準課件 round-trip，音訊位元級一致', () async {
      final fileIo = _MemoryFileIo();
      final engine = LessonPackEngine(fileIo: fileIo);
      final lesson = _goldenLesson(
        contentHash: 'stale-content-hash-must-be-recomputed',
      );

      await engine.write(lesson, '/tmp/she_has.abopack');
      final restored = await engine.read('/tmp/she_has.abopack');

      expect(restored.id, lesson.id);
      expect(restored.title, lesson.title);
      expect(restored.language, 'en');
      expect(restored.words, lesson.words);
      expect(restored.syllables, lesson.syllables);
      expect(restored.syllables.first.originalText, 'she-recognized');
      expect(restored.translations, lesson.translations);
      expect(restored.prosody, lesson.prosody);
      expect(restored.practiceConfig, lesson.practiceConfig);
      expect(restored.audioRelPath, 'audio/original.wav');
      expect(restored.originalAudioBytes, lesson.originalAudioBytes);
      expect(restored.contentHash, isNot(lesson.contentHash));
      expect(restored.contentHash, restored.recomputeContentHash());

      final archive = _decodePack(fileIo.bytesAt('/tmp/she_has.abopack'));
      final manifest = _manifestJson(archive);
      expect(manifest['schemaVersion'], 2);
      expect(manifest['lesson']['language'], 'en');
      expect(manifest['lesson']['contentHash'], restored.contentHash);
      expect(_entryBytes(archive, 'audio/original.wav'),
          lesson.originalAudioBytes);
    });

    test('AT-19-04 schemaVersion 2 round-trip 保存自訂排列與 stale 狀態', () async {
      final fileIo = _MemoryFileIo();
      final engine = LessonPackEngine(fileIo: fileIo);
      final arrangement = PracticeEngine()
          .generateArrangement(
            _goldenLesson().syllables,
            lessonId: 'lesson-she-has',
            updatedAt: DateTime.utc(2026, 7, 13, 14),
          )
          .markStale(updatedAt: DateTime.utc(2026, 7, 13, 14, 1));
      final lesson = _goldenLesson().copyWith(arrangement: arrangement);

      await engine.write(lesson, '/tmp/arranged.abopack');
      final restored = await engine.read('/tmp/arranged.abopack');

      expect(restored.arrangement, isNotNull);
      expect(restored.arrangement!.lessonId, 'lesson-she-has');
      expect(restored.arrangement!.rows, hasLength(11));
      expect(restored.arrangement!.staleFlag, isTrue);
      expect(restored.arrangement!.rows.last.blocks, hasLength(11));
      expect(restored.arrangement!.rows.last.blocks.last.repeatN, 1);
      expect(restored.arrangement!.rows.last.blocks.last.silenceFactor, 1);
      expect(restored.arrangement!.rows.last.repeatN, 3);
      expect(restored.arrangement!.rows.last.silenceFactor, 1);
      expect(restored.arrangement!.updatedAt, DateTime.utc(2026, 7, 13, 14, 1));

      final manifest = _manifestJson(
        _decodePack(fileIo.bytesAt('/tmp/arranged.abopack')),
      );
      expect(manifest['schemaVersion'], 2);
      expect(manifest['lesson']['arrangement'], isA<Map<String, dynamic>>());
    });

    test('AT-15-11 舊 pack 的 silenceFactor=2.5 原值 round-trip', () async {
      final fileIo = _MemoryFileIo();
      final engine = LessonPackEngine(fileIo: fileIo);
      final base = _goldenLesson();
      final arrangement = PracticeArrangement(
        lessonId: base.id,
        rows: [
          PracticeRow(
            index: 1,
            blocks: [
              PracticeBlock(
                syllables: [base.syllables.first],
                silenceFactor: 2.5,
              ),
            ],
          ),
        ],
        updatedAt: DateTime.utc(2026, 7, 14, 9),
      );

      await engine.write(
        base.copyWith(arrangement: arrangement),
        '/tmp/legacy-silence.abopack',
      );
      final restored = await engine.read('/tmp/legacy-silence.abopack');

      expect(
          restored.arrangement!.rows.single.blocks.single.silenceFactor, 2.5);
    });

    test('AT-15-13 舊排列缺 row config 時採現行預設 3／1', () {
      final syllable = _goldenLesson().syllables.first;
      final row = PracticeRow.fromJson({
        'index': 1,
        'blocks': [
          PracticeBlock(syllables: [syllable]).toJson(),
        ],
      });

      expect(row.repeatN, 3);
      expect(row.silenceFactor, 1);
    });

    test('AT-07-05 pack 不含 key、secret、password 或絕對路徑', () async {
      final fileIo = _MemoryFileIo();
      final engine = LessonPackEngine(fileIo: fileIo);

      await engine.write(_goldenLesson(), '/tmp/she_has.abopack');

      final archive = _decodePack(fileIo.bytesAt('/tmp/she_has.abopack'));
      expect(archive.files.map((f) => f.name),
          containsAll(['manifest.json', 'audio/original.wav']));
      for (final file in archive.files) {
        expect(file.name.startsWith('/'), isFalse,
            reason: 'pack entry 不可使用絕對路徑');
        expect(file.name.contains('..'), isFalse,
            reason: 'pack entry 不可包含 parent traversal');
      }

      final packText = utf8.decode(fileIo.bytesAt('/tmp/she_has.abopack'),
          allowMalformed: true);
      expect(packText.toLowerCase(), isNot(contains('api_key')));
      expect(packText.toLowerCase(), isNot(contains('secret')));
      expect(packText.toLowerCase(), isNot(contains('password')));
      expect(packText, isNot(contains('/Users/')));
    });

    test('AT-18-06 pack 不含 RecordingBuffer metadata、暫存檔名或 PCM 檔', () async {
      final fileIo = _MemoryFileIo();
      final engine = LessonPackEngine(fileIo: fileIo);

      await engine.write(_goldenLesson(), '/tmp/no-recording-buffer.abopack');

      final bytes = fileIo.bytesAt('/tmp/no-recording-buffer.abopack');
      final archive = _decodePack(bytes);
      final names = archive.files.map((file) => file.name).toList();
      expect(names, unorderedEquals(['manifest.json', 'audio/original.wav']));
      expect(
        names.where((name) =>
            name.endsWith('.pcm') ||
            name.endsWith('.meta.json') ||
            name.contains('recording_buffer') ||
            name.contains('recording-')),
        isEmpty,
      );

      final text = utf8.decode(bytes, allowMalformed: true).toLowerCase();
      for (final marker in [
        'recording_buffer',
        'recording-',
        '.meta.json',
        'pcmpath',
        'recordingpath',
        'attemptcontext',
      ]) {
        expect(text, isNot(contains(marker)),
            reason: 'pack 不得含暫存 marker=$marker');
      }
    });

    test('AT-07-03 損毀 zip 拋 ERR_PACK_CORRUPTED，不回傳部分 Lesson', () {
      final fileIo = _MemoryFileIo()
        ..store('/tmp/broken.abopack', Uint8List.fromList([1, 2, 3, 4]));
      final engine = LessonPackEngine(fileIo: fileIo);

      expect(
        engine.read('/tmp/broken.abopack'),
        _domainError(ErrorCodes.packCorrupted),
      );
    });

    test('AT-07-03 manifest 缺音訊檔時拒絕，不部分載入', () {
      final fileIo = _MemoryFileIo()
        ..store('/tmp/missing-audio.abopack', _packWithoutAudio());
      final engine = LessonPackEngine(fileIo: fileIo);

      expect(
        engine.read('/tmp/missing-audio.abopack'),
        _domainError(ErrorCodes.packCorrupted),
      );
    });

    test('AT-17-04 讀取無 language 的 v1 舊 pack 時補 en', () async {
      final fileIo = _MemoryFileIo()
        ..store('/tmp/legacy.abopack', _legacyPackWithoutLanguage());
      final engine = LessonPackEngine(fileIo: fileIo);

      final restored = await engine.read('/tmp/legacy.abopack');

      expect(restored.language, 'en');
    });
  });
}

Lesson _goldenLesson({String contentHash = ''}) {
  final syllables = [
    Syllable(
      text: 'she',
      originalText: 'she-recognized',
      startMs: 0,
      endMs: 200,
      wordIndex: 0,
      needsReview: false,
    ),
    Syllable(
        text: 'has',
        startMs: 200,
        endMs: 400,
        wordIndex: 1,
        needsReview: false),
    Syllable(
        text: 'ex', startMs: 400, endMs: 600, wordIndex: 2, needsReview: true),
    Syllable(
        text: 'cel', startMs: 600, endMs: 800, wordIndex: 2, needsReview: true),
    Syllable(
        text: 'lent',
        startMs: 800,
        endMs: 1000,
        wordIndex: 2,
        needsReview: true),
    Syllable(
        text: 'com',
        startMs: 1000,
        endMs: 1300,
        wordIndex: 3,
        needsReview: true),
    Syllable(
        text: 'mu',
        startMs: 1300,
        endMs: 1600,
        wordIndex: 3,
        needsReview: true),
    Syllable(
        text: 'ni',
        startMs: 1600,
        endMs: 1900,
        wordIndex: 3,
        needsReview: true),
    Syllable(
        text: 'ca',
        startMs: 1900,
        endMs: 2200,
        wordIndex: 3,
        needsReview: true),
    Syllable(
        text: 'tion',
        startMs: 2200,
        endMs: 2650,
        wordIndex: 3,
        needsReview: true),
    Syllable(
        text: 'skills',
        startMs: 2650,
        endMs: 3150,
        wordIndex: 4,
        needsReview: false),
  ];

  return Lesson(
    id: 'lesson-she-has',
    title: 'She has excellent communication skills',
    language: 'en',
    audioRelPath: 'audio/original.wav',
    originalAudioBytes: Uint8List.fromList(List.generate(32, (i) => i)),
    contentHash: contentHash,
    words: [
      Word(text: 'She', startMs: 0, endMs: 200, index: 0),
      Word(text: 'has', startMs: 200, endMs: 400, index: 1),
      Word(text: 'excellent', startMs: 400, endMs: 1000, index: 2),
      Word(text: 'communication', startMs: 1000, endMs: 2650, index: 3),
      Word(text: 'skills', startMs: 2650, endMs: 3150, index: 4),
    ],
    syllables: syllables,
    translations: [
      Translation(
        text: '她有出色的溝通能力',
        source: TranslationSource.manual,
        createdAt: DateTime.utc(2026, 7, 6, 9),
      ),
    ],
    prosody: Prosody(
      rhythm: [0.2, 0.5, 0.8],
      intensity: [0.1, 0.4, 0.7],
      stress: [0.0, 1.0, 0.0],
      pitchContour: [110.0, 125.0, 118.0],
      pitchAvailable: true,
    ),
    practiceConfig: const PracticeConfig(repeatN: 3),
    updatedAt: DateTime.utc(2026, 7, 6, 10),
  );
}

Archive _decodePack(Uint8List bytes) => ZipDecoder().decodeBytes(bytes);

Map<String, dynamic> _manifestJson(Archive archive) {
  final manifest = archive.findFile('manifest.json');
  if (manifest == null) {
    throw StateError('manifest.json missing');
  }
  return jsonDecode(utf8.decode(_contentBytes(manifest)))
      as Map<String, dynamic>;
}

Uint8List _entryBytes(Archive archive, String name) {
  final file = archive.findFile(name);
  if (file == null) {
    throw StateError('$name missing');
  }
  return _contentBytes(file);
}

Uint8List _contentBytes(ArchiveFile file) =>
    Uint8List.fromList(List<int>.from(file.content as Iterable<dynamic>));

Uint8List _packWithoutAudio() {
  final lesson = _goldenLesson().withContentHash();
  final archive = Archive()
    ..addFile(ArchiveFile(
      'manifest.json',
      0,
      utf8.encode(jsonEncode({
        'schemaVersion': 1,
        'lesson': lesson.toJson(),
      })),
    ));
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

Uint8List _legacyPackWithoutLanguage() {
  final lesson = _goldenLesson().withContentHash();
  final lessonJson = lesson.toJson()..remove('language');
  lessonJson.remove('arrangement');
  final manifestBytes = utf8.encode(jsonEncode({
    'schemaVersion': 1,
    'lesson': lessonJson,
  }));
  final archive = Archive()
    ..addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes))
    ..addFile(ArchiveFile(
      lesson.audioRelPath,
      lesson.originalAudioBytes.length,
      lesson.originalAudioBytes,
    ));
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
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
