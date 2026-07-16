// AI-Generate
import 'dart:async';
import 'dart:io';

import 'package:domain/domain.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infra/infra.dart';

import '../../shared/error/error_messages.dart';
import '../../shared/infra/sidecar_paths.dart';
import '../../shared/tokens.dart';

final practiceExportServiceProvider = Provider<PracticeExportService>((ref) {
  final paths = SidecarPaths.current();
  return InfraPracticeExportService(
    PracticeExporter(
      engine: PracticeEngine(),
      runner: const SidecarRunner(),
      fileIo: AtomicFileIo(tempDirPath: paths.tempDirectory),
      ffmpegPath: paths.ffmpegPath,
    ),
  );
});

final exportSaveLocationPickerProvider = Provider<ExportSaveLocationPicker>(
  (ref) => const FileSelectorExportSaveLocationPicker(),
);

final exportedFileRevealerProvider = Provider<ExportedFileRevealer>(
  (ref) => const FinderExportedFileRevealer(),
);

abstract interface class PracticeExportService {
  Future<PracticeExportResult> exportStep(
    PracticeStep step,
    Pcm originalPcm,
    String destPath,
  );

  Future<PracticeExportResult> exportMerged(
    List<PracticeStep> steps,
    Pcm originalPcm,
    String destPath,
  );

  Future<PracticeExportResult> exportUnits(
    PracticeUnits units,
    Pcm originalPcm,
    String destPath, {
    Map<int, PracticeUnitExportConfig> overrides = const {},
  });
}

class InfraPracticeExportService implements PracticeExportService {
  const InfraPracticeExportService(this._exporter);

  final PracticeExporter _exporter;

  @override
  Future<PracticeExportResult> exportStep(
    PracticeStep step,
    Pcm originalPcm,
    String destPath,
  ) => _exporter.exportStep(step, originalPcm, destPath);

  @override
  Future<PracticeExportResult> exportMerged(
    List<PracticeStep> steps,
    Pcm originalPcm,
    String destPath,
  ) => _exporter.exportMerged(steps, originalPcm, destPath);

  @override
  Future<PracticeExportResult> exportUnits(
    PracticeUnits units,
    Pcm originalPcm,
    String destPath, {
    Map<int, PracticeUnitExportConfig> overrides = const {},
  }) =>
      _exporter.exportUnits(units, originalPcm, destPath, overrides: overrides);
}

abstract interface class ExportSaveLocationPicker {
  Future<String?> pickMp3Path({required String suggestedName});
}

class FileSelectorExportSaveLocationPicker implements ExportSaveLocationPicker {
  const FileSelectorExportSaveLocationPicker();

  @override
  Future<String?> pickMp3Path({required String suggestedName}) async {
    const mp3Type = XTypeGroup(label: 'MP3', extensions: ['mp3']);
    final location = await getSaveLocation(
      acceptedTypeGroups: const [mp3Type],
      suggestedName: suggestedName,
      confirmButtonText: '儲存',
      canCreateDirectories: true,
    );
    final path = location?.path;
    if (path == null || path.toLowerCase().endsWith('.mp3')) {
      return path;
    }
    return '$path.mp3';
  }
}

abstract interface class ExportedFileRevealer {
  Future<void> reveal(String path);
}

class FinderExportedFileRevealer implements ExportedFileRevealer {
  const FinderExportedFileRevealer();

  @override
  Future<void> reveal(String path) async {
    await Process.run('/usr/bin/open', ['-R', path]);
  }
}

Future<void> showPracticeExportDialog(
  BuildContext context, {
  required List<PracticeStep> steps,
  required Pcm originalPcm,
  PracticeUnits? units,
  Map<PracticeExportAudioSource, PracticeExportAudioCandidate> audioSources =
      const {},
  Map<
        PracticeExportAudioSource,
        Map<PracticeExportArrangementSource, PracticeExportArrangementCandidate>
      >
      arrangementSources =
      const {},
  int? currentUnitIndex,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => PracticeExportDialog(
      steps: steps,
      units: units,
      originalPcm: originalPcm,
      audioSources: audioSources,
      arrangementSources: arrangementSources,
      currentUnitIndex: currentUnitIndex,
    ),
  );
}

