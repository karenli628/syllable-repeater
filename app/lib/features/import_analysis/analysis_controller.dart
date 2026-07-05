// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infra/infra.dart';

final analysisRunnerProvider = Provider<AnalysisRunner>(
  (ref) => const PreviewAnalysisRunner(),
);

/// UI 端音檔時長前置檢查（10 分鐘上限）；為 null 時跳過 UI 前置檢查，
/// 仍由 pipeline 解碼後把關（見 FfmpegDecoder.maxDurationMs）。
final audioDurationProbeProvider = Provider<AudioDurationProbe?>((ref) => null);

/// demucs.cpp 二進位與模型是否就緒（task-split 3.8）；為 false 時使用者若勾
/// separateVocals，UI 顯示「未就緒，將降級使用原音」提示。預設 false，由
/// `main.dart` 覆寫；widget test 不覆寫時等同「未就緒」＝preview 環境的合理值。
final demucsReadyProvider = Provider<bool>((ref) => false);

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

enum AnalysisRunStatus { idle, ready, running, done, failed }

class AnalysisUiState {
  const AnalysisUiState({
    this.selectedAudioPath,
    this.transcript = '',
    this.separateVocals = false,
    this.isDragging = false,
    this.status = AnalysisRunStatus.idle,
    this.latestEvent,
    this.result,
    this.error,
    this.lastCheckpoint,
  });

  static const Object _unset = Object();

  final String? selectedAudioPath;
  final String transcript;
  final bool separateVocals;
  final bool isDragging;
  final AnalysisRunStatus status;
  final AnalysisEvent? latestEvent;
  final AlignmentResult? result;
  final DomainException? error;

  /// pipeline 失敗時保留的分階段中間產物；重試時交回 pipeline 跳過已完成階段。
  final PipelineCheckpoint? lastCheckpoint;

  bool get hasAudio => selectedAudioPath != null;

  bool get isRunning => status == AnalysisRunStatus.running;

  bool get canStart => hasAudio && !isRunning;

  bool get canRetryStage =>
      status == AnalysisRunStatus.failed &&
      lastCheckpoint != null &&
      !lastCheckpoint!.isEmpty;

  AnalysisUiState copyWith({
    Object? selectedAudioPath = _unset,
    String? transcript,
    bool? separateVocals,
    bool? isDragging,
    AnalysisRunStatus? status,
    Object? latestEvent = _unset,
    Object? result = _unset,
    Object? error = _unset,
    Object? lastCheckpoint = _unset,
  }) {
    return AnalysisUiState(
      selectedAudioPath: identical(selectedAudioPath, _unset)
          ? this.selectedAudioPath
          : selectedAudioPath as String?,
      transcript: transcript ?? this.transcript,
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
    );
  }
}

class AnalysisController extends Notifier<AnalysisUiState> {
  static const Set<String> supportedExtensions = {'mp3', 'wav', 'm4a', 'flac'};

  @override
  AnalysisUiState build() => const AnalysisUiState();

  void setDragging(bool value) {
    state = state.copyWith(isDragging: value);
  }

  void setTranscript(String value) {
    state = state.copyWith(transcript: value);
  }

  void setSeparateVocals(bool value) {
    state = state.copyWith(separateVocals: value);
  }

  Future<void> selectAudioPath(String path) async {
    if (!_isSupportedAudio(path)) {
      state = state.copyWith(
        status: AnalysisRunStatus.failed,
        selectedAudioPath: path,
        error: const DomainException(ErrorCodes.unsupportedFormat, '音檔格式不支援'),
        latestEvent: null,
        result: null,
      );
      return;
    }

    state = state.copyWith(
      status: AnalysisRunStatus.ready,
      selectedAudioPath: path,
      error: null,
      latestEvent: null,
      result: null,
    );

    final probe = ref.read(audioDurationProbeProvider);
    if (probe == null) {
      return; // preview/test 環境：無 sidecar，仰賴 pipeline 內把關
    }

    try {
      await probe.probe(path);
    } on DomainException catch (error) {
      // 時長前置檢查失敗：保留選檔與字稿/勾選（frontend-design §八 通則）。
      if (state.selectedAudioPath != path) {
        return; // 使用者已重選其他檔，本次結果作廢
      }
      state = state.copyWith(
        status: AnalysisRunStatus.failed,
        error: error,
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
    if (audioPath == null || state.isRunning) {
      return;
    }

    final request = ImportRequest(
      audioPath: audioPath,
      transcript: state.transcript.trim().isEmpty
          ? null
          : state.transcript.trim(),
      separateVocals: state.separateVocals,
    );

    state = state.copyWith(
      status: AnalysisRunStatus.running,
      latestEvent: null,
      result: null,
      error: null,
      lastCheckpoint: clearCheckpoint ? null : state.lastCheckpoint,
    );

    try {
      await for (final event in ref
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

        state = state.copyWith(
          status: event.stage == AnalysisStage.done
              ? AnalysisRunStatus.done
              : AnalysisRunStatus.running,
          latestEvent: event,
          result: event.result,
          error: null,
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
    yield AnalysisEvent(stage: AnalysisStage.decoding, progress: 0.15);
    await Future<void>.delayed(const Duration(milliseconds: 180));

    if (request.separateVocals) {
      yield AnalysisEvent(stage: AnalysisStage.separating, progress: 0.35);
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }

    yield AnalysisEvent(stage: AnalysisStage.transcribing, progress: 0.62);
    await Future<void>.delayed(const Duration(milliseconds: 180));

    yield AnalysisEvent(stage: AnalysisStage.syllabifying, progress: 0.86);
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
