// AI-Generate

/// 單句匯入的真實處理階段（backend-design.md 介面 35；REQ-12／M15）。
enum AudioImportStage {
  readingBytes,
  validatingFormat,
  validatingDuration,
  ready,
}

/// 可呈現的匯入進度；只有 [totalBytes] 已知且大於 0 時才有比例。
class AudioImportProgress {
  const AudioImportProgress({
    required this.stage,
    this.bytesRead = 0,
    this.totalBytes,
  })  : assert(bytesRead >= 0),
        assert(totalBytes == null || totalBytes >= bytesRead);

  final AudioImportStage stage;
  final int bytesRead;
  final int? totalBytes;

  double? get ratio {
    final total = totalBytes;
    if (stage != AudioImportStage.readingBytes || total == null || total == 0) {
      return null;
    }
    return bytesRead / total;
  }
}

/// 已通過非空、格式與時長驗證的分析來源（介面 35）。
class AudioReadySource {
  const AudioReadySource({
    required this.path,
    required this.bytesRead,
    required this.durationMs,
    this.fromPendingSegment = false,
  })  : assert(path != ''),
        assert(bytesRead > 0 || fromPendingSegment),
        assert(durationMs > 0);

  final String path;
  final int bytesRead;
  final int durationMs;
  final bool fromPendingSegment;
}

/// 逐 chunk 匯入事件；只有 [readySource] 非 null 才可開始分析。
class AudioImportEvent {
  const AudioImportEvent({required this.progress, this.readySource});

  final AudioImportProgress progress;
  final AudioReadySource? readySource;
}

/// 音檔讀取與驗證 port（backend-design.md 介面 35；M5/M15）。
abstract interface class AudioImportReader {
  Stream<AudioImportEvent> readAndValidate(String path);
}
