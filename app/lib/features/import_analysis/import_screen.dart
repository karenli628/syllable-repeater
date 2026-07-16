// AI-Generate
import 'dart:async';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:domain/domain.dart' as domain;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/responsive_layout.dart';
import '../../shared/pending_segment.dart';
import '../../shared/tokens.dart';
import '../library/lesson_pack_service.dart';
import '../library/library_screen.dart' show libraryLessonEntriesProvider;
import '../pack_translate/lesson_session_controller.dart';
import '../progress/ai_settings_service.dart';
import 'analysis_controller.dart';
import 'widgets/staged_progress.dart';

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final TextEditingController _transcriptController = TextEditingController();
  final TextEditingController _translationController = TextEditingController();
  String? _pendingConsumeKey;
  String? _loadedDraftKey;
  bool _translating = false;
  bool _savingLesson = false;
  String? _translationMessage;
  String? _translationError;
  String? _lessonMessage;
  String? _lessonError;

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
    _translationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analysisControllerProvider);
    final pending = ref.watch(pendingSegmentProvider);
    final lessonSession = ref.watch(lessonSessionControllerProvider);
    final controller = ref.read(analysisControllerProvider.notifier);
    if (_transcriptController.text != state.transcript) {
      _transcriptController.value = TextEditingValue(
        text: state.transcript,
        selection: TextSelection.collapsed(offset: state.transcript.length),
      );
    }
    _syncTranslation(state, lessonSession.lesson);
    _schedulePendingConsume(pending);

    final hasDraft = _hasDraft(state, lessonSession);

    return CallbackShortcuts(
      bindings: const {},
      child: Focus(
        autofocus: true,
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceLg),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(state: state),
                const SizedBox(height: AppTokens.spaceLg),
                ResponsiveTwoPane(
                  primary: _ImportPanel(
                    state: state,
                    transcriptController: _transcriptController,
                    translationController: _translationController,
                    hasDraft: hasDraft,
                    translating: _translating,
                    savingLesson: _savingLesson,
                    translationMessage: _translationMessage,
                    translationError: _translationError,
                    lessonMessage: _lessonMessage,
                    lessonError: _lessonError,
                    onPickFile: () => _pickAudio(controller),
                    onDropped: (path) =>
                        unawaited(controller.selectAudioPath(path)),
                    onTranscriptChanged: controller.setTranscript,
                    onTranslationChanged: () => setState(() {
                      _translationMessage = null;
                      _lessonMessage = null;
                      _lessonError = null;
                    }),
                    onTranslate: () =>
                        unawaited(_translate(state, lessonSession.lesson)),
                    onSaveLesson: () =>
                        unawaited(_saveLesson(state, lessonSession)),
                    onSeparateVocalsChanged: controller.setSeparateVocals,
                    onStart: () => unawaited(controller.start()),
                    onDraggingChanged: controller.setDragging,
                  ),
                  secondary: _ResultPanel(state: state),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _syncTranslation(AnalysisUiState state, domain.Lesson? lesson) {
    final key = lesson?.id ?? state.selectedAudioPath;
    if (_loadedDraftKey == key) return;
    _loadedDraftKey = key;
    _translationController.text = lesson == null
        ? ''
        : (_preferredTranslation(lesson) ?? '');
    _translationMessage = null;
    _translationError = null;
  }

  bool _hasDraft(AnalysisUiState state, LessonSessionState session) =>
      session.hasLesson ||
      (state.result != null && state.latestEvent?.decodedPcm != null);

  Future<void> _translate(AnalysisUiState state, domain.Lesson? lesson) async {
    if (_translating) return;
    final sourceWords = state.result?.words ?? lesson?.words ?? const [];
    final text = state.transcript.trim().isNotEmpty
        ? state.transcript.trim()
        : sourceWords.map((word) => word.text).join(' ').trim();
    if (text.isEmpty) return;
    setState(() {
      _translating = true;
      _translationMessage = null;
      _translationError = null;
    });
    try {
      final translation = await ref
          .read(aiSettingsServiceProvider)
          .translate(text, 'zh-TW');
      ref
          .read(analysisControllerProvider.notifier)
          .setAiTranslation(translation);
      if (!mounted) return;
      setState(() => _translationMessage = 'AI 譯文已更新；手動譯文會優先保存');
    } catch (error) {
      if (!mounted) return;
      setState(() => _translationError = _describeError(error));
    } finally {
      if (mounted) setState(() => _translating = false);
    }
  }

  Future<void> _saveLesson(
    AnalysisUiState state,
    LessonSessionState session,
  ) async {
    if (_savingLesson || !_hasDraft(state, session)) return;
    final path = await ref.read(lessonPackFilePickerProvider).pickSavePath();
    if (!mounted || path == null) return;
    setState(() {
      _savingLesson = true;
      _lessonMessage = null;
      _lessonError = null;
    });
    try {
      final lesson = ref.read(currentLessonDraftBuilderProvider)(
        _translationController.text,
      );
      final hydratedLesson = lesson.withContentHash();
      final writtenPath = await ref
          .read(lessonPackServiceProvider)
          .save(hydratedLesson, path);
      await ref
          .read(lessonSessionControllerProvider.notifier)
          .hydrateLesson(hydratedLesson, sourcePath: writtenPath);
      ref.invalidate(libraryLessonEntriesProvider);
      if (!mounted) return;
      setState(() => _lessonMessage = '已儲存：$writtenPath');
    } catch (error) {
      if (!mounted) return;
      setState(() => _lessonError = _describeError(error));
    } finally {
      if (mounted) setState(() => _savingLesson = false);
    }
  }

  String _describeError(Object error) =>
      error is domain.DomainException ? error.message : '$error';

  void _schedulePendingConsume(PendingSegment? pending) {
    if (pending == null || _pendingConsumeKey == pending.segmentId) return;
    _pendingConsumeKey = pending.segmentId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(analysisControllerProvider.notifier).consumePendingSegment();
      _pendingConsumeKey = null;
    });
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
    required this.translationController,
    required this.hasDraft,
    required this.translating,
    required this.savingLesson,
    required this.translationMessage,
    required this.translationError,
    required this.lessonMessage,
    required this.lessonError,
    required this.onPickFile,
    required this.onDropped,
    required this.onTranscriptChanged,
    required this.onTranslationChanged,
    required this.onTranslate,
    required this.onSaveLesson,
    required this.onSeparateVocalsChanged,
    required this.onStart,
    required this.onDraggingChanged,
  });

  final AnalysisUiState state;
  final TextEditingController transcriptController;
  final TextEditingController translationController;
  final bool hasDraft;
  final bool translating;
  final bool savingLesson;
  final String? translationMessage;
  final String? translationError;
  final String? lessonMessage;
  final String? lessonError;
  final VoidCallback onPickFile;
  final ValueChanged<String> onDropped;
  final ValueChanged<String> onTranscriptChanged;
  final VoidCallback onTranslationChanged;
  final VoidCallback onTranslate;
  final VoidCallback onSaveLesson;
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
                    : colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.32,
                      ),
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
          if (!state.hasAudio) ...[
            Text(
              '請先匯入音檔，或到「段落標籤」選擇一個區段',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppTokens.spaceSm),
          ],
          if (state.pendingSegment != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTokens.spaceSm),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.secondaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(AppTokens.radius),
              ),
              child: Text(
                state.pendingSegment!.segmentIndex == null
                    ? '來自段落標籤：${state.pendingSegment!.segmentId}'
                    : '來自段落標籤：第 ${state.pendingSegment!.segmentIndex! + 1} 段',
              ),
            ),
            const SizedBox(height: AppTokens.spaceSm),
          ],
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
          _TranslationSection(
            controller: translationController,
            hasDraft: hasDraft,
            translating: translating,
            savingLesson: savingLesson,
            aiTranslation: state.aiTranslation,
            translationMessage: translationMessage,
            translationError: translationError,
            lessonMessage: lessonMessage,
            lessonError: lessonError,
            onChanged: onTranslationChanged,
            onTranslate: onTranslate,
            onSaveLesson: onSaveLesson,
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
              const Text('先做人聲分離'),
              const SizedBox(width: AppTokens.spaceSm),
              // demucs 未就緒＋使用者勾了 → 顯示降級提示（task-split 3.8 S1c-6）
              Consumer(
                builder: (context, ref, _) {
                  final ready = ref.watch(demucsReadyProvider);
                  if (ready || !state.separateVocals) {
                    return const SizedBox.shrink();
                  }
                  return Tooltip(
                    message: 'demucs 未就緒；勾選仍會分析，但將降級使用原音（backend-design M4）',
                    child: Icon(
                      Icons.info_outline,
                      size: 18,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                  );
                },
              ),
              const Spacer(),
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

class _TranslationSection extends StatelessWidget {
  const _TranslationSection({
    required this.controller,
    required this.hasDraft,
    required this.translating,
    required this.savingLesson,
    required this.aiTranslation,
    required this.translationMessage,
    required this.translationError,
    required this.lessonMessage,
    required this.lessonError,
    required this.onChanged,
    required this.onTranslate,
    required this.onSaveLesson,
  });

  final TextEditingController controller;
  final bool hasDraft;
  final bool translating;
  final bool savingLesson;
  final domain.Translation? aiTranslation;
  final String? translationMessage;
  final String? translationError;
  final String? lessonMessage;
  final String? lessonError;
  final VoidCallback onChanged;
  final VoidCallback onTranslate;
  final VoidCallback onSaveLesson;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('譯文', style: textTheme.titleMedium),
            const SizedBox(height: AppTokens.spaceSm),
            TextField(
              controller: controller,
              enabled: hasDraft && !savingLesson,
              maxLines: 2,
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                labelText: '手動譯文',
                hintText: '可輸入中文譯文；手動譯文會優先於 AI 譯文。',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppTokens.spaceSm),
            Wrap(
              spacing: AppTokens.spaceSm,
              runSpacing: AppTokens.spaceSm,
              children: [
                OutlinedButton.icon(
                  onPressed: !hasDraft || translating ? null : onTranslate,
                  icon: translating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.translate_outlined),
                  label: const Text('AI 翻譯'),
                ),
              ],
            ),
            if (aiTranslation != null) ...[
              const SizedBox(height: AppTokens.spaceSm),
              Text('AI 譯文預覽：${aiTranslation!.text}'),
            ],
            if (translationMessage != null) ...[
              const SizedBox(height: AppTokens.spaceXs),
              Text(translationMessage!),
            ],
            if (translationError != null) ...[
              const SizedBox(height: AppTokens.spaceXs),
              Text(
                translationError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (lessonMessage != null) ...[
              const SizedBox(height: AppTokens.spaceSm),
              Text(lessonMessage!),
            ],
            if (lessonError != null) ...[
              const SizedBox(height: AppTokens.spaceSm),
              Text(
                lessonError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.state});

  final AnalysisUiState state;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final result = state.result;

    return Container(
      constraints: const BoxConstraints(minHeight: 230),
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
      children: [Text('結果預覽', style: Theme.of(context).textTheme.titleMedium)],
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

String? _preferredTranslation(domain.Lesson lesson) {
  for (final translation in lesson.translations) {
    if (translation.source == domain.TranslationSource.manual) {
      return translation.text;
    }
  }
  return lesson.translations.isEmpty ? null : lesson.translations.first.text;
}
