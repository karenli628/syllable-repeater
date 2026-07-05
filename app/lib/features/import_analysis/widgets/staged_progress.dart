// AI-Generate
import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/error/error_messages.dart';
import '../../../shared/navigation.dart';
import '../../../shared/tokens.dart';
import '../analysis_controller.dart';

class StagedProgress extends ConsumerWidget {
  const StagedProgress({super.key, required this.state});

  final AnalysisUiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppTokens.radius),
      ),
      child: _buildBody(context, ref),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    if (state.status == AnalysisRunStatus.failed && state.error != null) {
      return _ErrorProgress(
        error: state.error!,
        canRetryStage: state.canRetryStage,
        onRetryStage: () => unawaited(
          ref.read(analysisControllerProvider.notifier).retryStage(),
        ),
      );
    }

    if (state.status == AnalysisRunStatus.done && state.result != null) {
      return _DoneProgress(
        result: state.result!,
        onOpenEditor: () {
          ref
              .read(appShellSelectedIndexProvider.notifier)
              .select(AppSection.editor.sectionIndex);
        },
      );
    }

    final event = state.latestEvent;
    final label = event == null ? '等待音檔' : _stageLabel(event.stage);
    final progress = event?.progress ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              state.isRunning ? Icons.autorenew : Icons.pending_outlined,
              size: 20,
            ),
            const SizedBox(width: AppTokens.spaceSm),
            Expanded(child: Text(label)),
            Text('${(progress * 100).round()}%'),
          ],
        ),
        const SizedBox(height: AppTokens.spaceSm),
        LinearProgressIndicator(value: state.isRunning ? progress : null),
      ],
    );
  }

  String _stageLabel(AnalysisStage stage) {
    return switch (stage) {
      AnalysisStage.decoding => '解碼中',
      AnalysisStage.separating => '分離人聲中',
      AnalysisStage.transcribing => '辨識字稿中',
      AnalysisStage.syllabifying => '切分音節中',
      AnalysisStage.done => '分析完成',
      AnalysisStage.failed => '分析失敗',
    };
  }
}

class _ErrorProgress extends StatelessWidget {
  const _ErrorProgress({
    required this.error,
    required this.canRetryStage,
    required this.onRetryStage,
  });

  final DomainException error;
  final bool canRetryStage;
  final VoidCallback onRetryStage;

  @override
  Widget build(BuildContext context) {
    final presentation = ErrorMessages.fromCode(error.code);
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(presentation.icon, color: colorScheme.error),
        const SizedBox(width: AppTokens.spaceSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                presentation.title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppTokens.spaceXs),
              Text(presentation.message),
              if (canRetryStage)
                Padding(
                  padding: const EdgeInsets.only(top: AppTokens.spaceSm),
                  child: TextButton.icon(
                    onPressed: onRetryStage,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重試此階段'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DoneProgress extends StatelessWidget {
  const _DoneProgress({required this.result, required this.onOpenEditor});

  final AlignmentResult result;
  final VoidCallback onOpenEditor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline, color: AppTokens.success),
        const SizedBox(width: AppTokens.spaceSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '分析完成',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTokens.success,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppTokens.spaceXs),
              Text(
                '${result.syllables.length} 個音節，信心 ${(result.confidence * 100).round()}%',
              ),
              if (result.needsReview)
                Padding(
                  padding: const EdgeInsets.only(top: AppTokens.spaceXs),
                  child: Text(
                    '有音節需要校正',
                    style: TextStyle(color: colorScheme.tertiary),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: AppTokens.spaceSm),
                child: FilledButton.icon(
                  onPressed: onOpenEditor,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('進入編輯器'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
