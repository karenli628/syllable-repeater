// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../import_analysis/analysis_controller.dart';
import '../pack_translate/lesson_session_controller.dart';

/// AlignmentEngine 注入點；預設 `AlignmentEngine()` 走內建 dictionary。
/// 拖動流程只需 `updateSyllableBoundary`（純函式），不必掛真 CMUdict。
final alignmentEngineProvider = Provider<AlignmentEngine>(
  (ref) => AlignmentEngine(),
);

final prosodyAnalyzerProvider = Provider<ProsodyAnalyzer>(
  (ref) => const ProsodyAnalyzer(),
);

final editorControllerProvider =
    NotifierProvider<EditorController, EditorUiState>(EditorController.new);

class EditorUiState {
  const EditorUiState({
    this.syllables = const [],
    this.undoStack = const [],
    this.prosody,
    this.showProsodyOverlay = true,
    this.sourceLessonId,
    this.draggingBoundaryIndex,
    this.draggingPreviewMs,
    this.lastSnappedMs,
    this.error,
  });

  static const Object _unset = Object();

  final List<Syllable> syllables;

  /// 每筆為一次成功邊界更新前的完整 syllables 快照；⌘Z 從尾端 pop。
  final List<List<Syllable>> undoStack;

  /// REQ-05 韻律分析結果；pitch 抽不到是 data 狀態且 `pitchAvailable=false`。
  final AsyncValue<Prosody>? prosody;

  final bool showProsodyOverlay;

  /// 由 `.abopack` hydrate 而來時記錄 lesson id；一般分析結果為 null。
  final String? sourceLessonId;

  final int? draggingBoundaryIndex;

  /// 拖動中的本地預覽毫秒；`onPanEnd` 才會 commit 到 domain（AT-02-03）。
  final int? draggingPreviewMs;

  /// 上次 domain 吸附落點；供 UI 顯示「已吸附至 X ms」提示。
  final int? lastSnappedMs;

  /// 上次 dragEnd 的 `ERR_BOUNDARY_INVALID` 例外；UI 端顯示 SnackBar 後應 clearError。
  final DomainException? error;

  bool get isDragging => draggingBoundaryIndex != null;
  bool get canUndo => undoStack.isNotEmpty;
  Prosody? get prosodyValue => prosody?.value;

  EditorUiState copyWith({
    List<Syllable>? syllables,
    List<List<Syllable>>? undoStack,
    Object? prosody = _unset,
    bool? showProsodyOverlay,
    Object? sourceLessonId = _unset,
    Object? draggingBoundaryIndex = _unset,
    Object? draggingPreviewMs = _unset,
    Object? lastSnappedMs = _unset,
    Object? error = _unset,
  }) {
    return EditorUiState(
      syllables: syllables ?? this.syllables,
      undoStack: undoStack ?? this.undoStack,
      prosody: identical(prosody, _unset)
          ? this.prosody
          : prosody as AsyncValue<Prosody>?,
      showProsodyOverlay: showProsodyOverlay ?? this.showProsodyOverlay,
      sourceLessonId: identical(sourceLessonId, _unset)
          ? this.sourceLessonId
          : sourceLessonId as String?,
      draggingBoundaryIndex: identical(draggingBoundaryIndex, _unset)
          ? this.draggingBoundaryIndex
          : draggingBoundaryIndex as int?,
      draggingPreviewMs: identical(draggingPreviewMs, _unset)
          ? this.draggingPreviewMs
          : draggingPreviewMs as int?,
      lastSnappedMs: identical(lastSnappedMs, _unset)
          ? this.lastSnappedMs
          : lastSnappedMs as int?,
      error: identical(error, _unset) ? this.error : error as DomainException?,
    );
  }
}

class EditorController extends Notifier<EditorUiState> {
  @override
  EditorUiState build() {
    // 監聽 analysis 完成→自動載入該次分析結果作為初始 syllables。
    ref.listen<AnalysisUiState>(analysisControllerProvider, (previous, next) {
      final justFinished =
          previous?.status != AnalysisRunStatus.done &&
          next.status == AnalysisRunStatus.done;
      final result = next.result;
      if (justFinished && result != null) {
        loadFrom(result.syllables, pcm: next.latestEvent?.decodedPcm);
      }
    });
    ref.listen<LessonSessionState>(lessonSessionControllerProvider, (
      previous,
      next,
    ) {
      final lesson = next.lesson;
      final pcm = next.pcm;
      if (lesson == null || pcm == null) {
        return;
      }
      final previousLesson = previous?.lesson;
      final sameLesson =
          previousLesson?.id == lesson.id &&
          previousLesson?.contentHash == lesson.contentHash &&
          previousLesson?.updatedAt == lesson.updatedAt;
      if (!sameLesson) {
        loadLesson(lesson, pcm: pcm);
      }
    });
    final session = ref.read(lessonSessionControllerProvider);
    final lesson = session.lesson;
    final pcm = session.pcm;
    if (lesson != null && pcm != null) {
      return _stateFromLesson(lesson, pcm);
    }

    final analysis = ref.read(analysisControllerProvider);
    final result = analysis.result;
    if (analysis.status == AnalysisRunStatus.done && result != null) {
      return _stateFromAnalysis(
        result.syllables,
        analysis.latestEvent?.decodedPcm,
      );
    }

    return const EditorUiState();
  }

