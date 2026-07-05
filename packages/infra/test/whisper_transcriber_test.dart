// AI-Generate
import 'dart:convert';
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:infra/infra.dart';
import 'package:test/test.dart';

class _FakeRunner implements ProcessRunner {
  final Future<SidecarResult> Function(List<String> args) _behavior;
  List<String>? capturedArgs;

  _FakeRunner(this._behavior);

  @override
  Future<SidecarResult> run(String executable, List<String> args,
      {Duration? timeout}) {
    capturedArgs = args;
    return _behavior(args);
  }
}

Matcher _domainError(String code) =>
    throwsA(isA<DomainException>().having((e) => e.code, 'code', code));

void main() {
  group('WhisperJsonParser（task-split 3.2）', () {
    test('解析 small.en full JSON tokens 成詞級時間戳', () {
      final words = const WhisperJsonParser().parseWords(_stepUpJson);

      expect(words.map((w) => w.text), [
        'step',
        'up',
        'your',
        'coding',
        'skills',
        'to',
        'a',
        'new',
        'level',
      ]);
      expect(words.first.startMs, 80);
      expect(words.first.endMs, 350);
      expect(words.last.startMs, 2520);
      expect(words.last.endMs, 3000);
    });
  });

  group('WhisperCppTranscriber', () {
    test('組出 small.en JSON 指令並讀回 outputBase.json', () async {
      final dir = await Directory.systemTemp.createTemp('whisper-test-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final outputBase = '${dir.path}/out';
      final fake = _FakeRunner((args) async {
        File('$outputBase.json').writeAsStringSync(_stepUpJson);
        return const SidecarResult(0, [], '');
      });
      final transcriber = WhisperCppTranscriber(
        runner: fake,
        whisperCliPath: 'whisper-cli',
        modelPath: 'ggml-small.en.bin',
        noGpu: true,
      );

      final words = await transcriber.transcribe('/tmp/audio.wav',
          outputBasePath: outputBase);

      expect(words, hasLength(9));
      expect(
          fake.capturedArgs,
          containsAllInOrder([
            '-m',
            'ggml-small.en.bin',
            '-f',
            '/tmp/audio.wav',
            '-oj',
            '-ojf',
            '-of',
            outputBase,
            '--no-gpu',
          ]));
    });

    test('逾時映射 ERR_SIDECAR_TIMEOUT', () async {
      final fake = _FakeRunner((args) async {
        throw const SidecarFailure('timeout', 'test');
      });
      final transcriber = WhisperCppTranscriber(
        runner: fake,
        whisperCliPath: 'whisper-cli',
        modelPath: 'ggml-small.en.bin',
      );

      await expectLater(
        transcriber.transcribe('/tmp/audio.wav', outputBasePath: '/tmp/out'),
        _domainError(ErrorCodes.sidecarTimeout),
      );
    });
  });
}

final String _stepUpJson = jsonEncode({
  'transcription': [
    {
      'tokens': [
        _token('[_BEG_]', 0, 0),
        _token(' Step', 80, 350),
        _token(' up', 350, 540),
        _token(' your', 540, 600),
        _token(' coding', 980, 1430),
        _token(' skills', 1440, 1980),
        _token(' to', 1980, 2160),
        _token(' a', 2160, 2230),
        _token(' new', 2250, 2520),
        _token(' level', 2520, 3000),
        _token('.', 3000, 3120),
      ],
    }
  ],
});

Map<String, Object?> _token(String text, int from, int to) => {
      'text': text,
      'offsets': {'from': from, 'to': to},
    };
