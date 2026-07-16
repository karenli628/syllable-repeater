// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infra/infra.dart';

import '../../shared/pending_segment.dart';

final analysisRunnerProvider = Provider<AnalysisRunner>(
  (ref) => const PreviewAnalysisRunner(),
);

/// UI 端音檔時長前置檢查（10 分鐘上限）；為 null 時跳過 UI 前置檢查，
/// 仍由 pipeline 解碼後把關（見 FfmpegDecoder.maxDurationMs）。
final audioDurationProbeProvider = Provider<AudioDurationProbe?>((ref) => null);

/// 真實逐 byte 匯入 reader；正式 App 由 main 注入，測試可用 fake 控制階段。
final audioImportReaderProvider = Provider<AudioImportReader?>((ref) => null);

/// demucs.cpp 二進位與模型是否就緒（task-split 3.8）；為 false 時使用者若勾
/// separateVocals，UI 顯示「未就緒，將降級使用原音」提示。預設 false，由
/// `main.dart` 覆寫；widget test 不覆寫時等同「未就緒」＝preview 環境的合理值。
final demucsReadyProvider = Provider<bool>((ref) => false);

/// 草稿 Lesson 身分產生器注入點（backend-design.md 介面 36；REQ-15）。
abstract interface class DraftLessonIdentityGenerator {
  DraftLessonIdentity create();
}

final draftLessonIdentityGeneratorProvider =
    Provider<DraftLessonIdentityGenerator>(
      (ref) => SystemDraftLessonIdentityGenerator(),
    );

/// 以 UTC 微秒建立單機草稿 id；同一程序內遇到相同時間時仍保持單調唯一。
class SystemDraftLessonIdentityGenerator
    implements DraftLessonIdentityGenerator {
  int _lastIssuedMicros = 0;

  @override
  DraftLessonIdentity create() {
    final current = DateTime.now().toUtc().microsecondsSinceEpoch;
    final issued = current > _lastIssuedMicros
        ? current
        : _lastIssuedMicros + 1;
    _lastIssuedMicros = issued;
    return DraftLessonIdentity(lessonId: 'draft-$issued');
  }
}

final analysisControllerProvider =
    NotifierProvider<AnalysisController, AnalysisUiState>(
      AnalysisController.new,
    );

abstract interface class AnalysisRunner {
  Stream<AnalysisEvent> analyze(
    ImportRequest request, {
    PipelineCheckpoint? resume,
  });
}

enum AnalysisRunStatus { idle, loading, ready, running, done, failed }

class AnalysisUiState {
  const AnalysisUiState({
    this.selectedAudioPath,
    this.transcript = '',
    this.language = 'en',
    this.separateVocals = false,
    this.isDragging = false,
    this.status = AnalysisRunStatus.idle,
    this.latestEvent,
    this.result,
    this.error,
    this.lastCheckpoint,
    this.pendingSegment,
    this.aiTranslation,
    this.draftIdentity,
    this.importProgress,
    this.readySource,
  });

  static const Object _unset = Object();

  final String? selectedAudioPath;
  final String transcript;
  final String language;
  final bool separateVocals;
  final bool isDragging;
  final AnalysisRunStatus status;
  final AnalysisEvent? latestEvent;
  final AlignmentResult? result;
  final DomainException? error;

  /// pipeline 失敗時保留的分階段中間產物；重試時交回 pipeline 跳過已完成階段。
  final PipelineCheckpoint? lastCheckpoint;

  /// 最近一次由段落標籤交接的來源資訊；PCM 不存於此狀態。
  final PendingSegment? pendingSegment;

  /// 最近一次 AI 譯文結果；手動譯文在課件草稿建構時永遠優先。
  final Translation? aiTranslation;

  /// 分析成功才建立；editor、arrangement 與保存流程沿用同一 id（#53）。
  final DraftLessonIdentity? draftIdentity;
  final AudioImportProgress? importProgress;
  final AudioReadySource? readySource;

  bool get hasAudio => selectedAudioPath != null;

  bool get isRunning => status == AnalysisRunStatus.running;

  bool get isLoading => status == AnalysisRunStatus.loading;

  bool get isAudioReady => readySource != null;

  bool get canStart => isAudioReady && !isRunning && !isLoading;

