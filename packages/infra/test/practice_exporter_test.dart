// AI-Generate
// PracticeExporter 單元測試（task-split 4.6）：以假 Runner/FileIo 驗證
// MP3 encode 介面、temp→atomic write、silenceGapsMs 與重入鎖，不依賴真實 FFmpeg。
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:infra/infra.dart';
import 'package:test/test.dart';

class _FakeRunner implements ProcessRunner {
  final Future<SidecarResult> Function() _behavior;
  List<String>? capturedArgs;

  _FakeRunner(this._behavior);

  @override
  Future<SidecarResult> run(String executable, List<String> args,
      {Duration? timeout}) {
    capturedArgs = args;
    return _behavior();
  }
}

class _FakeFileIo implements FileIo {
  final Map<String, Uint8List> files = {};
  final Set<String> deleted = {};
  final Set<String> unwritable = {};
  final Set<String> missingAfterWrite = {};
  int _counter = 0;

  @override
  Future<void> clearTemp() async {}

  @override
  Future<String> createTempFilePath(String suffix) async =>
      '/tmp/export-${_counter++}$suffix';

  @override
  Future<void> delete(String path) async {
    deleted.add(path);
    files.remove(path);
  }

  @override
  Future<bool> exists(String path) async => files.containsKey(path);

  @override
  Future<Uint8List> readBytes(String path) async => files[path]!;

  @override
  Future<void> writeBytesAtomic(String path, Uint8List bytes) async {
    if (unwritable.contains(path)) {
      throw StateError('unwritable $path');
    }
    if (!missingAfterWrite.contains(path)) {
      files[path] = Uint8List.fromList(bytes);
    }
  }
}

Matcher _domainError(String code) =>
    throwsA(isA<DomainException>().having((e) => e.code, 'code', code));

List<Syllable> _thankYouVeryMuchSyllables() => [
      Syllable(
          text: 'thank',
          startMs: 0,
          endMs: 200,
          wordIndex: 0,
          needsReview: false),
      Syllable(
          text: 'you',
          startMs: 200,
          endMs: 400,
          wordIndex: 1,
          needsReview: false),
      Syllable(
          text: 've',
          startMs: 400,
          endMs: 600,
          wordIndex: 2,
          needsReview: true),
      Syllable(
          text: 'ry',
          startMs: 600,
          endMs: 800,
          wordIndex: 2,
          needsReview: true),
      Syllable(
          text: 'much',
          startMs: 800,
          endMs: 1200,
          wordIndex: 3,
          needsReview: false),
    ];

Pcm _sourcePcm({int durationMs = 1200, int sampleRate = 1000}) {
  final samples = Int16List(durationMs * sampleRate ~/ 1000);
  for (var i = 0; i < samples.length; i++) {
    samples[i] = 1000 + i;
  }
  return Pcm(samples, sampleRate: sampleRate);
}

