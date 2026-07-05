// AI-Generate
import 'dart:io';

/// 開發期 sidecar 二進位與資料檔的本機路徑（S1a 起手；發布前 M9 授權合規時
/// 須改為隨 App bundle 的 Contents/Resources/sidecar/ 路徑）。
///
/// **必需**：ffmpeg／ffprobe／whisper-cli／whisper-model／cmudict——`missingPaths()`
///   任一缺失即 fallback 到 preview runner（見 [InfraAnalysisRunner]）。
/// **選用**：demucs-cli／demucs-model——`demucsAvailable()` 檢查；缺失時
///   pipeline 自動走「無分離降級」（M4／backend-design §5 第 704 行），
///   使用者若勾了 separateVocals UI 端會顯示「未就緒，將降級使用原音」提示。
class SidecarPaths {
  final String ffmpegPath;
  final String ffprobePath;
  final String whisperCliPath;
  final String whisperModelPath;
  final String cmudictPath;
  final String demucsCliPath;
  final String demucsModelDir;
  final String tempDirectory;

  const SidecarPaths({
    required this.ffmpegPath,
    required this.ffprobePath,
    required this.whisperCliPath,
    required this.whisperModelPath,
    required this.cmudictPath,
    required this.demucsCliPath,
    required this.demucsModelDir,
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
      demucsCliPath: env['DEMUCS_CLI_PATH'] ??
          '$devRoot/.local-tools/demucs.cpp/build/bin/demucs.cpp',
      demucsModelDir: env['DEMUCS_MODEL_DIR'] ??
          '$devRoot/.local-tools/demucs.cpp/ggml-model-htdemucs',
      tempDirectory: tempDir,
    );
  }

  static const _defaultDevRoot =
      '/Users/karen_files/vibercoding project/syllable repeater';

  /// 檢查**必需**依賴路徑是否存在，缺哪一項回傳缺失清單（空 = 全就緒）。
  /// demucs 為選用（見 [demucsAvailable]），不列入此檢查。
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

  /// demucs.cpp 二進位與模型目錄是否就緒（選用，不阻斷 pipeline）。
  /// 未就緒時 pipeline 走 backend-design §5 第 704 行「跳過分離用原音」降級。
  bool demucsAvailable() =>
      File(demucsCliPath).existsSync() &&
      (Directory(demucsModelDir).existsSync() ||
          File(demucsModelDir).existsSync());
}
