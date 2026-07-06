// AI-Generate
import 'dart:io';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syllable_repeater_app/features/practice/practice_player.dart';

class _FakeBackend implements PracticeAudioBackend {
  final events = <String>[];
  String? loadedPath;

  @override
  Future<void> setFilePath(String path) async {
    loadedPath = path;
    events.add('load');
  }

  @override
  Future<void> play() async {
    events.add('play');
  }

  @override
  Future<void> stop() async {
    events.add('stop');
  }

  @override
  Future<void> dispose() async {
    events.add('dispose');
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
  });
}
