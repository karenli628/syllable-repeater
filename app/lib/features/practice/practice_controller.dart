// AI-Generate
import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editor/editor_controller.dart';
import '../import_analysis/analysis_controller.dart';
import '../pack_translate/lesson_session_controller.dart';
import 'practice_player.dart';
import 'practice_recording.dart';

final practiceControllerProvider =
    NotifierProvider<PracticeController, PracticeUiState>(
      PracticeController.new,
    );

enum PracticePlayStatus { idle, loading, playing }

enum PracticeRecordStatus { idle, recording, comparing }

class PracticeUiState {
  const PracticeUiState({
    this.steps = const [],
    this.currentIndex = 0,
    this.repeatN = 3,
    this.playStatus = PracticePlayStatus.idle,
    this.recordStatus = PracticeRecordStatus.idle,
    this.recordingLevel = 0,
    this.comparison,
    this.decodedPcm,
    this.error,
  });

  static const Object _unset = Object();

  final List<PracticeStep> steps;
  final int currentIndex;
  final int repeatN;
  final PracticePlayStatus playStatus;
  final PracticeRecordStatus recordStatus;
  final double recordingLevel;
  final ComparisonResult? comparison;
  final Pcm? decodedPcm;
  final DomainException? error;

  PracticeStep? get currentStep =>
      steps.isEmpty ? null : steps[currentIndex.clamp(0, steps.length - 1)];

  bool get canPlay =>
      currentStep != null &&
      decodedPcm != null &&
      playStatus != PracticePlayStatus.loading &&
      recordStatus != PracticeRecordStatus.recording;

  bool get canRecord =>
      currentStep != null &&
      decodedPcm != null &&
      recordStatus == PracticeRecordStatus.idle;

  PracticeUiState copyWith({
    List<PracticeStep>? steps,
    int? currentIndex,
    int? repeatN,
    PracticePlayStatus? playStatus,
    PracticeRecordStatus? recordStatus,
    double? recordingLevel,
    Object? comparison = _unset,
    Object? decodedPcm = _unset,
    Object? error = _unset,
  }) {
    return PracticeUiState(
      steps: steps ?? this.steps,
      currentIndex: currentIndex ?? this.currentIndex,
      repeatN: repeatN ?? this.repeatN,
      playStatus: playStatus ?? this.playStatus,
      recordStatus: recordStatus ?? this.recordStatus,
      recordingLevel: recordingLevel ?? this.recordingLevel,
      comparison: identical(comparison, _unset)
          ? this.comparison
          : comparison as ComparisonResult?,
      decodedPcm: identical(decodedPcm, _unset)
          ? this.decodedPcm
          : decodedPcm as Pcm?,
      error: identical(error, _unset) ? this.error : error as DomainException?,
    );
  }
}

class PracticeController extends Notifier<PracticeUiState> {
  final PracticeEngine _engine = PracticeEngine();
  int _playRunId = 0;
  StreamSubscription<double>? _levelSub;
  String? _recordingPath;
  PracticeRecorder? _activeRecorder;

  @override
  PracticeUiState build() {
    ref.listen<EditorUiState>(editorControllerProvider, (previous, next) {
      _rebuildSteps(next.syllables, state.repeatN);
    });
    ref.listen<AnalysisUiState>(analysisControllerProvider, (previous, next) {
      state = state.copyWith(decodedPcm: next.latestEvent?.decodedPcm);
    });
    ref.listen<LessonSessionState>(lessonSessionControllerProvider, (
      previous,
      next,
    ) {
      if (next.pcm != null) {
        state = state.copyWith(decodedPcm: next.pcm);
      }
    });
    ref.onDispose(() {
      _cancelLevelSubscription();
      final recorder = _activeRecorder;
      if (_recordingPath != null && recorder != null) {
        unawaited(recorder.cancel());
      }
    });

    final editor = ref.read(editorControllerProvider);
    final analysis = ref.read(analysisControllerProvider);
    final session = ref.read(lessonSessionControllerProvider);
    return PracticeUiState(
      steps: _buildSteps(editor.syllables, 3),
      decodedPcm: session.pcm ?? analysis.latestEvent?.decodedPcm,
    );
  }

  void setRepeatN(int repeatN) {
    try {
      _rebuildSteps(ref.read(editorControllerProvider).syllables, repeatN);
    } on DomainException catch (error) {
      state = state.copyWith(error: error);
    }
  }

  Future<void> selectStep(int index) async {
    if (index < 0 || index >= state.steps.length) {
      return;
    }
    if (index == state.currentIndex) {
      return;
    }
    if (state.recordStatus == PracticeRecordStatus.recording) {
      await cancelRecording();
    }
    await stop();
    state = state.copyWith(currentIndex: index, comparison: null, error: null);
  }

