// AI-Generate
import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/tokens.dart';
import '../practice_controller.dart';
import 'overlay_chart.dart';

class RecordPanel extends ConsumerWidget {
  const RecordPanel({super.key, required this.state});

  final PracticeUiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(practiceControllerProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mic_none_outlined, color: colorScheme.primary),
              const SizedBox(width: AppTokens.spaceSm),
              Expanded(
                child: Text(
                  '錄音比對',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              _RecordActions(
                state: state,
                onStart: () => unawaited(controller.startRecording()),
                onStop: () => unawaited(controller.stopRecording()),
                onCancel: () => unawaited(controller.cancelRecording()),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceSm),
          _RecordLevel(state: state),
          if (state.recordedPcm != null) ...[
            const SizedBox(height: AppTokens.spaceMd),
            Row(
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('recording-playback-toggle'),
                  onPressed:
                      state.recordedPlaybackStatus ==
                          PracticeRecordedPlaybackStatus.playing
                      ? () => unawaited(controller.stopRecordingPlayback())
                      : () => unawaited(controller.playRecording()),
                  icon: Icon(
                    state.recordedPlaybackStatus ==
                            PracticeRecordedPlaybackStatus.playing
                        ? Icons.stop
                        : Icons.play_arrow,
                  ),
                  label: Text(
                    state.recordedPlaybackStatus ==
                            PracticeRecordedPlaybackStatus.playing
                        ? '停止播放'
                        : '播放錄音',
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '刪除本次錄音比對',
                  onPressed: () => unawaited(controller.clearRecordingResult()),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ],
          if (state.comparison != null) ...[
            const SizedBox(height: AppTokens.spaceMd),
            Align(
              alignment: Alignment.centerLeft,
              child: _ComparisonSummary(result: state.comparison!),
            ),
            const SizedBox(height: AppTokens.spaceMd),
            OverlayChart(data: state.comparison!.overlayData),
          ],
        ],
      ),
    );
  }
}

class _RecordActions extends StatelessWidget {
  const _RecordActions({
    required this.state,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
  });

  final PracticeUiState state;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return switch (state.recordStatus) {
      PracticeRecordStatus.idle => Wrap(
        spacing: AppTokens.spaceSm,
        runSpacing: AppTokens.spaceSm,
        children: [
          FilledButton.icon(
            onPressed: state.canRecord ? onStart : null,
            icon: const Icon(Icons.mic),
            label: const Text('錄音'),
          ),
        ],
      ),
      PracticeRecordStatus.recording => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton.icon(
            onPressed: onStop,
            icon: const Icon(Icons.stop),
            label: const Text('停止'),
          ),
          const SizedBox(width: AppTokens.spaceSm),
          IconButton.outlined(
            tooltip: '丟棄錄音',
            onPressed: onCancel,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      PracticeRecordStatus.comparing => FilledButton.icon(
        onPressed: null,
        icon: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: const Text('比對中'),
      ),
    };
  }
}

class _RecordLevel extends StatelessWidget {
  const _RecordLevel({required this.state});

  final PracticeUiState state;

  @override
  Widget build(BuildContext context) {
    final isRecording = state.recordStatus == PracticeRecordStatus.recording;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                minHeight: 8,
                value: isRecording ? state.recordingLevel.clamp(0.0, 1.0) : 0,
              ),
            ),
            const SizedBox(width: AppTokens.spaceSm),
            SizedBox(
              width: 72,
              child: Text(
                isRecording ? '錄音中' : '待錄音',
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ComparisonSummary extends StatelessWidget {
  const _ComparisonSummary({required this.result});

  final ComparisonResult result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Wrap(
      spacing: AppTokens.spaceSm,
      runSpacing: AppTokens.spaceSm,
      children: [
        _MetricPill(
          label: '節奏差異',
          value: result.rhythmDelta.toStringAsFixed(2),
          style: textTheme.labelLarge,
        ),
        _MetricPill(
          label: '語調差異',
          value: result.intonationDelta.toStringAsFixed(2),
          style: textTheme.labelLarge,
        ),
        if (result.score != null)
          _MetricPill(
            label: '分數',
            value: result.score!.toStringAsFixed(0),
            style: textTheme.labelLarge,
          ),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    required this.style,
  });

  final String label;
  final String value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceSm,
          vertical: AppTokens.spaceXs,
        ),
        child: Text('$label $value', style: style),
      ),
    );
  }
}
