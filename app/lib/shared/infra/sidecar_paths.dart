// AI-Generate
import 'dart:io';

/// 開發期 sidecar 二進位與資料檔的本機路徑（S1a 起手；發布前 M9 授權合規時
/// 須改為隨 App bundle 的 Contents/Resources/sidecar/ 路徑）。
class SidecarPaths {
  final String ffmpegPath;
  final String ffprobePath;
  final String whisperCliPath;
  final String whisperModelPath;
  final String cmudictPath;
  final String tempDirectory;

  const SidecarPaths({
    required this.ffmpegPath,
    required this.ffprobePath,
    required this.whisperCliPath,
    required this.whisperModelPath,
    required this.cmudictPath,
    required this.tempDirectory,
  });

  /// 開發期預設：`.local-tools/` 布局；env var 可覆寫個別路徑。
  factory SidecarPaths.dev() {
    final env = Platform.environment;
    final devRoot = env['SYLLABLE_REPEATER_DEV_ROOT'] ?? _defaultDevRoot;
    final tempDir = env['SYLLABLE_REPEATER_TEMP_DIR'] ??
        '${Directory.systemTemp.path}/syllable_repeater';
    return SidecarPaths(
      ffmpegPath: env['FFMPEG_PATH'] ?? '/usr/local/bin/ffmpeg',
      ffprobePath: env['FFPROBE_PATH'] ?? '/usr/local/bin/ffprobe',
      whisperCliPath: env['WHISPER_CLI_PATH'] ??
          '$devRoot/.local-tools/whisper.cpp/build/bin/whisper-cli',
      whisperModelPath: env['WHISPER_MODEL_PATH'] ??
          '$devRoot/.local-tools/whisper.cpp/models/ggml-small.en.bin',
      cmudictPath: env['CMUDICT_PATH'] ??
          '$devRoot/.local-tools/cmudict/cmudict.dict',
      tempDirectory: tempDir,
    );
  }

  static const _defaultDevRoot =
      '/Users/karen_files/vibercoding project/syllable repeater';

  /// 檢查所有依賴路徑是否存在，缺哪一項回傳缺失清單（空 = 全就緒）。
  List<String> missingPaths() {
    final missing = <String>[];
    void check(String label, String path) {
      if (!File(path).existsSync()) {
        missing.add('$label: $path');
      }
    }

    check('ffmpeg', ffmpegPath);
    check('ffprobe', ffprobePath);
    check('whisper-cli', whisperCliPath);
    check('whisper-model', whisperModelPath);
    check('cmudict', cmudictPath);
    return missing;
  }
}
