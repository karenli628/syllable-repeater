// AI-Generate
import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/empty_state.dart';
import '../../shared/error/error_messages.dart';
import '../../shared/tokens.dart';
import '../import_analysis/analysis_controller.dart';
import '../pack_translate/lesson_session_controller.dart';
import '../practice/practice_player.dart';
import 'editor_controller.dart';
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

  @override
  void dispose() {
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
    final needsReviewCount = state.syllables.where((s) => s.needsReview).length;
    final prosody = state.prosodyValue;

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
  const _WaveformSection({required this.state});

  final EditorUiState state;

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
      child: WaveformCanvas(
        peaks: peaks,
        syllables: state.syllables,
        totalDurationMs: totalDurationMs,
        draggingBoundaryIndex: state.draggingBoundaryIndex,
        draggingPreviewMs: state.draggingPreviewMs,
        prosody: prosody,
        onDragStart: controller.dragStart,
        onDragUpdate: controller.dragUpdate,
        onDragEnd: () => controller.dragEnd(pcm),
      ),
    );
  }
}

class _SyllableChipsRow extends ConsumerWidget {
  const _SyllableChipsRow({required this.state});

  final EditorUiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prosody = state.prosodyValue;
    return Wrap(
      spacing: AppTokens.spaceSm,
      runSpacing: AppTokens.spaceSm,
      children: [
        for (var i = 0; i < state.syllables.length; i++)
          _SyllableChip(
            label: state.syllables[i].text,
            needsReview: state.syllables[i].needsReview,
            invalidProsody: _invalidProsodyAt(prosody, i),
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
                _playSingleSyllable(context, ref, state.syllables[i], pcm),
              );
            },
          ),
      ],
    );
  }

  Future<void> _playSingleSyllable(
    BuildContext context,
    WidgetRef ref,
    Syllable syllable,
    Pcm pcm,
  ) async {
    try {
      final step = PracticeEngine().singleSyllableStep(syllable);
      await ref.read(practicePlayerProvider).playStep(step, pcm, repeatN: 1);
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

class _SyllableChip extends StatelessWidget {
  const _SyllableChip({
    required this.label,
    required this.needsReview,
    required this.invalidProsody,
    required this.onTap,
  });

  final String label;
  final bool needsReview;
  final bool invalidProsody;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = invalidProsody
        ? colorScheme.surfaceContainerHighest
        : needsReview
        ? AppTokens.needsReview
        : colorScheme.primaryContainer;
    final foreground = invalidProsody
        ? colorScheme.onSurfaceVariant
        : needsReview
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
