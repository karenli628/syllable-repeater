// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import '../../../shared/tokens.dart';

/// 波形＋音節邊界渲染（frontend-design 三-3、REQ-02 3.2.6 ≥30fps）。
///
/// 職責限縮：只做視覺與 hit-test；不呼叫 domain 介面（那由 controller 端負責）。
/// 使用者行為：
///   - `onPanDown` 若落在最近邊界 ±[hitToleranceDp] 內 → 呼叫 [onDragStart]
///   - 拖動中呼叫 [onDragUpdate]（僅本地預覽線，不打 domain，AT-02-03）
///   - 放開呼叫 [onDragEnd]（controller 端才呼叫介面 2）
class WaveformCanvas extends StatelessWidget {
  const WaveformCanvas({
    super.key,
    required this.peaks,
    required this.syllables,
    required this.totalDurationMs,
    required this.draggingBoundaryIndex,
    required this.draggingPreviewMs,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    this.hitToleranceDp = 12,
  });

  final List<WaveformPeak> peaks;
  final List<Syllable> syllables;
  final int totalDurationMs;
  final int? draggingBoundaryIndex;
  final int? draggingPreviewMs;

  final ValueChanged<int> onDragStart;
  final ValueChanged<int> onDragUpdate;
  final VoidCallback onDragEnd;
  final double hitToleranceDp;

  int? _hitTestBoundary(double dx, double width) {
    if (syllables.length < 2 || totalDurationMs <= 0) return null;
    int? bestIndex;
    double bestDistance = double.infinity;
    for (var i = 0; i < syllables.length - 1; i++) {
      final boundaryMs = syllables[i].endMs;
      final x = (boundaryMs / totalDurationMs) * width;
      final distance = (x - dx).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    if (bestIndex == null || bestDistance > hitToleranceDp) return null;
    return bestIndex;
  }

  int _pixelToMs(double dx, double width) {
    if (width <= 0 || totalDurationMs <= 0) return 0;
    final clamped = dx.clamp(0.0, width);
    return (clamped / width * totalDurationMs).round();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) {
            final index =
                _hitTestBoundary(details.localPosition.dx, width);
            if (index != null) onDragStart(index);
          },
          onPanUpdate: (details) {
            if (draggingBoundaryIndex == null) return;
            onDragUpdate(_pixelToMs(details.localPosition.dx, width));
          },
          onPanEnd: (_) {
            if (draggingBoundaryIndex == null) return;
            onDragEnd();
          },
          onPanCancel: () {
            if (draggingBoundaryIndex == null) return;
            onDragEnd();
          },
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _WaveformPainter(
                peaks: peaks,
                syllables: syllables,
                totalDurationMs: totalDurationMs,
                draggingBoundaryIndex: draggingBoundaryIndex,
                draggingPreviewMs: draggingPreviewMs,
                waveformColor: colorScheme.primary,
                needsReviewColor: AppTokens.needsReview,
                boundaryColor: colorScheme.outline,
                draggingColor: colorScheme.tertiary,
                surfaceColor:
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ),
              size: Size(width, constraints.hasBoundedHeight
                  ? constraints.maxHeight
                  : 180),
            ),
          ),
        );
      },
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.peaks,
    required this.syllables,
    required this.totalDurationMs,
    required this.draggingBoundaryIndex,
    required this.draggingPreviewMs,
    required this.waveformColor,
    required this.needsReviewColor,
    required this.boundaryColor,
    required this.draggingColor,
    required this.surfaceColor,
  });

  final List<WaveformPeak> peaks;
  final List<Syllable> syllables;
  final int totalDurationMs;
  final int? draggingBoundaryIndex;
  final int? draggingPreviewMs;
  final Color waveformColor;
  final Color needsReviewColor;
  final Color boundaryColor;
  final Color draggingColor;
  final Color surfaceColor;

  @override
  void paint(Canvas canvas, Size size) {
    // 背景
    canvas.drawRect(Offset.zero & size, Paint()..color = surfaceColor);

    if (totalDurationMs <= 0) return;

    // needsReview 音節整格灰底
    final reviewPaint = Paint()
      ..color = needsReviewColor.withValues(alpha: 0.18);
    for (final syllable in syllables) {
      if (!syllable.needsReview) continue;
      final left = (syllable.startMs / totalDurationMs) * size.width;
      final right = (syllable.endMs / totalDurationMs) * size.width;
      canvas.drawRect(
        Rect.fromLTRB(left, 0, right, size.height),
        reviewPaint,
      );
    }

    // 波形 bars
    if (peaks.isNotEmpty) {
      final barWidth = size.width / peaks.length;
      final midY = size.height / 2;
      final waveformPaint = Paint()
        ..color = waveformColor
        ..strokeWidth = 1;
      for (var i = 0; i < peaks.length; i++) {
        final peak = peaks[i];
        final x = i * barWidth + barWidth / 2;
        final topY = midY - peak.max * midY;
        final bottomY = midY - peak.min * midY;
        canvas.drawLine(Offset(x, topY), Offset(x, bottomY), waveformPaint);
      }
    }

    // 邊界線（不畫拖動中那條，改畫 preview）
    final boundaryPaint = Paint()
      ..color = boundaryColor
      ..strokeWidth = 1;
    for (var i = 0; i < syllables.length - 1; i++) {
      if (i == draggingBoundaryIndex) continue;
      final boundaryMs = syllables[i].endMs;
      final x = (boundaryMs / totalDurationMs) * size.width;
      canvas.drawLine(
          Offset(x, 0), Offset(x, size.height), boundaryPaint);
    }

    // 拖動預覽線（藍/主色，高亮突出）
    if (draggingBoundaryIndex != null && draggingPreviewMs != null) {
      final x = (draggingPreviewMs! / totalDurationMs) * size.width;
      final draggingPaint = Paint()
        ..color = draggingColor
        ..strokeWidth = 2;
      canvas.drawLine(
          Offset(x, 0), Offset(x, size.height), draggingPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) {
    return old.peaks != peaks ||
        old.syllables != syllables ||
        old.totalDurationMs != totalDurationMs ||
        old.draggingBoundaryIndex != draggingBoundaryIndex ||
        old.draggingPreviewMs != draggingPreviewMs;
  }
}
