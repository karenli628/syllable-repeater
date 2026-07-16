// AI-Generate
import 'dart:async';

import 'package:domain/domain.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/tokens.dart';
import '../library/lesson_pack_service.dart';
import 'ai_settings_service.dart';
import 'progress_service.dart';

final progressFilePickerProvider = Provider<ProgressFilePicker>(
  (ref) => const FileSelectorProgressFilePicker(),
);

final reminderConfigProvider = FutureProvider<ReminderConfig>((ref) {
  return ref.watch(progressServiceProvider).reminderConfig();
});

final sidecarConfigProvider = FutureProvider<SidecarConfig>((ref) {
  return ref.watch(progressServiceProvider).sidecarConfig();
});

final archivedGroupsProvider = FutureProvider<List<ArchivedGroup>>((ref) {
  return ref
      .watch(progressServiceProvider)
      .archivedGroups(DateTime.now().toUtc());
});

abstract interface class ProgressFilePicker {
  Future<String?> pickExportPath();

  Future<String?> pickImportPath();
}

class FileSelectorProgressFilePicker implements ProgressFilePicker {
  const FileSelectorProgressFilePicker();

  static const _progressType = XTypeGroup(
    label: 'AboProgress',
    extensions: ['aboprogress'],
  );

  @override
  Future<String?> pickExportPath() async {
    final location = await getSaveLocation(
      acceptedTypeGroups: const [_progressType],
      suggestedName: 'syllable-progress.aboprogress',
      confirmButtonText: '匯出',
      canCreateDirectories: true,
    );
    final path = location?.path;
    if (path == null || path.toLowerCase().endsWith('.aboprogress')) {
      return path;
    }
    return '$path.aboprogress';
  }

  @override
  Future<String?> pickImportPath() async {
    final file = await openFile(
      acceptedTypeGroups: const [_progressType],
      confirmButtonText: '匯入',
    );
    return file?.path;
  }
}

class ProgressSettingsScreen extends ConsumerStatefulWidget {
  const ProgressSettingsScreen({super.key});

  @override
  ConsumerState<ProgressSettingsScreen> createState() =>
      _ProgressSettingsScreenState();
}

