// AI-Generate
import 'package:flutter/material.dart';

import 'tokens.dart';

/// 視窗自適應模式（frontend-design.md §二、功能點 9；REQ-10）。
enum ResponsiveLayoutMode { wide, stacked }

/// 全域佈局的斷點判定殼層。
///
/// 以 [LayoutBuilder] 取得當下 viewport，≥1280px 暴露 wide 模式給各
/// feature screen，低於斷點則由 screen 自行採上下堆疊。macOS 原生視窗
/// 已限制 1100×700，因此本殼層不得再建立第三層垂直捲動（AT-15-19）。
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    required this.child,
    super.key,
    this.minWidth = AppTokens.minimumWindowWidth,
    this.minHeight = AppTokens.minimumWindowHeight,
  });

  static const double wideBreakpoint = 1280;

  final Widget child;
  final double minWidth;
  final double minHeight;

  /// 1280px 邊界的單一判定入口（AT-10-01）。
  static ResponsiveLayoutMode modeForWidth(double width) =>
      width >= wideBreakpoint
      ? ResponsiveLayoutMode.wide
      : ResponsiveLayoutMode.stacked;

  /// 供 feature screen 在自己的 LayoutBuilder 中查詢目前模式。
  static ResponsiveLayoutMode modeOf(BuildContext context) {
    return modeForWidth(MediaQuery.sizeOf(context).width);
  }

  @override
  Widget build(BuildContext context) => SizedBox.expand(child: child);
}

/// 波形／文字等雙欄頁面的共用重排容器（frontend-design.md §二、功能點 9）。
///
/// 寬度達 1280px 時並排；低於斷點時上下堆疊。此元件只負責幾何重排，
/// 不持有 feature 狀態，因而縮放不會重建或清掉編輯內容。
class ResponsiveTwoPane extends StatelessWidget {
  const ResponsiveTwoPane({
    required this.primary,
    required this.secondary,
    super.key,
    this.gap = AppTokens.spaceMd,
  });

  final Widget primary;
  final Widget secondary;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mode = ResponsiveLayout.modeForWidth(constraints.maxWidth);
        if (mode == ResponsiveLayoutMode.wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: primary),
              SizedBox(width: gap),
              Expanded(child: secondary),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            primary,
            SizedBox(height: gap),
            secondary,
          ],
        );
      },
    );
  }
}
