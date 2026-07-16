// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef ArrangementGroupCallback =
    void Function(int rowIndex, int fromPosition, int toPosition);
typedef ArrangementMoveCallback =
    void Function(int rowIndex, int fromPosition, int toPosition);
typedef ArrangementReorderCallback =
    void Function(
      int rowIndex,
      int blockPosition,
      int fromPosition,
      int toPosition,
    );
typedef ArrangementRemoveBlockCallback =
    void Function(int rowIndex, int blockPosition);
typedef ArrangementRemoveGroupedSyllableCallback =
    void Function(int rowIndex, int blockPosition, int syllablePosition);
typedef ArrangementExtractGroupedSyllableCallback =
    void Function(
      int rowIndex,
      int fromBlockPosition,
      int syllablePosition,
      int toPosition,
    );
typedef ArrangementMoveSingleIntoGroupCallback =
    void Function(
      int rowIndex,
      int fromBlockPosition,
      int toBlockPosition,
      int toSyllablePosition,
    );

/// 列內既有積木的拖曳資料（frontend-design 功能點 13、REQ-15 r9）。
class ArrangementDragData {
  const ArrangementDragData.block({
    required this.rowIndex,
    required this.blockPosition,
    this.syllablePosition,
    this.isGroupedBlock = false,
  });

  final int rowIndex;
  final int blockPosition;
  final int? syllablePosition;
  final bool isGroupedBlock;

  bool get isGroupedMember => syllablePosition != null;
}

/// 自由排列的一列（frontend-design 功能點 13、REQ-15 r9）。
///
/// AT-15-17/18/20：既有積木以內容區長按進行同列排序或組合；來源段落
/// 先選取後以插入按鈕放入，避免垂直拖曳與列捲動互相搶手勢。
class ArrangementRow extends StatefulWidget {
  const ArrangementRow({
    super.key,
    required this.row,
    required this.rowIndex,
    required this.canRemove,
    required this.onInsertBefore,
    required this.onRemove,
    required this.onGroup,
    required this.onMove,
    required this.onPlaceSyllable,
    required this.onReorderGroupedSyllable,
    required this.onUngroup,
    required this.onRemoveBlock,
    required this.onRemoveGroupedSyllable,
    required this.onExtractGroupedSyllable,
    required this.onMoveSingleIntoGroup,
    this.onConfigureBlock,
    this.onConfigureRow,
    this.onPreviewRow,
    this.onStopRow,
    this.onDragActiveChanged,
    this.pendingSourceSyllable,
    this.pendingSourceLessonId,
    this.onPendingPlaced,
    this.isPreviewing = false,
  });

  final PracticeRow row;
  final int rowIndex;
  final bool canRemove;
  final VoidCallback onInsertBefore;
  final VoidCallback onRemove;
  final ArrangementGroupCallback onGroup;
  final ArrangementMoveCallback onMove;
  final void Function(
    int rowIndex,
    int position,
    Syllable syllable,
    String sourceLessonId,
  )
  onPlaceSyllable;
  final ArrangementReorderCallback onReorderGroupedSyllable;
  final void Function(int rowIndex, int blockPosition) onUngroup;
  final ArrangementRemoveBlockCallback onRemoveBlock;
  final ArrangementRemoveGroupedSyllableCallback onRemoveGroupedSyllable;
  final ArrangementExtractGroupedSyllableCallback onExtractGroupedSyllable;
  final ArrangementMoveSingleIntoGroupCallback onMoveSingleIntoGroup;
  final void Function(int rowIndex, int blockPosition)? onConfigureBlock;
  final VoidCallback? onConfigureRow;
  final VoidCallback? onPreviewRow;
  final VoidCallback? onStopRow;
  final ValueChanged<bool>? onDragActiveChanged;
  final Syllable? pendingSourceSyllable;
  final String? pendingSourceLessonId;
  final VoidCallback? onPendingPlaced;
  final bool isPreviewing;

  @override
  State<ArrangementRow> createState() => _ArrangementRowState();
}

class _ArrangementRowState extends State<ArrangementRow> {
  static const _dragDelay = Duration(milliseconds: 300);
  final FocusNode _focusNode = FocusNode();
  int? _selectedBlockPosition;
  int? _selectedSyllablePosition;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _selectBlock(int blockPosition, {int? syllablePosition}) {
    _focusNode.requestFocus();
    setState(() {
      _selectedBlockPosition = blockPosition;
      _selectedSyllablePosition = syllablePosition;
    });
  }

