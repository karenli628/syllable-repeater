// AI-Generate
import 'package:flutter/material.dart';

import '../tokens.dart';

/// 播放控制條的最小殼元件；本輪 S1a 不接播放邏輯，僅提供視覺與 API 落點，
/// 讓 S2「句尾疊加練習」（frontend-design 功能點 4）與 editor 試聽（功能點 3）
/// 有共用元件可掛。
///
/// 真播放（just_audio / renderStep bytes）由 S2 的 practice controller 注入
/// `onPlay` / `onStop`；`state` 對應播放/停止/載入三態。
enum PlayerBarState { idle, loading, playing }

class PlayerBar extends StatelessWidget {
  const PlayerBar({
    super.key,
    required this.title,
    required this.state,
    this.subtitle,
    this.onPlay,
    this.onStop,
  });

  final String title;
  final String? subtitle;
  final PlayerBarState state;
  final VoidCallback? onPlay;
  final VoidCallback? onStop;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.spaceMd,
        vertical: AppTokens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTokens.radius),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          _playControl(context),
          const SizedBox(width: AppTokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (subtitle != null)
                  Text(subtitle!,
                      style: textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _playControl(BuildContext context) {
    switch (state) {
      case PlayerBarState.loading:
        return const SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      case PlayerBarState.playing:
        return IconButton.filled(
          onPressed: onStop,
          icon: const Icon(Icons.stop),
          tooltip: '停止',
        );
      case PlayerBarState.idle:
        return IconButton.filled(
          onPressed: onPlay,
          icon: const Icon(Icons.play_arrow),
          tooltip: '播放',
        );
    }
  }
}
