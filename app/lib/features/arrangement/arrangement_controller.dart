// AI-Generate
import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editor/editor_controller.dart';
import '../practice/practice_player.dart';

/// 自由排列 UI 狀態（frontend-design 功能點 13、REQ-15）。
class ArrangementUiState {
  const ArrangementUiState({
    this.arrangement,
    this.previewingRowIndex,
    this.error,
  });

  static const Object _unset = Object();

  final PracticeArrangement? arrangement;
  final int? previewingRowIndex;
  final String? error;

  bool get canUndo => arrangement?.undoDepth != 0;
  bool get isStale => arrangement?.staleFlag ?? false;

  ArrangementUiState copyWith({
    Object? arrangement = _unset,
    Object? previewingRowIndex = _unset,
    Object? error = _unset,
  }) {
    return ArrangementUiState(
      arrangement: identical(arrangement, _unset)
          ? this.arrangement
          : arrangement as PracticeArrangement?,
      previewingRowIndex: identical(previewingRowIndex, _unset)
          ? this.previewingRowIndex
          : previewingRowIndex as int?,
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }
}

final arrangementControllerProvider =
    NotifierProvider<ArrangementController, ArrangementUiState>(
      ArrangementController.new,
    );

/// 自由排列狀態控制器（backend-design.md 介面 27/28；REQ-15）。
///
/// Domain `PracticeArrangement` 是唯一排列真相；本 controller 只負責把
/// immutable 操作結果同步回 EditorController，校正 undo 與排列 undo 分離。
class ArrangementController extends Notifier<ArrangementUiState> {
  int _previewRunId = 0;
  @override
  ArrangementUiState build() {
    final current = ref.read(editorControllerProvider);
    ref.listen<EditorUiState>(editorControllerProvider, (previous, next) {
      if (previous?.arrangement == next.arrangement) return;
      state = state.copyWith(arrangement: next.arrangement, error: null);
    });
    return ArrangementUiState(arrangement: current.arrangement);
  }

  /// 依目前音節一鍵生成句尾疊加排列（AT-15-01）。
  void generate({required String lessonId, DateTime? updatedAt}) {
    final editor = ref.read(editorControllerProvider);
    if (editor.syllables.isEmpty) {
      _exposeError('尚無音節可生成排列');
      return;
    }
    try {
      final arrangement = PracticeEngine().generateArrangement(
        editor.syllables,
        lessonId: lessonId,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
      );
      _commit(arrangement);
    } on Object catch (error) {
      _exposeError('$error');
    }
  }

  /// 在指定位置插入空列，列號由 Domain 重新編排（AT-15-02）。
  void insertRow(int atIndex, {DateTime? updatedAt}) {
    _apply(
      (arrangement) => arrangement.insertRow(
        atIndex,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
      ),
    );
  }

  /// 刪除指定列；排列 undo 保留在 Domain 快照中（AT-15-02）。
  void removeRow(int index, {DateTime? updatedAt}) {
    _apply(
      (arrangement) => arrangement.removeRow(
        index,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
      ),
    );
  }

  /// 將上方音節池的原音積木放入任一列，包含空列（AT-15-02）。
  void placeSyllable({
    required int rowIndex,
    required int position,
    required Syllable syllable,
    required String sourceLessonId,
    DateTime? updatedAt,
  }) {
    _apply(
      (arrangement) => arrangement.placeBlock(
        rowIndex,
        position,
        syllable,
        sourceLessonId: sourceLessonId,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
      ),
    );
  }

  /// 同列長按拖曳後將相鄰積木合併成組（AT-15-02）。
  void groupBlocks(
    int rowIndex,
    int fromPosition,
    int toPosition, {
    DateTime? updatedAt,
  }) {
    _apply(
      (arrangement) => arrangement.groupBlocks(
        rowIndex,
        fromPosition,
        toPosition,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
      ),
    );
  }

  /// 同列長按拖曳調整積木位置；跨列由 Domain 拒絕（AT-15-17）。
  void moveBlock({
    required int rowIndex,
    required int fromPosition,
    required int toPosition,
    DateTime? updatedAt,
  }) {
    _apply(
      (arrangement) => arrangement.moveBlock(
        fromRowIndex: rowIndex,
        fromPosition: fromPosition,
        toRowIndex: rowIndex,
        toPosition: toPosition,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
      ),
    );
  }

