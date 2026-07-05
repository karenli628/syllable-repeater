// AI-Generate
import 'dart:typed_data';

import 'package:domain/domain.dart';
import 'package:path/path.dart' as p;

import 'sidecar_runner.dart';

/// FFmpeg 解碼契約（task-split 2.3；backend-design §3.2.1 依賴介面）。
///
/// 契約：`ffmpeg -i <in> -f s16le -ar 44100 -ac 1 -` → stdout 為
/// 16-bit little-endian / 44.1kHz / mono PCM；時長由 sample 數推得。
///
/// 錯誤映射（§3.2.8）：
/// - 副檔名不在白名單（Q8）→ ERR_UNSUPPORTED_FORMAT（不呼叫 sidecar）
/// - 行程正常結束但 exit>0（檔案損毀等）→ ERR_DECODE_FAILED
/// - 被訊號終止（exit<0，如 kill -9）或起不來 → ERR_SIDECAR_CRASHED
/// - 逾時 → ERR_SIDECAR_TIMEOUT
/// - 解碼成功但 >10 分鐘（Q8 上限）→ ERR_FILE_TOO_LONG
class FfmpegDecoder implements AnalysisAudioDecoder {
  static const supportedExtensions = {'.mp3', '.wav', '.m4a', '.flac'};
  static const maxDurationMs = 10 * 60 * 1000; // Q8 定案：單檔上限 10 分鐘
  static const sampleRate = 44100;

  final ProcessRunner runner;
  final String ffmpegPath;

  const FfmpegDecoder({required this.runner, required this.ffmpegPath});

  @override
  Future<Pcm> decode(String audioPath) async {
    final ext = p.extension(audioPath).toLowerCase();
    if (!supportedExtensions.contains(ext)) {
      throw const DomainException(
          ErrorCodes.unsupportedFormat, '不支援的音檔格式（支援 mp3/wav/m4a/flac）');
    }

    final SidecarResult result;
    try {
      result = await runner.run(ffmpegPath, [
        '-hide_banner',
        '-i',
        audioPath,
        '-f',
        's16le',
        '-ar',
        '$sampleRate',
        '-ac',
        '1',
        '-',
      ]);
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
    if (!result.isSuccess || result.stdout.isEmpty) {
      final tail = result.stderr.length > 300
          ? result.stderr.substring(result.stderr.length - 300)
          : result.stderr;
      throw DomainException(ErrorCodes.decodeFailed, '無法解碼，檔案可能損毀（$tail）');
    }

    // s16le → Int16List（截去可能的奇數尾 byte）。
    final bytes = Uint8List.fromList(result.stdout);
    final evenLength = bytes.length - (bytes.length % 2);
    final samples =
        bytes.buffer.asInt16List(bytes.offsetInBytes, evenLength ~/ 2);
    final pcm = Pcm(Int16List.fromList(samples), sampleRate: sampleRate);

    if (pcm.durationMs > maxDurationMs) {
      throw const DomainException(ErrorCodes.fileTooLong, '音檔超過 10 分鐘上限');
    }
    return pcm;
  }
}
