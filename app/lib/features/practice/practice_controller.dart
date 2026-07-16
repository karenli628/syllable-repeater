// AI-Generate
import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editor/editor_controller.dart';
import '../import_analysis/analysis_controller.dart';
import '../pack_translate/lesson_session_controller.dart';
import '../progress/progress_service.dart';
import '../../shared/navigation.dart';
import 'practice_player.dart';
import 'practice_recording.dart';

final practiceControllerProvider =
    NotifierProvider<PracticeController, PracticeUiState>(
      PracticeController.new,
    );

enum PracticePlayStatus { idle, loading, playing }

enum PracticeRecordStatus { idle, recording, comparing }

enum PracticeRecordedPlaybackStatus { idle, playing }

class PracticeUiState {
  const PracticeUiState({
    this.steps = const [],
    this.units = const [],
    this.currentIndex = 0,
    this.repeatN = 3,
    this.mode = PracticeMode.wholeSentence,
    this.stale = false,
    this.transcriptMode = TranscriptDisplayMode.transcript,
    this.playStatus = PracticePlayStatus.idle,
    this.recordStatus = PracticeRecordStatus.idle,
    this.recordedPlaybackStatus = PracticeRecordedPlaybackStatus.idle,
    this.recordingLevel = 0,
    this.recordedPcm,
    this.comparison,
    this.decodedPcm,
    this.error,
  });

  static const Object _unset = Object();

  final List<PracticeStep> steps;
  final List<PracticeUnit> units;
  final int currentIndex;
  final int repeatN;
  final PracticeMode mode;
  final bool stale;
  final TranscriptDisplayMode transcriptMode;
  final PracticePlayStatus playStatus;
  final PracticeRecordStatus recordStatus;
  final PracticeRecordedPlaybackStatus recordedPlaybackStatus;
  final double recordingLevel;
  final Pcm? recordedPcm;
  final ComparisonResult? comparison;
  final Pcm? decodedPcm;
  final DomainException? error;

  PracticeStep? get currentStep =>
      steps.isEmpty ? null : steps[currentIndex.clamp(0, steps.length - 1)];

  PracticeUnit? get currentUnit =>
      units.isEmpty ? null : units[currentIndex.clamp(0, units.length - 1)];

  bool get canPlay =>
      currentStep != null &&
      decodedPcm != null &&
      playStatus != PracticePlayStatus.loading &&
      recordStatus != PracticeRecordStatus.recording &&
      recordedPlaybackStatus == PracticeRecordedPlaybackStatus.idle;

  bool get canRecord =>
      currentStep != null &&
      decodedPcm != null &&
      recordStatus == PracticeRecordStatus.idle &&
      recordedPlaybackStatus == PracticeRecordedPlaybackStatus.idle;

