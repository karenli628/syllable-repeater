// AI-Generate
import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/empty_state.dart';
import '../../shared/error/error_messages.dart';
import '../../shared/tokens.dart';
import '../arrangement/arrangement_section.dart';
import '../import_analysis/analysis_controller.dart';
import '../pack_translate/lesson_session_controller.dart';
import '../practice/practice_player.dart';
import 'editor_controller.dart';
import 'waveform_node_range.dart';
import 'widgets/prosody_overlay.dart';
import 'widgets/waveform_canvas.dart';

/// 波形校正編輯器（frontend-design 功能點 3、REQ-02）。
///
/// 覆蓋：WaveformCanvas 波形＋邊界＋拖動、開區間驗證＋零交越吸附、
/// ⌘Z undo、單音節試聽，以及 S4 韻律疊圖。
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final FocusNode _focusNode = FocusNode();
  final ScrollController _outerScrollController = ScrollController();
  final ValueNotifier<int?> _playheadMs = ValueNotifier(null);
  Timer? _playheadTimer;
  bool _arrangementLocksOuterScroll = false;

  @override
  void dispose() {
    _playheadTimer?.cancel();
    _playheadMs.dispose();
    _outerScrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isMeta =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (isMeta && event.logicalKey == LogicalKeyboardKey.keyZ) {
      ref.read(editorControllerProvider.notifier).undo();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editorControllerProvider);
    // 監聽錯誤→SnackBar 顯示後 clearError（AT-02-02/05 通用回饋）
    ref.listen<EditorUiState>(editorControllerProvider, (previous, next) {
      final err = next.error;
      if (err != null && previous?.error != err) {
        final msg = ErrorMessages.fromCode(err.code).message;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(msg)));
        ref.read(editorControllerProvider.notifier).clearError();
      }
    });

    if (state.syllables.isEmpty) {
      return const EmptyState(
        icon: Icons.tune_outlined,
        title: '尚無可校正的分析結果',
        message: '請先在「匯入」完成一次分析，這裡會顯示波形＋音節邊界。',
      );
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceLg),
        child: SingleChildScrollView(
          key: const ValueKey('editor-outer-scroll'),
          controller: _outerScrollController,
          physics: _arrangementLocksOuterScroll
              ? const NeverScrollableScrollPhysics()
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(state: state),
              const SizedBox(height: AppTokens.spaceMd),
              _WaveformSection(state: state, playheadMs: _playheadMs),
              const SizedBox(height: AppTokens.spaceMd),
              _SyllableChipsRow(
                state: state,
                onTrackedPlayback: _trackPlayback,
              ),
              const SizedBox(height: AppTokens.spaceLg),
              ArrangementSection(
                onOuterScrollLockChanged: (locked) {
                  if (_arrangementLocksOuterScroll == locked) return;
                  setState(() => _arrangementLocksOuterScroll = locked);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _trackPlayback(
    TimeRange range,
    Future<void> Function() playback,
  ) async {
    _playheadTimer?.cancel();
    final stopwatch = Stopwatch()..start();
    _playheadMs.value = range.startMs;
    _playheadTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      _playheadMs.value = (range.startMs + stopwatch.elapsedMilliseconds).clamp(
        range.startMs,
        range.endMs,
      );
    });
    try {
      await playback();
    } finally {
      stopwatch.stop();
      _playheadTimer?.cancel();
      _playheadTimer = null;
      _playheadMs.value = null;
    }
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.state});

  final EditorUiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final needsReviewCount = state.syllables.where((s) => s.needsReview).length;
    final prosody = state.prosodyValue;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('段落校正', style: textTheme.headlineSmall),
              const SizedBox(height: AppTokens.spaceXs),
              Text(
                '共 ${state.syllables.length} 個音節；needsReview $needsReviewCount 個。'
                '${state.isDragging && state.draggingPreviewMs != null ? '　拖動中：${state.draggingPreviewMs} ms' : ''}'
                '${state.lastSnappedMs != null && !state.isDragging ? '　已吸附至 ${state.lastSnappedMs} ms' : ''}',
                style: textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        ProsodyOverlayControls(
          enabled: state.showProsodyOverlay,
          pitchAvailable: prosody?.pitchAvailable,
          onChanged: prosody == null
              ? null
              : (value) {
                  ref
                      .read(editorControllerProvider.notifier)
                      .setProsodyOverlay(value);
                },
        ),
        const SizedBox(width: AppTokens.spaceSm),
        TextButton.icon(
          onPressed: state.canUndo
              ? () => ref.read(editorControllerProvider.notifier).undo()
              : null,
          icon: const Icon(Icons.undo),
          label: const Text('撤銷 (⌘Z)'),
        ),
      ],
    );
  }
}

