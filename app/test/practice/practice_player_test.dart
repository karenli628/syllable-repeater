// AI-Generate
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/features/practice/practice_player.dart';

class _FakeBackend implements PracticeAudioBackend {
  final events = <String>[];
  String? loadedPath;
  Completer<void>? playStarted;
  Completer<void>? playRelease;
  bool releasePlaybackOnStop = false;

  @override
  Future<void> setFilePath(String path) async {
    loadedPath = path;
    events.add('load');
  }

  @override
  Future<void> play() async {
    events.add('play');
    playStarted?.complete();
    await playRelease?.future;
  }

  @override
  Future<void> stop() async {
    events.add('stop');
    if (releasePlaybackOnStop &&
        playStarted?.isCompleted == true &&
        playRelease?.isCompleted == false) {
      playRelease!.complete();
    }
  }

  @override
  Future<void> dispose() async {
    events.add('dispose');
  }
}

class _FakeAudioSessionCoordinator implements PracticeAudioSessionCoordinator {
  final events = <String>[];

  @override
  Future<void> finishPlayback() async => events.add('finishPlayback');

  @override
  Future<void> finishRecording() async => events.add('finishRecording');

  @override
  Future<void> prepareForPlayback() async => events.add('preparePlayback');

  @override
  Future<void> prepareForRecording() async => events.add('prepareRecording');
}

class _DelayedEngine extends PracticeEngine {
  final renderStarted = Completer<void>();
  final release = Completer<void>();

  @override
  Future<Pcm> renderBlockRow(PracticeRow row, Pcm originalPcm) async {
    renderStarted.complete();
    await release.future;
    return Pcm(Int16List(100), sampleRate: 1000);
  }
}

Pcm _pcm() {
  final samples = Int16List(4000);
  for (var i = 0; i < samples.length; i++) {
    samples[i] = i;
  }
  return Pcm(samples, sampleRate: 1000);
}

PracticeStep _step() => PracticeStep(
  index: 1,
  syllables: [
    Syllable(
      text: 'skills',
      startMs: 100,
      endMs: 200,
      wordIndex: 0,
      needsReview: false,
    ),
  ],
  sourceRanges: [TimeRange(100, 200)],
  totalDurationMs: 100,
);

PracticeRow _row() => PracticeRow(
  index: 1,
  blocks: [PracticeBlock(syllables: _step().syllables)],
);

void main() {
  group('PracticePlayer', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('practice_player_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('renderStepToFile 寫出 step hash wav 檔並快取重用', () async {
      final player = PracticePlayer(
        backend: _FakeBackend(),
        tempDirectory: tempDir,
      );

      final path = await player.renderStepToFile(_step(), _pcm(), repeatN: 2);
      final second = await player.renderStepToFile(_step(), _pcm(), repeatN: 2);

      expect(path, second);
      expect(path, endsWith('.wav'));
      final file = File(path);
      expect(file.existsSync(), isTrue);
      final bytes = file.readAsBytesSync();
      expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WAVE');
      expect(ByteData.sublistView(bytes).getUint32(40, Endian.little), 400);
    });

    test('guardrails #62 dispose 清除本 session 練習 WAV 快取', () async {
      final player = PracticePlayer(
        backend: _FakeBackend(),
        tempDirectory: tempDir,
      );
      await player.renderStepToFile(_step(), _pcm(), repeatN: 2);
      expect(tempDir.listSync(), isNotEmpty);

      await player.dispose();

      expect(tempDir.existsSync(), isFalse);
    });

    test('playStep 停止舊播放→載入檔案→onReady→play', () async {
      final backend = _FakeBackend();
      final player = PracticePlayer(backend: backend, tempDirectory: tempDir);
      var ready = false;

      await player.playStep(
        _step(),
        _pcm(),
        repeatN: 1,
        onReady: () {
          ready = true;
          backend.events.add('ready');
        },
      );

      expect(ready, isTrue);
      expect(backend.loadedPath, isNotNull);
      expect(backend.events, ['stop', 'load', 'ready', 'play']);
    });

    test('AT-15-05 renderRowToFile 依 block 與整列設定輸出 WAV', () async {
      final player = PracticePlayer(
        backend: _FakeBackend(),
        tempDirectory: tempDir,
      );

      final path = await player.renderRowToFile(_row(), _pcm());

      expect(File(path).existsSync(), isTrue);
      final bytes = File(path).readAsBytesSync();
      expect(ByteData.sublistView(bytes).getUint32(40, Endian.little), 1600);
    });

    test('AT-15-07 停止列預覽會阻擋尚未完成的舊 snapshot 播放', () async {
      final backend = _FakeBackend();
      final engine = _DelayedEngine();
      final player = PracticePlayer(
        backend: backend,
        engine: engine,
        tempDirectory: tempDir,
      );

      final future = player.playRow(_row(), _pcm());
      await engine.renderStarted.future;
      await player.stop();
      engine.release.complete();
      await future;

      expect(backend.events, ['stop', 'stop']);
    });

    test('AT-06-06 playPcm 播放後刪除一次性錄音暫存', () async {
      final backend = _FakeBackend();
      final player = PracticePlayer(backend: backend, tempDirectory: tempDir);

      await player.playPcm(_pcm());

      expect(backend.events, ['stop', 'load', 'play']);
      expect(backend.loadedPath, contains('recording-preview-'));
      expect(File(backend.loadedPath!).existsSync(), isFalse);
    });

    test('AT-18-08 錄音預覽完成前不刪 temp，完成後釋放播放 session', () async {
      final backend = _FakeBackend()
        ..playStarted = Completer<void>()
        ..playRelease = Completer<void>();
      final audioSession = _FakeAudioSessionCoordinator();
      final player = PracticePlayer(
        backend: backend,
        audioSession: audioSession,
        tempDirectory: tempDir,
      );

      final pending = player.playPcm(_pcm());
      await backend.playStarted!.future;

      expect(audioSession.events, ['preparePlayback']);
      expect(File(backend.loadedPath!).existsSync(), isTrue);

      backend.playRelease!.complete();
      await pending;

      expect(File(backend.loadedPath!).existsSync(), isFalse);
      expect(audioSession.events, ['preparePlayback', 'finishPlayback']);
    });

    test('AT-18-09 錄音預覽途中停止也會刪除一次性 temp', () async {
      final backend = _FakeBackend()
        ..playStarted = Completer<void>()
        ..playRelease = Completer<void>()
        ..releasePlaybackOnStop = true;
      final player = PracticePlayer(backend: backend, tempDirectory: tempDir);

      final pending = player.playPcm(_pcm());
      await backend.playStarted!.future;
      final previewPath = backend.loadedPath!;
      expect(File(previewPath).existsSync(), isTrue);

      await player.stop();
      await pending;

      expect(File(previewPath).existsSync(), isFalse);
    });

    test('AT-18-08 錄音預覽可連續播放兩次', () async {
      final backend = _FakeBackend();
      final audioSession = _FakeAudioSessionCoordinator();
      final player = PracticePlayer(
        backend: backend,
        audioSession: audioSession,
        tempDirectory: tempDir,
      );

      await player.playPcm(_pcm());
      await player.playPcm(_pcm());

      expect(backend.events.where((event) => event == 'play'), hasLength(2));
      expect(audioSession.events, [
        'preparePlayback',
        'finishPlayback',
        'preparePlayback',
        'finishPlayback',
      ]);
      expect(
        tempDir.listSync().whereType<File>(),
        isEmpty,
        reason: '兩次播放完成後皆不得殘留 recording-preview temp',
      );
    });
  });
}
