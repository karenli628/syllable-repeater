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
import '../labeling/labeling_controller.dart';
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
        final friendly = ErrorMessages.fromCode(err.code).message;
        final detail = err.message.trim();
        final message = detail.isEmpty || detail == friendly
            ? friendly
            : '$friendly\n$detail';
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
        ref.read(practiceControllerProvider.notifier).clearError();
      }
    });

    if (state.steps.isEmpty) {
      return const EmptyState(
        icon: Icons.play_circle_outline,
        title: '尚無練習單元',
        message: '完成匯入分析並進入校正後，這裡會顯示句尾疊加單元。',
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
            _TranscriptDisplay(
              mode: state.transcriptMode,
              transcript:
                  session.lesson?.syllables
                      .map((syllable) => syllable.text)
                      .join(' ') ??
                  editor.syllables.map((syllable) => syllable.text).join(' '),
              translation: session.lesson?.translations.isEmpty ?? true
                  ? null
                  : session.lesson!.translations.first.text,
              onChanged: (mode) => unawaited(
                ref
                    .read(practiceControllerProvider.notifier)
                    .setTranscriptMode(mode),
              ),
            ),
            if (state.mode == PracticeMode.custom && state.stale)
              Container(
                key: const ValueKey('practice-stale-banner'),
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: AppTokens.spaceSm),
                padding: const EdgeInsets.all(AppTokens.spaceSm),
                color: Theme.of(context).colorScheme.tertiaryContainer,
                child: const Text('目前排列的音節數已變更，請回到編輯區重新生成或確認保留。'),
              ),
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
    final editor = ref.watch(editorControllerProvider);
    final lessonSession = ref.watch(lessonSessionControllerProvider);
    final analysis = ref.watch(analysisControllerProvider);
    final labeling = ref.watch(labelingControllerProvider);
    final pcm = state.decodedPcm;
    final currentUnits = _unitsForExport(state);
    final currentIdentity = pcm == null
        ? null
        : _currentExportIdentity(
            pcm: pcm,
            lessonId: editor.sourceLessonId,
            analysis: analysis,
            labeling: labeling,
            lessonSession: lessonSession,
          );
    final audioSources = pcm == null
        ? const <PracticeExportAudioSource, PracticeExportAudioCandidate>{}
        : _exportAudioSources(pcm, lessonSession, currentIdentity!);
    final arrangementSources = pcm == null || editor.syllables.isEmpty
        ? const <
            PracticeExportAudioSource,
            Map<
              PracticeExportArrangementSource,
              PracticeExportArrangementCandidate
            >
          >{}
        : _exportArrangementSources(
            currentUnits: currentUnits,
            currentSyllables: editor.syllables,
            currentDurationMs: pcm.durationMs,
            lessonSession: lessonSession,
            currentIdentity: currentIdentity!,
          );
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
                '共 ${state.steps.length} 單元；目前第 ${state.currentIndex + 1} 單元。',
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
                      units: currentUnits,
                      originalPcm: state.decodedPcm!,
                      audioSources: audioSources,
                      arrangementSources: arrangementSources,
                      currentUnitIndex: state.currentUnit?.index,
                    ),
                  ),
            icon: const Icon(Icons.ios_share_outlined),
            label: const Text('匯出'),
          ),
        ),
        IconButton.outlined(
          tooltip: '目前單元整列重複次數 -1',
          onPressed: state.repeatN > PracticeBlock.minRepeatN
              ? () => controller.setRepeatN(state.repeatN - 1)
              : null,
          icon: const Icon(Icons.remove),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceSm),
          child: Text('×${state.repeatN}', style: textTheme.titleMedium),
        ),
        IconButton.outlined(
          tooltip: '目前單元整列重複次數 +1',
          onPressed: state.repeatN < PracticeBlock.maxRepeatN
              ? () => controller.setRepeatN(state.repeatN + 1)
              : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

class _TranscriptDisplay extends StatelessWidget {
  const _TranscriptDisplay({
    required this.mode,
    required this.transcript,
    required this.translation,
    required this.onChanged,
  });

  final TranscriptDisplayMode mode;
  final String transcript;
  final String? translation;
  final ValueChanged<TranscriptDisplayMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final showTranscript =
        mode == TranscriptDisplayMode.transcript ||
        mode == TranscriptDisplayMode.transcriptWithTranslation;
    final showTranslation =
        mode == TranscriptDisplayMode.translationOnly ||
        mode == TranscriptDisplayMode.transcriptWithTranslation;
    final hasTranslation =
        translation != null && translation!.trim().isNotEmpty;
    return Card(
      key: const ValueKey('transcript-display'),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceSm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<TranscriptDisplayMode>(
              key: const ValueKey('transcript-display-mode'),
              segments: const [
                ButtonSegment(
                  value: TranscriptDisplayMode.transcript,
                  label: Text('字稿'),
                ),
                ButtonSegment(
                  value: TranscriptDisplayMode.transcriptWithTranslation,
                  label: Text('字稿＋譯文'),
                ),
                ButtonSegment(
                  value: TranscriptDisplayMode.translationOnly,
                  label: Text('僅譯文'),
                ),
                ButtonSegment(
                  value: TranscriptDisplayMode.hidden,
                  label: Text('隱藏'),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (selection) => onChanged(selection.first),
            ),
            if (showTranscript) ...[
              const SizedBox(height: AppTokens.spaceSm),
              Text(transcript, key: const ValueKey('transcript-text')),
            ],
            if (showTranslation) ...[
              const SizedBox(height: AppTokens.spaceXs),
              if (hasTranslation)
                Text(translation!, key: const ValueKey('translation-text'))
              else
                const Text(
                  '尚無譯文；可回到匯入頁新增手動或 AI 譯文。',
                  key: ValueKey('translation-guidance'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

PracticeUnits _unitsForExport(PracticeUiState state) {
  if (state.units.isNotEmpty) {
    return PracticeUnits(
      mode: state.mode,
      units: state.units,
      stale: state.stale,
    );
  }
  return PracticeUnits(
    mode: PracticeMode.auto,
    units: state.steps.map(AutoPracticeUnit.new).toList(growable: false),
    stale: false,
  );
}

Map<PracticeExportAudioSource, PracticeExportAudioCandidate>
_exportAudioSources(
  Pcm currentPcm,
  LessonSessionState lessonSession,
  _ExportIdentity currentIdentity,
) {
  final sources = <PracticeExportAudioSource, PracticeExportAudioCandidate>{
    PracticeExportAudioSource.currentSentenceOriginal:
        PracticeExportAudioCandidate(
          pcm: currentPcm,
          ref: PracticeExportAudioSourceRef(
            choice: PracticeExportAudioSource.currentSentenceOriginal,
            audioFingerprint: currentIdentity.audioFingerprint,
            lessonId: currentIdentity.lessonId,
            sourceRanges: currentIdentity.sourceRanges,
          ),
        ),
  };
  final sourcePath = lessonSession.sourcePath?.toLowerCase();
  if (sourcePath?.endsWith('.abopack') ?? false) {
    final savedPcm = lessonSession.pcm;
    final bundle = lessonSession.courseBundle;
    final lesson = lessonSession.lesson;
    if (savedPcm != null && bundle != null && lesson != null) {
      sources[PracticeExportAudioSource.savedV3SentenceOriginal] =
          PracticeExportAudioCandidate(
            pcm: savedPcm,
            ref: PracticeExportAudioSourceRef(
              choice: PracticeExportAudioSource.savedV3SentenceOriginal,
              audioFingerprint: bundle.audioFingerprint,
              lessonId: lesson.id,
              sourceRanges: [
                bundle.sentenceSourceRange ?? TimeRange(0, savedPcm.durationMs),
              ],
            ),
          );
    }
    final originalPcm = lessonSession.courseOriginalPcm;
    final kept = bundle?.labels?.segments
        .where((segment) => segment.disposition == SegmentDisposition.kept)
        .toList(growable: false);
    if (originalPcm != null && kept != null && kept.isNotEmpty) {
      sources[PracticeExportAudioSource.keptSegmentsFromOriginal] =
          PracticeExportAudioCandidate(
            pcm: originalPcm,
            ref: PracticeExportAudioSourceRef(
              choice: PracticeExportAudioSource.keptSegmentsFromOriginal,
              audioFingerprint: bundle!.audioFingerprint,
              sourceRanges: [TimeRange(0, originalPcm.durationMs)],
            ),
          );
    }
  }
  return sources;
}

Map<
  PracticeExportAudioSource,
  Map<PracticeExportArrangementSource, PracticeExportArrangementCandidate>
>
_exportArrangementSources({
  required PracticeUnits currentUnits,
  required List<Syllable> currentSyllables,
  required int currentDurationMs,
  required LessonSessionState lessonSession,
  required _ExportIdentity currentIdentity,
}) {
  final engine = PracticeEngine();
  final currentSources =
      <PracticeExportArrangementSource, PracticeExportArrangementCandidate>{
        PracticeExportArrangementSource.wholeSentence:
            PracticeExportArrangementCandidate(
              snapshot: PracticeExportArrangementSnapshot(
                choice: PracticeExportArrangementSource.wholeSentence,
                audioFingerprint: currentIdentity.audioFingerprint,
                lessonId: currentIdentity.lessonId,
                sourceRanges: currentIdentity.sourceRanges,
                units: engine.effectiveUnits(
                  currentSyllables,
                  fullSentenceRange: TimeRange(0, currentDurationMs),
                ),
              ),
            ),
      };
  if (currentUnits.mode == PracticeMode.custom) {
    currentSources[PracticeExportArrangementSource.currentUnsaved] =
        PracticeExportArrangementCandidate(
          snapshot: PracticeExportArrangementSnapshot(
            choice: PracticeExportArrangementSource.currentUnsaved,
            audioFingerprint: currentIdentity.audioFingerprint,
            lessonId: currentIdentity.lessonId,
            sourceRanges: currentIdentity.sourceRanges,
            units: currentUnits,
          ),
        );
  }
  final sources =
      <
        PracticeExportAudioSource,
        Map<PracticeExportArrangementSource, PracticeExportArrangementCandidate>
      >{PracticeExportAudioSource.currentSentenceOriginal: currentSources};
  final savedLesson = lessonSession.lesson;
  final savedArrangement = savedLesson?.arrangement;
  final savedPcm = lessonSession.pcm;
  final sourcePath = lessonSession.sourcePath?.toLowerCase();
  if ((sourcePath?.endsWith('.abopack') ?? false) &&
      savedLesson != null &&
      savedPcm != null) {
    final bundle = lessonSession.courseBundle;
    if (bundle != null) {
      final savedSources =
          <PracticeExportArrangementSource, PracticeExportArrangementCandidate>{
            PracticeExportArrangementSource.wholeSentence:
                PracticeExportArrangementCandidate(
                  snapshot: PracticeExportArrangementSnapshot(
                    choice: PracticeExportArrangementSource.wholeSentence,
                    audioFingerprint: bundle.audioFingerprint,
                    lessonId: savedLesson.id,
                    sourceRanges: [
                      bundle.sentenceSourceRange ??
                          TimeRange(0, savedPcm.durationMs),
                    ],
                    units: engine.effectiveUnits(
                      savedLesson.syllables,
                      fullSentenceRange: TimeRange(0, savedPcm.durationMs),
                    ),
                  ),
                ),
          };
      if (savedArrangement != null && savedArrangement.rows.isNotEmpty) {
        savedSources[PracticeExportArrangementSource
            .savedV3] = PracticeExportArrangementCandidate(
          snapshot: PracticeExportArrangementSnapshot(
            choice: PracticeExportArrangementSource.savedV3,
            audioFingerprint: bundle.audioFingerprint,
            lessonId: savedLesson.id,
            sourceRanges: [
              bundle.sentenceSourceRange ?? TimeRange(0, savedPcm.durationMs),
            ],
            units: engine.effectiveUnits(
              savedLesson.syllables,
              fullSentenceRange: TimeRange(0, savedPcm.durationMs),
              arrangement: savedArrangement,
            ),
          ),
        );
      }
      sources[PracticeExportAudioSource.savedV3SentenceOriginal] = savedSources;
    }
  }
  final bundle = lessonSession.courseBundle;
  final originalPcm = lessonSession.courseOriginalPcm;
  final kept = bundle?.labels?.segments
      .where((segment) => segment.disposition == SegmentDisposition.kept)
      .where((segment) => segment.endMs <= (originalPcm?.durationMs ?? 0))
      .toList(growable: false);
  if ((sourcePath?.endsWith('.abopack') ?? false) &&
      bundle != null &&
      originalPcm != null &&
      kept != null &&
      kept.isNotEmpty) {
    final steps = [
      for (var offset = 0; offset < kept.length; offset++)
        PracticeStep(
          index: offset + 1,
          syllables: [
            Syllable(
              text: kept[offset].text.trim().isEmpty
                  ? '第 ${offset + 1} 段'
                  : kept[offset].text,
              startMs: kept[offset].startMs,
              endMs: kept[offset].endMs,
              wordIndex: 0,
              needsReview: false,
            ),
          ],
          sourceRanges: [kept[offset].range],
          totalDurationMs: kept[offset].range.durationMs,
        ),
    ];
    sources[PracticeExportAudioSource.keptSegmentsFromOriginal] = {
      PracticeExportArrangementSource.wholeSentence:
          PracticeExportArrangementCandidate(
            snapshot: PracticeExportArrangementSnapshot(
              choice: PracticeExportArrangementSource.wholeSentence,
              audioFingerprint: bundle.audioFingerprint,
              sourceRanges: kept.map((segment) => segment.range).toList(),
              units: PracticeUnits(
                mode: PracticeMode.wholeSentence,
                units: steps
                    .map((step) => WholeSentencePracticeUnit(step))
                    .toList(growable: false),
                stale: false,
              ),
            ),
          ),
    };
  }
  return sources;
}

class _ExportIdentity {
  const _ExportIdentity({
    required this.audioFingerprint,
    required this.lessonId,
    required this.sourceRanges,
  });

  final String audioFingerprint;
  final String? lessonId;
  final List<TimeRange> sourceRanges;
}

_ExportIdentity _currentExportIdentity({
  required Pcm pcm,
  required String? lessonId,
  required AnalysisUiState analysis,
  required LabelingUiState labeling,
  required LessonSessionState lessonSession,
}) {
  final pending = analysis.pendingSegment;
  final labelSession = labeling.session;
  final fromCurrentLabels =
      pending != null &&
      labelSession != null &&
      pending.sourceAudioPath == labeling.audioPath;
  if (fromCurrentLabels) {
    return _ExportIdentity(
      audioFingerprint: labelSession.audioFingerprint,
      lessonId: lessonId,
      sourceRanges: [pending.range],
    );
  }
  final bundle = lessonSession.courseBundle;
  final savedLesson = lessonSession.lesson;
  if (bundle != null && savedLesson?.id == lessonId) {
    return _ExportIdentity(
      audioFingerprint: bundle.audioFingerprint,
      lessonId: lessonId,
      sourceRanges: [
        bundle.sentenceSourceRange ?? TimeRange(0, pcm.durationMs),
      ],
    );
  }
  return _ExportIdentity(
    audioFingerprint: savedLesson?.id == lessonId
        ? savedLesson!.contentHash
        : 'draft-$lessonId',
    lessonId: lessonId,
    sourceRanges: [TimeRange(0, pcm.durationMs)],
  );
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
            label: Text(
              state.transcriptMode == TranscriptDisplayMode.hidden
                  ? '#${i + 1}'
                  : '#${i + 1} ${_stepText(state.steps[i])}',
            ),
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
      key: const ValueKey('practice-player-bar'),
      title: state.transcriptMode == TranscriptDisplayMode.hidden
          ? '第 ${step.index} 單元'
          : '第 ${step.index} 單元：${_stepText(step)}',
      subtitle: '整列重複 ${state.repeatN} 次 · ${step.totalDurationMs} ms',
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
    name: '第 ${step.index} 單元',
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