class _WaveformSection extends ConsumerWidget {
  const _WaveformSection({required this.state, required this.playheadMs});

  final EditorUiState state;
  final ValueListenable<int?> playheadMs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = ref.watch(analysisControllerProvider);
    final session = ref.watch(lessonSessionControllerProvider);
    final sessionActive =
        state.sourceLessonId != null &&
        state.sourceLessonId == session.lesson?.id;
    final peaks = sessionActive && session.waveformPeaks.isNotEmpty
        ? session.waveformPeaks
        : analysis.latestEvent?.waveformPeaks ?? const <WaveformPeak>[];
    final sessionPcm = sessionActive ? session.pcm : null;
    final pcmDurationMs =
        sessionPcm?.durationMs ?? analysis.latestEvent?.decodedPcm?.durationMs;
    final syllableSpanMs = state.syllables.isEmpty
        ? 0
        : state.syllables.last.endMs;
    final totalDurationMs =
        pcmDurationMs ?? (syllableSpanMs > 0 ? syllableSpanMs : 0);

    final controller = ref.read(editorControllerProvider.notifier);
    final pcm = sessionPcm ?? analysis.latestEvent?.decodedPcm;
    final prosody = state.showProsodyOverlay ? state.prosodyValue : null;
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: ValueListenableBuilder<int?>(
        valueListenable: playheadMs,
        builder: (context, currentPlayheadMs, _) => WaveformCanvas(
          peaks: peaks,
          syllables: state.syllables,
          totalDurationMs: totalDurationMs,
          draggingBoundaryIndex: state.draggingBoundaryIndex,
          draggingPreviewMs: state.draggingPreviewMs,
          playheadMs: currentPlayheadMs,
          prosody: prosody,
          selectedSyllableIndex: state.selectedSyllableIndex,
          selectedTimeRange: state.selectedTimeRange,
          onSelectSyllable: controller.selectSyllable,
          onTimeSelectionStart: controller.beginTimeSelection,
          onTimeSelectionUpdate: controller.updateTimeSelection,
          onTimeSelectionEnd: controller.endTimeSelection,
          onRemoveBoundary: controller.removeBoundary,
          onInsertBoundary: pcm == null
              ? null
              : (syllableIndex, atMs) =>
                    controller.insertBoundary(syllableIndex, atMs, pcm),
          onDragStart: controller.dragStart,
          onDragUpdate: controller.dragUpdate,
          onDragEnd: () => controller.dragEnd(pcm),
        ),
      ),
    );
  }
}

class _SyllableChipsRow extends ConsumerWidget {
  const _SyllableChipsRow({
    required this.state,
    required this.onTrackedPlayback,
  });