  PracticeUiState copyWith({
    List<PracticeStep>? steps,
    List<PracticeUnit>? units,
    int? currentIndex,
    int? repeatN,
    PracticeMode? mode,
    bool? stale,
    TranscriptDisplayMode? transcriptMode,
    PracticePlayStatus? playStatus,
    PracticeRecordStatus? recordStatus,
    PracticeRecordedPlaybackStatus? recordedPlaybackStatus,
    double? recordingLevel,
    Object? recordedPcm = _unset,
    Object? comparison = _unset,
    Object? decodedPcm = _unset,
    Object? error = _unset,
  }) {
    return PracticeUiState(
      steps: steps ?? this.steps,
      units: units ?? this.units,
      currentIndex: currentIndex ?? this.currentIndex,
      repeatN: repeatN ?? this.repeatN,
      mode: mode ?? this.mode,
      stale: stale ?? this.stale,
      transcriptMode: transcriptMode ?? this.transcriptMode,
      playStatus: playStatus ?? this.playStatus,
      recordStatus: recordStatus ?? this.recordStatus,
      recordedPlaybackStatus:
          recordedPlaybackStatus ?? this.recordedPlaybackStatus,
      recordingLevel: recordingLevel ?? this.recordingLevel,
      recordedPcm: identical(recordedPcm, _unset)
          ? this.recordedPcm
          : recordedPcm as Pcm?,
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
  int _wholeSentenceRepeatN = PracticeRow.defaultRepeatN;
  final double _wholeSentenceSilenceFactor = PracticeRow.defaultSilenceFactor;
  int _playRunId = 0;
  int _recordedPlaybackRunId = 0;
  int _compareRunId = 0;
  StreamSubscription<double>? _levelSub;
  String? _recordingPath;
  PracticeRecorder? _activeRecorder;
  PracticePlayback? _activePlayer;
  bool _recordingSessionActive = false;

  @override
  PracticeUiState build() {
    final audioSession = ref.read(practiceAudioSessionProvider);
    ref.listen<EditorUiState>(editorControllerProvider, (previous, next) {
      _rebuildUnits(next.syllables);
      if (next.sourceLessonId != previous?.sourceLessonId) {
        _discardRecordingResult();
        unawaited(_loadTranscriptMode(next.sourceLessonId));
      }
    });
    ref.listen<AnalysisUiState>(analysisControllerProvider, (previous, next) {
      state = state.copyWith(decodedPcm: next.latestEvent?.decodedPcm);
      _rebuildUnits(ref.read(editorControllerProvider).syllables);
    });
    ref.listen<LessonSessionState>(lessonSessionControllerProvider, (
      previous,
      next,
    ) {
      if (next.pcm != null) {
        state = state.copyWith(decodedPcm: next.pcm);
        _rebuildUnits(ref.read(editorControllerProvider).syllables);
      }
      if (next.lesson != null && next.pcm != null) {
        _rebuildUnits(ref.read(editorControllerProvider).syllables);
      }
    });
    ref.listen<int>(appShellSelectedIndexProvider, (previous, next) {
      if (previous == AppSection.practice.sectionIndex &&
          next != AppSection.practice.sectionIndex) {
        unawaited(_leavePractice());
      }
    });
    ref.onDispose(() {
      _compareRunId++;
      _recordedPlaybackRunId++;
      _cancelLevelSubscription();
      unawaited(_activePlayer?.stop());
      final recorder = _activeRecorder;
      if (_recordingPath != null && recorder != null) {
        unawaited(recorder.cancel());
      }
      if (_recordingSessionActive) {
        _recordingSessionActive = false;
        unawaited(audioSession.finishRecording());
      }
    });

    final editor = ref.read(editorControllerProvider);
    final analysis = ref.read(analysisControllerProvider);
    final session = ref.read(lessonSessionControllerProvider);
    final effective = _buildUnits(editor.syllables);
    if (editor.sourceLessonId != null) {
      unawaited(_loadTranscriptMode(editor.sourceLessonId));
    }
    return PracticeUiState(
      steps: effective.steps,
      units: effective.units,
      mode: effective.mode,
      stale: effective.stale,
      decodedPcm: session.pcm ?? analysis.latestEvent?.decodedPcm,
    );
  }

  void setRepeatN(int repeatN) {
    try {
      if (repeatN < PracticeBlock.minRepeatN ||
          repeatN > PracticeBlock.maxRepeatN) {
        throw DomainException(
          ErrorCodes.blockConfigOutOfRange,
          '整列重複次數須為 1–10，got $repeatN',
        );
      }
      final unit = state.currentUnit;
      if (unit is CustomPracticeUnit) {
        final editor = ref.read(editorControllerProvider);
        final arrangement = editor.arrangement;
        if (arrangement == null) return;
        final updated = arrangement.setRowConfig(
          state.currentIndex,
          repeatN: repeatN,
          updatedAt: DateTime.now().toUtc(),
        );
        ref.read(editorControllerProvider.notifier).setArrangement(updated);
        return;
      }
      if (unit is WholeSentencePracticeUnit) {
        _wholeSentenceRepeatN = repeatN;
        _rebuildUnits(ref.read(editorControllerProvider).syllables);
      }
    } on DomainException catch (error) {
      state = state.copyWith(error: error);
    }
  }

  Future<void> selectStep(int index) async {
    if (index < 0 || index >= state.units.length) {
      return;
    }
    if (index == state.currentIndex) {
      return;
    }
    _compareRunId++;
    if (state.recordStatus == PracticeRecordStatus.recording) {
      await cancelRecording();
    }
    await stop();
    state = state.copyWith(
      currentIndex: index,
      repeatN: _repeatNForUnit(state.units[index]),
      recordStatus: PracticeRecordStatus.idle,
      recordingLevel: 0,
      recordedPcm: null,
      recordedPlaybackStatus: PracticeRecordedPlaybackStatus.idle,
      comparison: null,
      error: null,
    );
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
      final player = ref.read(practicePlayerProvider);
      _activePlayer = player;
      void onReady() {
        if (_playRunId == runId) {
          state = state.copyWith(playStatus: PracticePlayStatus.playing);
        }
      }

      final unit = state.currentUnit;
      if (unit is CustomPracticeUnit) {
        await player.playRow(unit.row, pcm, onReady: onReady);
      } else if (unit is WholeSentencePracticeUnit) {
        final rendered = await _engine.renderUnitsExport(
          PracticeUnits(
            mode: PracticeMode.wholeSentence,
            units: [unit],
            stale: false,
          ),
          pcm,
        );
        await player.playPcm(rendered.pcm, onReady: onReady);
      } else {
        await player.playStep(
          step,
          pcm,
          repeatN: state.repeatN,
          onReady: onReady,
        );
      }
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

    _compareRunId++;
    await stop();
    _discardRecordingResult();
    try {
      await ref.read(practiceAudioSessionProvider).prepareForRecording();
      _recordingSessionActive = true;
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
      await _finishRecordingSession();
      _activeRecorder = null;
      _recordingPath = null;
      state = state.copyWith(error: error);
    } catch (error) {
      await _finishRecordingSession();
      _activeRecorder = null;
      _recordingPath = null;
      state = state.copyWith(
        error: DomainException(ErrorCodes.micPermissionDenied, '錄音啟動失敗：$error'),
      );
    }
  }

  Future<void> stopRecording() async {
    if (state.recordStatus != PracticeRecordStatus.recording) {
      return;
    }

    final compareRunId = ++_compareRunId;
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
      final recording = await recorder.stop();
      await _finishRecordingSession();
      final path = recording?.path ?? _recordingPath;
      _activeRecorder = null;
      _recordingPath = null;
      if (path == null || recording?.pcm == null) {
        throw const DomainException(ErrorCodes.decodeFailed, '錄音檔不存在');
      }
      if (compareRunId != _compareRunId) return;
      state = state.copyWith(recordedPcm: recording!.pcm);
      final comparison = await ref
          .read(practiceComparisonServiceProvider)
          .compare(
            userRecordingPath: path,
            syllables: ref.read(editorControllerProvider).syllables,
            step: step,
            originalPcm: pcm,
          );
      if (compareRunId != _compareRunId) return;
      state = state.copyWith(
        recordStatus: PracticeRecordStatus.idle,
        recordingLevel: 0,
        comparison: comparison,
        error: null,
      );
    } on DomainException catch (error) {
      await _finishRecordingSession();
      _activeRecorder = null;
      _recordingPath = null;
      if (compareRunId != _compareRunId) return;
      state = state.copyWith(
        recordStatus: PracticeRecordStatus.idle,
        recordingLevel: 0,
        comparison: null,
        error: error,
      );
    } catch (error) {
      await _finishRecordingSession();
      _activeRecorder = null;
      _recordingPath = null;
      if (compareRunId != _compareRunId) return;
      state = state.copyWith(
        recordStatus: PracticeRecordStatus.idle,
        recordingLevel: 0,
        comparison: null,
        error: DomainException(ErrorCodes.decodeFailed, '錄音比對失敗：$error'),
      );
    }
  }

  Future<void> cancelRecording() async {
    _compareRunId++;
    _cancelLevelSubscription();
    final recorder = _activeRecorder;
    _activeRecorder = null;
    _recordingPath = null;
    await recorder?.cancel();
    await _finishRecordingSession();
    state = state.copyWith(
      recordStatus: PracticeRecordStatus.idle,
      recordingLevel: 0,
      comparison: null,
      error: null,
    );
  }

  Future<void> stop() async {
    _playRunId++;
    _recordedPlaybackRunId++;
    final player = ref.read(practicePlayerProvider);
    _activePlayer = player;
    await player.stop();
    state = state.copyWith(
      playStatus: PracticePlayStatus.idle,
      recordedPlaybackStatus: PracticeRecordedPlaybackStatus.idle,
    );
  }

  /// 播放目前單元最近一次錄音 PCM（REQ-06／AT-06-07、AT-06-09）。
  Future<void> playRecording() async {
    final pcm = state.recordedPcm;
    if (pcm == null) return;
    await stop();
    final runId = ++_recordedPlaybackRunId;
    state = state.copyWith(
      recordedPlaybackStatus: PracticeRecordedPlaybackStatus.playing,
      error: null,
    );
    try {
      final player = ref.read(practicePlayerProvider);
      _activePlayer = player;
      await player.playPcm(pcm);
      if (_recordedPlaybackRunId == runId) {
        state = state.copyWith(
          recordedPlaybackStatus: PracticeRecordedPlaybackStatus.idle,
        );
      }
    } on DomainException catch (error) {
      if (_recordedPlaybackRunId == runId) {
        state = state.copyWith(
          recordedPlaybackStatus: PracticeRecordedPlaybackStatus.idle,
          error: error,
        );
      }
    } catch (error) {
      if (_recordedPlaybackRunId == runId) {
        state = state.copyWith(
          recordedPlaybackStatus: PracticeRecordedPlaybackStatus.idle,
          error: DomainException(ErrorCodes.decodeFailed, '錄音播放失敗：$error'),
        );
      }
    }
  }

  /// 停止錄音回放；下次播放由 PCM 開頭重新建立播放來源（AT-06-09）。
  Future<void> stopRecordingPlayback() async {
    _recordedPlaybackRunId++;
    final player = ref.read(practicePlayerProvider);
    _activePlayer = player;
    await player.stop();
    state = state.copyWith(
      recordedPlaybackStatus: PracticeRecordedPlaybackStatus.idle,
    );
  }

  /// 刪除目前 Lesson 的自訂排列並回落 auto；不觸碰錄音、進度或校正資料。
  Future<void> removeArrangement() async {
    await stop();
    ref.read(editorControllerProvider.notifier).setArrangement(null);
  }

  void clearError() {
    if (state.error == null) return;
    state = state.copyWith(error: null);
  }

  /// 清除目前單元錄音 PCM、播放與比對結果（REQ-06／AT-06-08）。
  Future<void> clearRecordingResult() async {
    if (state.recordedPcm == null && state.comparison == null) return;
    _compareRunId++;
    await stopRecordingPlayback();
    _discardRecordingResult();
  }

  /// 相容既有垃圾桶入口；語意已升級為清除整筆錄音結果。
  void clearComparison() {
    unawaited(clearRecordingResult());
  }

  /// 切換每 Lesson 字稿／譯文顯示偏好（REQ-19／介面 34）。
  Future<void> setTranscriptMode(TranscriptDisplayMode mode) async {
    final lessonId = ref.read(editorControllerProvider).sourceLessonId;
    if (lessonId == null) {
      state = state.copyWith(transcriptMode: mode);
      return;
    }
    state = state.copyWith(transcriptMode: mode, error: null);
    try {
      await ref
          .read(transcriptSettingsServiceProvider)
          .setTranscriptMode(lessonId, mode);
    } on Object catch (error) {
      if (ref.mounted) _exposeError(error);
    }
  }

  void _rebuildUnits(List<Syllable> syllables) {
    final result = _buildUnits(syllables);
    final steps = result.steps;
    final nextIndex = steps.isEmpty
        ? 0
        : state.currentIndex.clamp(0, steps.length - 1);
    state = state.copyWith(
      steps: steps,
      units: result.units,
      mode: result.mode,
      stale: result.stale,
      currentIndex: nextIndex,
      repeatN: result.units.isEmpty
          ? PracticeRow.defaultRepeatN
          : _repeatNForUnit(result.units[nextIndex]),
      error: null,
    );
  }

  _PracticeUnitsSnapshot _buildUnits(List<Syllable> syllables) {
    final editor = ref.read(editorControllerProvider);
    if (syllables.isEmpty) {
      return const _PracticeUnitsSnapshot(
        units: [],
        steps: [],
        mode: PracticeMode.wholeSentence,
        stale: false,
      );
    }
    final pcm =
        ref.read(lessonSessionControllerProvider).pcm ??
        ref.read(analysisControllerProvider).latestEvent?.decodedPcm;
    final pcmDurationMs = pcm?.durationMs ?? 0;
    final durationMs = pcmDurationMs > 0 ? pcmDurationMs : syllables.last.endMs;
    var effective = _engine.effectiveUnits(
      syllables,
      arrangement: editor.arrangement,
      fullSentenceRange: TimeRange(0, durationMs),
    );
    if (effective.mode == PracticeMode.wholeSentence) {
      final whole = effective.units.single as WholeSentencePracticeUnit;
      effective = PracticeUnits(
        mode: PracticeMode.wholeSentence,
        units: [
          WholeSentencePracticeUnit(
            whole.step,
            repeatN: _wholeSentenceRepeatN,
            silenceFactor: _wholeSentenceSilenceFactor,
          ),
        ],
        stale: false,
      );
    }
    final steps = effective.units.map(_unitAsStep).toList(growable: false);
    return _PracticeUnitsSnapshot(
      units: List.unmodifiable(effective.units),
      steps: List.unmodifiable(steps),
      mode: effective.mode,
      stale: effective.stale,
    );
  }

  void _cancelLevelSubscription() {
    final subscription = _levelSub;
    _levelSub = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
  }

  void _discardRecordingResult() {
    _recordedPlaybackRunId++;
    state = state.copyWith(
      recordedPcm: null,
      recordedPlaybackStatus: PracticeRecordedPlaybackStatus.idle,
      comparison: null,
    );
  }

  /// 離開錄音練習頁即結束暫存生命週期（M10／AT-18-09）。
  Future<void> _leavePractice() async {
    _compareRunId++;
    if (state.recordStatus == PracticeRecordStatus.recording) {
      await cancelRecording();
    } else {
      _cancelLevelSubscription();
    }
    await stop();
    _discardRecordingResult();
    state = state.copyWith(
      recordStatus: PracticeRecordStatus.idle,
      recordingLevel: 0,
    );
  }

  Future<void> _finishRecordingSession() async {
    if (!_recordingSessionActive) return;
    _recordingSessionActive = false;
    await ref.read(practiceAudioSessionProvider).finishRecording();
  }

  Future<void> _loadTranscriptMode(String? lessonId) async {
    if (lessonId == null) {
      if (ref.mounted) {
        state = state.copyWith(
          transcriptMode: TranscriptDisplayMode.transcript,
        );
      }
      return;
    }
    try {
      final mode = await ref
          .read(transcriptSettingsServiceProvider)
          .getTranscriptMode(lessonId);
      if (ref.mounted) state = state.copyWith(transcriptMode: mode);
    } on Object catch (error) {
      if (ref.mounted) _exposeError(error);
    }
  }

  void _exposeError(Object error) {
    if (!ref.mounted) return;
    state = state.copyWith(
      error: error is DomainException
          ? error
          : DomainException(ErrorCodes.decodeFailed, '$error'),
    );
  }
}

class _PracticeUnitsSnapshot {
  const _PracticeUnitsSnapshot({
    required this.units,
    required this.steps,
    required this.mode,
    required this.stale,
  });

