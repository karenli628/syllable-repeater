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
  static String? _managedTempDirectory;

  final String ffmpegPath;
  final String ffprobePath;
  final String whisperCliPath;
  final String whisperModelPath;
  final String cmudictPath;
  final String demucsCliPath;
  final String demucsModelPath;
  final String tempDirectory;

  const SidecarPaths({
    required this.ffmpegPath,
    required this.ffprobePath,
    required this.whisperCliPath,
    required this.whisperModelPath,
    required this.cmudictPath,
    required this.demucsCliPath,
    required this.demucsModelPath,
    required this.tempDirectory,
  });

  /// 啟動後把所有 adapter 導向本次受管理 session（guardrails #62）。
  static void useManagedTempDirectory(String path) {
    if (path.trim().isEmpty) {
      throw ArgumentError('managed temp directory 不可空白');
    }
    _managedTempDirectory = path;
  }

  /// 僅供 session 結束與測試隔離使用。
  static void clearManagedTempDirectory() {
    _managedTempDirectory = null;
  }

  /// App 預設 sidecar 來源：Release/App Store-like AOT 使用 bundle 內資源；
  /// 開發與 widget test 仍使用 `.local-tools/`。
  factory SidecarPaths.current() {
    if (const bool.fromEnvironment('dart.vm.product')) {
      return SidecarPaths.bundled();
    }
    return SidecarPaths.dev();
  }

  /// 開發期預設：`.local-tools/` 布局；env var 可覆寫個別路徑。
  ///
  /// devRoot 尋找順序（2026-07-07 修 S-001：移除寫死絕對路徑）：
  ///   ① 環境變數 `SYLLABLE_REPEATER_DEV_ROOT`
  ///   ② 由 `Directory.current` 或可執行檔所在目錄向上尋找含 `pubspec.yaml`
  ///      且宣告 `name: syllable_repeater_workspace` 的目錄；Finder 啟動
  ///      macOS debug app 時，current directory 通常不是 workspace，必須
  ///      以 executable path 作為第二個搜尋起點。
  ///   ③ 皆無 → `StateError` 提示需設環境變數（不再靜默 fallback）
  ///
  /// 他機 clone 若未設環境變數，會直接拋錯而非落到不存在的路徑。
  factory SidecarPaths.dev() {
    final env = Platform.environment;
    final devRoot = env['SYLLABLE_REPEATER_DEV_ROOT'] ?? _findWorkspaceRoot();
    final tempDir =
        _managedTempDirectory ??
        env['SYLLABLE_REPEATER_TEMP_DIR'] ??
        '${Directory.systemTemp.path}/syllable_repeater';
    return SidecarPaths(
      ffmpegPath: env['FFMPEG_PATH'] ?? '/usr/local/bin/ffmpeg',
      ffprobePath: env['FFPROBE_PATH'] ?? '/usr/local/bin/ffprobe',
      whisperCliPath:
          env['WHISPER_CLI_PATH'] ??
          '$devRoot/.local-tools/whisper.cpp/build/bin/whisper-cli',
      whisperModelPath:
          env['WHISPER_MODEL_PATH'] ??
          '$devRoot/.local-tools/whisper.cpp/models/ggml-small.en.bin',
      cmudictPath:
          env['CMUDICT_PATH'] ?? '$devRoot/.local-tools/cmudict/cmudict.dict',
      demucsCliPath:
          env['DEMUCS_CLI_PATH'] ??
          '$devRoot/.local-tools/demucs.cpp/build/demucs.cpp.main',
      demucsModelPath:
          env['DEMUCS_MODEL_PATH'] ??
          env['DEMUCS_MODEL_DIR'] ??
          '$devRoot/.local-tools/demucs.cpp/ggml-demucs/'
              'ggml-model-htdemucs-4s-f16.bin',
      tempDirectory: tempDir,
    );
  }

  /// 發布期預設：App bundle `Contents/Resources/sidecar/` 布局。
  ///
  /// 2.1 / M9 要求 release sidecar 由 `scripts/prepare_release_sidecars.py`
  /// 產生，並由 macOS build phase 複製到 bundle resources。
  factory SidecarPaths.bundled({String? resourcesRoot}) {
    final env = Platform.environment;
    final root =
        env['SYLLABLE_REPEATER_RESOURCES_DIR'] ??
        resourcesRoot ??
        _defaultBundledResourcesRoot();
    final sidecarRoot =
        env['SYLLABLE_REPEATER_SIDECAR_DIR'] ?? _join(root, 'sidecar');
    final tempDir =
        _managedTempDirectory ??
        env['SYLLABLE_REPEATER_TEMP_DIR'] ??
        '${Directory.systemTemp.path}/syllable_repeater';
    return SidecarPaths(
      ffmpegPath: _join(sidecarRoot, 'bin/ffmpeg'),
      ffprobePath: _join(sidecarRoot, 'bin/ffprobe'),
      whisperCliPath: _join(sidecarRoot, 'bin/whisper-cli'),
      whisperModelPath: _join(sidecarRoot, 'models/ggml-small.en.bin'),
      cmudictPath: _join(sidecarRoot, 'data/cmudict.dict'),
      demucsCliPath: _join(sidecarRoot, 'bin/demucs.cpp.main'),
      demucsModelPath: _join(
        sidecarRoot,
        'models/ggml-model-htdemucs-4s-f16.bin',
      ),
      tempDirectory: tempDir,
    );
  }

  /// 由執行環境可取得的兩個起點向上尋找 workspace 根目錄；找不到即拋錯。
  /// 判定條件：目錄下有 `pubspec.yaml` 且內含 `name: syllable_repeater_workspace`。
  static String _findWorkspaceRoot() {
    final starts = <Directory>[
      Directory.current,
      File(Platform.resolvedExecutable).parent,
    ];
    for (final start in starts) {
      var dir = start;
      for (var i = 0; i < 16; i++) {
        final pubspec = File('${dir.path}/pubspec.yaml');
        if (pubspec.existsSync()) {
          final content = pubspec.readAsStringSync();
          if (content.contains('name: syllable_repeater_workspace')) {
            return dir.path;
          }
        }
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
    }
    throw StateError(
      '找不到 syllable_repeater_workspace 根目錄。請設定環境變數 '
      'SYLLABLE_REPEATER_DEV_ROOT=<repo 絕對路徑>；'
      '或從 workspace／其 build app 路徑啟動。',
    );
  }

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

  /// demucs.cpp 二進位與模型檔是否就緒（選用，不阻斷 pipeline）。
  /// 未就緒時 pipeline 走 backend-design §5 第 704 行「跳過分離用原音」降級。
  bool demucsAvailable() =>
      File(demucsCliPath).existsSync() && File(demucsModelPath).existsSync();

  /// 結構化就緒狀態清單（2026-07-07 新增，借鏡 QwenASRMiniTool「工具就緒狀態」模式）。
  ///
  /// 供未來設定頁「分析工具狀態」區塊消費：每項就緒狀態、路徑、缺件時的取得指引；
  /// 本方法**不接 UI**，僅提供純資料，避免動已完成的 progress_settings_screen。
  ///
  /// 排序：必需項先、選用項後；同類按管線階段順序。
  List<SidecarComponentStatus> diagnose() {
    SidecarComponentStatus check({
      required String id,
      required String label,
      required String path,
      required bool required,
      required String hint,
    }) {
      return SidecarComponentStatus(
        id: id,
        label: label,
        path: path,
        exists: File(path).existsSync(),
        required: required,
        acquisitionHint: hint,
      );
    }

    return [
      check(
        id: 'ffmpeg',
        label: 'FFmpeg（解碼）',
        path: ffmpegPath,
        required: true,
        hint:
            'dev：brew install ffmpeg（GPL build 僅限開發）；'
            'release：必須 LGPL shared build（走 scripts/prepare_release_sidecars.py）。',
      ),
      check(
        id: 'ffprobe',
        label: 'FFprobe（時長探測）',
        path: ffprobePath,
        required: true,
        hint: '隨 FFmpeg 一起安裝；release 走 staging gate。',
      ),
      check(
        id: 'whisper-cli',
        label: 'whisper.cpp（辨識引擎）',
        path: whisperCliPath,
        required: true,
        hint:
            'clone github.com/ggerganov/whisper.cpp 並 cmake build；'
            '請放到 .local-tools/whisper.cpp/build/bin/。',
      ),
      check(
        id: 'whisper-model',
        label: 'whisper small.en 模型',
        path: whisperModelPath,
        required: true,
        hint:
            'bash whisper.cpp/models/download-ggml-model.sh small.en；'
            '約 466 MB，MIT 授權。',
      ),
      check(
        id: 'cmudict',
        label: 'CMUdict（音節切分）',
        path: cmudictPath,
        required: true,
        hint: 'clone github.com/cmusphinx/cmudict；BSD-like 授權。',
      ),
      check(
        id: 'demucs-cli',
        label: 'demucs.cpp（人聲分離，選用）',
        path: demucsCliPath,
        required: false,
        hint:
            'clone github.com/sevagh/demucs.cpp 並 cmake build；'
            '未就緒時 pipeline 自動跳過分離改用原音（M4 降級）。',
      ),
      check(
        id: 'demucs-model',
        label: 'demucs htdemucs 4-source 模型（選用）',
        path: demucsModelPath,
        required: false,
        hint:
            '下載 ggml-model-htdemucs-4s-f16.bin 到 '
            '.local-tools/demucs.cpp/ggml-demucs/。',
      ),
    ];
  }

  static String _defaultBundledResourcesRoot() {
    final executableDir = File(Platform.resolvedExecutable).parent;
    return _join(executableDir.parent.path, 'Resources');
  }

  static String _join(String base, String child) {
    final normalizedBase = base.endsWith(Platform.pathSeparator)
        ? base.substring(0, base.length - 1)
        : base;
    return '$normalizedBase${Platform.pathSeparator}$child';
  }
}

/// [SidecarPaths.diagnose] 的單筆結果（純資料，供未來 UI 消費）。
class SidecarComponentStatus {
  final String id;
  final String label;
  final String path;
  final bool exists;
  final bool required;
  final String acquisitionHint;

  const SidecarComponentStatus({
    required this.id,
    required this.label,
    required this.path,
    required this.exists,
    required this.required,
    required this.acquisitionHint,
  });

  /// 是否處於「就緒可用」狀態：檔案存在。
  bool get ready => exists;

  /// 是否阻斷主流程：必需項且缺件。
  bool get blocking => required && !exists;
}