void main() {
  group('PracticeExporter', () {
    test('真 FFmpeg＋AtomicFileIo 寫出非空 MP3 實檔', () async {
      final ffmpegPath = Platform.environment['FFMPEG_PATH'];
      if (ffmpegPath == null || !File(ffmpegPath).existsSync()) {
        markTestSkipped('需設定 FFMPEG_PATH 指向可執行 FFmpeg');
        return;
      }
      final dir = Directory.systemTemp.createTempSync('practice_export_real_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final destPath = '${dir.path}/practice.mp3';
      final exporter = PracticeExporter(
        engine: PracticeEngine(),
        runner: const SidecarRunner(),
        fileIo: AtomicFileIo(tempDirPath: '${dir.path}/temp'),
        ffmpegPath: ffmpegPath,
      );
      final step =
          PracticeEngine().buildSteps(_thankYouVeryMuchSyllables(), 1).first;

      final result = await exporter.exportStep(
        step,
        _sourcePcm(),
        destPath,
      );

      final output = File(result.path);
      expect(output.existsSync(), isTrue);
      expect(output.lengthSync(), greaterThan(0));
    });

    test('exportMerged 編碼 MP3 bytes，回傳 silenceGapsMs 並寫入目的檔', () async {
      final fileIo = _FakeFileIo();
      final runner = _FakeRunner(
          () async => const SidecarResult(0, [0x49, 0x44, 0x33], ''));
      final exporter = PracticeExporter(
        engine: PracticeEngine(),
        runner: runner,
        fileIo: fileIo,
        ffmpegPath: 'ffmpeg',
      );
      final steps =
          PracticeEngine().buildSteps(_thankYouVeryMuchSyllables(), 3);

      final result =
          await exporter.exportMerged(steps, _sourcePcm(), '/out/lesson.mp3');

      expect(result.path, '/out/lesson.mp3');
      expect(result.totalDurationMs, 20400);
      expect(result.silenceGapsMs, [1200, 1800, 2400, 3000]);
      expect(fileIo.files['/out/lesson.mp3'], [0x49, 0x44, 0x33]);
      expect(
          runner.capturedArgs, containsAllInOrder(['-codec:a', 'libmp3lame']));
      expect(runner.capturedArgs, containsAllInOrder(['-f', 'mp3', '-']));
      expect(fileIo.deleted, contains('/tmp/export-0.wav'));
    });

    test('exportStep 不產生 silenceGapsMs', () async {
      final fileIo = _FakeFileIo();
      final runner =
          _FakeRunner(() async => const SidecarResult(0, [1, 2, 3], ''));
      final exporter = PracticeExporter(
        engine: PracticeEngine(),
        runner: runner,
        fileIo: fileIo,
        ffmpegPath: 'ffmpeg',
      );
      final step =
          PracticeEngine().buildSteps(_thankYouVeryMuchSyllables(), 3).first;

      final result =
          await exporter.exportStep(step, _sourcePcm(), '/out/one.mp3');

      expect(result.totalDurationMs, 1200);
      expect(result.silenceGapsMs, isEmpty);
      expect(fileIo.files['/out/one.mp3'], [1, 2, 3]);
    });

    test('AT-16-05 exportUnits legacy auto 完整沿用既有 M3 合併靜音', () async {
      final fileIo = _FakeFileIo();
      final runner =
          _FakeRunner(() async => const SidecarResult(0, [1, 2, 3], ''));
      final engine = PracticeEngine();
      final exporter = PracticeExporter(
        engine: engine,
        runner: runner,
        fileIo: fileIo,
        ffmpegPath: 'ffmpeg',
      );
      final effective = PracticeUnits(
        mode: PracticeMode.auto,
        units: engine
            .buildSteps(_thankYouVeryMuchSyllables(), 3)
            .map(AutoPracticeUnit.new)
            .toList(growable: false),
        stale: false,
      );

      final result = await exporter.exportUnits(
        effective,
        _sourcePcm(),
        '/out/auto.mp3',
      );

      expect(result.totalDurationMs, 20400);
      expect(result.silenceGapsMs, [1200, 1800, 2400, 3000]);
    });

    test('AT-16-02/05 exportUnits custom 使用各 block 的靜音倍數', () async {
      final fileIo = _FakeFileIo();
      final runner =
          _FakeRunner(() async => const SidecarResult(0, [1, 2, 3], ''));
      final engine = PracticeEngine();
      final exporter = PracticeExporter(
        engine: engine,
        runner: runner,
        fileIo: fileIo,
        ffmpegPath: 'ffmpeg',
      );
      final syllables = [
        Syllable(
          text: 'itll',
          startMs: 0,
          endMs: 300,
          wordIndex: 0,
          needsReview: false,
        ),
        Syllable(
          text: 'rain',
          startMs: 300,
          endMs: 650,
          wordIndex: 1,
          needsReview: false,
        ),
      ];
      final arrangement = PracticeArrangement(
        lessonId: 'lesson-a',
        rows: [
          PracticeRow(
            index: 1,
            blocks: [
              PracticeBlock(syllables: [syllables[0]]),
              PracticeBlock(syllables: [syllables[1]], repeatN: 4),
              PracticeBlock(
                syllables: syllables,
                repeatN: 4,
                silenceFactor: 3,
                isGrouped: true,
              ),
            ],
          ),
        ],
        updatedAt: DateTime.utc(2026, 7, 13),
      );
      final effective = engine.effectiveUnits(
        syllables,
        arrangement: arrangement,
        fullSentenceRange: TimeRange(0, 650),
      );

      final result = await exporter.exportUnits(
        effective,
        _sourcePcm(durationMs: 650),
        '/out/custom.mp3',
      );

      // 積木明示值保留；缺省積木與整列採 1 倍靜音，整列 3 次且最後不留靜音。
      expect(result.totalDurationMs, 44000);
      expect(result.silenceGapsMs, isEmpty);
      expect(fileIo.files['/out/custom.mp3'], [1, 2, 3]);
    });

    test('同 destPath 匯出中重入 → ERR_EXPORT_IN_PROGRESS', () async {
      final gate = Completer<void>();
      final fileIo = _FakeFileIo();
      final runner = _FakeRunner(() async {
        await gate.future;
        return const SidecarResult(0, [1], '');
      });
      final exporter = PracticeExporter(
        engine: PracticeEngine(),
        runner: runner,
        fileIo: fileIo,
        ffmpegPath: 'ffmpeg',
      );
      final step =
          PracticeEngine().buildSteps(_thankYouVeryMuchSyllables(), 3).first;

      final first = exporter.exportStep(step, _sourcePcm(), '/out/same.mp3');
      await expectLater(
          exporter.exportStep(step, _sourcePcm(), '/out/same.mp3'),
          _domainError(ErrorCodes.exportInProgress));
      gate.complete();
      await first;
    });

    test('目的檔不可寫 → ERR_EXPORT_DEST_UNWRITABLE，且清掉輸入暫存', () async {
      final fileIo = _FakeFileIo()..unwritable.add('/out/readonly.mp3');
      final runner =
          _FakeRunner(() async => const SidecarResult(0, [1, 2, 3], ''));
      final exporter = PracticeExporter(
        engine: PracticeEngine(),
        runner: runner,
        fileIo: fileIo,
        ffmpegPath: 'ffmpeg',
      );
      final step =
          PracticeEngine().buildSteps(_thankYouVeryMuchSyllables(), 3).first;

      await expectLater(
          exporter.exportStep(step, _sourcePcm(), '/out/readonly.mp3'),
          _domainError(ErrorCodes.exportDestUnwritable));

      expect(fileIo.files.containsKey('/out/readonly.mp3'), isFalse);
      expect(fileIo.deleted, contains('/tmp/export-0.wav'));
    });

    test('寫入回傳成功但目的檔不存在 → ERR_EXPORT_DEST_UNWRITABLE', () async {
      final fileIo = _FakeFileIo()..missingAfterWrite.add('/out/missing.mp3');
      final runner =
          _FakeRunner(() async => const SidecarResult(0, [1, 2, 3], ''));
      final exporter = PracticeExporter(
        engine: PracticeEngine(),
        runner: runner,
        fileIo: fileIo,
        ffmpegPath: 'ffmpeg',
      );
      final step =
          PracticeEngine().buildSteps(_thankYouVeryMuchSyllables(), 3).first;

      await expectLater(
        exporter.exportStep(step, _sourcePcm(), '/out/missing.mp3'),
        _domainError(ErrorCodes.exportDestUnwritable),
      );
    });
  });
}
