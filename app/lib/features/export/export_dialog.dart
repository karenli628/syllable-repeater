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
  final paths = SidecarPaths.dev();
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
}) {
  return showDialog<void>(
    context: context,
    builder: (context) =>
        PracticeExportDialog(steps: steps, originalPcm: originalPcm),
  );
}

class PracticeExportDialog extends ConsumerStatefulWidget {
  const PracticeExportDialog({
    super.key,
    required this.steps,
    required this.originalPcm,
  });

  final List<PracticeStep> steps;
  final Pcm originalPcm;

  @override
  ConsumerState<PracticeExportDialog> createState() =>
      _PracticeExportDialogState();
}

class _PracticeExportDialogState extends ConsumerState<PracticeExportDialog> {
  late final Set<int> _selectedIndexes;
  String? _destPath;
  PracticeExportResult? _result;
  DomainException? _error;
  bool _isExporting = false;

  List<PracticeStep> get _selectedSteps => widget.steps
      .where((step) => _selectedIndexes.contains(step.index))
      .toList(growable: false);

  bool get _canExport =>
      _selectedIndexes.isNotEmpty && _destPath != null && !_isExporting;

  @override
  void initState() {
    super.initState();
    _selectedIndexes = widget.steps.map((step) => step.index).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('匯出練習音檔'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final step in widget.steps)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _selectedIndexes.contains(step.index),
                  onChanged: _isExporting
                      ? null
                      : (value) => _toggleStep(step.index, value: value),
                  title: Text('第 ${step.index} 步：${_stepText(step)}'),
                  subtitle: Text('${step.totalDurationMs} ms'),
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
                Text('已匯出：${_result!.path}', style: theme.textTheme.bodyMedium),
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
            ],
          ),
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
    if (destPath == null || _selectedIndexes.isEmpty || _isExporting) {
      return;
    }

    setState(() {
      _isExporting = true;
      _error = null;
      _result = null;
    });

    try {
      final steps = _selectedSteps;
      final service = ref.read(practiceExportServiceProvider);
      final result = steps.length == 1
          ? await service.exportStep(steps.single, widget.originalPcm, destPath)
          : await service.exportMerged(steps, widget.originalPcm, destPath);
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
}

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