/// App 層把 PCM 與 Domain provenance ref 綁在同一候選，避免 UI 選到後才猜來源。
class PracticeExportAudioCandidate {
  const PracticeExportAudioCandidate({required this.pcm, required this.ref});

  final Pcm pcm;
  final PracticeExportAudioSourceRef ref;
}

/// App 層的排列候選；[snapshot] 已包含不可變單元與來源身分。
class PracticeExportArrangementCandidate {
  const PracticeExportArrangementCandidate({required this.snapshot});

  final PracticeExportArrangementSnapshot snapshot;
}

class PracticeExportDialog extends ConsumerStatefulWidget {
  const PracticeExportDialog({
    super.key,
    required this.steps,
    this.units,
    required this.originalPcm,
    this.audioSources = const {},
    this.arrangementSources = const {},
    this.currentUnitIndex,
  });

  final List<PracticeStep> steps;
  final PracticeUnits? units;
  final Pcm originalPcm;
  final Map<PracticeExportAudioSource, PracticeExportAudioCandidate>
  audioSources;
  final Map<
    PracticeExportAudioSource,
    Map<PracticeExportArrangementSource, PracticeExportArrangementCandidate>
  >
  arrangementSources;
  final int? currentUnitIndex;

  @override
  ConsumerState<PracticeExportDialog> createState() =>
      _PracticeExportDialogState();
}

class _PracticeExportDialogState extends ConsumerState<PracticeExportDialog> {
  late final Set<int> _selectedIndexes;
  late final Map<int, PracticeUnitExportConfig> _unitConfigs;
  String? _destPath;
  PracticeExportResult? _result;
  DomainException? _error;
  bool _isExporting = false;
  late PracticeExportAudioSource _audioSource;
  late PracticeExportArrangementSource _arrangementSource;
  PracticeExportUnitScope _unitScope = PracticeExportUnitScope.selected;

  Map<PracticeExportAudioSource, PracticeExportAudioCandidate>
  get _availableAudioSources {
    if (widget.audioSources.isNotEmpty) return widget.audioSources;
    final range = TimeRange(0, widget.originalPcm.durationMs);
    return {
      PracticeExportAudioSource.currentSentenceOriginal:
          PracticeExportAudioCandidate(
            pcm: widget.originalPcm,
            ref: PracticeExportAudioSourceRef(
              choice: PracticeExportAudioSource.currentSentenceOriginal,
              audioFingerprint: 'dialog-local-original',
              sourceRanges: [range],
            ),
          ),
    };
  }

  Map<PracticeExportArrangementSource, PracticeExportArrangementCandidate>
  get _availableArrangementSources {
    final explicit = widget.arrangementSources[_audioSource];
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final units =
        widget.units ??
        PracticeUnits(
          mode: PracticeMode.auto,
          units: widget.steps.map(AutoPracticeUnit.new).toList(growable: false),
          stale: false,
        );
    final source = units.mode == PracticeMode.custom
        ? PracticeExportArrangementSource.currentUnsaved
        : PracticeExportArrangementSource.wholeSentence;
    return {
      source: PracticeExportArrangementCandidate(
        snapshot: PracticeExportArrangementSnapshot(
          choice: source,
          audioFingerprint:
              _availableAudioSources[_audioSource]!.ref.audioFingerprint,
          lessonId: _availableAudioSources[_audioSource]!.ref.lessonId,
          sourceRanges: _availableAudioSources[_audioSource]!.ref.sourceRanges,
          units: units,
        ),
      ),
    };
  }

  bool get _canExport =>
      _scopedUnits.isNotEmpty && _destPath != null && !_isExporting;

  PracticeUnits get _effectiveUnits =>
      _availableArrangementSources[_arrangementSource]!.snapshot.units;