  /// 刪除所選單一積木或整個組合積木（AT-15-17）。
  void removeBlock({
    required int rowIndex,
    required int blockPosition,
    DateTime? updatedAt,
  }) {
    _apply(
      (arrangement) => arrangement.removeBlock(
        rowIndex,
        blockPosition,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
      ),
    );
  }

  /// 刪除組合內的指定音節；剩一個時由 Domain 自動降為單一積木（AT-15-18）。
  void removeGroupedSyllable({
    required int rowIndex,
    required int blockPosition,
    required int syllablePosition,
    DateTime? updatedAt,
  }) {
    _apply(
      (arrangement) => arrangement.removeGroupedSyllable(
        rowIndex: rowIndex,
        blockPosition: blockPosition,
        syllablePosition: syllablePosition,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
      ),
    );
  }

  /// 把組合內音節抽出成同列的獨立積木（AT-15-18）。
  void extractGroupedSyllable({
    required int rowIndex,
    required int fromBlockPosition,
    required int syllablePosition,
    required int toPosition,
    DateTime? updatedAt,
  }) {
    _apply(
      (arrangement) => arrangement.extractGroupedSyllable(
        fromRowIndex: rowIndex,
        fromBlockPosition: fromBlockPosition,
        syllablePosition: syllablePosition,
        toRowIndex: rowIndex,
        toPosition: toPosition,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
      ),
    );
  }

  /// 把獨立積木插入既有組合的指定位置（AT-15-18）。
  void moveSingleBlockIntoGroup({
    required int rowIndex,
    required int fromBlockPosition,
    required int toBlockPosition,
    required int toSyllablePosition,
    DateTime? updatedAt,
  }) {
    _apply(
      (arrangement) => arrangement.moveSingleBlockIntoGroup(
        fromRowIndex: rowIndex,
        fromBlockPosition: fromBlockPosition,
        toRowIndex: rowIndex,
        toBlockPosition: toBlockPosition,
        toSyllablePosition: toSyllablePosition,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
      ),
    );
  }

  /// 成組積木內拖曳音節後重新排序（AT-15-03）。
  void reorderGroupedSyllable({
    required int rowIndex,
    required int blockPosition,
    required int fromPosition,
    required int toPosition,
    DateTime? updatedAt,
  }) {
    _apply(
      (arrangement) => arrangement.reorderGroupedSyllable(
        rowIndex: rowIndex,
        blockPosition: blockPosition,
        fromPosition: fromPosition,
        toPosition: toPosition,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
      ),
    );
  }

  /// 拆開指定成組積木回到單音節積木（AT-15-03）。
  void ungroup(int rowIndex, int blockPosition, {DateTime? updatedAt}) {
    _apply(
      (arrangement) => arrangement.ungroup(
        rowIndex,
        blockPosition,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
      ),
    );
  }

  /// 調整單一積木的重複次數與靜音倍數（AT-15-04/06）。
  ///
  /// Domain 先驗證範圍；失敗時只呈現錯誤，不提交新快照，因此既有值不會
  /// 被清空，排列 undo 也維持原狀。
  void setBlockConfig({
    required int rowIndex,
    required int blockPosition,
    int? repeatN,
    double? silenceFactor,
    DateTime? updatedAt,
  }) {
    _apply(
      (arrangement) => arrangement.setBlockConfig(
        rowIndex,
        blockPosition,
        repeatN: repeatN,
        silenceFactor: silenceFactor,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
      ),
    );
  }

  /// 將指定積木／組塊原子重置為初始 1 次／3 倍（AT-15-11）。
  void resetBlockConfig({
    required int rowIndex,
    required int blockPosition,
    DateTime? updatedAt,
  }) {
    _apply(
      (arrangement) => arrangement.resetBlockConfig(
        rowIndex,
        blockPosition,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
      ),
    );
  }

  /// 調整整列外層的重複次數與靜音倍數（AT-15-13）。
  void setRowConfig({
    required int rowIndex,
    int? repeatN,
    double? silenceFactor,
    DateTime? updatedAt,
  }) {
    _apply(
      (arrangement) => arrangement.setRowConfig(
        rowIndex,
        repeatN: repeatN,
        silenceFactor: silenceFactor,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
      ),
    );
  }

  /// 將整列外層設定重置為 3 次／3 倍（AT-15-13）。
  void resetRowConfig({required int rowIndex, DateTime? updatedAt}) {
    _apply(
      (arrangement) => arrangement.resetRowConfig(
        rowIndex,
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
      ),
    );
  }

