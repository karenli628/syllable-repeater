// AI-Generate
import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../export/export_dialog.dart';
import '../editor/editor_controller.dart';
import '../../shared/empty_state.dart';
import '../../shared/error/error_messages.dart';
import '../../shared/player/player_bar.dart';
import '../../shared/tokens.dart';
import '../pack_translate/lesson_session_controller.dart';
import 'practice_controller.dart';
import 'widgets/record_panel.dart';
import 'widgets/settle_bar.dart';
import '../import_analysis/analysis_controller.dart';

class PracticeScreen extends ConsumerWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(practiceControllerProvider);
    ref.listen<PracticeUiState>(practiceControllerProvider, (previous, next) {
      final err = next.error;
      if (err != null && previous?.error != err) {
        final message = ErrorMessages.fromCode(err.code).message;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
        ref.read(practiceControllerProvider.notifier).clearError();
      }
    });

    if (state.steps.isEmpty) {
      return const EmptyState(
        icon: Icons.play_circle_outline,
        title: '尚無練習步驟',
        message: '完成匯入分析並進入校正後，這裡會顯示句尾疊加步驟。',
      );
    }

    final currentStep = state.currentStep!;
    final editor = ref.watch(editorControllerProvider);
    final session = ref.watch(lessonSessionControllerProvider);
    final practiceGroup = _practiceGroupFor(
      ref.watch(analysisControllerProvider),
      currentStep,
      lesson: editor.sourceLessonId == session.lesson?.id
          ? session.lesson
          : null,
    );
    return Padding(
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(state: state),
            const SizedBox(height: AppTokens.spaceMd),
            _StepNavigator(state: state),
            const SizedBox(height: AppTokens.spaceMd),
            _PracticePlayerBar(state: state),
            const SizedBox(height: AppTokens.spaceMd),
            RecordPanel(state: state),
            const SizedBox(height: AppTokens.spaceMd),
            SettleBar(groupId: practiceGroup.id, group: practiceGroup),
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.state});

  final PracticeUiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final controller = ref.read(practiceControllerProvider.notifier);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('句尾疊加練習', style: textTheme.headlineSmall),
              const SizedBox(height: AppTokens.spaceXs),
              Text(
                '共 ${state.steps.length} 步；目前第 ${state.currentIndex + 1} 步。',
                style: textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: AppTokens.spaceMd),
          child: FilledButton.icon(
            onPressed: state.decodedPcm == null
                ? null
                : () => unawaited(
                    showPracticeExportDialog(
                      context,
                      steps: state.steps,
                      originalPcm: state.decodedPcm!,
                    ),
                  ),
            icon: const Icon(Icons.ios_share_outlined),
            label: const Text('匯出'),
          ),
        ),
        IconButton.outlined(
          tooltip: '重複次數 -1',
          onPressed: state.repeatN > PracticeEngine.minRepeatN
              ? () => controller.setRepeatN(state.repeatN - 1)
              : null,
          icon: const Icon(Icons.remove),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceSm),
          child: Text('x${state.repeatN}', style: textTheme.titleMedium),
        ),
        IconButton.outlined(
          tooltip: '重複次數 +1',
          onPressed: state.repeatN < PracticeEngine.maxRepeatN
              ? () => controller.setRepeatN(state.repeatN + 1)
              : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _StepNavigator extends ConsumerWidget {
  const _StepNavigator({required this.state});

  final PracticeUiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(practiceControllerProvider.notifier);
    return Wrap(
      spacing: AppTokens.spaceSm,
      runSpacing: AppTokens.spaceSm,
      children: [
        for (var i = 0; i < state.steps.length; i++)
          ChoiceChip(
            label: Text('#${i + 1} ${_stepText(state.steps[i])}'),
            selected: i == state.currentIndex,
            onSelected: (_) => unawaited(controller.selectStep(i)),
          ),
      ],
    );
  }
}

class _PracticePlayerBar extends ConsumerWidget {
  const _PracticePlayerBar({required this.state});

  final PracticeUiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = state.currentStep!;
    final controller = ref.read(practiceControllerProvider.notifier);
    return PlayerBar(
      title: '第 ${step.index} 步：${_stepText(step)}',
      subtitle: '重複 ${state.repeatN} 次 · ${step.totalDurationMs} ms',
      state: switch (state.playStatus) {
        PracticePlayStatus.idle => PlayerBarState.idle,
        PracticePlayStatus.loading => PlayerBarState.loading,
        PracticePlayStatus.playing => PlayerBarState.playing,
      },
      onPlay: state.canPlay ? () => unawaited(controller.play()) : null,
      onStop: () => unawaited(controller.stop()),
    );
  }
}

String _stepText(PracticeStep step) =>
    step.syllables.map((s) => s.text).join(' ');

PracticeGroup _practiceGroupFor(
  AnalysisUiState analysis,
  PracticeStep step, {
  Lesson? lesson,
}) {
  final title =
      lesson?.title ??
      _lessonTitle(
        analysis.selectedAudioPath ?? analysis.result?.source ?? 'lesson',
      );
  final lessonId = lesson?.id ?? _lessonId(title);
  return PracticeGroup(
    id: '$lessonId-step-${step.index}',
    profileId: 'profile-local',
    courseId: 'course-local',
    lessonId: lessonId,
    name: '第 ${step.index} 步',
    stepRange: StepRange(startStepIndex: step.index, endStepIndex: step.index),
    updatedAt: DateTime.now().toUtc(),
  );
}

String _lessonTitle(String source) {
  final fileName = source.replaceAll('\\', '/').split('/').last;
  final dot = fileName.lastIndexOf('.');
  final stem = dot <= 0 ? fileName : fileName.substring(0, dot);
  return stem.trim().isEmpty ? 'Untitled Lesson' : stem;
}

String _lessonId(String title) {
  final normalized = title
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return normalized.isEmpty ? 'untitled-lesson' : normalized;
}