  List<PracticeUnit> get _selectedUnits => _effectiveUnits.units
      .where((unit) => _selectedIndexes.contains(unit.index))
      .toList(growable: false);

  List<PracticeUnit> get _scopedUnits => switch (_unitScope) {
    PracticeExportUnitScope.all => _effectiveUnits.units,
    PracticeExportUnitScope.selected => _selectedUnits,
    PracticeExportUnitScope.current => [
      _effectiveUnits.units.firstWhere(
        (unit) => unit.index == widget.currentUnitIndex,
        orElse: () => _effectiveUnits.units.first,
      ),
    ],
  };

  @override
  void initState() {
    super.initState();
    _audioSource = _availableAudioSources.keys.first;
    _arrangementSource = _availableArrangementSources.keys.first;
    _selectedIndexes = _effectiveUnits.units.map((unit) => unit.index).toSet();
    _unitConfigs = {
      for (final unit in _effectiveUnits.units) unit.index: _configFor(unit),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contentHeight = (MediaQuery.sizeOf(context).height * 0.82)
        .clamp(400.0, 700.0)
        .toDouble();
    return AlertDialog(
      title: const Text('匯出練習音檔'),
      content: SizedBox(
        width: 640,
        height: contentHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ExportLayerPicker<PracticeExportAudioSource>(
              title: '1. 音訊資料源',
              value: _audioSource,
              values: _availableAudioSources.keys.toList(growable: false),
              label: _audioSourceLabel,
              enabled: !_isExporting,
              onChanged: _changeAudioSource,
            ),
            _ExportLayerPicker<PracticeExportArrangementSource>(
              title: '2. 排列資料源',
              value: _arrangementSource,
              values: _availableArrangementSources.keys.toList(growable: false),
              label: _arrangementSourceLabel,
              enabled: !_isExporting,
              onChanged: _changeArrangementSource,
            ),
            _ExportLayerPicker<PracticeExportUnitScope>(
              title: '3. 匯出範圍',
              value: _unitScope,
              values: PracticeExportUnitScope.values,
              label: _unitScopeLabel,
              enabled: !_isExporting,
              onChanged: (value) => setState(() => _unitScope = value),
            ),
            const Text(
              '4. 各單元最後調整',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Row(
              children: [
                TextButton.icon(
                  onPressed:
                      _isExporting ||
                          _selectedIndexes.length ==
                              _effectiveUnits.units.length
                      ? null
                      : () => _setAllSelected(selected: true),
                  icon: const Icon(Icons.select_all),
                  label: const Text('全部選取'),
                ),
                const SizedBox(width: AppTokens.spaceXs),
                TextButton.icon(
                  onPressed: _isExporting || _selectedIndexes.isEmpty
                      ? null
                      : () => _setAllSelected(selected: false),
                  icon: const Icon(Icons.deselect),
                  label: const Text('全部取消'),
                ),
                const Spacer(),
                Text(
                  '已選 ${_selectedIndexes.length}/${_effectiveUnits.units.length}',
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: [
                  if (_isExporting) ...[
                    const SizedBox(height: AppTokens.spaceMd),
                    const LinearProgressIndicator(),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: AppTokens.spaceMd),
                    _InlineError(error: _error!),
                  ],
                  if (_result != null) ...[
                    const SizedBox(height: AppTokens.spaceMd),
                    Text(
                      '已匯出：${_result!.path}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text('總長 ${_result!.totalDurationMs} ms'),
                    if (_result!.silenceGapsMs.isNotEmpty)
                      Text('靜音間隔：${_result!.silenceGapsMs.join(', ')} ms'),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => unawaited(
                          ref
                              .read(exportedFileRevealerProvider)
                              .reveal(_result!.path),
                        ),
                        icon: const Icon(Icons.folder_outlined),
                        label: const Text('在 Finder 顯示'),
                      ),
                    ),
                  ],
                  for (final unit in _effectiveUnits.units)
                    _ExportUnitTile(
                      unit: unit,
                      selected: _selectedIndexes.contains(unit.index),
                      config: _unitConfigs[unit.index]!,
                      enabled: !_isExporting,
                      onSelected: (value) =>
                          _toggleStep(unit.index, value: value),
                      onConfigChanged: (config) =>
                          _setUnitConfig(unit.index, config),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppTokens.spaceSm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _destPath ?? '尚未選擇匯出位置',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppTokens.spaceSm),
                OutlinedButton.icon(
                  onPressed: _isExporting ? null : _pickDestination,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('選擇位置'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
          child: const Text('關閉'),
        ),
        FilledButton.icon(
          onPressed: _canExport ? _export : null,
          icon: const Icon(Icons.ios_share_outlined),
          label: const Text('匯出'),
        ),
      ],
    );
  }

  void _toggleStep(int index, {required bool? value}) {
    setState(() {
      _result = null;
      _error = null;
      if (value == true) {
        _selectedIndexes.add(index);
      } else {
        _selectedIndexes.remove(index);
      }
    });
  }

  void _setAllSelected({required bool selected}) {
    setState(() {
      _result = null;
      _error = null;
      _selectedIndexes
        ..clear()
        ..addAll(
          selected
              ? _effectiveUnits.units.map((unit) => unit.index)
              : const <int>[],
        );
    });
  }

  void _setUnitConfig(int index, PracticeUnitExportConfig config) {
    setState(() {
      _unitConfigs[index] = config;
      _result = null;
      _error = null;
    });
  }

  Future<void> _pickDestination() async {
    final path = await ref
        .read(exportSaveLocationPickerProvider)
        .pickMp3Path(suggestedName: 'practice-export.mp3');
    if (!mounted || path == null) {
      return;
    }
    setState(() {
      _destPath = path;
      _error = null;
      _result = null;
    });
  }

  Future<void> _export() async {
    final destPath = _destPath;
    if (destPath == null || _scopedUnits.isEmpty || _isExporting) {
      return;
    }

    setState(() {
      _isExporting = true;
      _error = null;
      _result = null;
    });

    try {
      final service = ref.read(practiceExportServiceProvider);
      final scopedUnits = _scopedUnits;
      final plan = PracticeExportPlanner.build(
        audioSourceRef: _availableAudioSources[_audioSource]!.ref,
        arrangementSnapshot:
            _availableArrangementSources[_arrangementSource]!.snapshot,
        unitScope: _unitScope,
        selectedUnitIndices: scopedUnits.map((unit) => unit.index).toSet(),
        currentUnitIndex: widget.currentUnitIndex,
        unitOverrides: {
          for (final unit in scopedUnits) unit.index: _unitConfigs[unit.index]!,
        },
      );
      final selectedUnits = PracticeUnits(
        mode: plan.arrangementSnapshot.units.mode,
        units: plan.arrangementSnapshot.units.units
            .where((unit) => plan.unitIndexes.contains(unit.index))
            .toList(growable: false),
        stale: plan.arrangementSnapshot.units.stale,
      );
      final result = await service.exportUnits(
        selectedUnits,
        _availableAudioSources[_audioSource]!.pcm,
        destPath,
        overrides: plan.unitOverrides,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isExporting = false;
        _result = result;
      });
    } on DomainException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isExporting = false;
        _error = error;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isExporting = false;
        _error = DomainException(ErrorCodes.exportDestUnwritable, '$error');
      });
    }
  }

  void _changeArrangementSource(PracticeExportArrangementSource value) {
    setState(() {
      _arrangementSource = value;
      _selectedIndexes
        ..clear()
        ..addAll(_effectiveUnits.units.map((unit) => unit.index));
      _unitConfigs
        ..clear()
        ..addEntries(
          _effectiveUnits.units.map(
            (unit) => MapEntry(unit.index, _configFor(unit)),
          ),
        );
      _result = null;
      _error = null;
    });
  }

  void _changeAudioSource(PracticeExportAudioSource value) {
    setState(() {
      _audioSource = value;
      _arrangementSource = _availableArrangementSources.keys.first;
      _selectedIndexes
        ..clear()
        ..addAll(_effectiveUnits.units.map((unit) => unit.index));
      _unitConfigs
        ..clear()
        ..addEntries(
          _effectiveUnits.units.map(
            (unit) => MapEntry(unit.index, _configFor(unit)),
          ),
        );
      _result = null;
      _error = null;
    });
  }
}

class _ExportLayerPicker<T extends Enum> extends StatelessWidget {
  const _ExportLayerPicker({
    required this.title,
    required this.value,
    required this.values,
    required this.label,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final T value;
  final List<T> values;
  final String Function(T value) label;
  final bool enabled;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.spaceXs),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              items: [
                for (final item in values)
                  DropdownMenuItem(value: item, child: Text(label(item))),
              ],
              onChanged: enabled
                  ? (next) {
                      if (next != null) onChanged(next);
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

String _audioSourceLabel(PracticeExportAudioSource source) => switch (source) {
  PracticeExportAudioSource.currentSentenceOriginal => '目前單句原音',
  PracticeExportAudioSource.keptSegmentsFromOriginal => '段落標籤保留區間',
  PracticeExportAudioSource.savedV3SentenceOriginal => '已儲存 v3 單句原音',
};

String _arrangementSourceLabel(PracticeExportArrangementSource source) =>
    switch (source) {
      PracticeExportArrangementSource.wholeSentence => '完整單句',
      PracticeExportArrangementSource.currentUnsaved => '目前未儲存排列',
      PracticeExportArrangementSource.savedV3 => '已儲存 v3 排列',
    };

String _unitScopeLabel(PracticeExportUnitScope scope) => switch (scope) {
  PracticeExportUnitScope.all => '全部單元',
  PracticeExportUnitScope.selected => '勾選單元',
  PracticeExportUnitScope.current => '目前單元',
};

class _InlineError extends StatelessWidget {
  const _InlineError({required this.error});

  final DomainException error;

  @override
  Widget build(BuildContext context) {
    final presentation = ErrorMessages.fromCode(error.code);
    final color = Theme.of(context).colorScheme.error;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(presentation.icon, color: color),
        const SizedBox(width: AppTokens.spaceSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                presentation.title,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
              ),
              Text(presentation.message),
            ],
          ),
        ),
      ],
    );
  }
}

