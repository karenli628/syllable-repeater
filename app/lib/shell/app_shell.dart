// AI-Generate
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/editor/editor_screen.dart';
import '../features/import_analysis/import_screen.dart';
import '../shared/empty_state.dart';
import '../shared/navigation.dart';
import '../shared/tokens.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(appShellSelectedIndexProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: AppTokens.minimumWindowWidth,
              minHeight: AppTokens.minimumWindowHeight,
            ),
            child: SizedBox(
              width: AppTokens.minimumWindowSize.width,
              height: AppTokens.minimumWindowSize.height,
              child: Row(
                children: [
                  NavigationRail(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (index) {
                      ref
                          .read(appShellSelectedIndexProvider.notifier)
                          .select(index);
                    },
                    labelType: NavigationRailLabelType.all,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTokens.spaceLg,
                      ),
                      child: Icon(
                        Icons.graphic_eq,
                        color: colorScheme.primary,
                        size: 30,
                      ),
                    ),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.library_music_outlined),
                        selectedIcon: Icon(Icons.library_music),
                        label: Text('課件庫'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.upload_file_outlined),
                        selectedIcon: Icon(Icons.upload_file),
                        label: Text('匯入'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.tune_outlined),
                        selectedIcon: Icon(Icons.tune),
                        label: Text('校正'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.play_circle_outline),
                        selectedIcon: Icon(Icons.play_circle),
                        label: Text('練習'),
                      ),
                    ],
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: colorScheme.outlineVariant,
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: selectedIndex,
                      children: const [
                        _PlaceholderScreen(
                          icon: Icons.library_music_outlined,
                          title: '課件庫',
                          message: '完成匯入後，課件會從這裡進入練習與校正。',
                        ),
                        ImportScreen(),
                        EditorScreen(),
                        _PlaceholderScreen(
                          icon: Icons.play_circle_outline,
                          title: '句尾疊加練習',
                          message: 'S2 會在這裡播放 11 步原聲疊加練習。',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return EmptyState(icon: icon, title: title, message: message);
  }
}
