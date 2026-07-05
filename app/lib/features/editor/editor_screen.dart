// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/empty_state.dart';
import '../../shared/tokens.dart';
import '../import_analysis/analysis_controller.dart';

/// S1a 收尾用的編輯器最小殼：顯示分析結果摘要與音節列表。
/// 真正的 CustomPaint 波形／邊界拖動歸 S1b（frontend-design 功能點 3）。
class EditorScreen extends ConsumerWidget {
  const EditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(analysisControllerProvider);
    final result = state.result;

    if (result == null) {
      return const EmptyState(
        icon: Icons.tune_outlined,
        title: '尚無可校正的分析結果',
        message: '請先在「匯入」完成一次分析，這裡會顯示音節列表與待校正提示。',
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppTokens.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(result: result),
          const SizedBox(height: AppTokens.spaceLg),
          Expanded(child: _SyllableList(result: result)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.result});

  final AlignmentResult result;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('音節校正', style: textTheme.headlineSmall),
        const SizedBox(height: AppTokens.spaceXs),
        Text(
          '共 ${result.syllables.length} 個音節；信心 ${(result.confidence * 100).round()}%。',
          style: textTheme.bodyMedium,
        ),
        if (result.needsReview)
          Padding(
            padding: const EdgeInsets.only(top: AppTokens.spaceXs),
            child: Text(
              '有音節標為 needsReview（下列以警示色標示），S1b 波形拖動會在此上線。',
              style: textTheme.bodySmall
                  ?.copyWith(color: colorScheme.tertiary),
            ),
          ),
      ],
    );
  }
}

class _SyllableList extends StatelessWidget {
  const _SyllableList({required this.result});

  final AlignmentResult result;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemBuilder: (context, index) {
        final syllable = result.syllables[index];
        return _SyllableRow(index: index, syllable: syllable);
      },
      separatorBuilder: (_, __) =>
          const SizedBox(height: AppTokens.spaceXs),
      itemCount: result.syllables.length,
    );
  }
}

class _SyllableRow extends StatelessWidget {
  const _SyllableRow({required this.index, required this.syllable});

  final int index;
  final Syllable syllable;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = syllable.needsReview
        ? AppTokens.needsReview.withValues(alpha: 0.2)
        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceMd,
        vertical: AppTokens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Text('#${index + 1}',
                style: Theme.of(context).textTheme.labelSmall),
          ),
          const SizedBox(width: AppTokens.spaceSm),
          Expanded(
            child: Text(syllable.text,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Text(
            '${syllable.startMs}–${syllable.endMs} ms',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (syllable.needsReview)
            Padding(
              padding: const EdgeInsets.only(left: AppTokens.spaceSm),
              child: Text(
                'needsReview',
                style: TextStyle(color: colorScheme.tertiary),
              ),
            ),
        ],
      ),
    );
  }
}
