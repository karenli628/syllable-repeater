// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import '../../../shared/tokens.dart';

/// 全檔波形與段落邊界互動（frontend-design.md 功能點 10、介面 21）。
///
/// Widget 只做繪製、hit-test 與本地拖曳預覽；Domain session 的提交由
/// LabelingController 在 [onDragEnd]／[onInsertBoundary]／[onRemoveBoundary]
/// 中完成，避免 UI 直接改 mutable Segment list。
class FullTrackWaveform extends StatelessWidget {
  const FullTrackWaveform({
    required this.peaks,
    required this.segments,
    required this.totalDurationMs,
    required this.selectedSegmentIndex,
    required this.draggingBoundaryIndex,
    required this.draggingPreviewMs,
    this.playheadMs,
    required this.onSelectSegment,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onInsertBoundary,
    required this.onRemoveBoundary,
    super.key,
    this.hitToleranceDp = 14,
  });

  final List<double> peaks;
  final List<Segment> segments;
  final int totalDurationMs;
  final int? selectedSegmentIndex;
  final int? draggingBoundaryIndex;
  final int? draggingPreviewMs;
  final int? playheadMs;
  final ValueChanged<int> onSelectSegment;
  final ValueChanged<int> onDragStart;
  final ValueChanged<int> onDragUpdate;
  final VoidCallback onDragEnd;
  final ValueChanged<int> onInsertBoundary;
  final ValueChanged<int> onRemoveBoundary;
  final double hitToleranceDp;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return SizedBox(
          height: 252,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  final index = _segmentAt(details.localPosition.dx, width);
                  if (index != null) onSelectSegment(index);
                },
                onPanDown: (details) {
                  final index = _hitTestBoundary(
                    details.localPosition.dx,
                    width,
                  );
                  if (index != null) onDragStart(index);
                },
                onPanUpdate: (details) {
                  if (draggingBoundaryIndex == null) return;
                  onDragUpdate(_pixelToMs(details.localPosition.dx, width));
                },
                onPanEnd: (_) {
                  if (draggingBoundaryIndex != null) onDragEnd();
                },
                onPanCancel: () {
                  if (draggingBoundaryIndex != null) onDragEnd();
                },
                child: CustomPaint(
                  painter: _FullTrackPainter(
                    peaks: peaks,
                    segments: segments,
                    totalDurationMs: totalDurationMs,
                    selectedSegmentIndex: selectedSegmentIndex,
                    draggingBoundaryIndex: draggingBoundaryIndex,
                    draggingPreviewMs: draggingPreviewMs,
                    colorScheme: Theme.of(context).colorScheme,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
              if (playheadMs != null && totalDurationMs > 0)
                Positioned(
                  key: const ValueKey('labeling-playhead'),
                  left:
                      (playheadMs!.clamp(0, totalDurationMs) /
                          totalDurationMs) *
                      width,
                  top: 0,
                  bottom: 28,
                  child: const IgnorePointer(
                    child: SizedBox(
                      width: 1,
                      child: CustomPaint(painter: _RedDashedAxisPainter()),
                    ),
                  ),
                ),
              for (var i = 0; i < segments.length - 1; i++)
                if (totalDurationMs > 0)
                  Positioned(
                    left: _boundaryX(i, width) - 18,
                    top: 4,
                    child: SizedBox.square(
                      dimension: 36,
                      child: IconButton(
                        tooltip: '刪除第 ${i + 1} 條標籤線',
                        padding: EdgeInsets.zero,
                        onPressed: () => onRemoveBoundary(i),
                        icon: const Icon(Icons.close, size: 16),
                      ),
                    ),
                  ),
              if (selectedSegmentIndex != null &&
                  selectedSegmentIndex! < segments.length &&
                  totalDurationMs > 0)
                Positioned(
                  left: _segmentCenterX(selectedSegmentIndex!, width) - 18,
                  bottom: 24,
                  child: SizedBox.square(
                    dimension: 36,
                    child: IconButton(
                      tooltip: '在此段中間新增標籤線',
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        final segment = segments[selectedSegmentIndex!];
                        onInsertBoundary(
                          segment.startMs +
                              ((segment.endMs - segment.startMs) ~/ 2),
                        );
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [const Text('0 ms'), Text('$totalDurationMs ms')],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int? _hitTestBoundary(double dx, double width) {
    if (segments.length < 2 || totalDurationMs <= 0) return null;
    int? bestIndex;
    var bestDistance = double.infinity;
    for (var i = 0; i < segments.length - 1; i++) {
      final distance = (_boundaryX(i, width) - dx).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    return bestDistance <= hitToleranceDp ? bestIndex : null;
  }

  int? _segmentAt(double dx, double width) {
    if (totalDurationMs <= 0) return null;
    final ms = _pixelToMs(dx, width);
    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      if (ms >= segment.startMs && ms <= segment.endMs) return i;
    }
    return null;
  }

  double _boundaryX(int index, double width) {
    return (segments[index].endMs / totalDurationMs) * width;
  }

  double _segmentCenterX(int index, double width) {
    final segment = segments[index];
    return (((segment.startMs + segment.endMs) / 2) / totalDurationMs) * width;
  }

  int _pixelToMs(double dx, double width) {
    if (width <= 0 || totalDurationMs <= 0) return 0;
    return (dx.clamp(0.0, width) / width * totalDurationMs).round();
  }
}

class _RedDashedAxisPainter extends CustomPainter {
  const _RedDashedAxisPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 2;
    for (var y = 0.0; y < size.height; y += 8) {
      canvas.drawLine(Offset.zero.translate(0, y), Offset(0, y + 4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FullTrackPainter extends CustomPainter {
  const _FullTrackPainter({
    required this.peaks,
    required this.segments,
    required this.totalDurationMs,
    required this.selectedSegmentIndex,
    required this.draggingBoundaryIndex,
    required this.draggingPreviewMs,
    required this.colorScheme,
  });

  final List<double> peaks;
  final List<Segment> segments;
  final int totalDurationMs;
  final int? selectedSegmentIndex;
  final int? draggingBoundaryIndex;
  final int? draggingPreviewMs;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final trackHeight = size.height - 28;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, trackHeight),
      Paint()
        ..color = colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
    );
    if (totalDurationMs <= 0) return;

    if (selectedSegmentIndex != null &&
        selectedSegmentIndex! < segments.length) {
      final selected = segments[selectedSegmentIndex!];
      canvas.drawRect(
        Rect.fromLTRB(
          _x(selected.startMs, size.width),
          0,
          _x(selected.endMs, size.width),
          trackHeight,
        ),
        Paint()..color = AppTokens.selectedHighlight.withValues(alpha: 0.22),
      );
    }

    if (peaks.isNotEmpty) {
      final paint = Paint()
        ..color = colorScheme.primary
        ..strokeWidth = 1;
      final center = trackHeight / 2;
      final step = size.width / peaks.length;
      for (var i = 0; i < peaks.length; i++) {
        final amplitude = peaks[i].abs().clamp(0.02, 1.0).toDouble();
        final x = (i + 0.5) * step;
        final extent = amplitude * center * 0.85;
        canvas.drawLine(
          Offset(x, center - extent),
          Offset(x, center + extent),
          paint,
        );
      }
    }

    final boundaryPaint = Paint()
      ..color = colorScheme.outline
      ..strokeWidth = 1;
    for (var i = 0; i < segments.length - 1; i++) {
      if (i == draggingBoundaryIndex) continue;
      final x = _x(segments[i].endMs, size.width);
      canvas.drawLine(Offset(x, 0), Offset(x, trackHeight), boundaryPaint);
    }
    if (draggingBoundaryIndex != null && draggingPreviewMs != null) {
      final x = _x(draggingPreviewMs!, size.width);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, trackHeight),
        Paint()
          ..color = colorScheme.tertiary
          ..strokeWidth = 2,
      );
    }
  }

  double _x(int ms, double width) => (ms / totalDurationMs) * width;

  @override
  bool shouldRepaint(covariant _FullTrackPainter oldDelegate) =>
      oldDelegate.peaks != peaks ||
      oldDelegate.segments != segments ||
      oldDelegate.totalDurationMs != totalDurationMs ||
      oldDelegate.selectedSegmentIndex != selectedSegmentIndex ||
      oldDelegate.draggingBoundaryIndex != draggingBoundaryIndex ||
      oldDelegate.draggingPreviewMs != draggingPreviewMs ||
      oldDelegate.colorScheme != colorScheme;
}