String _stepText(PracticeStep step) =>
    step.syllables.map((s) => s.text).join(' ');

String _unitText(PracticeUnit unit) {
  return switch (unit) {
    AutoPracticeUnit(:final step) => _stepText(step),
    WholeSentencePracticeUnit(:final step) => _stepText(step),
    CustomPracticeUnit(:final row) =>
      row.blocks
          .expand((block) => block.syllables)
          .map((syllable) => syllable.text)
          .join(' '),
  };
}

int _unitDuration(PracticeUnit unit) {
  return switch (unit) {
    AutoPracticeUnit(:final step) => step.totalDurationMs,
    WholeSentencePracticeUnit(:final step) => step.totalDurationMs,
    CustomPracticeUnit(:final row) => row.blocks.fold(
      0,
      (total, block) =>
          total +
          block.sourceDurationMs * block.repeatN +
          block.silenceDurationMs,
    ),
  };
}

PracticeUnitExportConfig _configFor(PracticeUnit unit) {
  return switch (unit) {
    AutoPracticeUnit(:final step) => PracticeUnitExportConfig(
      repeatN: _stepRepeatN(step),
      silenceFactor: 0,
    ),
    WholeSentencePracticeUnit(:final repeatN, :final silenceFactor) =>
      PracticeUnitExportConfig(repeatN: repeatN, silenceFactor: silenceFactor),
    CustomPracticeUnit(:final row) => PracticeUnitExportConfig(
      repeatN: row.repeatN,
      silenceFactor: row.silenceFactor,
    ),
  };
}

