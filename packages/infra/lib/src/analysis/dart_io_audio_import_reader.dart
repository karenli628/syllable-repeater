// AI-Generate
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:path/path.dart' as p;

import '../sidecar/ffmpeg_decoder.dart';
import '../sidecar/ffprobe_duration.dart';

/// 以真實檔案 bytes 與 ffprobe 驗證驅動匯入就緒（介面 35；M15）。
class DartIoAudioImportReader implements AudioImportReader {
  const DartIoAudioImportReader({required this.durationProbe});

  final AudioDurationProbe durationProbe;

  @override
  Stream<AudioImportEvent> readAndValidate(String path) async* {
    if (path.trim().isEmpty) {
      throw ArgumentError('path 不可空白');
    }
    final file = File(path);
    try {
      final totalBytes = await file.length();
      var bytesRead = 0;
      await for (final chunk in file.openRead()) {
        bytesRead += chunk.length;
        yield AudioImportEvent(
          progress: AudioImportProgress(
            stage: AudioImportStage.readingBytes,
            bytesRead: bytesRead,
            totalBytes: totalBytes,
          ),
        );
      }
      if (bytesRead == 0) {
        throw const DomainException(ErrorCodes.decodeFailed, '音檔內容為空');
      }

      yield AudioImportEvent(
        progress: AudioImportProgress(
          stage: AudioImportStage.validatingFormat,
          bytesRead: bytesRead,
          totalBytes: totalBytes,
        ),
      );
      if (!FfmpegDecoder.supportedExtensions.contains(
        p.extension(path).toLowerCase(),
      )) {
        throw const DomainException(
          ErrorCodes.unsupportedFormat,
          '不支援的音檔格式（支援 mp3/wav/m4a/flac）',
        );
      }

      yield AudioImportEvent(
        progress: AudioImportProgress(
          stage: AudioImportStage.validatingDuration,
          bytesRead: bytesRead,
          totalBytes: totalBytes,
        ),
      );
      final duration = await durationProbe.probe(path);
      final readySource = AudioReadySource(
        path: path,
        bytesRead: bytesRead,
        durationMs: duration.inMilliseconds,
      );
      yield AudioImportEvent(
        progress: AudioImportProgress(
          stage: AudioImportStage.ready,
          bytesRead: bytesRead,
          totalBytes: totalBytes,
        ),
        readySource: readySource,
      );
    } on DomainException {
      rethrow;
    } on FileSystemException catch (error) {
      throw DomainException(ErrorCodes.decodeFailed, '音檔讀取失敗：${error.message}');
    }
  }
}
