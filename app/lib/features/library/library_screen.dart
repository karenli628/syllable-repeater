// AI-Generate
import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:infra/infra.dart' show AppDatabase;

import '../../shared/empty_state.dart';
import '../../shared/navigation.dart';
import '../../shared/tokens.dart';
import '../pack_translate/lesson_session_controller.dart';
import '../progress/progress_service.dart';
import 'lesson_pack_service.dart';

final libraryDueListProvider = FutureProvider<List<DueGroup>>((ref) {
  return ref.watch(progressServiceProvider).dueList(DateTime.now().toUtc());
});

final libraryLessonEntriesProvider = FutureProvider<List<LessonLibraryEntry>>((
  ref,
) async {
  return _loadLessonEntries(ref.watch(appDatabaseProvider));
});

class LessonLibraryEntry {
  const LessonLibraryEntry({
    required this.id,
    required this.title,
    required this.packPath,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String packPath;
  final DateTime updatedAt;
}

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(libraryDueListProvider);
    final lessons = ref.watch(libraryLessonEntriesProvider);
    return Padding(
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      child: ListView(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '課件庫',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton.outlined(
                tooltip: '重新整理',
                onPressed: () {
                  ref.invalidate(libraryDueListProvider);
                  ref.invalidate(libraryLessonEntriesProvider);
                },
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.spaceMd),
          SizedBox(
            height: 190,
            child: due.when(
              data: (items) => items.isEmpty
                  ? const EmptyState(
                      icon: Icons.library_music_outlined,
                      title: '目前沒有到期練習',
                      message: '完成課件後，今日可練清單會顯示在這裡。',
                    )
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppTokens.spaceSm),
                      itemBuilder: (context, index) =>
                          _DueTile(item: items[index]),
                    ),
              error: (error, _) => EmptyState(
                icon: Icons.error_outline,
                title: '讀取失敗',
                message: '$error',
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
          ),
          const SizedBox(height: AppTokens.spaceMd),
          _LessonLibrarySection(lessons: lessons),
          const SizedBox(height: AppTokens.spaceMd),
          const _PackTranslationPanel(),
        ],
      ),
    );
  }
}

class _LessonLibrarySection extends ConsumerWidget {
  const _LessonLibrarySection({required this.lessons});

