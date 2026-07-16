// AI-Generate
import 'dart:async';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:test/test.dart';

void main() {
  group('LabelSession 不變式（AT-11-02／AT-11-04）', () {
    test('AT-11-12 保留／捨棄可有未標記間隙，只有 keptSegments 可送分析', () {
      final session = LabelSession(
        audioFingerprint: _fingerprint,
        audioDurationMs: 10000,
        segments: const [],
      );

      session.markDiscarded(TimeRange(0, 2000), note: '前導無聲');
      session.markKept(TimeRange(2500, 4200), text: 'sentence one');
      session.markDiscarded(TimeRange(7000, 7600), note: '狀聲詞');
      session.markKept(TimeRange(8000, 10000), text: 'sentence two');

      expect(session.segments, hasLength(4));
      expect(session.keptSegments.map((item) => item.text),
          ['sentence one', 'sentence two']);
      expect(session.discardedSegments.map((item) => item.note),
          ['前導無聲', '狀聲詞']);
      expect(session.segments.map((item) => item.disposition), [
        SegmentDisposition.discarded,
        SegmentDisposition.kept,
        SegmentDisposition.discarded,
        SegmentDisposition.kept,
      ]);
      expect(session.dirty, isTrue);
    });

    test('AT-11-15 清除註記後回到未標記，不自動併入相鄰 kept', () {
      final session = LabelSession(
        audioFingerprint: _fingerprint,
        audioDurationMs: 5000,
        segments: const [],
      );
      session.markKept(TimeRange(0, 1000), text: 'one');
      session.markDiscarded(TimeRange(1000, 2000), note: 'noise');
      session.markKept(TimeRange(2000, 3000), text: 'two');

      final discardedId = session.discardedSegments.single.id;
      session.clearDisposition(discardedId);

      expect(session.segments, hasLength(2));
      expect(session.keptSegments.map((item) => item.range),
          [TimeRange(0, 1000), TimeRange(2000, 3000)]);
    });

    test('建立時要求 segments 單調、不重疊且落在音檔時長內', () {
      expect(
        () => LabelSession(
          audioFingerprint: _fingerprint,
          audioDurationMs: 3000,
          segments: [
            _segment('s1', 0, 1600, 'one'),
            _segment('s2', 1500, 3000, 'two'),
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => LabelSession(
          audioFingerprint: _fingerprint,
          audioDurationMs: 3000,
          segments: [_segment('s1', 0, 3001, 'one')],
        ),
        throwsArgumentError,
      );
    });

    test('移動邊界置 dirty；undo 還原；markSaved 回 CLEAN', () {
      final session = _session();

      session.moveBoundary(0, 1200);

      expect(session.segments[0].endMs, 1200);
      expect(session.segments[1].startMs, 1200);
      expect(session.segments[0].userAdjusted, isTrue);
      expect(session.dirty, isTrue);
      expect(() => session.segments.add(_segment('x', 0, 1, 'x')),
          throwsUnsupportedError);

      expect(session.undo(), isTrue);
      expect(session.segments[0].endMs, 1000);
      expect(session.segments[1].startMs, 1000);
      expect(session.dirty, isFalse);

      session.moveBoundary(0, 1200);
      session.markSaved();
      expect(session.dirty, isFalse);
    });

    test('插入邊界距既有 499ms 拒絕；500ms 放行並重排', () {
      final rejected = _session();
      expect(
        () => rejected.insertBoundary(1499),
        _domainError(ErrorCodes.segmentTooClose),
      );
      expect(rejected.segments, hasLength(2));
      expect(rejected.dirty, isFalse);

      final allowed = _session();
      allowed.insertBoundary(1500);
      expect(allowed.segments, hasLength(3));
      expect(allowed.segments.map((item) => item.id).toSet(), hasLength(3));
      expect(allowed.segments[1].endMs, 1500);
      expect(allowed.segments[2].startMs, 1500);
      expect(allowed.dirty, isTrue);
    });

    test('刪除邊界合併相鄰文字；undo 恢復兩段', () {
      final session = _session();

      session.removeBoundary(0);

      expect(session.segments, hasLength(1));
      expect(session.segments.single.text, 'one two');
      expect(session.segments.single.startMs, 0);
      expect(session.segments.single.endMs, 3000);
      expect(session.dirty, isTrue);

      expect(session.undo(), isTrue);
      expect(session.segments, hasLength(2));
      expect(session.segments.map((item) => item.text), ['one', 'two']);
    });

    test('AT-11-09：只剩一段時沿用 ERR_BOUNDARY_INVALID 且狀態不變', () {
      final session = LabelSession(
        audioFingerprint: _fingerprint,
        audioDurationMs: 3000,
        segments: [_segment('only', 0, 3000, 'only')],
      );

      expect(
        () => session.removeBoundary(0),
        _domainError(ErrorCodes.boundaryInvalid),
      );
      expect(session.segments, hasLength(1));
      expect(session.dirty, isFalse);
    });
  });

  test('AT-11-06：ASR 失敗可用正常空 session＋警告承載', () {
    final result = LabelOpenResult(
      session: LabelSession(
        audioFingerprint: _fingerprint,
        audioDurationMs: 3000,
        segments: const [],
      ),
      peaks: const [0.1, 0.5, 0.2],
      warning: const LabelOpenWarning(
        code: ErrorCodes.transcribeFailed,
        message: '切段失敗，可重試或手動切段',
      ),
    );

    expect(result.session.segments, isEmpty);
    expect(result.warning!.code, ErrorCodes.transcribeFailed);
    expect(result.peaks, isNotEmpty);
  });

  group('SegmentEngine.openAudio（AT-11-01／06／08）', () {
    test('AT-11-06：ASR crash 回正常空 session＋警告與已解碼波形', () async {
      final fileIo = _MemoryFileIo();
      final decoder = _FakeDecoder(_pcm());
      final engine = _segmentEngine(
        fileIo: fileIo,
        decoder: decoder,
        transcriber: _FakeTranscriber(
          onSegment: (pcm, language) async {
            throw const DomainException(
              ErrorCodes.sidecarCrashed,
              'fixture crash',
            );
          },
        ),
      );

      final result = await engine.openAudio('/fixture/song.wav');

      expect(result.session.segments, isEmpty);
      expect(result.warning!.code, ErrorCodes.transcribeFailed);
      expect(result.warning!.message, '切段失敗，可重試或手動切段');
      expect(result.peaks, isNotEmpty);
      expect(decoder.callCount, 1);
    });

    test('M14：ja 缺切分器時在任何檔案／解碼副作用前拒絕', () async {
      final fileIo = _MemoryFileIo();
      final decoder = _FakeDecoder(_pcm());
      final engine = _segmentEngine(
        fileIo: fileIo,
        decoder: decoder,
        transcriber: _FakeTranscriber(
          supportedLanguages: const {'en', 'ja'},
        ),
      );

      await expectLater(
        engine.openAudio('/fixture/song.wav', language: 'ja'),
        _domainError(ErrorCodes.languageUnsupported),
      );
      expect(fileIo.readCount, 0);
      expect(decoder.callCount, 0);
    });

    test('AT-11-01：成功切段回 CLEAN session 與既有標籤提示', () async {
      final engine = _segmentEngine(
        fileIo: _MemoryFileIo(),
        decoder: _FakeDecoder(_pcm()),
        transcriber: _FakeTranscriber(
          onSegment: (pcm, language) async => [
            _segment('auto-1', 0, 1000, 'one'),
            _segment('auto-2', 1000, 3000, 'two'),
          ],
        ),
        repository: _FakeLabelRegistry('/labels/song.abolabel'),
      );

      final result = await engine.openAudio('/fixture/song.wav');

      expect(result.session.segments, hasLength(2));
      expect(result.session.dirty, isFalse);
      expect(result.existingLabelPath, '/labels/song.abolabel');
      expect(result.warning, isNull);
    });

    test('AT-11-08：自動切段共用重入鎖，第二次立即拒絕', () async {
      final entered = Completer<void>();
      final release = Completer<List<Segment>>();
      final engine = _segmentEngine(
        fileIo: _MemoryFileIo(),
        decoder: _FakeDecoder(_pcm()),
        transcriber: _FakeTranscriber(
          onSegment: (pcm, language) {
            entered.complete();
            return release.future;
          },
        ),
      );

      final first = engine.openAudio('/fixture/song-a.wav');
      await entered.future;
      await expectLater(
        engine.openAudio('/fixture/song-b.wav'),
        _domainError(ErrorCodes.analysisInProgress),
      );
      release.complete([_segment('auto', 0, 3000, 'one')]);
      await first;
    });

    test('AT-11-10：解碼未完成前進度不得越級到自動切句', () async {
      final entered = Completer<void>();
      final release = Completer<Pcm>();
      final progress = <LabelOpenProgress>[];
      final engine = _segmentEngine(
        fileIo: _MemoryFileIo(),
        decoder: _FakeDecoder(
          _pcm(),
          onDecode: () {
            entered.complete();
            return release.future;
          },
        ),
        transcriber: _FakeTranscriber(),
      );

      final pending = engine.openAudio(
        '/fixture/song.wav',
        separateVocals: false,
        onProgress: progress.add,
      );
      await entered.future;

      expect(progress.last.stage, LabelOpenStage.decoding);
      expect(progress.last.ratio, isNull);
      expect(
        progress.where((item) => item.stage == LabelOpenStage.segmenting),
        isEmpty,
      );

      release.complete(_pcm());
      await pending;
      expect(progress.last.stage, LabelOpenStage.completed);
      expect(progress.last.ratio, 1);
      expect(
        progress.map((item) => item.stage).toSet(),
        containsAll([
          LabelOpenStage.readingFingerprint,
          LabelOpenStage.decoding,
          LabelOpenStage.segmenting,
          LabelOpenStage.buildingWaveform,
          LabelOpenStage.completed,
        ]),
      );
    });
  });
}

LabelSession _session() => LabelSession(
      audioFingerprint: _fingerprint,
      audioDurationMs: 3000,
      segments: [
        _segment('s1', 0, 1000, 'one'),
        _segment('s2', 1000, 3000, 'two'),
      ],
    );

Segment _segment(String id, int startMs, int endMs, String text) => Segment(
      id: id,
      startMs: startMs,
      endMs: endMs,
      text: text,
      language: 'en',
      confidence: 0.9,
    );

Matcher _domainError(String code) => throwsA(
      isA<DomainException>().having((error) => error.code, 'code', code),
    );

const _fingerprint =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Pcm _pcm() => Pcm(Int16List(3000), sampleRate: 1000);

SegmentEngine _segmentEngine({
  required _MemoryFileIo fileIo,
  required _FakeDecoder decoder,
  required _FakeTranscriber transcriber,
  LabelRegistryRepository? repository,
}) =>
    SegmentEngine(
      decoder: decoder,
      fileIo: fileIo,
      transcriberRegistry: TranscriberRegistry([transcriber]),
      syllabifierRegistry: SyllabifierRegistry([EnglishSyllabifier()]),
      labelRegistryRepository: repository,
      waveformBucketCount: 4,
    );

class _FakeDecoder implements AnalysisAudioDecoder {
  final Pcm pcm;
  final Future<Pcm> Function()? onDecode;
  int callCount = 0;

  _FakeDecoder(this.pcm, {this.onDecode});

  @override
  Future<Pcm> decode(String audioPath) async {
    callCount++;
    return onDecode?.call() ?? pcm;
  }
}

class _FakeTranscriber implements TranscriberEngine {
  final Future<List<Segment>> Function(Pcm pcm, String language)? onSegment;

  @override
  final Set<String> supportedLanguages;

  _FakeTranscriber({
    this.onSegment,
    this.supportedLanguages = const {'en'},
  });

  @override
  String get engineName => 'fixture-asr';

  @override
  Future<List<Segment>> segment(
    Pcm pcm, {
    required String language,
  }) =>
      onSegment?.call(pcm, language) ?? Future.value(const []);

  @override
  Future<List<Word>> transcribe(
    Pcm pcm, {
    required String language,
    String? transcript,
  }) async =>
      const [];
}

class _MemoryFileIo implements FileIo {
  int readCount = 0;

  @override
  Future<Uint8List> readBytes(String path) async {
    readCount++;
    return Uint8List.fromList([1, 2, 3]);
  }

  @override
  Future<void> clearTemp() async {}

  @override
  Future<String> createTempFilePath(String suffix) async => '/tmp/file$suffix';

  @override
  Future<void> delete(String path) async {}

  @override
  Future<bool> exists(String path) async => true;

  @override
  Future<void> writeBytesAtomic(String path, Uint8List bytes) async {}
}

class _FakeLabelRegistry implements LabelRegistryRepository {
  final String path;

  _FakeLabelRegistry(this.path);

  @override
  Future<LabelRegistryRecord?> findByFingerprint(
          String audioFingerprint) async =>
      LabelRegistryRecord(
        audioFingerprint: audioFingerprint,
        labelPath: path,
        segmentCount: 2,
        updatedAt: DateTime.utc(2026, 7, 13),
      );

  @override
  Future<void> upsert(LabelRegistryRecord record) async {}
}
