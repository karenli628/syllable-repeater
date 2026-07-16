// AI-Generate
import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../editor/editor_controller.dart';
import '../import_analysis/analysis_controller.dart';
import '../pack_translate/lesson_session_controller.dart';
import 'arrangement_controller.dart';
import 'widgets/block_config_menu.dart';
import 'widgets/arrangement_row.dart';

/// 自由排列編輯區（frontend-design 功能點 13、REQ-15）。
///
/// 呈現列與排列操作入口；積木設定、列預覽與拖曳皆委派 controller。
class ArrangementSection extends ConsumerStatefulWidget {
  const ArrangementSection({super.key, this.onOuterScrollLockChanged});

  /// 游標位於列區或正在拖曳時，請外層暫停捲動（AT-15-16）。
  final ValueChanged<bool>? onOuterScrollLockChanged;

  @override
  ConsumerState<ArrangementSection> createState() => _ArrangementSectionState();
}

class _ArrangementSectionState extends ConsumerState<ArrangementSection> {
  final ScrollController _rowsController = ScrollController();
  final FocusNode _sectionFocusNode = FocusNode();
  final GlobalKey _rowsViewportKey = GlobalKey();
  final Map<int, GlobalKey> _rowKeys = {};
  Timer? _highlightTimer;
  int? _highlightedRowIndex;
  bool _dragActive = false;
  bool _pointerInsideRows = false;
  bool _outerScrollLocked = false;
  int? _pendingSourceSyllableIndex;

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _rowsController.dispose();
    _sectionFocusNode.dispose();
    super.dispose();
  }

  void _insertRow(ArrangementController controller, int position) {
    controller.insertRow(position);
    _highlightTimer?.cancel();
    setState(() => _highlightedRowIndex = position);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rowContext = _rowKeys[position]?.currentContext;
      final viewportContext = _rowsViewportKey.currentContext;
      final rowBox = rowContext?.findRenderObject() as RenderBox?;
      final viewportBox = viewportContext?.findRenderObject() as RenderBox?;
      if (rowBox == null ||
          viewportBox == null ||
          !_rowsController.hasClients) {
        return;
      }
      final rowTop = rowBox.localToGlobal(Offset.zero).dy;
      final viewportTop = viewportBox.localToGlobal(Offset.zero).dy;
      final target = (_rowsController.offset + rowTop - viewportTop - 80).clamp(
        _rowsController.position.minScrollExtent,
        _rowsController.position.maxScrollExtent,
      );
      unawaited(
        _rowsController.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        ),
      );
    });
    _highlightTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _highlightedRowIndex = null);
    });
  }

  void _setDragActive(bool active) {
    _dragActive = active;
    _syncOuterScrollLock();
  }

  void _setPointerInsideRows(bool inside) {
    _pointerInsideRows = inside;
    _syncOuterScrollLock();
  }

  void _syncOuterScrollLock() {
    final locked = _dragActive || _pointerInsideRows;
    if (_outerScrollLocked == locked) return;
    _outerScrollLocked = locked;
    widget.onOuterScrollLockChanged?.call(locked);
  }

  void _togglePendingSource(int index) {
    _sectionFocusNode.requestFocus();
    setState(() {
      _pendingSourceSyllableIndex = _pendingSourceSyllableIndex == index
          ? null
          : index;
    });
  }

  void _clearPendingSource() {
    if (_pendingSourceSyllableIndex == null) return;
    setState(() => _pendingSourceSyllableIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    final editor = ref.watch(editorControllerProvider);
    final state = ref.watch(arrangementControllerProvider);
    final controller = ref.read(arrangementControllerProvider.notifier);
    final analysis = ref.watch(analysisControllerProvider);
    final session = ref.watch(lessonSessionControllerProvider);
    final arrangement = state.arrangement;
    final lessonId = editor.sourceLessonId;
    final pcm = session.pcm ?? analysis.latestEvent?.decodedPcm;

    final rawPendingIndex = _pendingSourceSyllableIndex;
    final pendingIndex =
        rawPendingIndex != null &&
            rawPendingIndex >= 0 &&
            rawPendingIndex < editor.syllables.length
        ? rawPendingIndex
        : null;
    final pendingSyllable = pendingIndex == null
        ? null
        : editor.syllables[pendingIndex];

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _clearPendingSource,
      },
      child: Focus(
        focusNode: _sectionFocusNode,
        autofocus: true,
        child: Card(
          key: const ValueKey('arrangement-section'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (arrangement != null)
                      IconButton(
                        key: const ValueKey('arrangement-remove'),
                        tooltip: '刪除自訂排列',
                        onPressed: () => unawaited(
                          _confirmRemoveArrangement(context, controller),
                        ),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    Expanded(
                      child: Text(
                        '自由排列',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (arrangement != null && state.canUndo)
                      TextButton.icon(
                        key: const ValueKey('arrangement-undo'),
                        onPressed: controller.undo,
                        icon: const Icon(Icons.undo),
                        label: const Text('撤銷排列'),
                      ),
                  ],
                ),
                if (state.error != null)
                  Container(
                    key: const ValueKey('arrangement-error'),
                    padding: const EdgeInsets.all(8),
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Text(state.error!),
                  ),
                if (arrangement == null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      key: const ValueKey('arrangement-generate'),
                      onPressed: lessonId == null
                          ? null
                          : () => controller.generate(lessonId: lessonId),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('一鍵生成排列'),
                    ),
                  )
                else ...[
                  if (state.isStale)
                    Container(
                      key: const ValueKey('arrangement-stale-banner'),
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          const Text('音節數已變更，這份排列可能過期。'),
                          TextButton(
                            key: const ValueKey('arrangement-regenerate'),
                            onPressed: lessonId == null
                                ? null
                                : () => controller.generate(lessonId: lessonId),
                            child: const Text('重新生成'),
                          ),
                          TextButton(
                            key: const ValueKey('arrangement-keep'),
                            onPressed: controller.keepCurrent,
                            child: const Text('保留目前排列'),
                          ),
                        ],
                      ),
                    ),
                  _PinnedSyllableToolbar(
                    syllables: editor.syllables,
                    enabled: lessonId != null,
                    selectedIndex: pendingIndex,
                    onSelected: _togglePendingSource,
                  ),
                  if (pendingSyllable != null)
                    Container(
                      key: const ValueKey('arrangement-pending-place-hint'),
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(8),
                      color: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(
                        '已選取「${pendingSyllable.text}」：請點各列的插入圖示；Esc 取消。',
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('共 ${arrangement.rows.length} 列'),
                      const Spacer(),
                      IconButton(
                        key: const ValueKey('arrangement-insert-row'),
                        tooltip: '新增排列列',
                        onPressed: () =>
                            _insertRow(controller, arrangement.rows.length),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  MouseRegion(
                    key: const ValueKey('arrangement-rows-mouse-region'),
                    onEnter: (_) => _setPointerInsideRows(true),
                    onExit: (_) => _setPointerInsideRows(false),
                    child: Container(
                      key: _rowsViewportKey,
                      height: (arrangement.rows.length * 132.0).clamp(
                        300.0,
                        430.0,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ClipRRect(
                        key: const ValueKey('arrangement-rows-viewport'),
                        borderRadius: BorderRadius.circular(10),
                        child: Scrollbar(
                          key: const ValueKey('arrangement-rows-scrollbar'),
                          controller: _rowsController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            key: const ValueKey('arrangement-rows-scroll'),
                            controller: _rowsController,
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              children: [
                                for (final row in arrangement.rows)
                                  AnimatedContainer(
                                    key: ValueKey(
                                      _highlightedRowIndex == row.index - 1
                                          ? 'arrangement-new-row-highlight-${row.index}'
                                          : 'arrangement-row-shell-${row.index}',
                                    ),
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color:
                                          _highlightedRowIndex == row.index - 1
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.tertiaryContainer
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: KeyedSubtree(
                                      key: _rowKeys.putIfAbsent(
                                        row.index - 1,
                                        GlobalKey.new,
                                      ),
                                      child: ArrangementRow(
                                        row: row,
                                        rowIndex: row.index - 1,
                                        canRemove: true,
                                        onInsertBefore: () => _insertRow(
                                          controller,
                                          row.index - 1,
                                        ),
                                        onRemove: () =>
                                            controller.removeRow(row.index - 1),
                                        onDragActiveChanged: _setDragActive,
                                        onGroup: controller.groupBlocks,
                                        onMove: (rowIndex, from, to) =>
                                            controller.moveBlock(
                                              rowIndex: rowIndex,
                                              fromPosition: from,
                                              toPosition: to,
                                            ),
                                        onPlaceSyllable:
                                            (
                                              rowIndex,
                                              position,
                                              syllable,
                                              sourceLessonId,
                                            ) => controller.placeSyllable(
                                              rowIndex: rowIndex,
                                              position: position,
                                              syllable: syllable,
                                              sourceLessonId: sourceLessonId,
                                            ),
                                        pendingSourceSyllable: pendingSyllable,
                                        pendingSourceLessonId:
                                            pendingSyllable == null
                                            ? null
                                            : lessonId,
                                        onPendingPlaced: _clearPendingSource,
                                        onReorderGroupedSyllable:
                                            (
                                              rowIndex,
                                              blockPosition,
                                              fromPosition,
                                              toPosition,
                                            ) => controller
                                                .reorderGroupedSyllable(
                                                  rowIndex: rowIndex,
                                                  blockPosition: blockPosition,
                                                  fromPosition: fromPosition,
                                                  toPosition: toPosition,
                                                ),
                                        onRemoveBlock:
                                            (rowIndex, blockPosition) =>
                                                controller.removeBlock(
                                                  rowIndex: rowIndex,
                                                  blockPosition: blockPosition,
                                                ),
                                        onRemoveGroupedSyllable:
                                            (
                                              rowIndex,
                                              blockPosition,
                                              syllablePosition,
                                            ) => controller
                                                .removeGroupedSyllable(
                                                  rowIndex: rowIndex,
                                                  blockPosition: blockPosition,
                                                  syllablePosition:
                                                      syllablePosition,
                                                ),
                                        onExtractGroupedSyllable:
                                            (
                                              rowIndex,
                                              fromBlock,
                                              syllablePosition,
                                              toPosition,
                                            ) => controller
                                                .extractGroupedSyllable(
                                                  rowIndex: rowIndex,
                                                  fromBlockPosition: fromBlock,
                                                  syllablePosition:
                                                      syllablePosition,
                                                  toPosition: toPosition,
                                                ),
                                        onMoveSingleIntoGroup:
                                            (
                                              rowIndex,
                                              fromBlock,
                                              toBlock,
                                              toSyllable,
                                            ) => controller
                                                .moveSingleBlockIntoGroup(
                                                  rowIndex: rowIndex,
                                                  fromBlockPosition: fromBlock,
                                                  toBlockPosition: toBlock,
                                                  toSyllablePosition:
                                                      toSyllable,
                                                ),
                                        onUngroup: controller.ungroup,
                                        onConfigureBlock: (rowIndex, blockPosition) {
                                          final selected = arrangement
                                              .rows[rowIndex]
                                              .blocks[blockPosition];
                                          unawaited(
                                            showDialog<void>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                content: BlockConfigMenu(
                                                  initialRepeatN:
                                                      selected.repeatN,
                                                  initialSilenceFactor:
                                                      selected.silenceFactor,
                                                  onChanged:
                                                      (repeatN, silenceFactor) {
                                                        controller
                                                            .setBlockConfig(
                                                              rowIndex:
                                                                  rowIndex,
                                                              blockPosition:
                                                                  blockPosition,
                                                              repeatN: repeatN,
                                                              silenceFactor:
                                                                  silenceFactor,
                                                            );
                                                      },
                                                  onReset: () => controller
                                                      .resetBlockConfig(
                                                        rowIndex: rowIndex,
                                                        blockPosition:
                                                            blockPosition,
                                                      ),
                                                  onPreview: pcm == null
                                                      ? null
                                                      : () => unawaited(
                                                          controller.previewBlock(
                                                            rowIndex: rowIndex,
                                                            blockPosition:
                                                                blockPosition,
                                                            pcm: pcm,
                                                          ),
                                                        ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        onConfigureRow: () {
                                          final selected =
                                              arrangement.rows[row.index - 1];
                                          unawaited(
                                            showDialog<void>(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                content: BlockConfigMenu(
                                                  title: '整列設定',
                                                  keyPrefix: 'row',
                                                  previewLabel: '預覽整列',
                                                  resetRepeatN: PracticeRow
                                                      .defaultRepeatN,
                                                  resetSilenceFactor:
                                                      PracticeRow
                                                          .defaultSilenceFactor,
                                                  initialRepeatN:
                                                      selected.repeatN,
                                                  initialSilenceFactor:
                                                      selected.silenceFactor,
                                                  onChanged:
                                                      (repeatN, silenceFactor) {
                                                        controller.setRowConfig(
                                                          rowIndex:
                                                              row.index - 1,
                                                          repeatN: repeatN,
                                                          silenceFactor:
                                                              silenceFactor,
                                                        );
                                                      },
                                                  onReset: () =>
                                                      controller.resetRowConfig(
                                                        rowIndex: row.index - 1,
                                                      ),
                                                  onPreview: pcm == null
                                                      ? null
                                                      : () => unawaited(
                                                          controller.previewRow(
                                                            rowIndex:
                                                                row.index - 1,
                                                            pcm: pcm,
                                                          ),
                                                        ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        isPreviewing:
                                            state.previewingRowIndex ==
                                            row.index - 1,
                                        onStopRow: () =>
                                            unawaited(controller.stopPreview()),
                                        onPreviewRow: pcm == null
                                            ? null
                                            : () => unawaited(
                                                controller.previewRow(
                                                  rowIndex: row.index - 1,
                                                  pcm: pcm,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PinnedSyllableToolbar extends StatelessWidget {
  const _PinnedSyllableToolbar({
    required this.syllables,
    required this.enabled,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<Syllable> syllables;
  final bool enabled;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('arrangement-source-toolbar'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text('來源段落'),
            ),
            for (var i = 0; i < syllables.length; i++) ...[
              GestureDetector(
                key: ValueKey('arrangement-source-syllable-$i'),
                behavior: HitTestBehavior.opaque,
                onTap: enabled ? () => onSelected(i) : null,
                child: Chip(
                  label: Text(syllables[i].text),
                  backgroundColor: selectedIndex == i
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  side: selectedIndex == i
                      ? BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _confirmRemoveArrangement(
  BuildContext context,
  ArrangementController controller,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('刪除自訂排列？'),
      content: const Text('只會刪除目前排列，段落校正、錄音與進度都會保留。'),
      actions: [
        TextButton(
          key: const ValueKey('arrangement-remove-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('arrangement-remove-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('刪除排列'),
        ),
      ],
    ),
  );
  if (confirmed == true) await controller.removeArrangement();
}