  final AsyncValue<List<LessonLibraryEntry>> lessons;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 170,
      child: lessons.when(
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.folder_open_outlined,
              title: '尚未儲存課件',
              message: '儲存 .abopack 後會顯示在這裡。',
            );
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppTokens.spaceSm),
            itemBuilder: (context, index) => _LessonCard(
              entry: items[index],
              onPractice: () => unawaited(
                _openEntry(context, ref, items[index], AppSection.practice),
              ),
              onEdit: () => unawaited(
                _openEntry(context, ref, items[index], AppSection.editor),
              ),
            ),
          );
        },
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: '課件清單讀取失敗',
          message: '$error',
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _openEntry(
    BuildContext context,
    WidgetRef ref,
    LessonLibraryEntry entry,
    AppSection section,
  ) async {
    try {
      final lesson = await ref
          .read(lessonPackServiceProvider)
          .open(entry.packPath);
      await ref
          .read(lessonSessionControllerProvider.notifier)
          .hydrateLesson(lesson, sourcePath: entry.packPath);
      ref
          .read(appShellSelectedIndexProvider.notifier)
          .select(section.sectionIndex);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(_describePackError(error))));
    }
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.entry,
    required this.onPractice,
    required this.onEdit,
  });

  final LessonLibraryEntry entry;
  final VoidCallback onPractice;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 280,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.radius),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppTokens.spaceXs),
              Text(
                _fileName(entry.packPath),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Wrap(
                spacing: AppTokens.spaceSm,
                children: [
                  OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.tune_outlined),
                    label: const Text('編輯'),
                  ),
                  FilledButton.icon(
                    onPressed: onPractice,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('練習'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DueTile extends ConsumerWidget {
  const _DueTile({required this.item});

  final DueGroup item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radius),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      leading: const Icon(Icons.play_circle_outline),
      title: Text(item.lessonTitle),
      subtitle: Text('下次：${_dateLabel(item.nextDue)}'),
      trailing: Wrap(
        spacing: AppTokens.spaceSm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(_priorityLabel(item.priority)),
          IconButton.outlined(
            tooltip: '歸檔 ${item.lessonTitle}',
            onPressed: () => unawaited(_confirmArchive(context, ref)),
            icon: const Icon(Icons.archive_outlined),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmArchive(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('歸檔練習組'),
        content: Text('${item.lessonTitle} 會移到歸檔區，168 小時內可恢復。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.archive_outlined),
            label: const Text('歸檔'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(progressServiceProvider).archive(item.groupId);
      ref.invalidate(libraryDueListProvider);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

class _PackTranslationPanel extends ConsumerStatefulWidget {
  const _PackTranslationPanel();

  @override
  ConsumerState<_PackTranslationPanel> createState() =>
      _PackTranslationPanelState();
}

class _PackTranslationPanelState extends ConsumerState<_PackTranslationPanel> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyO, meta: true):
            _openShortcut,
        const SingleActivator(LogicalKeyboardKey.keyO, control: true):
            _openShortcut,
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
            _saveShortcut,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            _saveShortcut,
      },
      child: Focus(
        autofocus: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(AppTokens.radius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.spaceMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('譯文', style: textTheme.titleMedium),
                const SizedBox(height: AppTokens.spaceSm),
                TextField(
                  controller: _controller,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '手動譯文',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppTokens.spaceSm),
                Wrap(
                  spacing: AppTokens.spaceSm,
                  runSpacing: AppTokens.spaceSm,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => unawaited(_openPack()),
                      icon: const Icon(Icons.folder_open_outlined),
                      label: const Text('開啟課件'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => unawaited(_savePack()),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('儲存課件'),
                    ),
                    Tooltip(
                      message: '尚未設定 AI key',
                      child: FilledButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: const Text('自動翻譯'),
                      ),
                    ),
                  ],
                ),
                if (_busy) ...[
                  const SizedBox(height: AppTokens.spaceSm),
                  const LinearProgressIndicator(),
                ],
                if (_message != null) ...[
                  const SizedBox(height: AppTokens.spaceSm),
                  Text(_message!, style: textTheme.bodyMedium),
                ],
                if (_error != null) ...[
                  const SizedBox(height: AppTokens.spaceSm),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openShortcut() {
    if (_busy) {
      return;
    }
    unawaited(_openPack());
  }

  void _saveShortcut() {
    if (_busy) {
      return;
    }
    unawaited(_savePack());
  }

  Future<void> _openPack() async {
    final path = await ref.read(lessonPackFilePickerProvider).pickOpenPath();
    if (!mounted || path == null) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
      _error = null;
    });
    try {
      final lesson = await ref.read(lessonPackServiceProvider).open(path);
      await ref
          .read(lessonSessionControllerProvider.notifier)
          .hydrateLesson(lesson, sourcePath: path);
      if (!mounted) {
        return;
      }
      final translation = _preferredTranslation(lesson);
      setState(() {
        _controller.text = translation ?? '';
        _message = '已開啟：${lesson.title}';
      });
      ref.invalidate(libraryLessonEntriesProvider);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = _describePackError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _savePack() async {
    final path = await ref.read(lessonPackFilePickerProvider).pickSavePath();
    if (!mounted || path == null) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
      _error = null;
    });
    try {
      final lesson = ref.read(currentLessonDraftBuilderProvider)(
        _controller.text,
      );
      final hydratedLesson = lesson.withContentHash();
      final writtenPath = await ref
          .read(lessonPackServiceProvider)
          .save(hydratedLesson, path);
      await ref
          .read(lessonSessionControllerProvider.notifier)
          .hydrateLesson(hydratedLesson, sourcePath: writtenPath);
      if (!mounted) {
        return;
      }
      setState(() => _message = '已儲存：$writtenPath');
      ref.invalidate(libraryLessonEntriesProvider);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = _describePackError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

String? _preferredTranslation(Lesson lesson) {
  for (final translation in lesson.translations) {
    if (translation.source == TranslationSource.manual) {
      return translation.text;
    }
  }
  return lesson.translations.isEmpty ? null : lesson.translations.first.text;
}

String _describePackError(Object error) =>
    error is DomainException ? error.message : '$error';

String _priorityLabel(int priority) => switch (priority) {
  3 => '困難',
  2 => '普通',
  _ => '輕鬆',
};

Future<List<LessonLibraryEntry>> _loadLessonEntries(AppDatabase db) async {
  final rows = await db.select(db.lessonRegistry).get();
  rows.sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
  return List.unmodifiable(
    rows.map(
      (row) => LessonLibraryEntry(
        id: row.id,
        title: row.title,
        packPath: row.packPath,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row.updatedAt,
          isUtc: true,
        ),
      ),
    ),
  );
}

String _dateLabel(DateTime value) =>
    '${value.month}/${value.day} ${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

String _fileName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.lastIndexOf('/');
  return index == -1 ? normalized : normalized.substring(index + 1);
}