  bool get canRetryStage =>
      status == AnalysisRunStatus.failed &&
      lastCheckpoint != null &&
      !lastCheckpoint!.isEmpty;

  AnalysisUiState copyWith({
    Object? selectedAudioPath = _unset,
    String? transcript,
    String? language,
    bool? separateVocals,
    bool? isDragging,
    AnalysisRunStatus? status,
    Object? latestEvent = _unset,
    Object? result = _unset,
    Object? error = _unset,
    Object? lastCheckpoint = _unset,
    Object? pendingSegment = _unset,
    Object? aiTranslation = _unset,
    Object? draftIdentity = _unset,
    Object? importProgress = _unset,
    Object? readySource = _unset,
  }) {
    return AnalysisUiState(
      selectedAudioPath: identical(selectedAudioPath, _unset)
          ? this.selectedAudioPath
          : selectedAudioPath as String?,
      transcript: transcript ?? this.transcript,
      language: language ?? this.language,
      separateVocals: separateVocals ?? this.separateVocals,
      isDragging: isDragging ?? this.isDragging,
      status: status ?? this.status,
      latestEvent: identical(latestEvent, _unset)
          ? this.latestEvent
          : latestEvent as AnalysisEvent?,
      result: identical(result, _unset)
          ? this.result
          : result as AlignmentResult?,
      error: identical(error, _unset) ? this.error : error as DomainException?,
      lastCheckpoint: identical(lastCheckpoint, _unset)
          ? this.lastCheckpoint
          : lastCheckpoint as PipelineCheckpoint?,
      pendingSegment: identical(pendingSegment, _unset)
          ? this.pendingSegment
          : pendingSegment as PendingSegment?,
      aiTranslation: identical(aiTranslation, _unset)
          ? this.aiTranslation
          : aiTranslation as Translation?,
      draftIdentity: identical(draftIdentity, _unset)
          ? this.draftIdentity
          : draftIdentity as DraftLessonIdentity?,
      importProgress: identical(importProgress, _unset)
          ? this.importProgress
          : importProgress as AudioImportProgress?,
      readySource: identical(readySource, _unset)
          ? this.readySource
          : readySource as AudioReadySource?,
    );
  }
}

class AnalysisController extends Notifier<AnalysisUiState> {
  static const Set<String> supportedExtensions = {'mp3', 'wav', 'm4a', 'flac'};
  int _audioImportRunId = 0;

  @override
  AnalysisUiState build() => const AnalysisUiState();

  void setDragging(bool value) {
    state = state.copyWith(isDragging: value);
  }

  void setTranscript(String value) {
    state = state.copyWith(transcript: value);
  }

  /// 設定目前分析草稿的 AI 譯文；不會改寫手動輸入欄位。
  void setAiTranslation(Translation? translation) {
    state = state.copyWith(aiTranslation: translation);
  }

  /// 消費 labeling 交接的唯一待處理區段，預填單句音檔、字稿與 language。
  ///
  /// 這裡只搬移 metadata；原音切片仍由後續分析入口依 [pendingSegment]
  /// 的起訖範圍處理，不在 UI 狀態複製 PCM。
  bool consumePendingSegment() {
    if (state.isRunning) return false;
    final pending = ref.read(pendingSegmentProvider);
    if (pending == null) return false;
    state = state.copyWith(
      selectedAudioPath: pending.sourceAudioPath,
      transcript: pending.text,
      language: pending.language,
      status: AnalysisRunStatus.ready,
      latestEvent: null,
      result: null,
      error: null,
      lastCheckpoint: null,
      pendingSegment: pending,
      aiTranslation: null,
      draftIdentity: null,
      importProgress: const AudioImportProgress(stage: AudioImportStage.ready),
      readySource: AudioReadySource(
        path: pending.sourceAudioPath,
        bytesRead: 0,
        durationMs: pending.range.durationMs,
        fromPendingSegment: true,
      ),
    );
    ref.read(pendingSegmentProvider.notifier).clear();
    return true;
  }

  void setSeparateVocals(bool value) {
    state = state.copyWith(separateVocals: value);
  }

