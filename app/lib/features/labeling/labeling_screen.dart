// AI-Generate
import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/error/error_messages.dart';
import '../../shared/navigation.dart';
import '../../shared/responsive_layout.dart';
import '../../shared/tokens.dart';
import 'labeling_controller.dart';
import 'widgets/full_track_waveform.dart';
import 'widgets/segment_list.dart';

/// 段落標籤頁骨架（frontend-design.md 功能點 10、REQ-11）。
///
/// 提供單檔匯入、階段進度、Domain session、標籤線編輯與 `.abolabel` dirty 攔截。
class LabelingScreen extends ConsumerStatefulWidget {
  const LabelingScreen({super.key});

  @override
  ConsumerState<LabelingScreen> createState() => _LabelingScreenState();
}

class _LabelingScreenState extends ConsumerState<LabelingScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(labelingControllerProvider);
    final controller = ref.read(labelingControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              state: state,
              onSave: state.isReady
                  ? () => unawaited(_saveCurrentLabel())
                  : null,
            ),
            const SizedBox(height: AppTokens.spaceMd),
            _ImportDropZone(
              state: state,
              onDropped: (path) => unawaited(_requestOpen(path)),
              onPick: () => unawaited(_pickAudio()),
            ),
            const SizedBox(height: AppTokens.spaceMd),
            _LabelingProgress(state: state),
            if (state.error != null) ...[
              const SizedBox(height: AppTokens.spaceMd),
              _ErrorBanner(error: state.error!),
            ],
            if (state.warning != null) ...[
              const SizedBox(height: AppTokens.spaceMd),
              _WarningBanner(warning: state.warning!),
            ],
            const SizedBox(height: AppTokens.spaceMd),
            ResponsiveTwoPane(
              primary: _TrackPreview(
                state: state,
                onSelect: controller.selectSegment,
                onDragStart: controller.dragStart,
                onDragUpdate: controller.dragUpdate,
                onDragEnd: controller.dragEnd,
                onInsertBoundary: controller.insertBoundary,
                onRemoveBoundary: controller.removeBoundary,
              ),
              secondary: _SessionPreview(
                state: state,
                onSelect: controller.selectSegment,
                onPreview: controller.previewSegment,
                onStopPreview: controller.stopPreview,
                onRemoveBoundary: controller.removeBoundary,
                onDispositionChanged: controller.setSegmentDisposition,
                onHandoff: () {
                  if (controller.handoffSelectedSegment()) {
                    ref
                        .read(appShellSelectedIndexProvider.notifier)
                        .select(AppSection.importAnalysis.sectionIndex);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAudio() async {
    final path = await ref.read(labelingFilePickerProvider).pickAudioPath();
    if (mounted && path != null) {
      await _requestOpen(path);
    }
  }

  Future<void> _requestOpen(String path) async {
    final controller = ref.read(labelingControllerProvider.notifier);
    if (ref.read(labelingControllerProvider).dirty) {
      final choice = await _showDirtyDialog();
      if (!mounted || choice == _DirtyChoice.cancel) return;
      if (choice == _DirtyChoice.save && !await _saveCurrentLabel()) {
        return;
      }
    }

    await controller.openAudio(path);
    if (!mounted) return;
    await _maybePromptExistingLabel();
  }

  Future<bool> _saveCurrentLabel() async {
    final path = await ref.read(labelingFilePickerProvider).pickLabelSavePath();
    if (!mounted || path == null) return false;
    return ref.read(labelingControllerProvider.notifier).saveLabel(path);
  }

  Future<_DirtyChoice?> _showDirtyDialog() {
    return showDialog<_DirtyChoice>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('有未儲存的標籤'),
        content: const Text('目前音檔的標籤線或文字尚未儲存，要如何處理？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_DirtyChoice.cancel),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_DirtyChoice.discard),
            child: const Text('放棄並開啟'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_DirtyChoice.save),
            child: const Text('儲存後開啟'),
          ),
        ],
      ),
    );
  }

  Future<void> _maybePromptExistingLabel() async {
    final path = ref.read(labelingControllerProvider).existingLabelPath;
    if (!mounted || path == null) return;
    final shouldLoad = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('找到既有標籤'),
        content: Text('找到此音檔先前的標籤註記：$path\n是否載入？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('不載入'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('載入'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    final controller = ref.read(labelingControllerProvider.notifier);
    if (shouldLoad == true) {
      await controller.loadExistingLabel();
    } else {
      controller.dismissExistingLabel();
    }
  }
}

enum _DirtyChoice { save, discard, cancel }

class _Header extends StatelessWidget {
  const _Header({required this.state, this.onSave});

  final LabelingUiState state;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('段落標籤', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AppTokens.spaceXs),
              Text(
                state.audioPath == null
                    ? '匯入整段音檔後，先看見波形與自動切句結果。'
                    : _fileName(state.audioPath!),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: AppTokens.spaceSm,
          children: [
            FilledButton.icon(
              onPressed: state.isOpening ? null : onSave,
              icon: const Icon(Icons.save_outlined),
              label: const Text('儲存標籤'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ImportDropZone extends StatelessWidget {
  const _ImportDropZone({
    required this.state,
    required this.onDropped,
    required this.onPick,
  });

  final LabelingUiState state;
  final ValueChanged<String> onDropped;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DropTarget(
      enable: !state.isOpening,
      onDragDone: (details) {
        if (details.files.isNotEmpty) {
          onDropped(details.files.first.path);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTokens.spaceLg),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(AppTokens.radius),
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
        ),
        child: Row(
          children: [
            Icon(Icons.audio_file_outlined, color: colorScheme.primary),
            const SizedBox(width: AppTokens.spaceSm),
            const Expanded(child: Text('拖入 mp3、wav、m4a 或 flac；一次處理一個音檔。')),
            OutlinedButton(
              onPressed: state.isOpening ? null : onPick,
              child: const Text('瀏覽'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelingProgress extends StatelessWidget {
  const _LabelingProgress({required this.state});

  final LabelingUiState state;

  @override
  Widget build(BuildContext context) {
    final progress = state.progress;
    final (icon, label, value) = switch (state.status) {
      LabelingRunStatus.idle => (Icons.pending_outlined, '等待音檔', 0.0),
      LabelingRunStatus.opening => (
        Icons.autorenew,
        _progressLabel(progress?.stage),
        progress?.ratio,
      ),
      LabelingRunStatus.ready => (
        Icons.check_circle_outline,
        '標籤 session 已就緒',
        1.0,
      ),
      LabelingRunStatus.failed => (Icons.error_outline, '開啟失敗', null),
    };

    return Container(
      key: const ValueKey('labeling-real-progress'),
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppTokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: AppTokens.spaceSm),
              Expanded(child: Text(label)),
              if (value != null) Text('${(value * 100).round()}%'),
            ],
          ),
          const SizedBox(height: AppTokens.spaceSm),
          LinearProgressIndicator(value: value),
        ],
      ),
    );
  }

  String _progressLabel(LabelOpenStage? stage) => switch (stage) {
    null => '準備解碼／自動切句',
    LabelOpenStage.readingFingerprint => '讀取音檔指紋',
    LabelOpenStage.decoding => '解碼音檔',
    LabelOpenStage.separatingVocals => '分離人聲',
    LabelOpenStage.segmenting => '自動切句',
    LabelOpenStage.buildingWaveform => '建立波形',
    LabelOpenStage.completed => '完成解碼／自動切句',
  };
}

class _TrackPreview extends StatelessWidget {
  const _TrackPreview({
    required this.state,
    required this.onSelect,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onInsertBoundary,
    required this.onRemoveBoundary,
  });

  final LabelingUiState state;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onDragStart;
  final ValueChanged<int> onDragUpdate;
  final VoidCallback onDragEnd;
  final ValueChanged<int> onInsertBoundary;
  final ValueChanged<int> onRemoveBoundary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 260),
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppTokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('全檔波形預覽', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppTokens.spaceSm),
          FullTrackWaveform(
            peaks: state.peaks,
            segments: state.session?.segments ?? const [],
            totalDurationMs: state.session?.audioDurationMs ?? 0,
            selectedSegmentIndex: state.selectedSegmentIndex,
            draggingBoundaryIndex: state.draggingBoundaryIndex,
            draggingPreviewMs: state.draggingPreviewMs,
            playheadMs: state.playheadMs,
            onSelectSegment: onSelect,
            onDragStart: onDragStart,
            onDragUpdate: onDragUpdate,
            onDragEnd: onDragEnd,
            onInsertBoundary: onInsertBoundary,
            onRemoveBoundary: onRemoveBoundary,
          ),
        ],
      ),
    );
  }
}

class _SessionPreview extends StatelessWidget {
  const _SessionPreview({
    required this.state,
    required this.onSelect,
    required this.onPreview,
    required this.onStopPreview,
    required this.onRemoveBoundary,
    required this.onDispositionChanged,
    required this.onHandoff,
  });

  final LabelingUiState state;
  final ValueChanged<int?> onSelect;
  final ValueChanged<int> onPreview;
  final VoidCallback onStopPreview;
  final ValueChanged<int> onRemoveBoundary;
  final SegmentDispositionChanged onDispositionChanged;
  final VoidCallback onHandoff;

  @override
  Widget build(BuildContext context) {
    final session = state.session;
    if (session == null) {
      return _PanelMessage(
        icon: Icons.segment_outlined,
        title: '自動標籤結果',
        message: '完成匯入後，這裡會顯示段落數、語言與可選區段。',
      );
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 260),
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppTokens.radius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('自動標籤結果', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppTokens.spaceXs),
          Text(
            '${session.segments.length} 段 · ${session.language} · ${session.audioDurationMs} ms',
          ),
          const SizedBox(height: AppTokens.spaceSm),
          SegmentList(
            segments: session.segments,
            selectedSegmentIndex: state.selectedSegmentIndex,
            previewingSegmentIndex: state.previewingSegmentIndex,
            previewStatus: state.previewStatus,
            onSelect: onSelect,
            onPreview: onPreview,
            onStopPreview: onStopPreview,
            onRemoveBoundary: onRemoveBoundary,
            onDispositionChanged: onDispositionChanged,
          ),
          if (state.selectedSegmentIndex != null) ...[
            const SizedBox(height: AppTokens.spaceSm),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onHandoff,
                icon: const Icon(Icons.arrow_forward_outlined),
                label: const Text('送到單句分析'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PanelMessage extends StatelessWidget {
  const _PanelMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 260),
      padding: const EdgeInsets.all(AppTokens.spaceMd),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppTokens.radius),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(height: AppTokens.spaceSm),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppTokens.spaceXs),
          Text(message),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error});

  final DomainException error;

  @override
  Widget build(BuildContext context) {
    final presentation = ErrorMessages.fromCode(error.code);
    return ListTile(
      leading: Icon(
        presentation.icon,
        color: Theme.of(context).colorScheme.error,
      ),
      title: Text(presentation.title),
      subtitle: Text(presentation.message),
      tileColor: Theme.of(context).colorScheme.errorContainer,
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.warning});

  final LabelOpenWarning warning;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.warning_amber_outlined),
      title: const Text('自動切句提示'),
      subtitle: Text(warning.message),
      tileColor: Theme.of(context).colorScheme.tertiaryContainer,
    );
  }
}

String _fileName(String path) => path.split('/').last;
