// AI-Generate
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:path/path.dart' as p;

import 'sidecar_runner.dart';

/// 將原始匯入音檔準備成 demucs.cpp 需要的音訊檔（REQ-18／M4）。
abstract interface class DemucsAudioPreparer {
  Future<void> prepare(ImportRequest request, String destinationPath);
}

/// 以受管 FFmpeg 將原始音檔轉為 44.1kHz PCM WAV。
///
/// 立體聲保留原始雙聲道線索；單聲道也保持 mono，不使用重複
/// 左右聲道的方式偽裝成有立體線索。Whisper 的 mono 轉換仍在分離後才進行
/// （AT-18-10）。
class FfmpegDemucsAudioPreparer implements DemucsAudioPreparer {
  final ProcessRunner runner;
  final String ffmpegPath;
  final bool verifyOutputExists;

  const FfmpegDemucsAudioPreparer({
    required this.runner,
    required this.ffmpegPath,
    this.verifyOutputExists = true,
  });

  @override
  Future<void> prepare(
    ImportRequest request,
    String destinationPath,
  ) async {
    final args = <String>[
      '-hide_banner',
      '-nostdin',
      '-y',
      '-i',
      request.audioPath,
      if (request.sourceRange != null) ...[
        '-ss',
        _seconds(request.sourceRange!.startMs),
        '-t',
        _seconds(request.sourceRange!.durationMs),
      ],
      '-map',
      '0:a:0',
      '-vn',
      '-sn',
      '-dn',
      '-ar',
      '44100',
      '-c:a',
      'pcm_s16le',
      destinationPath,
    ];

    final SidecarResult result;
    try {
      result = await runner.run(ffmpegPath, args);
    } on SidecarFailure catch (failure) {
      await _deleteIfPresent(destinationPath);
      if (failure.isTimeout) {
        throw const DomainException(
          ErrorCodes.sidecarTimeout,
          '人聲分離輸入準備逾時',
        );
      }
      throw DomainException(
        ErrorCodes.sidecarCrashed,
        '人聲分離輸入準備無法啟動（${failure.detail}）',
      );
    }

    if (result.wasKilledBySignal) {
      await _deleteIfPresent(destinationPath);
      throw const DomainException(
        ErrorCodes.sidecarCrashed,
        '人聲分離輸入準備異常終止',
      );
    }
    if (!result.isSuccess) {
      await _deleteIfPresent(destinationPath);
      final tail = result.stderr.length > 300
          ? result.stderr.substring(result.stderr.length - 300)
          : result.stderr;
      throw DomainException(
        ErrorCodes.separateFailed,
        '人聲分離輸入準備失敗（$tail）',
      );
    }
    if (verifyOutputExists && !File(destinationPath).existsSync()) {
      throw const DomainException(
        ErrorCodes.separateFailed,
        '人聲分離輸入準備未產生 stereo WAV',
      );
    }
  }

  static String _seconds(int milliseconds) =>
      (milliseconds / 1000).toStringAsFixed(3);

  static Future<void> _deleteIfPresent(String path) async {
    final file = File(path);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {
        // App 啟動 clearTemp 仍會兜底，不掩蓋原始 sidecar 錯誤。
      }
    }
  }
}

