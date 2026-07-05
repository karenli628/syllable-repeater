// AI-Generate
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:path/path.dart' as p;

import '../sidecar/sidecar_runner.dart';
import '../sidecar/whisper_transcriber.dart';

/// AnalysisPipeline 的 infra 轉接器：用 FFmpeg 產生 whisper.cpp 友善的 16k mono WAV。
class FfmpegTranscriptionAudioPreparer {
  static const whisperSampleRate = 16000;

  final ProcessRunner runner;
  final String ffmpegPath;
  final String tempDirectory;
  final Duration timeout;
  final bool verifyOutputExists;

  const FfmpegTranscriptionAudioPreparer({
    required this.runner,
    required this.ffmpegPath,
    required this.tempDirectory,
    this.timeout = const Duration(seconds: 120),
    this.verifyOutputExists = true,
  });

  Future<String> prepare(ImportRequest request) async {
    Directory(tempDirectory).createSync(recursive: true);
    final safeBase = _safeBaseName(request.audioPath);
    final outputPath = p.join(
      tempDirectory,
      '${safeBase}_${DateTime.now().microsecondsSinceEpoch}_16k.wav',
    );

    final SidecarResult result;
    try {
      result = await runner.run(
          ffmpegPath,
          [
            '-hide_banner',
            '-y',
            '-i',
            request.audioPath,
            '-ac',
            '1',
            '-ar',
            '$whisperSampleRate',
            outputPath,
          ],
          timeout: timeout);
    } on SidecarFailure catch (f) {
      if (f.isTimeout) {
        throw const DomainException(
            ErrorCodes.sidecarTimeout, '分析逾時，可重試或調高逾時設定');
      }
      throw DomainException(
          ErrorCodes.sidecarCrashed, '分析引擎異常結束，可重試（${f.detail}）');
    }

    if (result.wasKilledBySignal) {
      throw const DomainException(ErrorCodes.sidecarCrashed, '分析引擎異常結束，可重試');
    }
    if (!result.isSuccess) {
      final tail = result.stderr.length > 300
          ? result.stderr.substring(result.stderr.length - 300)
          : result.stderr;
      throw DomainException(ErrorCodes.decodeFailed, '無法產生辨識用 WAV（$tail）');
    }
    if (verifyOutputExists && !File(outputPath).existsSync()) {
      throw const DomainException(ErrorCodes.decodeFailed, '無法產生辨識用 WAV');
    }
    return outputPath;
  }

  String _safeBaseName(String audioPath) {
    final raw = p.basenameWithoutExtension(audioPath).toLowerCase();
    final safe = raw.replaceAll(RegExp('[^a-z0-9_-]+'), '_');
    return safe.isEmpty ? 'audio' : safe;
  }
}

/// AnalysisTranscriber 轉接器：準備 16k WAV 後呼叫既有 whisper.cpp wrapper。
class WhisperAnalysisTranscriber implements AnalysisTranscriber {
  final FfmpegTranscriptionAudioPreparer audioPreparer;
  final WhisperCppTranscriber transcriber;
  final String outputDirectory;

  const WhisperAnalysisTranscriber({
    required this.audioPreparer,
    required this.transcriber,
    required this.outputDirectory,
  });

  @override
  Future<List<Word>> transcribe(
    ImportRequest request, {
    required Pcm decodedPcm,
  }) async {
    if (decodedPcm.samples.isEmpty) {
      throw const DomainException(ErrorCodes.decodeFailed, '無法辨識空白音訊');
    }
    Directory(outputDirectory).createSync(recursive: true);
    final wavPath = await audioPreparer.prepare(request);
    final outputBase = p.join(
      outputDirectory,
      '${p.basenameWithoutExtension(wavPath)}_whisper',
    );
    return transcriber.transcribe(wavPath, outputBasePath: outputBase);
  }
}
