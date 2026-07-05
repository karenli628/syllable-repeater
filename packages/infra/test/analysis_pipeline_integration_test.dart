// AI-Generate
@Tags(['sidecar'])
library;

import 'dart:io';

import 'package:domain/domain.dart';
import 'package:infra/infra.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('S1a interim demo：使用者 mp3 經 AnalysisPipeline 切出 11 音節', () async {
    final root = Directory.current.parent.parent;
    final ffmpeg = _firstExisting([
      '/usr/local/bin/ffmpeg',
      '/opt/homebrew/bin/ffmpeg',
    ]);
    final whisperCli = File(p.join(
      root.path,
      '.local-tools/whisper.cpp/build/bin/whisper-cli',
    ));
    final model = File(p.join(
      root.path,
      '.local-tools/whisper.cpp/models/ggml-small.en.bin',
    ));
    final cmudict =
        File(p.join(root.path, '.local-tools/cmudict/cmudict.dict'));
    final audio = File(p.join(
      root.path,
      'step up your coding skills to a new level.mp3',
    ));

    if (ffmpeg == null) {
      markTestSkipped('FFmpeg not installed');
      return;
    }
    if (!whisperCli.existsSync() || !model.existsSync()) {
      markTestSkipped('whisper.cpp small.en local tool not installed');
      return;
    }
    if (!cmudict.existsSync()) {
      markTestSkipped('CMUdict local file not installed');
      return;
    }
    if (!audio.existsSync()) {
      markTestSkipped('S1a user audio file not found');
      return;
    }

    final tempDir = Directory(p.join(
      root.path,
      '.local-tools/s1a/analysis_pipeline_integration',
    ));
    tempDir.createSync(recursive: true);
    final runner = const SidecarRunner(defaultTimeout: Duration(seconds: 120));
    final pipeline = AnalysisPipeline(
      decoder: FfmpegDecoder(runner: runner, ffmpegPath: ffmpeg.path),
      transcriber: WhisperAnalysisTranscriber(
        audioPreparer: FfmpegTranscriptionAudioPreparer(
          runner: runner,
          ffmpegPath: ffmpeg.path,
          tempDirectory: tempDir.path,
        ),
        transcriber: WhisperCppTranscriber(
          runner: runner,
          whisperCliPath: whisperCli.path,
          modelPath: model.path,
          noGpu: true,
        ),
        outputDirectory: tempDir.path,
      ),
      alignmentEngine: AlignmentEngine(
        dictionary: const CmuDictLoader().load(cmudict.path),
      ),
    );

    final events = await pipeline
        .analyze(ImportRequest(
          audioPath: audio.path,
          transcript: 'step up your coding skills to a new level',
          waveformBucketCount: 32,
        ))
        .toList();

    expect(events.last.stage, AnalysisStage.done);
    expect(events.last.error, isNull);
    expect(events.last.result!.syllables.map((s) => s.text), [
      'step',
      'up',
      'your',
      'cod',
      'ing',
      'skills',
      'to',
      'a',
      'new',
      'le',
      'vel',
    ]);
    expect(events.last.waveformPeaks, hasLength(32));
  }, timeout: const Timeout(Duration(minutes: 2)));
}

File? _firstExisting(List<String> paths) {
  for (final path in paths) {
    final file = File(path);
    if (file.existsSync()) {
      return file;
    }
  }
  return null;
}
