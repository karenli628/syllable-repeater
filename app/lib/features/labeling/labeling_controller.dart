// AI-Generate
import 'dart:async';

import 'package:domain/domain.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infra/infra.dart'
    show AtomicFileIo, DriftLabelRegistryRepository;
import 'package:just_audio/just_audio.dart';

import '../../features/progress/progress_service.dart' show appDatabaseProvider;
import '../../features/progress/progress_service.dart' show SystemClock;
import '../../shared/infra/segment_engine_factory.dart';
import '../../shared/pending_segment.dart';
import '../../shared/infra/sidecar_paths.dart';

/// 段落標籤頁的音檔選擇器窄介面（frontend-design.md 功能點 10）。
abstract interface class LabelingFilePicker {
  Future<String?> pickAudioPath();

  Future<String?> pickLabelSavePath();

  Future<String?> pickLabelOpenPath();
}

/// macOS 原生音檔選擇器；批次匯入不在本任務範圍。
class FileSelectorLabelingFilePicker implements LabelingFilePicker {
  const FileSelectorLabelingFilePicker();

  static const _audioTypes = XTypeGroup(
    label: 'Audio',
    extensions: ['mp3', 'wav', 'm4a', 'flac'],
    uniformTypeIdentifiers: [
      'public.mp3',
      'com.microsoft.waveform-audio',
      'public.mpeg-4-audio',
      'org.xiph.flac',
    ],
  );

  static const _labelTypes = XTypeGroup(
    label: 'AboLabel',
    extensions: ['abolabel'],
  );

  @override
  Future<String?> pickAudioPath() async {
    final file = await openFile(
      acceptedTypeGroups: const [_audioTypes],
      confirmButtonText: '選擇音檔',
    );
    return file?.path;
  }

  @override
  Future<String?> pickLabelSavePath() async {
    final location = await getSaveLocation(
      acceptedTypeGroups: const [_labelTypes],
      suggestedName: 'syllable-label.abolabel',
      confirmButtonText: '儲存標籤',
      canCreateDirectories: true,
    );
    final path = location?.path;
    if (path == null || path.toLowerCase().endsWith('.abolabel')) {
      return path;
    }
    return '$path.abolabel';
  }

  @override
  Future<String?> pickLabelOpenPath() async {
    final file = await openFile(
      acceptedTypeGroups: const [_labelTypes],
      confirmButtonText: '載入標籤',
    );
    return file?.path;
  }
}

/// SegmentEngine 介面 20 的注入點；測試可覆寫為 fake engine。
final labelingEngineProvider = Provider<SegmentEngine?>((ref) {
  final paths = SidecarPaths.current();
  if (paths.missingPaths().isNotEmpty) {
    return null;
  }
  return buildSegmentEngine(
    paths: paths,
    database: ref.watch(appDatabaseProvider),
  );
});

final labelingFilePickerProvider = Provider<LabelingFilePicker>(
  (ref) => const FileSelectorLabelingFilePicker(),
);

/// Controller 使用的 `.abolabel` 儲存窄介面；實作委派 Domain LabelPackEngine。
abstract interface class LabelingPackStore {
  Future<String> writeLabel(LabelSession session, String destPath);

  Future<LabelSession> readLabel(
    String path, {
    required String expectedFingerprint,
  });
}

class DomainLabelingPackStore implements LabelingPackStore {
  const DomainLabelingPackStore(this.engine);

  final LabelPackEngine engine;

  @override
  Future<String> writeLabel(LabelSession session, String destPath) =>
      engine.writeLabel(session, destPath);

  @override
  Future<LabelSession> readLabel(
    String path, {
    required String expectedFingerprint,
  }) => engine.readLabel(path, expectedFingerprint: expectedFingerprint);
}

