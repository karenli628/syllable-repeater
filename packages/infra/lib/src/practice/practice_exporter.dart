// AI-Generate
import 'dart:typed_data';

import 'package:domain/domain.dart';

import '../sidecar/sidecar_runner.dart';

/// MP3 匯出完成結果（backend-design.md §3.2.2 介面 5/6）。
class PracticeExportResult {
  final String path;
  final int totalDurationMs;
  final List<int> silenceGapsMs;

  PracticeExportResult({
    required this.path,
    required this.totalDurationMs,
    required List<int> silenceGapsMs,
  }) : silenceGapsMs = List.unmodifiable(silenceGapsMs);
}

/// PracticeEngine 匯出轉接器（task-split 4.6）。
///
/// Domain 只負責 M1/M3 音訊組裝；本類負責 FFmpeg MP3 編碼、temp→atomic
/// write 與同目的檔重入鎖，避免把 Process/File IO 帶入 packages/domain。
class PracticeExporter {
  final PracticeEngine engine;
  final ProcessRunner runner;
  final FileIo fileIo;
  final String ffmpegPath;
  final Duration timeout;

  final Set<String> _activeDestPaths = <String>{};

  PracticeExporter({
    required this.engine,
    required this.runner,
    required this.fileIo,
    required this.ffmpegPath,
    this.timeout = const Duration(seconds: 120),
  });

  Future<PracticeExportResult> exportStep(
    PracticeStep step,
    Pcm originalPcm,
    String destPath,
  ) {
    final audio = engine.renderExportStep(step, originalPcm);
    return _writeMp3(audio, destPath);
  }

  Future<PracticeExportResult> exportMerged(
    List<PracticeStep> steps,
    Pcm originalPcm,
    String destPath,
  ) {
    final audio = engine.renderMergedExport(steps, originalPcm);
    return _writeMp3(audio, destPath);
  }

  Future<PracticeExportResult> _writeMp3(
    PracticeExportAudio audio,
    String destPath,
  ) async {
    if (_activeDestPaths.contains(destPath)) {
      throw const DomainException(ErrorCodes.exportInProgress, '匯出進行中');
    }

    _activeDestPaths.add(destPath);
    try {
      final mp3Bytes = await _encodeMp3(audio.pcm);
      try {
        await fileIo.writeBytesAtomic(destPath, mp3Bytes);
      } catch (_) {
        throw const DomainException(
          ErrorCodes.exportDestUnwritable,
          '目的地無法寫入',
        );
      }

      return PracticeExportResult(
        path: destPath,
        totalDurationMs: audio.totalDurationMs,
        silenceGapsMs: audio.silenceGapsMs,
      );
    } finally {
      _activeDestPaths.remove(destPath);
    }
  }

  Future<Uint8List> _encodeMp3(Pcm pcm) async {
    final inputPath = await fileIo.createTempFilePath('.wav');
    try {
      await fileIo.writeBytesAtomic(inputPath, encodeWav(pcm));
      final SidecarResult result;
      try {
        result = await runner.run(
            ffmpegPath,
            [
              '-hide_banner',
              '-y',
              '-i',
              inputPath,
              '-codec:a',
              'libmp3lame',
              '-f',
              'mp3',
              '-',
            ],
            timeout: timeout);
      } on SidecarFailure catch (failure) {
        if (failure.isTimeout) {
          throw const DomainException(
            ErrorCodes.sidecarTimeout,
            '匯出編碼逾時，可重試或調高逾時設定',
          );
        }
        throw DomainException(
          ErrorCodes.sidecarCrashed,
          '匯出編碼器無法啟動（${failure.detail}）',
        );
      }

      if (result.wasKilledBySignal) {
        throw const DomainException(ErrorCodes.sidecarCrashed, '匯出編碼器異常結束');
      }
      if (!result.isSuccess || result.stdout.isEmpty) {
        final tail = result.stderr.length > 300
            ? result.stderr.substring(result.stderr.length - 300)
            : result.stderr;
        throw DomainException(ErrorCodes.sidecarCrashed, '匯出編碼失敗（$tail）');
      }

      return Uint8List.fromList(result.stdout);
    } finally {
      try {
        await fileIo.delete(inputPath);
      } catch (_) {
        // 清理失敗不掩蓋編碼或寫檔錯誤；App 啟動時仍會 clearTemp。
      }
    }
  }
}