  Future<void> selectAudioPath(String path) async {
    final runId = ++_audioImportRunId;
    if (!_isSupportedAudio(path)) {
      state = state.copyWith(
        status: AnalysisRunStatus.failed,
        selectedAudioPath: path,
        error: const DomainException(ErrorCodes.unsupportedFormat, '音檔格式不支援'),
        latestEvent: null,
        result: null,
        aiTranslation: null,
        draftIdentity: null,
        importProgress: null,
        readySource: null,
      );
      return;
    }

    state = state.copyWith(
      status: AnalysisRunStatus.loading,
      selectedAudioPath: path,
      language: 'en',
      error: null,
      latestEvent: null,
      result: null,
      pendingSegment: null,
      aiTranslation: null,
      draftIdentity: null,
      importProgress: const AudioImportProgress(
        stage: AudioImportStage.readingBytes,
      ),
      readySource: null,
    );

    final reader = ref.read(audioImportReaderProvider);
    if (reader == null) {
      // 純 widget／preview 環境沒有真檔 reader；正式 App 一律由 main 注入。
      if (runId != _audioImportRunId) return;
      state = state.copyWith(
        status: AnalysisRunStatus.ready,
        importProgress: const AudioImportProgress(
          stage: AudioImportStage.ready,
        ),
        readySource: AudioReadySource(path: path, bytesRead: 1, durationMs: 1),
      );
      return;
    }

    try {
      await for (final event in reader.readAndValidate(path)) {
        if (runId != _audioImportRunId) return;
        state = state.copyWith(
          status: event.readySource == null
              ? AnalysisRunStatus.loading
              : AnalysisRunStatus.ready,
          importProgress: event.progress,
          readySource: event.readySource,
          error: null,
        );
      }
    } on DomainException catch (error) {
      if (runId != _audioImportRunId) return;
      state = state.copyWith(
        status: AnalysisRunStatus.failed,
        error: error,
        readySource: null,
      );
    } catch (error) {
      if (runId != _audioImportRunId) return;
      state = state.copyWith(
        status: AnalysisRunStatus.failed,
        error: DomainException(ErrorCodes.decodeFailed, '音檔匯入失敗：$error'),
        readySource: null,
      );
    }
  }

  Future<void> start() => _run(resume: null, clearCheckpoint: true);

  /// 用 pipeline 失敗時保留的 checkpoint 重跑，跳過已完成階段。
  Future<void> retryStage() {
    if (!state.canRetryStage) return Future.value();
    return _run(resume: state.lastCheckpoint, clearCheckpoint: false);
  }

  Future<void> _run({
    required PipelineCheckpoint? resume,
    required bool clearCheckpoint,
  }) async {
    final audioPath = state.selectedAudioPath;
    if (audioPath == null || !state.canStart) {
      return;
    }

    final request = ImportRequest(
      audioPath: audioPath,
      transcript: state.transcript.trim().isEmpty
          ? null
          : state.transcript.trim(),
      language: state.language,
      separateVocals: state.separateVocals,
      sourceRange: state.pendingSegment?.range,
    );

    state = state.copyWith(
      status: AnalysisRunStatus.running,
      latestEvent: null,
      result: null,
      error: null,
      lastCheckpoint: clearCheckpoint ? null : state.lastCheckpoint,
      draftIdentity: null,
    );

    try {
      await for (final event
          in ref
              .read(analysisRunnerProvider)
              .analyze(request, resume: resume)) {
        if (event.stage == AnalysisStage.failed) {
          state = state.copyWith(
            status: AnalysisRunStatus.failed,
            latestEvent: event,
            error: event.error,
            result: null,
            lastCheckpoint: event.checkpoint,
          );
          return;
        }

        final inferredTranscript =
            event.stage == AnalysisStage.done &&
                state.transcript.trim().isEmpty &&
                event.result != null
            ? event.result!.words.map((word) => word.text).join(' ')
            : null;
        final draftIdentity =
            event.stage == AnalysisStage.done && event.result != null
            ? ref.read(draftLessonIdentityGeneratorProvider).create()
            : null;
        state = state.copyWith(
          status: event.stage == AnalysisStage.done
              ? AnalysisRunStatus.done
              : AnalysisRunStatus.running,
          latestEvent: event,
          result: event.result,
          transcript: inferredTranscript ?? state.transcript,
          error: null,
          draftIdentity: draftIdentity,
        );
      }
    } on DomainException catch (error) {
      state = state.copyWith(status: AnalysisRunStatus.failed, error: error);
    } catch (error) {
      state = state.copyWith(
        status: AnalysisRunStatus.failed,
        error: DomainException(ErrorCodes.decodeFailed, '分析流程失敗：$error'),
      );
    }
  }