int _stepRepeatN(PracticeStep step) {
  final sourceDurationMs = step.sourceRanges.fold<int>(
    0,
    (total, range) => total + range.durationMs,
  );
  if (sourceDurationMs == 0 || step.totalDurationMs % sourceDurationMs != 0) {
    return 1;
  }
  return (step.totalDurationMs ~/ sourceDurationMs).clamp(
    PracticeBlock.minRepeatN,
    PracticeBlock.maxRepeatN,
  );
}

class _ExportUnitTile extends StatelessWidget {
  const _ExportUnitTile({
    required this.unit,
    required this.selected,
    required this.config,
    required this.enabled,
    required this.onSelected,
    required this.onConfigChanged,
  });

  final PracticeUnit unit;
  final bool selected;
  final PracticeUnitExportConfig config;
  final bool enabled;
  final ValueChanged<bool?> onSelected;
  final ValueChanged<PracticeUnitExportConfig> onConfigChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTokens.spaceXs),
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppTokens.spaceXs),
        child: Column(
          children: [
            CheckboxListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceSm,
              ),
              value: selected,
              onChanged: enabled ? onSelected : null,
              title: Text('第 ${unit.index} 單元：${_unitText(unit)}'),
              subtitle: Text('原始單元 ${_unitDuration(unit)} ms'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceSm,
              ),
              child: Wrap(
                spacing: AppTokens.spaceMd,
                runSpacing: AppTokens.spaceXs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('重複'),
                      IconButton(
                        key: ValueKey('export-unit-${unit.index}-repeat-down'),
                        tooltip: '第 ${unit.index} 單元重複次數 -1',
                        onPressed:
                            enabled && config.repeatN > PracticeBlock.minRepeatN
                            ? () => onConfigChanged(
                                PracticeUnitExportConfig(
                                  repeatN: config.repeatN - 1,
                                  silenceFactor: config.silenceFactor,
                                ),
                              )
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Text(
                        '${config.repeatN}',
                        key: ValueKey('export-unit-${unit.index}-repeat-value'),
                      ),
                      IconButton(
                        key: ValueKey('export-unit-${unit.index}-repeat-up'),
                        tooltip: '第 ${unit.index} 單元重複次數 +1',
                        onPressed:
                            enabled && config.repeatN < PracticeBlock.maxRepeatN
                            ? () => onConfigChanged(
                                PracticeUnitExportConfig(
                                  repeatN: config.repeatN + 1,
                                  silenceFactor: config.silenceFactor,
                                ),
                              )
                            : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('靜音倍數'),
                      IconButton(
                        key: ValueKey('export-unit-${unit.index}-silence-down'),
                        tooltip: '第 ${unit.index} 單元靜音倍數 -0.5',
                        onPressed:
                            enabled &&
                                config.silenceFactor >
                                    PracticeBlock.minSilenceFactor
                            ? () => onConfigChanged(
                                PracticeUnitExportConfig(
                                  repeatN: config.repeatN,
                                  silenceFactor:
                                      config.silenceFactor -
                                      PracticeBlock.silenceFactorStep,
                                ),
                              )
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Text(
                        config.silenceFactor.toStringAsFixed(1),
                        key: ValueKey(
                          'export-unit-${unit.index}-silence-value',
                        ),
                      ),
                      IconButton(
                        key: ValueKey('export-unit-${unit.index}-silence-up'),
                        tooltip: '第 ${unit.index} 單元靜音倍數 +0.5',
                        onPressed:
                            enabled &&
                                config.silenceFactor <
                                    PracticeBlock.maxSilenceFactor
                            ? () => onConfigChanged(
                                PracticeUnitExportConfig(
                                  repeatN: config.repeatN,
                                  silenceFactor:
                                      config.silenceFactor +
                                      PracticeBlock.silenceFactorStep,
                                ),
                              )
                            : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