  /// 從 pipeline done 結果載入 syllables，重置 undoStack。
  void loadFrom(List<Syllable> initial, {Pcm? pcm}) {
    state = _stateFromAnalysis(initial, pcm);
  }

  void loadLesson(Lesson lesson, {required Pcm pcm}) {
    state = _stateFromLesson(lesson, pcm);
  }

  EditorUiState _stateFromAnalysis(List<Syllable> initial, Pcm? pcm) {
    final syllables = List<Syllable>.unmodifiable(initial);
    return EditorUiState(
      syllables: syllables,
      prosody: _analyzeProsody(pcm, syllables),
    );
  }

  EditorUiState _stateFromLesson(Lesson lesson, Pcm pcm) {
    final syllables = List<Syllable>.unmodifiable(lesson.syllables);
    return EditorUiState(
      syllables: syllables,
      prosody: lesson.prosody == null
          ? _analyzeProsody(pcm, syllables)
          : AsyncValue.data(lesson.prosody!),
      sourceLessonId: lesson.id,
    );
  }

  void setProsodyOverlay(bool value) {
    state = state.copyWith(showProsodyOverlay: value);
  }

  void dragStart(int boundaryIndex) {
    if (boundaryIndex < 0 || boundaryIndex >= state.syllables.length - 1) {
      return;
    }
    state = state.copyWith(
      draggingBoundaryIndex: boundaryIndex,
      draggingPreviewMs: state.syllables[boundaryIndex].endMs,
      error: null,
    );
  }

  /// 拖動中僅更新本地預覽；不打 domain（AT-02-03 連續快速拖動只送最終值）。
  void dragUpdate(int previewMs) {
    if (!state.isDragging) return;
    state = state.copyWith(draggingPreviewMs: previewMs);
  }

  /// 放開後呼叫 domain 介面 2；失敗（ERR_BOUNDARY_INVALID）→回彈原值＋error 曝光。
  /// [pcm] 由 UI 端從最近一次分析結果（`AnalysisEvent.decodedPcm`）傳入，方便測試
  /// 直接注入 fake PCM，不必 stub 整個 analysisControllerProvider。
  void dragEnd(Pcm? pcm) {
    final index = state.draggingBoundaryIndex;
    final previewMs = state.draggingPreviewMs;
    if (index == null || previewMs == null) return;

    if (pcm == null) {
      // 尚無 PCM（未跑分析或環境無 sidecar）：清拖動狀態、不更動 syllables。
      state = state.copyWith(
        draggingBoundaryIndex: null,
        draggingPreviewMs: null,
      );
      return;
    }

    try {
      final engine = ref.read(alignmentEngineProvider);
      final result = engine.updateSyllableBoundary(
        current: state.syllables,
        boundaryIndex: index,
        newPositionMs: previewMs,
        pcm: pcm,
      );
      final nextSyllables = List<Syllable>.unmodifiable(result.syllables);
      state = state.copyWith(
        syllables: nextSyllables,
        undoStack: [...state.undoStack, state.syllables],
        prosody: _analyzeProsody(pcm, nextSyllables),
        draggingBoundaryIndex: null,
        draggingPreviewMs: null,
        lastSnappedMs: result.snappedMs,
        error: null,
      );
    } on DomainException catch (err) {
      // AT-02-02/05 拒絕→保留原 syllables、清拖動狀態、error 給 UI 彈 SnackBar。
      state = state.copyWith(
        draggingBoundaryIndex: null,
        draggingPreviewMs: null,
        error: err,
      );
    }
  }

  /// AT-02-04：⌘Z 撤銷回復到上一筆 syllables。
  void undo() {
    if (state.undoStack.isEmpty) return;
    final restored = state.undoStack.last;
    final rest = state.undoStack.sublist(0, state.undoStack.length - 1);
    final session = ref.read(lessonSessionControllerProvider);
    final pcm = state.sourceLessonId == session.lesson?.id
        ? session.pcm
        : ref.read(analysisControllerProvider).latestEvent?.decodedPcm;
    state = state.copyWith(
      syllables: List<Syllable>.unmodifiable(restored),
      undoStack: rest,
      prosody: _analyzeProsody(pcm, restored),
      lastSnappedMs: null,
      error: null,
    );
  }

  void clearError() {
    if (state.error == null) return;
    state = state.copyWith(error: null);
  }

  AsyncValue<Prosody>? _analyzeProsody(Pcm? pcm, List<Syllable> syllables) {
    if (pcm == null || syllables.isEmpty) {
      return null;
    }
    try {
      final prosody = ref.read(prosodyAnalyzerProvider).analyze(pcm, syllables);
      return AsyncValue.data(prosody);
    } catch (error, stackTrace) {
      return AsyncValue.error(error, stackTrace);
    }
  }
}