  bool _isSupportedAudio(String path) {
    final extension = path.split('.').last.toLowerCase();
    return supportedExtensions.contains(extension);
  }
}

class PreviewAnalysisRunner implements AnalysisRunner {
  const PreviewAnalysisRunner();

  @override
  Stream<AnalysisEvent> analyze(
    ImportRequest request, {
    PipelineCheckpoint? resume,
  }) async* {
    yield AnalysisEvent(stage: AnalysisStage.decoding, progress: 0);
    await Future<void>.delayed(const Duration(milliseconds: 180));

    if (request.separateVocals) {
      yield AnalysisEvent(stage: AnalysisStage.separating, progress: 0);
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }

    yield AnalysisEvent(stage: AnalysisStage.transcribing, progress: 0);
    await Future<void>.delayed(const Duration(milliseconds: 180));

    yield AnalysisEvent(stage: AnalysisStage.syllabifying, progress: 0);
    await Future<void>.delayed(const Duration(milliseconds: 180));

    final result = _previewResult(request.audioPath);
    yield AnalysisEvent(stage: AnalysisStage.done, progress: 1, result: result);
  }

  AlignmentResult _previewResult(String audioPath) {
    final fileName = audioPath.split('/').last;
    final words = [
      Word(text: 'Step', startMs: 0, endMs: 360, index: 0),
      Word(text: 'up', startMs: 360, endMs: 620, index: 1),
      Word(text: 'your', startMs: 620, endMs: 900, index: 2),
      Word(text: 'coding', startMs: 900, endMs: 1450, index: 3),
      Word(text: 'skills', startMs: 1450, endMs: 1900, index: 4),
      Word(text: 'to', startMs: 1900, endMs: 2100, index: 5),
      Word(text: 'a', startMs: 2100, endMs: 2240, index: 6),
      Word(text: 'new', startMs: 2240, endMs: 2580, index: 7),
      Word(text: 'level', startMs: 2580, endMs: 3060, index: 8),
    ];
    final syllables = [
      Syllable(
        text: 'Step',
        startMs: 0,
        endMs: 360,
        wordIndex: 0,
        needsReview: false,
      ),
      Syllable(
        text: 'up',
        startMs: 360,
        endMs: 620,
        wordIndex: 1,
        needsReview: false,
      ),
      Syllable(
        text: 'your',
        startMs: 620,
        endMs: 900,
        wordIndex: 2,
        needsReview: false,
      ),
      Syllable(
        text: 'co',
        startMs: 900,
        endMs: 1180,
        wordIndex: 3,
        needsReview: false,
      ),
      Syllable(
        text: 'ding',
        startMs: 1180,
        endMs: 1450,
        wordIndex: 3,
        needsReview: false,
      ),
      Syllable(
        text: 'skills',
        startMs: 1450,
        endMs: 1900,
        wordIndex: 4,
        needsReview: false,
      ),
      Syllable(
        text: 'to',
        startMs: 1900,
        endMs: 2100,
        wordIndex: 5,
        needsReview: false,
      ),
      Syllable(
        text: 'a',
        startMs: 2100,
        endMs: 2240,
        wordIndex: 6,
        needsReview: false,
      ),
      Syllable(
        text: 'new',
        startMs: 2240,
        endMs: 2580,
        wordIndex: 7,
        needsReview: false,
      ),
      Syllable(
        text: 'le',
        startMs: 2580,
        endMs: 2820,
        wordIndex: 8,
        needsReview: false,
      ),
      Syllable(
        text: 'vel',
        startMs: 2820,
        endMs: 3060,
        wordIndex: 8,
        needsReview: false,
      ),
    ];

    return AlignmentResult(
      words: words,
      syllables: syllables,
      source: 'preview:$fileName',
      confidence: 0.86,
    );
  }
}