class _ProgressSettingsScreenState
    extends ConsumerState<ProgressSettingsScreen> {
  final _aiKeyController = TextEditingController();
  ReminderConfig? _editing;
  SidecarConfig? _editingSidecar;
  bool _saving = false;
  bool _savingAi = false;
  bool _transferring = false;
  bool _savingCourse = false;
  String? _aiMessage;
  String? _aiError;
  String? _transferMessage;
  MergeSummary? _transferSummary;
  String? _transferError;

  @override
  void dispose() {
    _aiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(reminderConfigProvider);
    final sidecarConfig = ref.watch(sidecarConfigProvider);
    final archivedGroups = ref.watch(archivedGroupsProvider);
    return Padding(
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      child: config.when(
        data: (value) => sidecarConfig.when(
          data: (sidecar) => _SettingsForm(
            config: _editing ?? value,
            sidecarConfig: _editingSidecar ?? sidecar,
            archivedGroups: archivedGroups,
            aiKeyController: _aiKeyController,
            saving: _saving,
            savingAi: _savingAi,
            transferring: _transferring,
            savingCourse: _savingCourse,
            aiMessage: _aiMessage,
            aiError: _aiError,
            transferMessage: _transferMessage,
            transferSummary: _transferSummary,
            transferError: _transferError,
            onChanged: (next) => setState(() => _editing = next),
            onSidecarChanged: (next) => setState(() => _editingSidecar = next),
            onSave: () =>
                unawaited(_save(_editing ?? value, _editingSidecar ?? sidecar)),
            onSaveAiCredential: () => unawaited(_saveAiCredential()),
            onExportProgress: () => unawaited(_exportProgress()),
            onImportProgress: () => unawaited(_importProgress()),
            onSaveCourse: () => unawaited(_saveCourse()),
            onRestoreGroup: (groupId) => unawaited(_restoreGroup(groupId)),
          ),
          error: (error, _) => Text('$error'),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Text('$error'),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _save(ReminderConfig config, SidecarConfig sidecarConfig) async {
    setState(() => _saving = true);
    try {
      await ref.read(progressServiceProvider).saveReminderConfig(config);
      await ref.read(progressServiceProvider).saveSidecarConfig(sidecarConfig);
      ref.invalidate(reminderConfigProvider);
      ref.invalidate(sidecarConfigProvider);
      setState(() {
        _editing = null;
        _editingSidecar = null;
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _saveAiCredential() async {
    setState(() {
      _savingAi = true;
      _aiMessage = null;
      _aiError = null;
    });
    try {
      await ref
          .read(aiSettingsServiceProvider)
          .configureCredential(_aiKeyController.text);
      if (!mounted) {
        return;
      }
      _aiKeyController.clear();
      setState(() => _aiMessage = '已更新 AI key');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _aiError = _describeError(error));
    } finally {
      if (mounted) {
        setState(() => _savingAi = false);
      }
    }
  }

  Future<void> _exportProgress() async {
    final path = await ref.read(progressFilePickerProvider).pickExportPath();
    if (!mounted || path == null) {
      return;
    }
    setState(() {
      _transferring = true;
      _transferMessage = null;
      _transferSummary = null;
      _transferError = null;
    });
    try {
      final writtenPath = await ref
          .read(progressServiceProvider)
          .exportProgress(path);
      if (!mounted) {
        return;
      }
      setState(() {
        _transferMessage = '已匯出：$writtenPath';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _transferError = _describeError(error));
    } finally {
      if (mounted) {
        setState(() => _transferring = false);
      }
    }
  }

  Future<void> _saveCourse() async {
    final path = await ref.read(lessonPackFilePickerProvider).pickSavePath();
    if (!mounted || path == null) return;
    setState(() {
      _savingCourse = true;
      _transferMessage = null;
      _transferError = null;
    });
    try {
      final bundle = await ref.read(currentCourseBundleDraftBuilderProvider)();
      final written = await ref
          .read(courseBundleSaveServiceProvider)
          .save(bundle, path);
      if (mounted) setState(() => _transferMessage = '已儲存課程：$written');
    } catch (error) {
      if (mounted) setState(() => _transferError = _describeError(error));
    } finally {
      if (mounted) setState(() => _savingCourse = false);
    }
  }

  Future<void> _importProgress() async {
    final path = await ref.read(progressFilePickerProvider).pickImportPath();
    if (!mounted || path == null) {
      return;
    }
    setState(() {
      _transferring = true;
      _transferMessage = null;
      _transferSummary = null;
      _transferError = null;
    });
    try {
      final summary = await ref
          .read(progressServiceProvider)
          .importProgress(path);
      if (!mounted) {
        return;
      }
      setState(() {
        _transferMessage = '已匯入：$path';
        _transferSummary = summary;
      });
      ref.invalidate(archivedGroupsProvider);
      unawaited(_showMergeSummary(summary));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _transferError = _describeError(error));
    } finally {
      if (mounted) {
        setState(() => _transferring = false);
      }
    }
  }

  Future<void> _restoreGroup(String groupId) async {
    setState(() => _transferError = null);
    try {
      await ref.read(progressServiceProvider).restore(groupId);
      ref.invalidate(archivedGroupsProvider);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _transferError = _describeError(error));
    }
  }

  String _describeError(Object error) =>
      error is DomainException ? error.message : '$error';

  Future<void> _showMergeSummary(MergeSummary summary) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('匯入摘要'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('套用 ${summary.applied}，略過 ${summary.skipped}'),
            if (summary.resetLessons.isNotEmpty) ...[
              const SizedBox(height: AppTokens.spaceSm),
              Text('重置課件：${summary.resetLessons.join(', ')}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }
}

class _SettingsForm extends StatelessWidget {
  const _SettingsForm({
    required this.config,
    required this.sidecarConfig,
    required this.archivedGroups,
    required this.aiKeyController,
    required this.saving,
    required this.savingAi,
    required this.transferring,
    required this.savingCourse,
    required this.aiMessage,
    required this.aiError,
    required this.transferMessage,
    required this.transferSummary,
    required this.transferError,
    required this.onChanged,
    required this.onSidecarChanged,
    required this.onSave,
    required this.onSaveAiCredential,
    required this.onExportProgress,
    required this.onImportProgress,
    required this.onSaveCourse,
    required this.onRestoreGroup,
  });

  final ReminderConfig config;
  final SidecarConfig sidecarConfig;
  final AsyncValue<List<ArchivedGroup>> archivedGroups;
  final TextEditingController aiKeyController;
  final bool saving;
  final bool savingAi;
  final bool transferring;
  final bool savingCourse;
  final String? aiMessage;
  final String? aiError;
  final String? transferMessage;
  final MergeSummary? transferSummary;
  final String? transferError;
  final ValueChanged<ReminderConfig> onChanged;
  final ValueChanged<SidecarConfig> onSidecarChanged;
  final VoidCallback onSave;
  final VoidCallback onSaveAiCredential;
  final VoidCallback onExportProgress;
  final VoidCallback onImportProgress;
  final VoidCallback onSaveCourse;
  final ValueChanged<String> onRestoreGroup;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('進度設定', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppTokens.spaceLg),
          _AiCredentialSection(
            controller: aiKeyController,
            saving: savingAi,
            message: aiMessage,
            error: aiError,
            onSave: onSaveAiCredential,
          ),
          const SizedBox(height: AppTokens.spaceLg),
          _FileManagementSection(
            transferring: transferring,
            savingCourse: savingCourse,
            message: transferMessage,
            summary: transferSummary,
            error: transferError,
            onExport: onExportProgress,
            onImport: onImportProgress,
            onSaveCourse: onSaveCourse,
          ),
          const SizedBox(height: AppTokens.spaceLg),
          _ArchivedGroupsSection(
            archivedGroups: archivedGroups,
            onRestore: onRestoreGroup,
          ),
          const SizedBox(height: AppTokens.spaceLg),
          Text('提醒節奏', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppTokens.spaceMd),
          _StepperRow(
            label: '每次分鐘',
            value: config.minutesPerSession,
            onChanged: (value) => onChanged(
              ReminderConfig(
                minutesPerSession: value,
                failCapPerSession: config.failCapPerSession,
                dailySessions: config.dailySessions,
              ),
            ),
          ),
          _StepperRow(
            label: '上限個數',
            value: config.failCapPerSession,
            onChanged: (value) => onChanged(
              ReminderConfig(
                minutesPerSession: config.minutesPerSession,
                failCapPerSession: value,
                dailySessions: config.dailySessions,
              ),
            ),
          ),
          _StepperRow(
            label: '每日次數',
            value: config.dailySessions,
            onChanged: (value) => onChanged(
              ReminderConfig(
                minutesPerSession: config.minutesPerSession,
                failCapPerSession: config.failCapPerSession,
                dailySessions: value,
              ),
            ),
          ),
          _StepperRow(
            label: 'Sidecar 逾時秒數',
            value: sidecarConfig.timeoutSeconds,
            onChanged: (value) =>
                onSidecarChanged(SidecarConfig(timeoutSeconds: value)),
          ),
          const SizedBox(height: AppTokens.spaceLg),
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('儲存'),
          ),
        ],
      ),
    );
  }
}

class _AiCredentialSection extends StatelessWidget {
  const _AiCredentialSection({
    required this.controller,
    required this.saving,
    required this.message,
    required this.error,
    required this.onSave,
  });

  final TextEditingController controller;
  final bool saving;
  final String? message;
  final String? error;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AI 翻譯', style: textTheme.titleMedium),
        const SizedBox(height: AppTokens.spaceMd),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: TextField(
            controller: controller,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'AI key',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(height: AppTokens.spaceSm),
        FilledButton.icon(
          onPressed: saving ? null : onSave,
          icon: saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.vpn_key_outlined),
          label: const Text('儲存 AI key'),
        ),
        if (message != null) ...[
          const SizedBox(height: AppTokens.spaceSm),
          Text(message!, style: textTheme.bodyMedium),
        ],
        if (error != null) ...[
          const SizedBox(height: AppTokens.spaceSm),
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _FileManagementSection extends StatelessWidget {
  const _FileManagementSection({
    required this.transferring,
    required this.savingCourse,
    required this.message,
    required this.summary,
    required this.error,
    required this.onExport,
    required this.onImport,
    required this.onSaveCourse,
  });

  final bool transferring;
  final bool savingCourse;
  final String? message;
  final MergeSummary? summary;
  final String? error;
  final VoidCallback onExport;
  final VoidCallback onImport;
  final VoidCallback onSaveCourse;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('檔案管理', style: textTheme.titleMedium),
        const SizedBox(height: AppTokens.spaceMd),
        Wrap(
          spacing: AppTokens.spaceSm,
          runSpacing: AppTokens.spaceSm,
          children: [
            FilledButton.icon(
              onPressed: transferring || savingCourse ? null : onSaveCourse,
              icon: savingCourse
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.inventory_2_outlined),
              label: const Text('儲存課件'),
            ),
            OutlinedButton.icon(
              onPressed: transferring ? null : onExport,
              icon: const Icon(Icons.file_upload_outlined),
              label: const Text('匯出進度'),
            ),
            OutlinedButton.icon(
              onPressed: transferring ? null : onImport,
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('匯入進度'),
            ),
          ],
        ),
        if (transferring) ...[
          const SizedBox(height: AppTokens.spaceMd),
          const LinearProgressIndicator(),
        ],
        if (message != null) ...[
          const SizedBox(height: AppTokens.spaceMd),
          Text(message!, style: textTheme.bodyMedium),
        ],
        if (summary != null) ...[
          const SizedBox(height: AppTokens.spaceXs),
          Text('套用 ${summary!.applied}，略過 ${summary!.skipped}'),
          if (summary!.resetLessons.isNotEmpty)
            Text('重置課件：${summary!.resetLessons.join(', ')}'),
        ],
        if (error != null) ...[
          const SizedBox(height: AppTokens.spaceMd),
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }
}

class _ArchivedGroupsSection extends StatelessWidget {
  const _ArchivedGroupsSection({
    required this.archivedGroups,
    required this.onRestore,
  });

  final AsyncValue<List<ArchivedGroup>> archivedGroups;
  final ValueChanged<String> onRestore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('歸檔練習組', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppTokens.spaceMd),
        archivedGroups.when(
          data: (groups) {
            if (groups.isEmpty) {
              return const Text('目前沒有歸檔練習組');
            }
            return Column(
              children: [
                for (final group in groups)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTokens.spaceSm),
                    child: _ArchivedGroupTile(
                      group: group,
                      onRestore: onRestore,
                    ),
                  ),
              ],
            );
          },
          error: (error, _) => Text('$error'),
          loading: () => const LinearProgressIndicator(),
        ),
      ],
    );
  }
}

class _ArchivedGroupTile extends StatelessWidget {
  const _ArchivedGroupTile({required this.group, required this.onRestore});

  final ArchivedGroup group;
  final ValueChanged<String> onRestore;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radius),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      leading: const Icon(Icons.archive_outlined),
      title: Text(group.lessonTitle),
      subtitle: Text(
        group.expired
            ? '已超過 168 小時'
            : '剩餘 ${_hoursLabel(group.remainingRestoreWindow)} 可恢復',
      ),
      trailing: FilledButton.icon(
        onPressed: group.expired ? null : () => onRestore(group.groupId),
        icon: const Icon(Icons.restore_outlined),
        label: const Text('恢復'),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.spaceMd),
      child: Row(
        children: [
          SizedBox(width: 96, child: Text(label)),
          IconButton.outlined(
            tooltip: '$label -1',
            onPressed: value <= 1 ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove),
          ),
          SizedBox(width: 48, child: Center(child: Text('$value'))),
          IconButton.outlined(
            tooltip: '$label +1',
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

String _hoursLabel(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60);
  return minutes == 0 ? '$hours 小時' : '$hours 小時 $minutes 分鐘';
}
