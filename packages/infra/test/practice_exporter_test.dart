// AI-Generate
// PracticeExporter 單元測試（task-split 4.6）：以假 Runner/FileIo 驗證
// MP3 encode 介面、temp→atomic write、silenceGapsMs 與重入鎖，不依賴真實 FFmpeg。
import 'dart:async';
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
    files[path] = Uint8List.fromList(bytes);
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
  });
}
