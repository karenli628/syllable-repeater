// AI-Generate
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:path/path.dart' as p;

import '../file_io_impl.dart';
import 'sidecar_runner.dart';

/// demucs.cpp（sevagh/demucs.cpp，MIT，OQ-2 定案 2026-07-06）人聲分離 adapter，
/// 實作 domain `AnalysisVocalSeparator` port（backend-design §3.2.1 依賴介面
/// 第 378 行；task-split 3.8）。
///
/// 契約：
/// - 將 pipeline 已解碼的 44.1kHz mono [decodedPcm] 包成暫存 WAV，再呼叫
///   demucs.cpp CLI，讓它分離為
///   `<workDir>/target_3_vocals.wav`（本 adapter 只讀 vocals）
/// - 用注入的 [decoder]（通常＝`FfmpegDecoder`）把 vocals wav 讀回 PCM
/// - 回傳 `SeparatedAudio{audioPath: vocalsPath, pcm}`；上游 pipeline 用
///   audioPath 覆寫 `ImportRequest` 給 whisper adapter，用 pcm 算 waveform peaks
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

  /// demucs.cpp 官方 CLI 僅接受 44.1kHz 輸入。
  static const _requiredSampleRate = 44100;

  static const _inputFileName = 'input_44100_mono.wav';

  final ProcessRunner runner;
  final AnalysisAudioDecoder decoder;
  final String demucsCliPath;
  final String modelPath;
  final String outputDirectory;
  final Duration timeout;

  const DemucsCppVocalSeparator({
    required this.runner,
    required this.decoder,
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

    if (decodedPcm.sampleRate != _requiredSampleRate) {
      throw DomainException(
        ErrorCodes.separateFailed,
        '人聲分離輸入必須為 44100Hz（got ${decodedPcm.sampleRate}）',
      );
    }

    final inputPath = p.join(workDir, _inputFileName);
    try {
      await AtomicFileIo(tempDirPath: workDir).writeBytesAtomic(
        inputPath,
        encodeWav(decodedPcm),
      );
    } catch (error) {
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
            ErrorCodes.sidecarTimeout, '人聲分離逾時，可重試或調高逾時設定');
      }
      throw DomainException(
          ErrorCodes.sidecarCrashed, '人聲分離引擎異常結束，可重試（${f.detail}）');
    } finally {
      try {
        await File(inputPath).delete();
      } catch (_) {
        // 暫存輸入清理失敗不掩蓋 sidecar 原始結果；App 啟動 clearTemp 兜底。
      }
    }

    if (result.wasKilledBySignal) {
      throw const DomainException(ErrorCodes.sidecarCrashed, '人聲分離引擎異常結束，可重試');
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
  }

  static String _safeBase(String audioPath) {
    final raw = p.basenameWithoutExtension(audioPath).toLowerCase();
    final safe = raw.replaceAll(RegExp('[^a-z0-9_-]+'), '_');
    return safe.isEmpty ? 'audio' : safe;
  }
}