final labelingPackStoreProvider = Provider<LabelingPackStore>((ref) {
  final paths = SidecarPaths.current();
  return DomainLabelingPackStore(
    LabelPackEngine(
      fileIo: AtomicFileIo(tempDirPath: paths.tempDirectory),
      repository: DriftLabelRegistryRepository(ref.watch(appDatabaseProvider)),
      clock: const SystemClock(),
    ),
  );
});

/// 段落原音試聽窄介面；只接受原始音檔路徑與 Domain Segment 範圍。
abstract interface class LabelingSegmentPreview {
  Stream<int> get positionsMs;

  Future<void> play(String audioPath, Segment segment);

  Future<void> pause();

  Future<void> resume();

  Future<void> stop();
}

final labelingSegmentPreviewProvider = Provider<LabelingSegmentPreview>((ref) {
  final preview = JustAudioLabelingSegmentPreview();
  ref.onDispose(preview.dispose);
  return preview;
});

/// just_audio 的窄介面，讓 clip 相對座標與完整區段播放可被單元測試鎖定。
abstract interface class LabelingAudioBackend {
  Stream<Duration> get positions;

  Future<void> setFilePath(String path);

  Future<void> setClip({required Duration start, required Duration end});

  Future<void> seek(Duration position);

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  Future<void> dispose();
}

