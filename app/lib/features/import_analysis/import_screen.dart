// AI-Generate
import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:domain/domain.dart' as domain;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/tokens.dart';
import 'analysis_controller.dart';
import 'widgets/staged_progress.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final TextEditingController _transcriptController = TextEditingController();

  static const XTypeGroup _audioTypeGroup = XTypeGroup(
    label: 'Audio',
    extensions: ['mp3', 'wav', 'm4a', 'flac'],
    uniformTypeIdentifiers: [
      'public.mp3',
      'com.microsoft.waveform-audio',
      'public.mpeg-4-audio',
      'org.xiph.flac',
    ],
  );

  @override
  void dispose() {
    _transcriptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analysisControllerProvider);
    final controller = ref.read(analysisControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(state: state),
          const SizedBox(height: AppTokens.spaceLg),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: _ImportPanel(
                    state: state,
                    transcriptController: _transcriptController,
                    onPickFile: () => _pickAudio(controller),
                    onDropped: (path) =>
                        unawaited(controller.selectAudioPath(path)),
                    onTranscriptChanged: controller.setTranscript,
                    onSeparateVocalsChanged: controller.setSeparateVocals,
                    onStart: () => unawaited(controller.start()),
                    onDraggingChanged: controller.setDragging,
                  ),
                ),
                const SizedBox(width: AppTokens.spaceLg),
                Expanded(flex: 4, child: _ResultPanel(state: state)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAudio(AnalysisController controller) async {
    final file = await openFile(
      acceptedTypeGroups: const [_audioTypeGroup],
      confirmButtonText: '選擇音檔',
    );
    if (file != null) {
      unawaited(controller.selectAudioPath(file.path));
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final AnalysisUiState state;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('匯入與分析', style: textTheme.headlineSmall),
              const SizedBox(height: AppTokens.spaceXs),
              Text('拖入或選擇一句金標準音檔，確認後顯示階段化分析進度。', style: textTheme.bodyMedium),
            ],
          ),
        ),
        if (state.isRunning)
          const Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: AppTokens.spaceSm),
              Text('分析中'),
            ],
          ),
      ],
    );
  }
}

class _ImportPanel extends StatelessWidget {
  const _ImportPanel({
    required this.state,
    required this.transcriptController,
    required this.onPickFile,
    required this.onDropped,
    required this.onTranscriptChanged,
    required this.onSeparateVocalsChanged,
    required this.onStart,
    required this.onDraggingChanged,
  });

  final AnalysisUiState state;
  final TextEditingController transcriptController;
  final VoidCallback onPickFile;
  final ValueChanged<String> onDropped;
  final ValueChanged<String> onTranscriptChanged;
  final ValueChanged<bool> onSeparateVocalsChanged;
  final VoidCallback onStart;
  final ValueChanged<bool> onDraggingChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropTarget(
          enable: !state.isRunning,
          onDragEntered: (_) => onDraggingChanged(true),
          onDragExited: (_) => onDraggingChanged(false),
          onDragDone: (details) {
            onDraggingChanged(false);
            if (details.files.isNotEmpty) {
              onDropped(details.files.first.path);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            height: 230,
            width: double.infinity,
            padding: const EdgeInsets.all(AppTokens.spaceLg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radius),
              border: Border.all(
                color: state.isDragging
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
                width: state.isDragging ? 2 : 1,
              ),
              color: state.isDragging
                  ? colorScheme.primaryContainer.withValues(alpha: 0.32)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.audio_file_outlined,
                  size: 44,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: AppTokens.spaceMd),
                Text(
                  state.selectedAudioPath == null
                      ? '拖入音檔'
                      : _fileName(state.selectedAudioPath!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppTokens.spaceSm),
                Text(
                  '支援 mp3、wav、m4a、flac；本次不做批次匯入。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: AppTokens.spaceMd),
                OutlinedButton.icon(
                  onPressed: state.isRunning ? null : onPickFile,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('選擇音檔'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTokens.spaceMd),
        TextField(
          controller: transcriptController,
          enabled: !state.isRunning,
          maxLines: 5,
          onChanged: onTranscriptChanged,
          decoration: const InputDecoration(
            labelText: '字稿（可留空）',
            hintText: '留空時會使用辨識結果；貼上字稿可讓後續校正更穩。',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: AppTokens.spaceMd),
        Row(
          children: [
            Checkbox(
              value: state.separateVocals,
              onChanged: state.isRunning
                  ? null
                  : (value) => onSeparateVocalsChanged(value ?? false),
            ),
            const Expanded(child: Text('先做人聲分離')),
            FilledButton.icon(
              onPressed: state.canStart ? onStart : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('開始分析'),
            ),
          ],
        ),
        const SizedBox(height: AppTokens.spaceMd),
        StagedProgress(state: state),
      ],
      ),
    );
  }

  String _fileName(String path) => path.split('/').last;
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.state});

  final AnalysisUiState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final result = state.result;

    return Container(
      height: double.infinity,
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppTokens.radius),
      ),
      child: result == null
          ? _WaitingResult(state: state)
          : _SyllablePreview(result: result),
    );
  }
}

class _WaitingResult extends StatelessWidget {
  const _WaitingResult({required this.state});

  final AnalysisUiState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('結果預覽', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppTokens.spaceSm),
        Text(
          state.selectedAudioPath == null
              ? '選擇音檔後，這裡會顯示音節切分結果。'
              : '音檔已就緒，按下開始分析後顯示 11 音節預覽。',
        ),
      ],
    );
  }
}

class _SyllablePreview extends StatelessWidget {
  const _SyllablePreview({required this.result});

  final domain.AlignmentResult result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('音節預覽', style: textTheme.titleMedium),
        const SizedBox(height: AppTokens.spaceXs),
        Text(
          result.source,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: AppTokens.spaceMd),
        Wrap(
          spacing: AppTokens.spaceSm,
          runSpacing: AppTokens.spaceSm,
          children: [
            for (final syllable in result.syllables)
              _SyllableChip(
                label: syllable.text,
                needsReview: syllable.needsReview,
              ),
          ],
        ),
      ],
    );
  }
}

class _SyllableChip extends StatelessWidget {
  const _SyllableChip({required this.label, required this.needsReview});

  final String label;
  final bool needsReview;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = needsReview
        ? AppTokens.needsReview
        : colorScheme.primaryContainer;
    final foregroundColor = needsReview
        ? Colors.black
        : colorScheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceMd,
        vertical: AppTokens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppTokens.radius),
      ),
      child: Text(
        label,
        style: TextStyle(color: foregroundColor, fontWeight: FontWeight.w700),
      ),
    );
  }
}
