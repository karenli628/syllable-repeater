// AI-Generate
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:infra/infra.dart';
import 'package:path/path.dart' as p;

const _benchmarkSeconds = 10;
const _target = Duration(seconds: 60);
// v1 Q10 基準（2026-07-07，Intel i5-8259U）：4.689 秒。
const _v1BaselineElapsedMs = 4689;
const _maxRegressionRatio = 1.05;
const _v11RegressionLimitMs = 4924;
const _sourceAudioName = 'step up your coding skills to a new level.mp3';

Future<void> main() async {
  try {
    final report = await _runBenchmark();
    stdout.writeln('Alignment pipeline benchmark');
    stdout.writeln('cpu: ${report.cpuBrand}');
    stdout.writeln('audioDurationMs: ${report.audioDurationMs}');
    stdout.writeln('elapsedMs: ${report.elapsedMs}');
    stdout.writeln('elapsedSeconds: ${report.elapsedSeconds}');
    stdout.writeln('v1BaselineElapsedMs: $_v1BaselineElapsedMs');
    stdout.writeln('v1BaselineElapsedSeconds: ${_v1BaselineElapsedMs / 1000}');
    stdout.writeln('maxRegressionRatio: $_maxRegressionRatio');
    stdout.writeln('v11RegressionLimitMs: $_v11RegressionLimitMs');
    stdout.writeln(
        'rerunCommand: dart run bin/benchmark_alignment_pipeline.dart');
    stdout.writeln('syllableCount: ${report.syllableCount}');
    stdout.writeln('waveformPeaks: ${report.waveformPeakCount}');
    stdout.writeln('targetSeconds: ${_target.inSeconds}');
    stdout.writeln('status: ${report.passed ? 'PASS' : 'FAIL'}');
    if (!report.passed) {
      exitCode = 2;
    }
  } catch (e) {
    stderr.writeln('Benchmark failed: $e');
    exitCode = 1;
  }
}

Future<_BenchmarkReport> _runBenchmark() async {
  final root = _findRepoRoot(Directory.current);
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
  final cmudict = File(p.join(root.path, '.local-tools/cmudict/cmudict.dict'));
  final sourceAudio = File(p.join(
    root.path,
    '.local-tools/fixtures',
    _sourceAudioName,
  ));

  if (ffmpeg == null) {
    throw StateError('FFmpeg not found at /usr/local/bin or /opt/homebrew/bin');
  }
  _requireFile(whisperCli, 'whisper.cpp CLI');
  _requireFile(model, 'whisper.cpp small.en model');
  _requireFile(cmudict, 'CMUdict');
  _requireFile(sourceAudio, 'source benchmark audio');

  final tempDir =
      Directory(p.join(root.path, '.local-tools/s1a/performance_benchmark'));
  tempDir.createSync(recursive: true);
  final benchmarkAudio =
      File(p.join(tempDir.path, 'alignment_pipeline_10s.wav'));
  await _createBenchmarkAudio(
    ffmpegPath: ffmpeg.path,
    sourceAudioPath: sourceAudio.path,
    outputAudioPath: benchmarkAudio.path,
  );

  final runner = const SidecarRunner(defaultTimeout: Duration(seconds: 180));
  final transcriber = WhisperAnalysisTranscriber(
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
  );
  final pipeline = AnalysisPipeline(
    decoder: FfmpegDecoder(runner: runner, ffmpegPath: ffmpeg.path),
    transcriberRegistry: TranscriberRegistry([transcriber]),
    syllabifierRegistry: SyllabifierRegistry([
      EnglishSyllabifier(
        alignmentEngine: AlignmentEngine(
          dictionary: const CmuDictLoader().load(cmudict.path),
        ),
      ),
    ]),
  );

  AnalysisEvent? done;
  final stopwatch = Stopwatch()..start();
  await for (final event in pipeline.analyze(ImportRequest(
    audioPath: benchmarkAudio.path,
    waveformBucketCount: 32,
  ))) {
    if (event.stage == AnalysisStage.failed) {
      throw event.error ??
          const DomainException(ErrorCodes.decodeFailed, '分析失敗');
    }
    if (event.stage == AnalysisStage.done) {
      done = event;
    }
  }
  stopwatch.stop();

  final result = done?.result;
  final pcm = done?.decodedPcm;
  if (result == null || pcm == null) {
    throw StateError('pipeline completed without a done result');
  }

  return _BenchmarkReport(
    cpuBrand: await _cpuBrand(),
    audioDurationMs: pcm.durationMs,
    elapsedMs: stopwatch.elapsedMilliseconds,
    syllableCount: result.syllables.length,
    waveformPeakCount: done?.waveformPeaks?.length ?? 0,
  );
}

Future<void> _createBenchmarkAudio({
  required String ffmpegPath,
  required String sourceAudioPath,
  required String outputAudioPath,
}) async {
  final result = await Process.run(ffmpegPath, [
    '-hide_banner',
    '-y',
    '-stream_loop',
    '2',
    '-i',
    sourceAudioPath,
    '-t',
    '$_benchmarkSeconds',
    '-ac',
    '1',
    '-ar',
    '44100',
    outputAudioPath,
  ]).timeout(const Duration(seconds: 60));
  if (result.exitCode != 0) {
    throw StateError('failed to create benchmark audio: ${result.stderr}');
  }
}

Directory _findRepoRoot(Directory start) {
  var current = start.absolute;
  while (true) {
    final pubspec = File(p.join(current.path, 'pubspec.yaml'));
    final specDir = Directory(p.join(current.path, 'spec-syllable-repeater'));
    if (pubspec.existsSync() && specDir.existsSync()) {
      return current;
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      throw StateError('repository root not found from ${start.path}');
    }
    current = parent;
  }
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

void _requireFile(File file, String label) {
  if (!file.existsSync()) {
    throw StateError('$label not found: ${file.path}');
  }
}

Future<String> _cpuBrand() async {
  final result = await Process.run('sysctl', ['-n', 'machdep.cpu.brand_string'])
      .timeout(const Duration(seconds: 5));
  if (result.exitCode != 0) {
    return 'unknown';
  }
  return result.stdout.toString().trim();
}

class _BenchmarkReport {
  final String cpuBrand;
  final int audioDurationMs;
  final int elapsedMs;
  final int syllableCount;
  final int waveformPeakCount;

  const _BenchmarkReport({
    required this.cpuBrand,
    required this.audioDurationMs,
    required this.elapsedMs,
    required this.syllableCount,
    required this.waveformPeakCount,
  });

  String get elapsedSeconds => (elapsedMs / 1000).toStringAsFixed(3);
  bool get passed =>
      Duration(milliseconds: elapsedMs) <= _target &&
      elapsedMs <= _v11RegressionLimitMs;
}
