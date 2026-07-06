// AI-Generate
import 'dart:async';

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/tokens.dart';
import '../../progress/progress_service.dart';

class SettleBar extends ConsumerStatefulWidget {
  const SettleBar({super.key, required this.groupId, this.group});

  final String groupId;
  final PracticeGroup? group;

  @override
  ConsumerState<SettleBar> createState() => _SettleBarState();
}

class _SettleBarState extends ConsumerState<SettleBar> {
  SrsState? _lastState;
  Object? _error;
  bool _settling = false;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(AppTokens.radius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.spaceMd),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _lastState == null
                        ? '結算'
                        : '下次：${_dateLabel(_lastState!.nextDue)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_error != null)
                    Text(
                      '結算失敗',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            for (final item in const [
              (Difficulty.hard, '困難'),
              (Difficulty.normal, '普通'),
              (Difficulty.easy, '輕鬆'),
            ]) ...[
              const SizedBox(width: AppTokens.spaceSm),
              FilledButton(
                onPressed: _settling ? null : () => unawaited(_settle(item.$1)),
                child: Text(item.$2),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _settle(Difficulty difficulty) async {
    setState(() => _settling = true);
    try {
      final progressService = ref.read(progressServiceProvider);
      final group = widget.group;
      if (group != null) {
        await progressService.ensurePracticeGroup(group);
      }
      final result = await progressService.settle(widget.groupId, difficulty);
      if (mounted) {
        setState(() {
          _lastState = result;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) {
        setState(() => _settling = false);
      }
    }
  }
}

String _dateLabel(DateTime value) =>
    '${value.month}/${value.day} ${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';