  final List<PracticeUnit> units;
  final List<PracticeStep> steps;
  final PracticeMode mode;
  final bool stale;
}

PracticeStep _unitAsStep(PracticeUnit unit) {
  return switch (unit) {
    AutoPracticeUnit(:final step) => step,
    WholeSentencePracticeUnit(:final step) => step,
    CustomPracticeUnit(:final row) => PracticeStep(
      index: row.index,
      syllables: row.blocks.expand((block) => block.syllables).toList(),
      sourceRanges: row.blocks
          .expand((block) => block.sourceRanges)
          .toList(growable: false),
      totalDurationMs:
          row.blocks.fold(
                0,
                (total, block) =>
                    total +
                    (block.sourceDurationMs + block.silenceDurationMs) *
                        block.repeatN,
              ) *
              row.repeatN +
          row.silenceDurationMs * (row.repeatN - 1),
    ),
  };
}

int _repeatNForUnit(PracticeUnit unit) => switch (unit) {
  AutoPracticeUnit(:final step) => _repeatNForStep(step),
  WholeSentencePracticeUnit(:final repeatN) => repeatN,
  CustomPracticeUnit(:final row) => row.repeatN,
};

int _repeatNForStep(PracticeStep step) {
  final sourceDurationMs = step.sourceRanges.fold<int>(
    0,
    (total, range) => total + range.durationMs,
  );
  if (sourceDurationMs <= 0 || step.totalDurationMs % sourceDurationMs != 0) {
    return 1;
  }
  return step.totalDurationMs ~/ sourceDurationMs;
}