  final EditorUiState state;
  final Future<void> Function(TimeRange range, Future<void> Function() playback)
  onTrackedPlayback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prosody = state.prosodyValue;
    final controller = ref.read(editorControllerProvider.notifier);
    return Wrap(
      spacing: AppTokens.spaceSm,
      runSpacing: AppTokens.spaceSm,
      children: [
        for (var i = 0; i < state.syllables.length; i++)
          _SyllableChip(
            label: state.syllables[i].text,
            index: i,
            selected: _overlapsSelection(state.syllables[i]),
            needsReview: state.syllables[i].needsReview,
            invalidProsody: _invalidProsodyAt(prosody, i),
            onSelect: () => controller.selectSyllable(i),
            onEdit: (text) => controller.updateSyllableText(i, text),
            onTap: () {
              final session = ref.read(lessonSessionControllerProvider);
              final sessionActive =
                  state.sourceLessonId != null &&
                  state.sourceLessonId == session.lesson?.id;
              final pcm = sessionActive
                  ? session.pcm
                  : ref
                        .read(analysisControllerProvider)
                        .latestEvent
                        ?.decodedPcm;
              if (pcm == null) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(const SnackBar(content: Text('尚無可播放的原音 PCM')));
                return;
              }
              unawaited(
                _playSingleSyllable(context, ref, state.syllables, i, pcm),
              );
            },
          ),
      ],
    );
  }

  bool _overlapsSelection(Syllable syllable) {
    final range = state.selectedTimeRange;
    if (range == null) return false;
    return syllable.startMs < range.endMs && syllable.endMs > range.startMs;
  }

  Future<void> _playSingleSyllable(
    BuildContext context,
    WidgetRef ref,
    List<Syllable> syllables,
    int syllableIndex,
    Pcm pcm,
  ) async {
    try {
      final syllable = syllables[syllableIndex];
      final range = waveformNodeRange(
        syllables: syllables,
        syllableIndex: syllableIndex,
        totalDurationMs: pcm.durationMs,
      );
      final step = PracticeStep(
        index: syllableIndex + 1,
        syllables: [syllable],
        sourceRanges: [range],
        totalDurationMs: range.durationMs,
      );
      await onTrackedPlayback(
        range,
        () => ref.read(practicePlayerProvider).playStep(step, pcm, repeatN: 1),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('試聽失敗：$error')));
    }
  }

  bool _invalidProsodyAt(Prosody? prosody, int index) {
    if (prosody == null) return false;
    final rhythmInvalid =
        index < prosody.rhythm.length && prosody.rhythm[index].isNaN;
    final stressInvalid =
        index < prosody.stress.length && prosody.stress[index].isNaN;
    return rhythmInvalid || stressInvalid;
  }
}

class _SyllableChip extends StatefulWidget {
  const _SyllableChip({
    required this.label,
    required this.index,
    required this.selected,
    required this.needsReview,
    required this.invalidProsody,
    required this.onSelect,
    required this.onEdit,
    required this.onTap,
  });

  final String label;
  final int index;
  final bool selected;
  final bool needsReview;
  final bool invalidProsody;
  final VoidCallback onSelect;
  final ValueChanged<String> onEdit;
  final VoidCallback onTap;

  @override
  State<_SyllableChip> createState() => _SyllableChipState();
}

class _SyllableChipState extends State<_SyllableChip> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  var _editing = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.label);
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant _SyllableChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.label != widget.label) {
      _textController.value = TextEditingValue(
        text: widget.label,
        selection: TextSelection.collapsed(offset: widget.label.length),
      );
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _textController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus && _editing) _finishEditing();
  }

  void _startEditing() {
    if (_editing) return;
    widget.onSelect();
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_editing) return;
      _focusNode.requestFocus();
      _textController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _textController.text.length,
      );
    });
  }

  void _finishEditing() {
    if (!_editing) return;
    final text = _textController.text;
    setState(() => _editing = false);
    widget.onEdit(text);
  }

  void _handleTap() {
    if (_editing) return;
    widget.onSelect();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = widget.selected
        ? AppTokens.selectedHighlight
        : widget.invalidProsody
        ? colorScheme.surfaceContainerHighest
        : widget.needsReview
        ? AppTokens.needsReview
        : colorScheme.primaryContainer;
    final foreground = widget.selected
        ? Colors.black
        : widget.invalidProsody
        ? colorScheme.onSurfaceVariant
        : widget.needsReview
        ? Colors.black
        : colorScheme.onPrimaryContainer;
    final chip = _editing
        ? ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 72, maxWidth: 180),
            child: TextField(
              key: ValueKey('syllable-text-field-${widget.index + 1}'),
              controller: _textController,
              focusNode: _focusNode,
              autofocus: true,
              textAlign: TextAlign.center,
              maxLines: 1,
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: AppTokens.spaceSm,
                  vertical: AppTokens.spaceSm,
                ),
              ),
              onTap: widget.onSelect,
              onSubmitted: (_) => _finishEditing(),
            ),
          )
        : InkWell(
            onTap: _handleTap,
            onDoubleTap: _startEditing,
            borderRadius: BorderRadius.circular(AppTokens.radius),
            child: Container(
              key: ValueKey('syllable-chip-${widget.index + 1}'),
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceMd,
                vertical: AppTokens.spaceSm,
              ),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(AppTokens.radius),
              ),
              child: Text(
                widget.label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        chip,
        const SizedBox(height: AppTokens.spaceXs),
        Text(
          '${widget.index + 1}',
          key: ValueKey('syllable-index-${widget.index + 1}'),
          style: TextStyle(
            color: widget.selected
                ? Colors.black
                : colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