  /// 以目前列的 immutable snapshot 播放預覽（AT-15-05/07/09）。
  Future<void> previewRow({required int rowIndex, required Pcm pcm}) async {
    final arrangement = state.arrangement;
    if (arrangement == null) return;
    if (rowIndex < 0 || rowIndex >= arrangement.rows.length) {
      _exposeError('rowIndex 超出範圍，got $rowIndex');
      return;
    }
    final runId = ++_previewRunId;
    final snapshot = arrangement.rows[rowIndex];
    try {
      await ref
          .read(practicePlayerProvider)
          .playRow(
            snapshot,
            pcm,
            onReady: () {
              if (runId == _previewRunId) {
                state = state.copyWith(
                  previewingRowIndex: rowIndex,
                  error: null,
                );
              }
            },
          );
      if (runId != _previewRunId) return;
      state = state.copyWith(previewingRowIndex: null);
    } on Object catch (error) {
      if (runId == _previewRunId) {
        state = state.copyWith(previewingRowIndex: null);
        _exposeError('$error');
      }
    }
  }

  /// 預覽單一積木，沿用 PracticePlayer 的原音切片路徑（AT-15-04/05）。
  Future<void> previewBlock({
    required int rowIndex,
    required int blockPosition,
    required Pcm pcm,
  }) async {
    final arrangement = state.arrangement;
    if (arrangement == null) return;
    if (rowIndex < 0 || rowIndex >= arrangement.rows.length) {
      _exposeError('rowIndex 超出範圍，got $rowIndex');
      return;
    }
    final row = arrangement.rows[rowIndex];
    if (blockPosition < 0 || blockPosition >= row.blocks.length) {
      _exposeError('blockPosition 超出範圍，got $blockPosition');
      return;
    }
    final block = row.blocks[blockPosition];
    final previewRow = PracticeRow(
      index: row.index,
      blocks: [block],
      repeatN: 1,
      silenceFactor: 0,
    );
    final runId = ++_previewRunId;
    try {
      await ref.read(practicePlayerProvider).playRow(previewRow, pcm);
      if (runId != _previewRunId) return;
    } on Object catch (error) {
      if (runId == _previewRunId) _exposeError('$error');
    }
  }

  /// 明示停止列預覽；排列異動也會自動呼叫同一防線。
  Future<void> stopPreview() async {
    _previewRunId++;
    await ref.read(practicePlayerProvider).stop();
    state = state.copyWith(previewingRowIndex: null);
  }

  /// 刪除目前 Lesson 的自訂排列並回落完整單句；校正與錄音資料不受影響。
  Future<void> removeArrangement() async {
    await stopPreview();
    ref.read(editorControllerProvider.notifier).setArrangement(null);
    state = state.copyWith(
      arrangement: null,
      previewingRowIndex: null,
      error: null,
    );
  }

  /// 只撤銷排列操作，不改 EditorController 的校正 undo（AT-15-08）。
  void undo({DateTime? updatedAt}) {
    _apply(
      (arrangement) => arrangement.undoArrangement(
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
      ),
    );
  }

  /// 使用者明示保留目前排列，清除 stale banner（AT-15-08）。
  void keepCurrent({DateTime? updatedAt}) {
    final arrangement = state.arrangement;
    if (arrangement == null) return;
    _commit(
      arrangement.keepCurrentArrangement(
        updatedAt: updatedAt ?? DateTime.now().toUtc(),
      ),
    );
  }

  void clearError() {
    if (state.error == null) return;
    state = state.copyWith(error: null);
  }

  void _apply(
    PracticeArrangement Function(PracticeArrangement arrangement) operation,
  ) {
    final arrangement = state.arrangement;
    if (arrangement == null) return;
    try {
      _commit(operation(arrangement));
    } on Object catch (error) {
      _exposeError('$error');
    }
  }

  void _commit(PracticeArrangement arrangement) {
    _previewRunId++;
    unawaited(ref.read(practicePlayerProvider).stop());
    ref.read(editorControllerProvider.notifier).setArrangement(arrangement);
    state = state.copyWith(
      arrangement: arrangement,
      previewingRowIndex: null,
      error: null,
    );
  }

  void _exposeError(String message) {
    state = state.copyWith(error: message);
  }
}
