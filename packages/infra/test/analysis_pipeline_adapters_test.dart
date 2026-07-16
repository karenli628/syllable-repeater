// AI-Generate
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:infra/infra.dart';
import 'package:test/test.dart';

void main() {
  group('AnalysisPipeline infra adapters（task-split 3.4）', () {
    test('WhisperAnalysisTranscriber 先產生 16k mono WAV，再呼叫 whisper.cpp',
        () async {
      final dir = await Directory.systemTemp.createTemp('analysis-adapter-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final runner = _ScriptedRunner((executable, args) async {
        if (executable == 'whisper-cli') {
          final outputBase = args[args.indexOf('-of') + 1];
          File('$outputBase.json').writeAsStringSync(_stepUpJson);
        }
        return const SidecarResult(0, [], '');
      });
      final adapter = WhisperAnalysisTranscriber(
        audioPreparer: FfmpegTranscriptionAudioPreparer(
          runner: runner,
          ffmpegPath: 'ffmpeg',
          tempDirectory: dir.path,
          verifyOutputExists: false,
        ),
        transcriber: WhisperCppTranscriber(
          runner: runner,
          whisperCliPath: 'whisper-cli',
          modelPath: 'ggml-small.en.bin',
          noGpu: true,
        ),
        outputDirectory: dir.path,
      );

      final words = await adapter.transcribe(
        Pcm(Int16List(44100 * 3)),
        language: 'en',
      );

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
      expect(runner.calls, hasLength(2));
      expect(runner.calls[0].executable, 'ffmpeg');
      expect(
        runner.calls[0].args,
        containsAllInOrder(['-ac', '1', '-ar', '16000']),
      );
      expect(runner.calls[0].args.last, endsWith('_16k.wav'));
      expect(runner.calls[1].executable, 'whisper-cli');
      expect(
        runner.calls[1].args,
        containsAllInOrder(['-f', runner.calls[0].args.last, '-l', 'en']),
      );
      expect(runner.calls[1].args, contains('--no-gpu'));
      expect(dir.listSync(), isEmpty,
          reason: '16k WAV 與 whisper JSON 皆須 finally 清除');
    });

    test('AT-17-05：同一 adapter 可回傳 segment 級時間戳', () async {
      final dir = await Directory.systemTemp.createTemp('segment-adapter-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final runner = _ScriptedRunner((executable, args) async {
        if (executable == 'whisper-cli') {
          final outputBase = args[args.indexOf('-of') + 1];
          File('$outputBase.json').writeAsStringSync(_stepUpJson);
        }
        return const SidecarResult(0, [], '');
      });
      final adapter = WhisperAnalysisTranscriber(
        audioPreparer: FfmpegTranscriptionAudioPreparer(
          runner: runner,
          ffmpegPath: 'ffmpeg',
          tempDirectory: dir.path,
          verifyOutputExists: false,
        ),
        transcriber: WhisperCppTranscriber(
          runner: runner,
          whisperCliPath: 'whisper-cli',
          modelPath: 'ggml-small.en.bin',
          noGpu: true,
        ),
        outputDirectory: dir.path,
      );

      final segments = await adapter.segment(
        Pcm(Int16List(44100 * 3)),
        language: 'en',
      );

      expect(segments, hasLength(1));
      expect(segments.single.startMs, 80);
      expect(segments.single.endMs, 3120);
      expect(segments.single.language, 'en');
      expect(dir.listSync(), isEmpty, reason: 'segment 作業中介檔不得留在 session');
    });

    test('辨識用 WAV 準備逾時映射 ERR_SIDECAR_TIMEOUT', () async {
      final dir = await Directory.systemTemp.createTemp('analysis-adapter-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final preparer = FfmpegTranscriptionAudioPreparer(
        runner: _ScriptedRunner((executable, args) async {
          throw const SidecarFailure('timeout', 'test');
        }),
        ffmpegPath: 'ffmpeg',
        tempDirectory: dir.path,
      );

      await expectLater(
        preparer.prepare(ImportRequest(audioPath: '/tmp/input.mp3')),
        _domainError(ErrorCodes.sidecarTimeout),
      );
    });
  });
}

class _Call {
  final String executable;
  final List<String> args;

  const _Call(this.executable, this.args);
}

class _ScriptedRunner implements ProcessRunner {
  final Future<SidecarResult> Function(String executable, List<String> args)
      behavior;
  final calls = <_Call>[];

  _ScriptedRunner(this.behavior);

  @override
  Future<SidecarResult> run(String executable, List<String> args,
      {Duration? timeout}) {
    calls.add(_Call(executable, args));
    return behavior(executable, args);
  }
}

Matcher _domainError(String code) =>
    throwsA(isA<DomainException>().having((e) => e.code, 'code', code));

final String _stepUpJson = jsonEncode({
  'transcription': [
    {
      'offsets': {'from': 80, 'to': 3120},
      'text': ' Step up your coding skills to a new level.',
      'confidence': 0.91,
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
