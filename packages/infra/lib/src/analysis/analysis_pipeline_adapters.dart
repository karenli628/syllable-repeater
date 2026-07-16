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
    return _preparePath(
      request.audioPath,
      safeBase: _safeBaseName(request.audioPath),
    );
  }

  /// 將 Domain PCM 先包成暫存 WAV，再由 FFmpeg 轉成 Intel whisper 相容的 16k mono（REQ-17）。
  Future<String> preparePcm(Pcm pcm) async {
    if (pcm.samples.isEmpty) {
      throw const DomainException(ErrorCodes.decodeFailed, '無法辨識空白音訊');
    }
    Directory(tempDirectory).createSync(recursive: true);
    final token = DateTime.now().microsecondsSinceEpoch;
    final sourcePath = p.join(tempDirectory, 'pcm_${token}_source.wav');
    File(sourcePath).writeAsBytesSync(encodeWav(pcm), flush: true);
    try {
      return await _preparePath(sourcePath, safeBase: 'pcm_$token');
    } finally {
      final source = File(sourcePath);
      if (source.existsSync()) {
        source.deleteSync();
      }
    }
  }

  Future<String> _preparePath(
    String inputPath, {
    required String safeBase,
  }) async {
    Directory(tempDirectory).createSync(recursive: true);
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
            inputPath,
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

/// 本地 TranscriberEngine 轉接器：準備 16k WAV 後呼叫 whisper.cpp（REQ-17/M13）。
class WhisperAnalysisTranscriber implements TranscriberEngine {
  final FfmpegTranscriptionAudioPreparer audioPreparer;
  final WhisperCppTranscriber transcriber;
  final String outputDirectory;

  const WhisperAnalysisTranscriber({
    required this.audioPreparer,
    required this.transcriber,
    required this.outputDirectory,
  });

  @override
  String get engineName => 'whisper.cpp';

  @override
  Set<String> get supportedLanguages => const {'en'};

  @override
  Future<List<Word>> transcribe(
    Pcm pcm, {
    required String language,
    String? transcript,
  }) async {
    _validateLanguage(language);
    Directory(outputDirectory).createSync(recursive: true);
    final wavPath = await audioPreparer.preparePcm(pcm);
    final outputBase = p.join(
      outputDirectory,
      '${p.basenameWithoutExtension(wavPath)}_whisper',
    );
    try {
      return await transcriber.transcribe(
        wavPath,
        outputBasePath: outputBase,
        language: language,
      );
    } finally {
      await _deleteWhisperArtifacts(wavPath, outputBase);
    }
  }

  @override
  Future<List<Segment>> segment(
    Pcm pcm, {
    required String language,
  }) async {
    _validateLanguage(language);
    Directory(outputDirectory).createSync(recursive: true);
    final wavPath = await audioPreparer.preparePcm(pcm);
    final outputBase = p.join(
      outputDirectory,
      '${p.basenameWithoutExtension(wavPath)}_segments',
    );
    try {
      return await transcriber.segment(
        wavPath,
        outputBasePath: outputBase,
        language: language,
      );
    } finally {
      await _deleteWhisperArtifacts(wavPath, outputBase);
    }
  }

  void _validateLanguage(String language) {
    final normalized = language.trim().toLowerCase();
    if (!supportedLanguages.contains(normalized)) {
      throw DomainException(
        ErrorCodes.languageUnsupported,
        'whisper.cpp adapter 不支援「$normalized」；目前支援：en',
      );
    }
  }

  Future<void> _deleteWhisperArtifacts(
    String wavPath,
    String outputBase,
  ) async {
    for (final path in [wavPath, '$outputBase.json']) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }
}