  Future<void> play() async {
    final step = state.currentStep;
    final pcm = state.decodedPcm;
    if (step == null || pcm == null) {
      state = state.copyWith(
        error: const DomainException(ErrorCodes.decodeFailed, '尚無可播放的原音 PCM'),
      );
      return;
    }

    final runId = ++_playRunId;
    state = state.copyWith(playStatus: PracticePlayStatus.loading, error: null);
    try {
      await ref
          .read(practicePlayerProvider)
          .playStep(
            step,
            pcm,
            repeatN: state.repeatN,
            onReady: () {
              if (_playRunId == runId) {
                state = state.copyWith(playStatus: PracticePlayStatus.playing);
              }
            },
          );
      if (_playRunId == runId) {
        state = state.copyWith(playStatus: PracticePlayStatus.idle);
      }
    } on DomainException catch (error) {
      if (_playRunId == runId) {
        state = state.copyWith(
          playStatus: PracticePlayStatus.idle,
          error: error,
        );
      }
    } catch (error) {
      if (_playRunId == runId) {
        state = state.copyWith(
          playStatus: PracticePlayStatus.idle,
          error: DomainException(ErrorCodes.decodeFailed, '播放失敗：$error'),
        );
      }
    }
  }

  Future<void> startRecording() async {
    final step = state.currentStep;
    final pcm = state.decodedPcm;
    if (step == null || pcm == null) {
      state = state.copyWith(
        error: const DomainException(ErrorCodes.decodeFailed, '尚無可錄音比對的原音 PCM'),
      );
      return;
    }

    await stop();
    try {
      final recorder = ref.read(practiceRecorderProvider);
      final path = await recorder.start();
      _activeRecorder = recorder;
      _recordingPath = path;
      _cancelLevelSubscription();
      _levelSub = recorder.levels.listen((level) {
        state = state.copyWith(recordingLevel: level);
      });
      state = state.copyWith(
        recordStatus: PracticeRecordStatus.recording,
        recordingLevel: 0,
        comparison: null,
        error: null,
      );
    } on DomainException catch (error) {
      _activeRecorder = null;
      state = state.copyWith(error: error);
    } catch (error) {
      _activeRecorder = null;
      state = state.copyWith(
        error: DomainException(ErrorCodes.micPermissionDenied, '錄音啟動失敗：$error'),
      );
    }
  }

  Future<void> stopRecording() async {
    if (state.recordStatus != PracticeRecordStatus.recording) {
      return;
    }

    final step = state.currentStep;
    final pcm = state.decodedPcm;
    if (step == null || pcm == null) {
      await cancelRecording();
      state = state.copyWith(
        error: const DomainException(ErrorCodes.decodeFailed, '尚無可比對的原音 PCM'),
      );
      return;
    }

    _cancelLevelSubscription();
    state = state.copyWith(recordStatus: PracticeRecordStatus.comparing);

    try {
      final recorder = _activeRecorder;
      if (recorder == null) {
        throw const DomainException(ErrorCodes.decodeFailed, '錄音器不存在');
      }
      final stoppedPath = await recorder.stop();
      final path = stoppedPath ?? _recordingPath;
      _activeRecorder = null;
      _recordingPath = null;
      if (path == null) {
        throw const DomainException(ErrorCodes.decodeFailed, '錄音檔不存在');
      }
      final comparison = await ref
          .read(practiceComparisonServiceProvider)
          .compare(
            userRecordingPath: path,
            syllables: ref.read(editorControllerProvider).syllables,
            step: step,
            originalPcm: pcm,
          );
      state = state.copyWith(
        recordStatus: PracticeRecordStatus.idle,
        recordingLevel: 0,
        comparison: comparison,
        error: null,
      );
    } on DomainException catch (error) {
      _activeRecorder = null;
      state = state.copyWith(
        recordStatus: PracticeRecordStatus.idle,
        recordingLevel: 0,
        comparison: null,
        error: error,
      );
    } catch (error) {
      _activeRecorder = null;
      state = state.copyWith(
        recordStatus: PracticeRecordStatus.idle,
        recordingLevel: 0,
        comparison: null,
        error: DomainException(ErrorCodes.decodeFailed, '錄音比對失敗：$error'),
      );
    }
  }

  Future<void> cancelRecording() async {
    _cancelLevelSubscription();
    final recorder = _activeRecorder;
    _activeRecorder = null;
    _recordingPath = null;
    await recorder?.cancel();
    state = state.copyWith(
      recordStatus: PracticeRecordStatus.idle,
      recordingLevel: 0,
      comparison: null,
      error: null,
    );
  }

  Future<void> stop() async {
    _playRunId++;
    await ref.read(practicePlayerProvider).stop();
    state = state.copyWith(playStatus: PracticePlayStatus.idle);
  }

  void clearError() {
    if (state.error == null) return;
    state = state.copyWith(error: null);
  }

  void _rebuildSteps(List<Syllable> syllables, int repeatN) {
    final steps = _buildSteps(syllables, repeatN);
    final nextIndex = steps.isEmpty
        ? 0
        : state.currentIndex.clamp(0, steps.length - 1);
    state = state.copyWith(
      steps: steps,
      currentIndex: nextIndex,
      repeatN: repeatN,
      error: null,
    );
  }

  List<PracticeStep> _buildSteps(List<Syllable> syllables, int repeatN) =>
      List.unmodifiable(_engine.buildSteps(syllables, repeatN));

  void _cancelLevelSubscription() {
    final subscription = _levelSub;
    _levelSub = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
  }
}