  void _deleteSelection() {
    final blockPosition = _selectedBlockPosition;
    if (blockPosition == null) return;
    final syllablePosition = _selectedSyllablePosition;
    if (syllablePosition == null) {
      widget.onRemoveBlock(widget.rowIndex, blockPosition);
    } else {
      widget.onRemoveGroupedSyllable(
        widget.rowIndex,
        blockPosition,
        syllablePosition,
      );
    }
    setState(() {
      _selectedBlockPosition = null;
      _selectedSyllablePosition = null;
    });
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.delete ||
            event.logicalKey == LogicalKeyboardKey.backspace) &&
        _selectedBlockPosition != null) {
      _deleteSelection();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _notifyDrag(bool active) => widget.onDragActiveChanged?.call(active);

  void _acceptBlockGap(ArrangementDragData data, int targetPosition) {
    if (data.rowIndex != widget.rowIndex) return;
    if (data.isGroupedMember) {
      widget.onExtractGroupedSyllable(
        widget.rowIndex,
        data.blockPosition,
        data.syllablePosition!,
        targetPosition,
      );
      return;
    }
    var adjustedPosition = targetPosition;
    if (data.blockPosition < targetPosition) adjustedPosition--;
    if (data.blockPosition == adjustedPosition) return;
    widget.onMove(widget.rowIndex, data.blockPosition, adjustedPosition);
  }

  void _acceptBlockCenter(ArrangementDragData data, int targetPosition) {
    if (data.rowIndex != widget.rowIndex ||
        data.isGroupedMember ||
        data.isGroupedBlock ||
        data.blockPosition == targetPosition) {
      return;
    }
    widget.onGroup(
      widget.rowIndex,
      data.blockPosition < targetPosition ? data.blockPosition : targetPosition,
      data.blockPosition < targetPosition ? targetPosition : data.blockPosition,
    );
  }

  void _acceptGroupGap(
    ArrangementDragData data,
    int blockPosition,
    int targetSyllablePosition,
  ) {
    if (data.rowIndex != widget.rowIndex) return;
    if (data.isGroupedMember && data.blockPosition == blockPosition) {
      var adjustedPosition = targetSyllablePosition;
      if (data.syllablePosition! < targetSyllablePosition) adjustedPosition--;
      if (data.syllablePosition == adjustedPosition) return;
      widget.onReorderGroupedSyllable(
        widget.rowIndex,
        blockPosition,
        data.syllablePosition!,
        adjustedPosition,
      );
      return;
    }
    if (!data.isGroupedMember && !data.isGroupedBlock) {
      widget.onMoveSingleIntoGroup(
        widget.rowIndex,
        data.blockPosition,
        blockPosition,
        targetSyllablePosition,
      );
    }
  }

  Widget _sourceInsertButton(int targetPosition, {bool empty = false}) {
    final pending = widget.pendingSourceSyllable;
    final lessonId = widget.pendingSourceLessonId;
    final canPlace = pending != null && lessonId != null;
    if (!canPlace) {
      return empty
          ? const SizedBox(
              height: 50,
              child: Center(child: Text('空列：請先選取來源段落')),
            )
          : const SizedBox.shrink();
    }
    void place() {
      widget.onPlaceSyllable(
        widget.rowIndex,
        targetPosition,
        pending,
        lessonId,
      );
      widget.onPendingPlaced?.call();
    }

    if (empty) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.tonal(
          key: ValueKey('arrangement-source-empty-${widget.rowIndex}'),
          onPressed: place,
          child: const Text('點此放下積木'),
        ),
      );
    }
    return IconButton(
      key: ValueKey(
        'arrangement-source-insert-${widget.rowIndex}-$targetPosition',
      ),
      tooltip: targetPosition == widget.row.blocks.length
          ? '把所選來源段落插入列尾'
          : '把所選來源段落插入此積木前',
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
      onPressed: place,
      icon: const Icon(Icons.add_circle_outline, size: 20),
    );
  }

  Widget _blockGap(int targetPosition) {
    return DragTarget<ArrangementDragData>(
      onWillAcceptWithDetails: (details) =>
          details.data.rowIndex == widget.rowIndex,
      onAcceptWithDetails: (details) =>
          _acceptBlockGap(details.data, targetPosition),
      builder: (context, candidates, _) => AnimatedContainer(
        key: ValueKey('arrangement-gap-${widget.rowIndex}-$targetPosition'),
        duration: const Duration(milliseconds: 100),
        width: candidates.isNotEmpty ? 18 : 8,
        height: 44,
        decoration: BoxDecoration(
          color: candidates.isNotEmpty
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _groupGap(int blockPosition, int targetSyllablePosition) {
    return DragTarget<ArrangementDragData>(
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        if (data.rowIndex != widget.rowIndex) return false;
        return (data.isGroupedMember && data.blockPosition == blockPosition) ||
            (!data.isGroupedMember && !data.isGroupedBlock);
      },
      onAcceptWithDetails: (details) =>
          _acceptGroupGap(details.data, blockPosition, targetSyllablePosition),
      builder: (context, candidates, _) => AnimatedContainer(
        key: ValueKey(
          'arrangement-member-target-${widget.rowIndex}-$blockPosition-$targetSyllablePosition',
        ),
        duration: const Duration(milliseconds: 100),
        width: candidates.isNotEmpty ? 18 : 7,
        height: 34,
        decoration: BoxDecoration(
          color: candidates.isNotEmpty
              ? Theme.of(context).colorScheme.tertiary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _centerTarget({required int targetPosition, required Widget child}) {
    return DragTarget<ArrangementDragData>(
      onWillAcceptWithDetails: (details) =>
          details.data.rowIndex == widget.rowIndex &&
          !details.data.isGroupedMember &&
          !details.data.isGroupedBlock,
      onAcceptWithDetails: (details) =>
          _acceptBlockCenter(details.data, targetPosition),
      builder: (context, candidates, _) => AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          border: candidates.isNotEmpty
              ? Border.all(
                  color: Theme.of(context).colorScheme.tertiary,
                  width: 2,
                )
              : null,
        ),
        child: Stack(
          children: [
            child,
            if (candidates.isNotEmpty)
              const Positioned.fill(
                child: IgnorePointer(child: Center(child: Text('放開以組合'))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _longPressDraggable({
    required ArrangementDragData data,
    required Widget feedback,
    required Widget child,
  }) {
    return LongPressDraggable<ArrangementDragData>(
      data: data,
      delay: _dragDelay,
      maxSimultaneousDrags: 1,
      onDragStarted: () => _notifyDrag(true),
      onDragEnd: (_) => _notifyDrag(false),
      feedback: Material(color: Colors.transparent, child: feedback),
      childWhenDragging: Opacity(opacity: 0.35, child: child),
      child: child,
    );
  }

  Widget _buildUngroupedBlock(PracticeBlock block, int blockPosition) {
    final selected =
        _selectedBlockPosition == blockPosition &&
        _selectedSyllablePosition == null;
    final card = GestureDetector(
      key: ValueKey('arrangement-block-$blockPosition'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _selectBlock(blockPosition),
      onDoubleTap: widget.onConfigureBlock == null
          ? null
          : () => widget.onConfigureBlock!(widget.rowIndex, blockPosition),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: _BlockCard(block: block, dragging: false),
      ),
    );
    return _centerTarget(
      targetPosition: blockPosition,
      child: _longPressDraggable(
        data: ArrangementDragData.block(
          rowIndex: widget.rowIndex,
          blockPosition: blockPosition,
        ),
        feedback: _BlockCard(block: block, dragging: true),
        child: card,
      ),
    );
  }

  Widget _buildGroupedBlock(PracticeBlock block, int blockPosition) {
    final groupSelected =
        _selectedBlockPosition == blockPosition &&
        _selectedSyllablePosition == null;
    final group = GestureDetector(
      key: ValueKey('arrangement-group-$blockPosition'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _selectBlock(blockPosition),
      onDoubleTap: widget.onConfigureBlock == null
          ? null
          : () => widget.onConfigureBlock!(widget.rowIndex, blockPosition),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: groupSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.indigo.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: groupSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.indigo.withValues(alpha: 0.45),
            width: groupSelected ? 2 : 1,
          ),
        ),
        child: Wrap(
          spacing: 3,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < block.syllables.length; i++) ...[
              _groupGap(blockPosition, i),
              _longPressDraggable(
                data: ArrangementDragData.block(
                  rowIndex: widget.rowIndex,
                  blockPosition: blockPosition,
                  syllablePosition: i,
                ),
                feedback: Chip(label: Text(block.syllables[i].text)),
                child: GestureDetector(
                  key: ValueKey('arrangement-member-$blockPosition-$i'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _selectBlock(blockPosition, syllablePosition: i),
                  child: Chip(
                    label: Text(block.syllables[i].text),
                    backgroundColor:
                        _selectedBlockPosition == blockPosition &&
                            _selectedSyllablePosition == i
                        ? Theme.of(context).colorScheme.tertiaryContainer
                        : null,
                  ),
                ),
              ),
            ],
            _groupGap(blockPosition, block.syllables.length),
            IconButton(
              key: ValueKey('arrangement-ungroup-$blockPosition'),
              tooltip: '拆組',
              onPressed: () => widget.onUngroup(widget.rowIndex, blockPosition),
              icon: const Icon(Icons.call_split, size: 18),
            ),
          ],
        ),
      ),
    );
    return _longPressDraggable(
      data: ArrangementDragData.block(
        rowIndex: widget.rowIndex,
        blockPosition: blockPosition,
        isGroupedBlock: true,
      ),
      feedback: _BlockCard(block: block, dragging: true),
      child: group,
    );
  }

  String? get _deleteTooltip {
    final blockPosition = _selectedBlockPosition;
    if (blockPosition == null || blockPosition >= widget.row.blocks.length) {
      return null;
    }
    if (_selectedSyllablePosition != null) return '刪除組內音節';
    return widget.row.blocks[blockPosition].isGrouped ? '刪除整個組合' : '刪除積木';
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      child: Card(
        key: ValueKey('arrangement-row-${widget.row.index}'),
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('第 ${widget.row.index} 列')),
                  if (_deleteTooltip != null)
                    IconButton(
                      key: const ValueKey('arrangement-delete-selection'),
                      tooltip: _deleteTooltip,
                      onPressed: _deleteSelection,
                      icon: const Icon(Icons.delete_forever),
                    ),
                  IconButton(
                    tooltip: '在第 ${widget.row.index} 列前插入',
                    onPressed: widget.onInsertBefore,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                  IconButton(
                    tooltip: '刪除第 ${widget.row.index} 列',
                    onPressed: widget.canRemove ? widget.onRemove : null,
                    icon: const Icon(Icons.delete_outline),
                  ),
                  IconButton(
                    key: ValueKey('arrangement-config-row-${widget.row.index}'),
                    tooltip: '設定第 ${widget.row.index} 列',
                    onPressed: widget.onConfigureRow,
                    icon: const Icon(Icons.tune),
                  ),
                  IconButton(
                    key: ValueKey(
                      'arrangement-preview-row-${widget.row.index}',
                    ),
                    tooltip: widget.isPreviewing
                        ? '停止第 ${widget.row.index} 列預覽'
                        : '播放第 ${widget.row.index} 列預覽',
                    onPressed: widget.isPreviewing
                        ? widget.onStopRow
                        : widget.onPreviewRow,
                    icon: Icon(
                      widget.isPreviewing
                          ? Icons.stop
                          : Icons.play_circle_outline,
                    ),
                  ),
                ],
              ),
              if (widget.row.blocks.isEmpty)
                _sourceInsertButton(0, empty: true)
              else
                Wrap(
                  spacing: 2,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (var i = 0; i < widget.row.blocks.length; i++) ...[
                      _sourceInsertButton(i),
                      _blockGap(i),
                      widget.row.blocks[i].isGrouped
                          ? _buildGroupedBlock(widget.row.blocks[i], i)
                          : _buildUngroupedBlock(widget.row.blocks[i], i),
                    ],
                    _sourceInsertButton(widget.row.blocks.length),
                    _blockGap(widget.row.blocks.length),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({required this.block, required this.dragging});

  final PracticeBlock block;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    final label = block.syllables.map((syllable) => syllable.text).join(' ');
    return Chip(
      label: Text(label.isEmpty ? '待檢音節' : label),
      backgroundColor: dragging
          ? Theme.of(context).colorScheme.tertiaryContainer
          : null,
    );
  }
}
