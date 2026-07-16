// AI-Generate
import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../import_analysis/analysis_controller.dart';
import '../pack_translate/lesson_session_controller.dart';
import 'prosody_analysis_runner.dart';
import 'waveform_node_range.dart';

/// AlignmentEngine 注入點；預設 `AlignmentEngine()` 走內建 dictionary。
/// 拖動流程只需 `updateSyllableBoundary`（純函式），不必掛真 CMUdict。
final alignmentEngineProvider = Provider<AlignmentEngine>(
  (ref) => AlignmentEngine(),
);

final prosodyAnalyzerProvider = Provider<ProsodyAnalyzer>(
  (ref) => const ProsodyAnalyzer(),
);

final prosodyAnalysisRunnerProvider = Provider<ProsodyAnalysisRunner>(
  (ref) => IsolateProsodyAnalysisRunner(ref.watch(prosodyAnalyzerProvider)),
);

final editorControllerProvider =
    NotifierProvider<EditorController, EditorUiState>(EditorController.new);

class EditorUiState {
  const EditorUiState({
    this.syllables = const [],
    this.undoStack = const [],
    this.prosody,
    this.arrangement,
    this.showProsodyOverlay = true,
    this.selectedSyllableIndex,
    this.selectedTimeRange,
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

  /// REQ-15 自訂排列；音節總數變更時只標記 stale，不自動改內容。
  final PracticeArrangement? arrangement;

  final bool showProsodyOverlay;

  /// 波形與文字 chip 共用的單一選中音節索引（REQ-14／AT-14-05）。
  final int? selectedSyllableIndex;

  /// 波形框選的半開時間範圍；所有重疊音節均視為選中（REQ-17／AT-17-01）。
  final TimeRange? selectedTimeRange;

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
    Object? arrangement = _unset,
    bool? showProsodyOverlay,
    Object? selectedSyllableIndex = _unset,
    Object? selectedTimeRange = _unset,
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
      arrangement: identical(arrangement, _unset)
          ? this.arrangement
          : arrangement as PracticeArrangement?,
      showProsodyOverlay: showProsodyOverlay ?? this.showProsodyOverlay,
      selectedSyllableIndex: identical(selectedSyllableIndex, _unset)
          ? this.selectedSyllableIndex
          : selectedSyllableIndex as int?,
      selectedTimeRange: identical(selectedTimeRange, _unset)
          ? this.selectedTimeRange
          : selectedTimeRange as TimeRange?,
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
  static const int _maxUndoDepth = 4;
  static const Object _keepSelection = Object();
  int? _selectionAnchorMs;
  int _prosodyGeneration = 0;
  Pcm? _sourcePcm;

  @override
  EditorUiState build() {
    // 監聽 analysis 完成→自動載入該次分析結果作為初始 syllables。
    ref.listen<AnalysisUiState>(analysisControllerProvider, (previous, next) {
      final justFinished =
          previous?.status != AnalysisRunStatus.done &&
          next.status == AnalysisRunStatus.done;
      final result = next.result;
      if (justFinished && result != null) {
        loadFrom(
          result.syllables,
          pcm: next.latestEvent?.decodedPcm,
          sourceLessonId: next.draftIdentity?.lessonId,
        );
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
      _sourcePcm = pcm;
      return _stateFromLesson(lesson, pcm);
    }

    final analysis = ref.read(analysisControllerProvider);
    final result = analysis.result;
    if (analysis.status == AnalysisRunStatus.done && result != null) {
      _sourcePcm = analysis.latestEvent?.decodedPcm;
      return _stateFromAnalysis(
        result.syllables,
        analysis.latestEvent?.decodedPcm,
        sourceLessonId: analysis.draftIdentity?.lessonId,
      );
    }

    return const EditorUiState();
  }

  /// 從 pipeline done 結果載入 syllables，重置 undoStack。
  void loadFrom(List<Syllable> initial, {Pcm? pcm, String? sourceLessonId}) {
    _prosodyGeneration++;
    _sourcePcm = pcm;
    state = _stateFromAnalysis(initial, pcm, sourceLessonId: sourceLessonId);
  }

  void loadLesson(Lesson lesson, {required Pcm pcm}) {
    _prosodyGeneration++;
    _sourcePcm = pcm;
    state = _stateFromLesson(lesson, pcm);
  }

  EditorUiState _stateFromAnalysis(
    List<Syllable> initial,
    Pcm? pcm, {
    String? sourceLessonId,
  }) {
    final syllables = List<Syllable>.unmodifiable(initial);
    return EditorUiState(
      syllables: syllables,
      prosody: _analyzeProsody(pcm, syllables),
      sourceLessonId: sourceLessonId,
    );
  }

  EditorUiState _stateFromLesson(Lesson lesson, Pcm pcm) {
    final syllables = List<Syllable>.unmodifiable(lesson.syllables);
    return EditorUiState(
      syllables: syllables,
      prosody: lesson.prosody == null
          ? _analyzeProsody(pcm, syllables)
          : AsyncValue.data(lesson.prosody!),
      arrangement: lesson.arrangement,
      sourceLessonId: lesson.id,
    );
  }

  void setProsodyOverlay(bool value) {
    state = state.copyWith(showProsodyOverlay: value);
  }

  /// 設定波形與文字區共用的選中音節；null 代表清除選中。
  void selectSyllable(int? index) {
    if (index != null && (index < 0 || index >= state.syllables.length)) {
      return;
    }
    state = state.copyWith(
      selectedSyllableIndex: index,
      selectedTimeRange: index == null ? null : state.syllables[index].range,
    );
  }

  /// 從波形非切點處開始框選；初始先選取落點所在的完整音節。
  void beginTimeSelection(int atMs) {
    final index = _syllableIndexAt(atMs);
    if (index == null) return;
    _selectionAnchorMs = atMs;
    selectSyllable(index);
  }

  /// 更新半開時間範圍；以 overlap 規則同步所有相關積木的高亮。
  void updateTimeSelection(int atMs) {
    final anchor = _selectionAnchorMs;
    if (anchor == null) return;
    final clamped = atMs.clamp(
      state.syllables.first.startMs,
      state.syllables.last.endMs,
    );
    if (clamped == anchor) return;
    final startMs = anchor < clamped ? anchor : clamped;
    final endMs = anchor < clamped ? clamped : anchor;
    final range = TimeRange(startMs, endMs);
    state = state.copyWith(
      selectedSyllableIndex: _firstOverlappingIndex(range),
      selectedTimeRange: range,
    );
  }

  void endTimeSelection() {
    _selectionAnchorMs = null;
  }

  /// 刪除相鄰音節間切點，委派 Domain 合併並將成功操作納入校正 undo（REQ-13／AT-13-01）。
  void removeBoundary(int boundaryIndex) {
    if (boundaryIndex < 0 || boundaryIndex >= state.syllables.length - 1) {
      return;
    }
    try {
      final result = ref
          .read(alignmentEngineProvider)
          .removeBoundary(_currentAlignmentResult(), boundaryIndex);
      _commitSyllableEdit(
        result.syllables,
        selectedSyllableIndex: _selectionAfterRemove(boundaryIndex),
      );
    } on DomainException catch (error) {
      state = state.copyWith(
        draggingBoundaryIndex: null,
        draggingPreviewMs: null,
        error: error,
      );
    }
  }

  /// 在指定音節內新增切點，後半段由 Domain 建立為待檢音節（REQ-13／AT-13-02）。
  void insertBoundary(int syllableIndex, int atMs, Pcm pcm) {
    if (syllableIndex < 0 || syllableIndex >= state.syllables.length) {
      return;
    }
    try {
      final nodeRange = waveformNodeRange(
        syllables: state.syllables,
        syllableIndex: syllableIndex,
        totalDurationMs: pcm.durationMs,
      );
      final target = state.syllables[syllableIndex];
      final nodeSyllables = List<Syllable>.of(state.syllables)
        ..[syllableIndex] = target.copyWith(
          startMs: nodeRange.startMs,
          endMs: nodeRange.endMs,
        );
      final result = ref
          .read(alignmentEngineProvider)
          .insertBoundary(
            _currentAlignmentResult(syllables: nodeSyllables),
            syllableIndex,
            atMs,
            pcm: pcm,
          );
      _commitSyllableEdit(
        result.syllables,
        selectedSyllableIndex: _selectionAfterInsert(syllableIndex),
      );
    } on DomainException catch (error) {
      state = state.copyWith(
        draggingBoundaryIndex: null,
        draggingPreviewMs: null,
        error: error,
      );
    }
  }

  /// 修改音節文字；空字串合法且會由 Domain 標記 needsReview（REQ-13／AT-13-03～04）。
  void updateSyllableText(int index, String newText) {
    if (index < 0 || index >= state.syllables.length) {
      return;
    }
    try {
      final result = ref
          .read(alignmentEngineProvider)
          .updateSyllableText(_currentAlignmentResult(), index, newText);
      _commitSyllableEdit(result.syllables);
    } on DomainException catch (error) {
      _exposeError(error);
    }
  }

  /// 套用已通過 Domain 驗證的音節編輯結果（backend-design.md §3.1.3）。
  ///
  /// 只有總數改變才標記既有排列過期；文字或邊界位置改動不誤標。
  void applySyllableEdit(
    AlignmentResult result, {
    required DateTime updatedAt,
  }) {
    _commitSyllableEdit(result.syllables, updatedAt: updatedAt);
  }

  /// 使用者明示保留手動排列：清旗標但不重排（AT-15-08）。
  void keepCurrentArrangement({required DateTime updatedAt}) {
    final arrangement = state.arrangement;
    if (arrangement == null) return;
    state = state.copyWith(
      arrangement: arrangement.keepCurrentArrangement(updatedAt: updatedAt),
    );
  }

  /// 由 ArrangementController 寫回同一份排列狀態（REQ-15、AT-15-08）。
  ///
  /// 排列自身保留 immutable undo；此入口不觸碰校正 undo stack。
  void setArrangement(PracticeArrangement? arrangement) {
    state = state.copyWith(arrangement: arrangement);
  }

  /// 使用者明示重新生成：以目前音節總數建立全新排列（AT-15-08）。
  void regenerateArrangement({required DateTime updatedAt}) {
    final lessonId = state.sourceLessonId;
    if (lessonId == null) return;
    state = state.copyWith(
      arrangement: PracticeEngine().generateArrangement(
        state.syllables,
        lessonId: lessonId,
        updatedAt: updatedAt,
      ),
    );
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
        undoStack: _pushUndo(state.syllables),
        draggingBoundaryIndex: null,
        draggingPreviewMs: null,
        lastSnappedMs: result.snappedMs,
        error: null,
      );
      _scheduleProsodyAnalysis(pcm, nextSyllables);
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
    final pcm = _currentPcm();
    state = state.copyWith(
      syllables: List<Syllable>.unmodifiable(restored),
      undoStack: rest,
      selectedSyllableIndex:
          state.selectedSyllableIndex != null &&
              state.selectedSyllableIndex! < restored.length
          ? state.selectedSyllableIndex
          : null,
      selectedTimeRange: _rangeForIndex(
        state.selectedSyllableIndex != null &&
                state.selectedSyllableIndex! < restored.length
            ? state.selectedSyllableIndex
            : null,
        restored,
      ),
      lastSnappedMs: null,
      error: null,
    );
    _scheduleProsodyAnalysis(pcm, state.syllables);
  }

  void clearError() {
    if (state.error == null) return;
    state = state.copyWith(error: null);
  }

  Pcm? _currentPcm() {
    if (_sourcePcm != null) return _sourcePcm;
    final session = ref.read(lessonSessionControllerProvider);
    return state.sourceLessonId == session.lesson?.id
        ? session.pcm
        : ref.read(analysisControllerProvider).latestEvent?.decodedPcm;
  }

  AlignmentResult _currentAlignmentResult({List<Syllable>? syllables}) =>
      AlignmentResult(
        words: const [],
        syllables: syllables ?? state.syllables,
        source: 'editor-controller',
        confidence: 1,
      );

  void _commitSyllableEdit(
    List<Syllable> next, {
    DateTime? updatedAt,
    Object? selectedSyllableIndex = _keepSelection,
  }) {
    final nextSyllables = List<Syllable>.unmodifiable(next);
    final countChanged = nextSyllables.length != state.syllables.length;
    final nextArrangement = countChanged && updatedAt != null
        ? state.arrangement?.markStale(updatedAt: updatedAt)
        : countChanged
        ? state.arrangement?.markStale(updatedAt: DateTime.now().toUtc())
        : state.arrangement;
    final nextSelection = identical(selectedSyllableIndex, _keepSelection)
        ? state.selectedSyllableIndex != null &&
                  state.selectedSyllableIndex! < nextSyllables.length
              ? state.selectedSyllableIndex
              : null
        : selectedSyllableIndex as int?;
    final pcm = _currentPcm();
    state = state.copyWith(
      syllables: nextSyllables,
      undoStack: _pushUndo(state.syllables),
      arrangement: nextArrangement,
      selectedSyllableIndex: nextSelection,
      selectedTimeRange: _rangeForIndex(nextSelection, nextSyllables),
      draggingBoundaryIndex: null,
      draggingPreviewMs: null,
      lastSnappedMs: null,
      error: null,
    );
    _scheduleProsodyAnalysis(pcm, nextSyllables);
  }

  List<List<Syllable>> _pushUndo(List<Syllable> snapshot) {
    final next = [...state.undoStack, snapshot];
    if (next.length <= _maxUndoDepth) return next;
    return next.sublist(next.length - _maxUndoDepth);
  }

  int? _selectionAfterRemove(int boundaryIndex) {
    final selected = state.selectedSyllableIndex;
    if (selected == null) return null;
    if (selected == boundaryIndex || selected == boundaryIndex + 1) {
      return null;
    }
    return selected > boundaryIndex + 1 ? selected - 1 : selected;
  }

  int? _selectionAfterInsert(int syllableIndex) {
    final selected = state.selectedSyllableIndex;
    if (selected == null) return null;
    return selected >= syllableIndex + 1 ? selected + 1 : selected;
  }

  int? _syllableIndexAt(int atMs) {
    for (var i = 0; i < state.syllables.length; i++) {
      final syllable = state.syllables[i];
      if (atMs >= syllable.startMs && atMs < syllable.endMs) return i;
    }
    if (state.syllables.isNotEmpty && atMs == state.syllables.last.endMs) {
      return state.syllables.length - 1;
    }
    return null;
  }

  int? _firstOverlappingIndex(TimeRange range) {
    for (var i = 0; i < state.syllables.length; i++) {
      final syllable = state.syllables[i];
      if (syllable.startMs < range.endMs && syllable.endMs > range.startMs) {
        return i;
      }
    }
    return null;
  }

  TimeRange? _rangeForIndex(int? index, List<Syllable> syllables) {
    if (index == null || index < 0 || index >= syllables.length) return null;
    return syllables[index].range;
  }

  void _exposeError(DomainException error) {
    state = state.copyWith(error: error);
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

  /// AT-13-09：切點先提交；背景結果以 generation 防止舊工作倒灌。
  void _scheduleProsodyAnalysis(Pcm? pcm, List<Syllable> syllables) {
    final generation = ++_prosodyGeneration;
    if (pcm == null || syllables.isEmpty) {
      state = state.copyWith(prosody: null);
      return;
    }
    state = state.copyWith(prosody: const AsyncValue<Prosody>.loading());
    unawaited(
      ref
          .read(prosodyAnalysisRunnerProvider)
          .analyze(pcm, syllables)
          .then((prosody) {
            if (!ref.mounted || generation != _prosodyGeneration) return;
            state = state.copyWith(prosody: AsyncValue.data(prosody));
          })
          .catchError((Object error, StackTrace stackTrace) {
            if (!ref.mounted || generation != _prosodyGeneration) return;
            state = state.copyWith(
              prosody: AsyncValue<Prosody>.error(error, stackTrace),
            );
          }),
    );
  }
}
