// AI-Generate
import 'package:domain/domain.dart';
import 'package:path/path.dart' as p;

import 'ffmpeg_decoder.dart';
import 'sidecar_runner.dart';

/// 音檔時長探測抽象（不進 pipeline，只供 UI 前置檢查用）。
abstract interface class AudioDurationProbe {
  /// 回傳音檔時長；副檔名不支援或超過 10 分鐘 → 拋對應 DomainException。
  Future<Duration> probe(String audioPath);
}

/// 走 ffprobe（`-show_entries format=duration -of default=nk=1:nw=1`）抓時長，
/// 供 UI 在選檔／拖入後即擋 >10 分鐘的音檔，不必等 pipeline 解碼整段。
///
/// 錯誤映射（frontend-design §八 錯誤策略）：
/// - 副檔名不在白名單 → ERR_UNSUPPORTED_FORMAT（不呼叫 sidecar）
/// - 逾時 → ERR_SIDECAR_TIMEOUT
/// - 崩潰／spawn 失敗 → ERR_SIDECAR_CRASHED
/// - 行程正常結束但無法解析時長 → ERR_DECODE_FAILED
/// - 時長 > 10 分鐘 → ERR_FILE_TOO_LONG
class FfprobeDurationProbe implements AudioDurationProbe {
  static const supportedExtensions = FfmpegDecoder.supportedExtensions;
  static const maxDuration = Duration(milliseconds: FfmpegDecoder.maxDurationMs);

  final ProcessRunner runner;
  final String ffprobePath;
  final Duration timeout;

  const FfprobeDurationProbe({
    required this.runner,
    required this.ffprobePath,
    this.timeout = const Duration(seconds: 30),
  });

  @override
  Future<Duration> probe(String audioPath) async {
    final ext = p.extension(audioPath).toLowerCase();
    if (!supportedExtensions.contains(ext)) {
      throw const DomainException(
          ErrorCodes.unsupportedFormat, '不支援的音檔格式（支援 mp3/wav/m4a/flac）');
    }

    final SidecarResult result;
    try {
      result = await runner.run(
        ffprobePath,
        [
          '-v',
          'error',
          '-show_entries',
          'format=duration',
          '-of',
          'default=nokey=1:noprint_wrappers=1',
          audioPath,
        ],
        timeout: timeout,
      );
    } on SidecarFailure catch (f) {
      if (f.isTimeout) {
        throw const DomainException(
            ErrorCodes.sidecarTimeout, '時長檢查逾時，可重試或調高逾時設定');
      }
      throw DomainException(
          ErrorCodes.sidecarCrashed, '時長檢查失敗（${f.detail}）');
    }

    if (result.wasKilledBySignal) {
      throw const DomainException(ErrorCodes.sidecarCrashed, '時長檢查引擎異常結束');
    }
    if (!result.isSuccess) {
      final tail = result.stderr.length > 300
          ? result.stderr.substring(result.stderr.length - 300)
          : result.stderr;
      throw DomainException(ErrorCodes.decodeFailed, '無法讀取音檔時長（$tail）');
    }

    final stdoutText = String.fromCharCodes(result.stdout).trim();
    final seconds = double.tryParse(stdoutText);
    if (seconds == null || seconds.isNaN || seconds.isInfinite || seconds < 0) {
      throw DomainException(
          ErrorCodes.decodeFailed, '無法解析音檔時長：$stdoutText');
    }

    final duration = Duration(milliseconds: (seconds * 1000).round());
    if (duration > maxDuration) {
      throw const DomainException(ErrorCodes.fileTooLong, '音檔超過 10 分鐘上限');
    }
    return duration;
  }
}