class JustAudioLabelingBackend implements LabelingAudioBackend {
  JustAudioLabelingBackend({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Stream<Duration> get positions => _player.positionStream;

  @override
  Future<void> setFilePath(String path) async {
    await _player.setFilePath(path);
  }

  @override
  Future<void> setClip({required Duration start, required Duration end}) async {
    await _player.setClip(start: start, end: end);
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

/// 以原音檔的時間範圍試聽，不產生或改寫任何分析音訊。
class JustAudioLabelingSegmentPreview implements LabelingSegmentPreview {
  JustAudioLabelingSegmentPreview({LabelingAudioBackend? backend})
    : _backend = backend ?? JustAudioLabelingBackend();

  final LabelingAudioBackend _backend;
  int _clipStartMs = 0;

  @override
  Stream<int> get positionsMs => _backend.positions.map(
    (position) => _clipStartMs + position.inMilliseconds,
  );

  @override
  Future<void> play(String audioPath, Segment segment) async {
    await stop();
    _clipStartMs = segment.startMs;
    await _backend.setFilePath(audioPath);
    await _backend.setClip(
      start: Duration(milliseconds: segment.startMs),
      end: Duration(milliseconds: segment.endMs),
    );
    await _backend.seek(Duration.zero);
    await _backend.play();
  }

  @override
  Future<void> pause() => _backend.pause();

  @override
  Future<void> resume() => _backend.play();

  @override
  Future<void> stop() => _backend.stop();

  Future<void> dispose() => _backend.dispose();
}

/// 標籤頁的階段狀態；介面 20 回報真實 stage，未知總量時以 indeterminate
/// 呈現，不虛構 sidecar 的細部百分比（REQ-11／M15）。
enum LabelingRunStatus { idle, opening, ready, failed }

/// 段落試聽的播放狀態（REQ-11 AT-11-16）。
enum LabelingPreviewStatus { idle, playing, paused }

/// 段落標籤頁的不可變 UI 狀態（REQ-11、AT-11-01/05～08）。
class LabelingUiState {
  const LabelingUiState({
    this.audioPath,
    this.session,
    this.peaks = const [],
    this.status = LabelingRunStatus.idle,
    this.selectedSegmentIndex,
    this.draggingBoundaryIndex,
    this.draggingPreviewMs,
    this.existingLabelPath,
    this.warning,
    this.error,
    this.progress,
    this.previewStatus = LabelingPreviewStatus.idle,
    this.previewingSegmentIndex,
    this.playheadMs,
  });

  static const Object _unset = Object();

  final String? audioPath;
  final LabelSession? session;
  final List<double> peaks;
  final LabelingRunStatus status;
  final int? selectedSegmentIndex;
  final int? draggingBoundaryIndex;
  final int? draggingPreviewMs;
  final String? existingLabelPath;
  final LabelOpenWarning? warning;
  final DomainException? error;
  final LabelOpenProgress? progress;
  final LabelingPreviewStatus previewStatus;
  final int? previewingSegmentIndex;
  final int? playheadMs;

  bool get isOpening => status == LabelingRunStatus.opening;

  bool get isReady => status == LabelingRunStatus.ready && session != null;

  bool get dirty => session?.dirty ?? false;

  LabelingUiState copyWith({
    Object? audioPath = _unset,
    Object? session = _unset,
    List<double>? peaks,
    LabelingRunStatus? status,
    Object? selectedSegmentIndex = _unset,
    Object? draggingBoundaryIndex = _unset,
    Object? draggingPreviewMs = _unset,
    Object? existingLabelPath = _unset,
    Object? warning = _unset,
    Object? error = _unset,
    Object? progress = _unset,
    LabelingPreviewStatus? previewStatus,
    Object? previewingSegmentIndex = _unset,
    Object? playheadMs = _unset,
  }) {
    return LabelingUiState(
      audioPath: identical(audioPath, _unset)
          ? this.audioPath
          : audioPath as String?,
      session: identical(session, _unset)
          ? this.session
          : session as LabelSession?,
      peaks: peaks ?? this.peaks,
      status: status ?? this.status,
      selectedSegmentIndex: identical(selectedSegmentIndex, _unset)
          ? this.selectedSegmentIndex
          : selectedSegmentIndex as int?,
      draggingBoundaryIndex: identical(draggingBoundaryIndex, _unset)
          ? this.draggingBoundaryIndex
          : draggingBoundaryIndex as int?,
      draggingPreviewMs: identical(draggingPreviewMs, _unset)
          ? this.draggingPreviewMs
          : draggingPreviewMs as int?,
      existingLabelPath: identical(existingLabelPath, _unset)
          ? this.existingLabelPath
          : existingLabelPath as String?,
      warning: identical(warning, _unset)
          ? this.warning
          : warning as LabelOpenWarning?,
      error: identical(error, _unset) ? this.error : error as DomainException?,
      progress: identical(progress, _unset)
          ? this.progress
          : progress as LabelOpenProgress?,
      previewStatus: previewStatus ?? this.previewStatus,
      previewingSegmentIndex: identical(previewingSegmentIndex, _unset)
          ? this.previewingSegmentIndex
          : previewingSegmentIndex as int?,
      playheadMs: identical(playheadMs, _unset)
          ? this.playheadMs
          : playheadMs as int?,
    );
  }
}

/// 段落標籤頁 Controller（frontend-design.md 功能點 10、REQ-11）。
class LabelingController extends Notifier<LabelingUiState> {
  StreamSubscription<int>? _previewPositionSub;
  int _previewRunId = 0;

  @override
  LabelingUiState build() {
    ref.onDispose(() {
      _previewPositionSub?.cancel();
    });
    return const LabelingUiState();
  }

  /// 由 `.abopack v3` 還原可選段落標籤，原音仍使用封包抽出的本機檔（REQ-21）。
  void hydrateCourseBundleLabels(
    CourseBundle bundle, {
    required String extractedAudioPath,
  }) {
    final labels = bundle.labels;
    if (labels == null) {
      throw ArgumentError('CourseBundle.labels 不可為 null');
    }
    final session = LabelSession(
      audioFingerprint: bundle.audioFingerprint,
      audioDurationMs: bundle.audioDurationMs,
      language: labels.language,
      separateVocals: labels.separateVocals,
      segments: labels.segments,
    );
    state = LabelingUiState(
      audioPath: extractedAudioPath,
      session: session,
      status: LabelingRunStatus.ready,
    );
  }

  /// 介面 20：開啟整段音檔，保留正常 session 與 ASR warning。
  Future<void> openAudio(
    String path, {
    bool separateVocals = true,
    String language = 'en',
  }) async {
    if (state.isOpening) {
      return;
    }
    if (!_isSupportedAudio(path)) {
      state = state.copyWith(
        audioPath: path,
        status: LabelingRunStatus.failed,
        error: const DomainException(
          ErrorCodes.unsupportedFormat,
          '音檔格式不支援（支援 mp3/wav/m4a/flac）',
        ),
        session: null,
        peaks: const [],
      );
      return;
    }

    final engine = ref.read(labelingEngineProvider);
    if (engine == null) {
      state = state.copyWith(
        audioPath: path,
        status: LabelingRunStatus.failed,
        error: const DomainException(
          ErrorCodes.decodeFailed,
          '標籤分析工具尚未就緒，請先完成 FFmpeg、whisper.cpp 與 CMUdict 設定',
        ),
        session: null,
        peaks: const [],
      );
      return;
    }

    state = state.copyWith(
      audioPath: path,
      status: LabelingRunStatus.opening,
      session: null,
      peaks: const [],
      selectedSegmentIndex: null,
      existingLabelPath: null,
      warning: null,
      error: null,
      progress: null,
    );

    try {
      final result = await engine.openAudio(
        path,
        separateVocals: separateVocals,
        language: language,
        onProgress: (progress) {
          if (!state.isOpening || state.audioPath != path) return;
          state = state.copyWith(progress: progress);
        },
      );
      state = state.copyWith(
        status: LabelingRunStatus.ready,
        session: result.session,
        peaks: result.peaks,
        existingLabelPath: result.existingLabelPath,
        warning: result.warning,
        error: null,
      );
    } on DomainException catch (error) {
      state = state.copyWith(status: LabelingRunStatus.failed, error: error);
    } catch (error) {
      state = state.copyWith(
        status: LabelingRunStatus.failed,
        error: DomainException(ErrorCodes.decodeFailed, '標籤音檔開啟失敗：$error'),
      );
    }
  }

  /// 成功寫入 `.abolabel` 後才清除 Domain dirty 狀態（AT-11-03）。
  Future<bool> saveLabel(String destPath) async {
    final session = state.session;
    if (session == null || destPath.trim().isEmpty) {
      return false;
    }
    try {
      final writtenPath = await ref
          .read(labelingPackStoreProvider)
          .writeLabel(session, destPath);
      state = state.copyWith(existingLabelPath: writtenPath, error: null);
      return true;
    } on DomainException catch (error) {
      state = state.copyWith(error: error);
      return false;
    } catch (error) {
      state = state.copyWith(
        error: DomainException(
          ErrorCodes.exportDestUnwritable,
          '標籤檔儲存失敗：$error',
        ),
      );
      return false;
    }
  }

  /// 載入 SegmentEngine 提示的既有 `.abolabel`，並以目前音檔指紋驗證。
  Future<bool> loadExistingLabel() async {
    final path = state.existingLabelPath;
    final current = state.session;
    if (path == null || current == null) return false;
    try {
      final loaded = await ref
          .read(labelingPackStoreProvider)
          .readLabel(path, expectedFingerprint: current.audioFingerprint);
      state = state.copyWith(
        session: loaded,
        existingLabelPath: null,
        selectedSegmentIndex: null,
        error: null,
      );
      return true;
    } on DomainException catch (error) {
      state = state.copyWith(error: error);
      return false;
    } catch (error) {
      state = state.copyWith(
        error: DomainException(ErrorCodes.labelCorrupted, '標籤檔載入失敗：$error'),
      );
      return false;
    }
  }

  /// 使用者在既有標籤提示選擇「不載入」時清除提示，不改 session。
  void dismissExistingLabel() {
    state = state.copyWith(existingLabelPath: null);
  }

  /// 選取一個段落；實際線／清單互動由 FP10.2 寫回此狀態。
  void selectSegment(int? index) {
    final segments = state.session?.segments ?? const <Segment>[];
    if (index != null && (index < 0 || index >= segments.length)) {
      return;
    }
    state = state.copyWith(selectedSegmentIndex: index);
  }

  /// 將現有區間明示標記為保留或捨棄（REQ-11、AT-11-12）。
  void setSegmentDisposition(int index, SegmentDisposition disposition) {
    final session = state.session;
    final segments = session?.segments ?? const <Segment>[];
    if (session == null || index < 0 || index >= segments.length) {
      return;
    }
    final segment = segments[index];
    if (segment.disposition == disposition) {
      return;
    }
    if (disposition == SegmentDisposition.kept) {
      session.markKept(segment.range, text: segment.text);
    } else {
      session.markDiscarded(segment.range);
    }
    state = state.copyWith(
      session: session,
      selectedSegmentIndex: index,
      error: null,
    );
  }

  /// 將目前勾選的單一 Segment 交給單句分析入口（REQ-11／REQ-12、AT-12-02）。
  ///
  /// 只傳遞原音路徑、起訖毫秒、文字與 language；PCM 不跨 feature 複製，
  /// 且 shared provider 永遠只有一個待處理區段。
  bool handoffSelectedSegment() {
    final index = state.selectedSegmentIndex;
    if (index == null) return false;
    return handoffSegment(index);
  }

  /// 以索引交接單一 Segment，供清單勾選與鍵盤操作共用。
  bool handoffSegment(int index) {
    final path = state.audioPath;
    final segments = state.session?.segments ?? const <Segment>[];
    if (path == null || index < 0 || index >= segments.length) {
      return false;
    }
    final segment = segments[index];
    if (segment.disposition != SegmentDisposition.kept) {
      return false;
    }
    ref
        .read(pendingSegmentProvider.notifier)
        .set(
          PendingSegment(
            segmentId: segment.id,
            sourceAudioPath: path,
            startMs: segment.startMs,
            endMs: segment.endMs,
            text: segment.text,
            language: segment.language,
            segmentIndex: index,
          ),
        );
    state = state.copyWith(selectedSegmentIndex: index, error: null);
    return true;
  }

  /// 拖曳開始只記錄本地預覽，不修改 Domain session（AT-11-02）。
  void dragStart(int boundaryIndex) {
    final session = state.session;
    if (session == null ||
        boundaryIndex < 0 ||
        boundaryIndex >= session.segments.length - 1) {
      return;
    }
    state = state.copyWith(
      draggingBoundaryIndex: boundaryIndex,
      draggingPreviewMs: session.segments[boundaryIndex].endMs,
      error: null,
    );
  }

  /// 拖曳中只更新本地預覽線，放開時才呼叫 LabelSession.moveBoundary。
  void dragUpdate(int previewMs) {
    if (state.draggingBoundaryIndex == null) return;
    state = state.copyWith(draggingPreviewMs: previewMs);
  }

  /// 以 Domain 的 ERR_BOUNDARY_INVALID／邊界規則驗證並提交拖曳結果。
  void dragEnd() {
    final session = state.session;
    final index = state.draggingBoundaryIndex;
    final previewMs = state.draggingPreviewMs;
    if (session == null || index == null || previewMs == null) return;
    try {
      session.moveBoundary(index, previewMs);
      state = state.copyWith(
        session: session,
        draggingBoundaryIndex: null,
        draggingPreviewMs: null,
        error: null,
      );
    } on DomainException catch (error) {
      state = state.copyWith(
        draggingBoundaryIndex: null,
        draggingPreviewMs: null,
        error: error,
      );
    }
  }

  /// 在指定毫秒插入兩段；驗證交由 LabelSession。
  void insertBoundary(int atMs) {
    final session = state.session;
    if (session == null) return;
    try {
      session.insertBoundary(atMs);
      state = state.copyWith(session: session, error: null);
    } on DomainException catch (error) {
      state = state.copyWith(error: error);
    }
  }

  /// 移除第 [boundaryIndex] 條線並合併相鄰段落；最少一段由 Domain 擋下。
  void removeBoundary(int boundaryIndex) {
    final session = state.session;
    if (session == null) return;
    try {
      session.removeBoundary(boundaryIndex);
      final selected = state.selectedSegmentIndex;
      state = state.copyWith(
        session: session,
        selectedSegmentIndex: selected == null
            ? null
            : (selected > boundaryIndex ? selected - 1 : selected),
        error: null,
      );
    } on DomainException catch (error) {
      state = state.copyWith(error: error);
    }
  }

  /// 以原始音檔範圍試聽選定段落（M1：不合成、不跨來源拼接）。
  Future<void> previewSegment(int index) async {
    final path = state.audioPath;
    final segments = state.session?.segments ?? const <Segment>[];
    if (path == null || index < 0 || index >= segments.length) return;
    final preview = ref.read(labelingSegmentPreviewProvider);
    if (state.previewingSegmentIndex == index &&
        state.previewStatus == LabelingPreviewStatus.playing) {
      _previewRunId++;
      await preview.pause();
      state = state.copyWith(previewStatus: LabelingPreviewStatus.paused);
      return;
    }
    if (state.previewingSegmentIndex == index &&
        state.previewStatus == LabelingPreviewStatus.paused) {
      final runId = ++_previewRunId;
      state = state.copyWith(previewStatus: LabelingPreviewStatus.playing);
      try {
        await preview.resume();
        if (ref.mounted && _previewRunId == runId) {
          state = state.copyWith(
            previewStatus: LabelingPreviewStatus.idle,
            previewingSegmentIndex: null,
            playheadMs: null,
          );
        }
      } catch (error) {
        if (ref.mounted && _previewRunId == runId) {
          state = state.copyWith(
            previewStatus: LabelingPreviewStatus.idle,
            previewingSegmentIndex: null,
            playheadMs: null,
            error: DomainException(ErrorCodes.decodeFailed, '段落續播失敗：$error'),
          );
        }
      }
      return;
    }
    final runId = ++_previewRunId;
    await preview.stop();
    _previewPositionSub ??= preview.positionsMs.listen((positionMs) {
      if (!ref.mounted || state.previewStatus == LabelingPreviewStatus.idle) {
        return;
      }
      state = state.copyWith(
        playheadMs: positionMs.clamp(0, state.session!.audioDurationMs),
      );
    });
    state = state.copyWith(
      previewStatus: LabelingPreviewStatus.playing,
      previewingSegmentIndex: index,
      playheadMs: segments[index].startMs,
      error: null,
    );
    try {
      await preview.play(path, segments[index]);
      if (ref.mounted && _previewRunId == runId) {
        state = state.copyWith(
          previewStatus: LabelingPreviewStatus.idle,
          previewingSegmentIndex: null,
          playheadMs: null,
        );
      }
    } catch (error) {
      if (ref.mounted && _previewRunId == runId) {
        state = state.copyWith(
          previewStatus: LabelingPreviewStatus.idle,
          previewingSegmentIndex: null,
          playheadMs: null,
          error: DomainException(ErrorCodes.decodeFailed, '段落試聽失敗：$error'),
        );
      }
    }
  }

  /// 停止後清除播放軸；下次播放必須由區段起點重新開始（AT-11-16）。
  Future<void> stopPreview() async {
    _previewRunId++;
    await ref.read(labelingSegmentPreviewProvider).stop();
    state = state.copyWith(
      previewStatus: LabelingPreviewStatus.idle,
      previewingSegmentIndex: null,
      playheadMs: null,
    );
  }

  void clearError() => state = state.copyWith(error: null);

  bool _isSupportedAudio(String path) {
    final extension = path.split('.').last.toLowerCase();
    return const {'mp3', 'wav', 'm4a', 'flac'}.contains(extension);
  }
}

final labelingControllerProvider =
    NotifierProvider<LabelingController, LabelingUiState>(
      LabelingController.new,
    );
