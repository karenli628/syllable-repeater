// AI-Generate
import 'package:flutter/material.dart';

import '../../../shared/tokens.dart';

class ProsodyOverlayControls extends StatelessWidget {
  const ProsodyOverlayControls({
    super.key,
    required this.enabled,
    required this.pitchAvailable,
    required this.onChanged,
  });

  final bool enabled;
  final bool? pitchAvailable;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppTokens.spaceSm,
      runSpacing: AppTokens.spaceXs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: enabled, onChanged: onChanged),
            const Text('韻律疊圖'),
          ],
        ),
        if (pitchAvailable == false)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.spaceSm,
              vertical: AppTokens.spaceXs,
            ),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(AppTokens.radius),
            ),
            child: Text(
              '音高不可用',
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}