/// demucs.cpp（sevagh/demucs.cpp，MIT，OQ-2 定案 2026-07-06）人聲分離 adapter，
/// 實作 domain `AnalysisVocalSeparator` port（backend-design §3.2.1 依賴介面
/// 第 378 行；task-split 3.8）。
///
/// 契約：
/// - 將原始匯入音檔保留聲道數並轉成 44.1kHz WAV，再呼叫 demucs.cpp
///   CLI，讓它分離為
///   `<workDir>/target_3_vocals.wav`（本 adapter 只讀 vocals）
/// - 用注入的 [decoder]（通常＝`FfmpegDecoder`）把 vocals wav 讀回 PCM
/// - 回傳 `SeparatedAudio{audioPath: vocalsPath, pcm}`；`audioPath` 僅供診斷識別，
///   中介檔在 PCM 解碼後即刪除；上游 pipeline 一律用 pcm 做轉寫與 waveform peaks
///
/// 錯誤映射（frontend-design §八 錯誤策略；M4 崩潰隔離）：
/// - 逾時 → `ERR_SIDECAR_TIMEOUT`
/// - 崩潰／spawn 失敗／被訊號終止 → `ERR_SIDECAR_CRASHED`
/// - exit≠0 或 vocals wav 未生成 → `ERR_DECODE_FAILED`
/// - 上層 pipeline 收到任一例外時保留 `decodedPcm` 給 UI「重試此階段」（M4）
///
/// CLI 語法依 sevagh/demucs.cpp README：
/// `demucs.cpp.main model-file input-audio output-dir`。
class DemucsCppVocalSeparator implements AnalysisVocalSeparator {
  /// demucs.cpp 4-source `htdemucs` 產出的 vocals 檔名。
  static const _vocalsFileName = 'target_3_vocals.wav';

  static const _inputFileName = 'input_44100.wav';

  final ProcessRunner runner;
  final AnalysisAudioDecoder decoder;
  final DemucsAudioPreparer inputPreparer;
  final String demucsCliPath;
  final String modelPath;
  final String outputDirectory;
  final Duration timeout;

  const DemucsCppVocalSeparator({
    required this.runner,
    required this.decoder,
    required this.inputPreparer,
    required this.demucsCliPath,
    required this.modelPath,
    required this.outputDirectory,
    this.timeout = const Duration(seconds: 240),
  });

  @override
  Future<SeparatedAudio> separate(
    ImportRequest request, {
    required Pcm decodedPcm,
  }) async {
    Directory(outputDirectory).createSync(recursive: true);
    final safeBase = _safeBase(request.audioPath);
    final workDir = p.join(
      outputDirectory,
      '${safeBase}_demucs_${DateTime.now().microsecondsSinceEpoch}',
    );
    Directory(workDir).createSync(recursive: true);
    try {
      final inputPath = p.join(workDir, _inputFileName);
      try {
        await inputPreparer.prepare(request, inputPath);
      } catch (error) {
        if (error is DomainException) rethrow;
        throw DomainException(
          ErrorCodes.separateFailed,
          '人聲分離輸入準備失敗（$error）',
        );
      }

      final args = [modelPath, inputPath, workDir];

      final SidecarResult result;
      try {
        result = await runner.run(demucsCliPath, args, timeout: timeout);
      } on SidecarFailure catch (f) {
        if (f.isTimeout) {
          throw const DomainException(
            ErrorCodes.sidecarTimeout,
            '人聲分離逾時，可重試或調高逾時設定',
          );
        }
        throw DomainException(
          ErrorCodes.sidecarCrashed,
          '人聲分離引擎異常結束，可重試（${f.detail}）',
        );
      }

      if (result.wasKilledBySignal) {
        throw const DomainException(
          ErrorCodes.sidecarCrashed,
          '人聲分離引擎異常結束，可重試',
        );
      }
      if (!result.isSuccess) {
        final tail = result.stderr.length > 300
            ? result.stderr.substring(result.stderr.length - 300)
            : result.stderr;
        throw DomainException(ErrorCodes.separateFailed, '人聲分離失敗（$tail）');
      }

      final vocalsPath = p.join(workDir, _vocalsFileName);
      if (!File(vocalsPath).existsSync()) {
        throw const DomainException(
            ErrorCodes.separateFailed, '人聲分離未產出 target_3_vocals.wav');
      }

      final pcm = await decoder.decode(vocalsPath);
      return SeparatedAudio(audioPath: vocalsPath, pcm: pcm);
    } finally {
      final directory = Directory(workDir);
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  }

  static String _safeBase(String audioPath) {
    final raw = p.basenameWithoutExtension(audioPath).toLowerCase();
    final safe = raw.replaceAll(RegExp('[^a-z0-9_-]+'), '_');
    return safe.isEmpty ? 'audio' : safe;
  }
}
