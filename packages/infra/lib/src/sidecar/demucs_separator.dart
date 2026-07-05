// AI-Generate
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:path/path.dart' as p;

import 'sidecar_runner.dart';

/// demucs.cpp（sevagh/demucs.cpp，MIT，OQ-2 定案 2026-07-06）人聲分離 adapter，
/// 實作 domain `AnalysisVocalSeparator` port（backend-design §3.2.1 依賴介面
/// 第 378 行；task-split 3.8）。
///
/// 契約：
/// - 呼叫 demucs.cpp CLI，讓它把 [ImportRequest.audioPath] 分離為
///   `<workDir>/vocals.wav`（＋ instrumental.wav；本 adapter 只讀 vocals）
/// - 用注入的 [decoder]（通常＝`FfmpegDecoder`）把 vocals.wav 讀回 PCM
/// - 回傳 `SeparatedAudio{audioPath: vocalsPath, pcm}`；上游 pipeline 用
///   audioPath 覆寫 `ImportRequest` 給 whisper adapter，用 pcm 算 waveform peaks
///
/// 錯誤映射（frontend-design §八 錯誤策略；M4 崩潰隔離）：
/// - 逾時 → `ERR_SIDECAR_TIMEOUT`
/// - 崩潰／spawn 失敗／被訊號終止 → `ERR_SIDECAR_CRASHED`
/// - exit≠0 或 vocals.wav 未生成 → `ERR_DECODE_FAILED`
/// - 上層 pipeline 收到任一例外時保留 `decodedPcm` 給 UI「重試此階段」（M4）
///
/// CLI 語法（`--two-stems=vocals -o <dir> --model-dir <dir> <input>`）依
/// backend-design 契約推測；實際 sevagh/demucs.cpp CLI 語法待使用者本機
/// 首次跑真整合測試時驗證，若不符請只改本檔的 args 常數。
class DemucsCppVocalSeparator implements AnalysisVocalSeparator {
  /// demucs.cpp 產出的 vocals 檔名（backend-design 契約：two-stems 之 vocals）。
  static const _vocalsFileName = 'vocals.wav';

  final ProcessRunner runner;
  final AnalysisAudioDecoder decoder;
  final String demucsCliPath;
  final String modelDir;
  final String outputDirectory;
  final Duration timeout;

  const DemucsCppVocalSeparator({
    required this.runner,
    required this.decoder,
    required this.demucsCliPath,
    required this.modelDir,
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

    final args = [
      '--two-stems=vocals',
      '-o',
      workDir,
      '--model-dir',
      modelDir,
      request.audioPath,
    ];

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
    }

    if (result.wasKilledBySignal) {
      throw const DomainException(
          ErrorCodes.sidecarCrashed, '人聲分離引擎異常結束，可重試');
    }
    if (!result.isSuccess) {
      final tail = result.stderr.length > 300
          ? result.stderr.substring(result.stderr.length - 300)
          : result.stderr;
      throw DomainException(ErrorCodes.decodeFailed, '人聲分離失敗（$tail）');
    }

    final vocalsPath = p.join(workDir, _vocalsFileName);
    if (!File(vocalsPath).existsSync()) {
      throw const DomainException(
          ErrorCodes.decodeFailed, '人聲分離未產出 vocals.wav');
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
