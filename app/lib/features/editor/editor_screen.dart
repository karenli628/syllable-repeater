// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/empty_state.dart';
import '../../shared/error/error_messages.dart';
import '../../shared/tokens.dart';
import '../import_analysis/analysis_controller.dart';
import 'editor_controller.dart';
import 'widgets/waveform_canvas.dart';

/// 波形校正編輯器（frontend-design 功能點 3、REQ-02）。
///
/// 本輪（S1b）覆蓋：WaveformCanvas 波形＋邊界＋拖動、開區間驗證＋零交越吸附、
/// ⌘Z undo、單音節試聽 stub（S2 renderStep 接入後恢復）。韻律疊圖屬 S4，
/// 本輪 Non-scope。
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final isMeta = HardwareKeyboard.instance.isMetaPressed ||
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(state: state),
            const SizedBox(height: AppTokens.spaceMd),
            _WaveformSection(state: state),
            const SizedBox(height: AppTokens.spaceMd),
            _SyllableChipsRow(state: state),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.state});

  final EditorUiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final needsReviewCount =
        state.syllables.where((s) => s.needsReview).length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('音節校正', style: textTheme.headlineSmall),
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
  const _WaveformSection({required this.state});

  final EditorUiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysis = ref.watch(analysisControllerProvider);
    final peaks = analysis.latestEvent?.waveformPeaks ?? const <WaveformPeak>[];
    final pcmDurationMs = analysis.latestEvent?.decodedPcm?.durationMs;
    final syllableSpanMs = state.syllables.isEmpty
        ? 0
        : state.syllables.last.endMs;
    final totalDurationMs =
        pcmDurationMs ?? (syllableSpanMs > 0 ? syllableSpanMs : 0);

    final controller = ref.read(editorControllerProvider.notifier);
    final pcm = analysis.latestEvent?.decodedPcm;
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: WaveformCanvas(
        peaks: peaks,
        syllables: state.syllables,
        totalDurationMs: totalDurationMs,
        draggingBoundaryIndex: state.draggingBoundaryIndex,
        draggingPreviewMs: state.draggingPreviewMs,
        onDragStart: controller.dragStart,
        onDragUpdate: controller.dragUpdate,
        onDragEnd: () => controller.dragEnd(pcm),
      ),
    );
  }
}

class _SyllableChipsRow extends StatelessWidget {
  const _SyllableChipsRow({required this.state});

  final EditorUiState state;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppTokens.spaceSm,
      runSpacing: AppTokens.spaceSm,
      children: [
        for (final syllable in state.syllables)
          _SyllableChip(
            label: syllable.text,
            needsReview: syllable.needsReview,
            onTap: () {
              // 試聽 stub：S2 PracticeEngine.renderStep 接入前只給提示。
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(const SnackBar(
                  content: Text('單音節試聽將於 S2（PracticeEngine.renderStep）上線'),
                ));
            },
          ),
      ],
    );
  }
}

class _SyllableChip extends StatelessWidget {
  const _SyllableChip({
    required this.label,
    required this.needsReview,
    required this.onTap,
  });

  final String label;
  final bool needsReview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = needsReview
        ? AppTokens.needsReview
        : colorScheme.primaryContainer;
    final foreground = needsReview
        ? Colors.black
        : colorScheme.onPrimaryContainer;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTokens.radius),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceMd,
          vertical: AppTokens.spaceSm,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppTokens.radius),
        ),
        child: Text(
          label,
          style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
