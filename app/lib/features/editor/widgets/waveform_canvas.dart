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
    this.prosody,
    this.hitToleranceDp = 12,
  });

  final List<WaveformPeak> peaks;
  final List<Syllable> syllables;
  final int totalDurationMs;
  final int? draggingBoundaryIndex;
  final int? draggingPreviewMs;
  final Prosody? prosody;

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
            final index = _hitTestBoundary(details.localPosition.dx, width);
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
                prosody: prosody,
                waveformColor: colorScheme.primary,
                needsReviewColor: AppTokens.needsReview,
                invalidSyllableColor: colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.7),
                boundaryColor: colorScheme.outline,
                draggingColor: colorScheme.tertiary,
                pitchColor: colorScheme.secondary,
                stressColor: colorScheme.tertiary,
                surfaceColor: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
              ),
              size: Size(
                width,
                constraints.hasBoundedHeight ? constraints.maxHeight : 180,
              ),
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
    required this.prosody,
    required this.waveformColor,
    required this.needsReviewColor,
    required this.invalidSyllableColor,
    required this.boundaryColor,
    required this.draggingColor,
    required this.pitchColor,
    required this.stressColor,
    required this.surfaceColor,
  });

  final List<WaveformPeak> peaks;
  final List<Syllable> syllables;
  final int totalDurationMs;
  final int? draggingBoundaryIndex;
  final int? draggingPreviewMs;
  final Prosody? prosody;
  final Color waveformColor;
  final Color needsReviewColor;
  final Color invalidSyllableColor;
  final Color boundaryColor;
  final Color draggingColor;
  final Color pitchColor;
  final Color stressColor;
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
      canvas.drawRect(Rect.fromLTRB(left, 0, right, size.height), reviewPaint);
    }

    // AT-05-03：資料損毀/無有效樣本音節以灰底標記，整體仍可渲染。
    final invalidPaint = Paint()..color = invalidSyllableColor;
    for (var i = 0; i < syllables.length; i++) {
      if (!_isInvalidSyllable(i)) continue;
      final syllable = syllables[i];
      final left = (syllable.startMs / totalDurationMs) * size.width;
      final right = (syllable.endMs / totalDurationMs) * size.width;
      canvas.drawRect(Rect.fromLTRB(left, 0, right, size.height), invalidPaint);
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

    _drawPitchCurve(canvas, size);
    _drawStressMarkers(canvas, size);

    // 邊界線（不畫拖動中那條，改畫 preview）
    final boundaryPaint = Paint()
      ..color = boundaryColor
      ..strokeWidth = 1;
    for (var i = 0; i < syllables.length - 1; i++) {
      if (i == draggingBoundaryIndex) continue;
      final boundaryMs = syllables[i].endMs;
      final x = (boundaryMs / totalDurationMs) * size.width;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), boundaryPaint);
    }

    // 拖動預覽線（藍/主色，高亮突出）
    if (draggingBoundaryIndex != null && draggingPreviewMs != null) {
      final x = (draggingPreviewMs! / totalDurationMs) * size.width;
      final draggingPaint = Paint()
        ..color = draggingColor
        ..strokeWidth = 2;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), draggingPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter old) {
    return old.peaks != peaks ||
        old.syllables != syllables ||
        old.prosody != prosody ||
        old.totalDurationMs != totalDurationMs ||
        old.draggingBoundaryIndex != draggingBoundaryIndex ||
        old.draggingPreviewMs != draggingPreviewMs;
  }

  bool _isInvalidSyllable(int index) {
    final current = prosody;
    if (current == null) return false;
    final rhythmInvalid =
        index < current.rhythm.length && current.rhythm[index].isNaN;
    final stressInvalid =
        index < current.stress.length && current.stress[index].isNaN;
    return rhythmInvalid || stressInvalid;
  }

  void _drawPitchCurve(Canvas canvas, Size size) {
    final current = prosody;
    final pitch = current?.pitchContour;
    if (current == null ||
        !current.pitchAvailable ||
        pitch == null ||
        pitch.length < 2) {
      return;
    }

    final finitePitch = pitch.where((value) => value.isFinite).toList();
    if (finitePitch.length < 2) return;

    final minPitch = finitePitch.reduce((a, b) => a < b ? a : b);
    final maxPitch = finitePitch.reduce((a, b) => a > b ? a : b);
    final span = maxPitch - minPitch;

    final path = Path();
    var started = false;
    for (var i = 0; i < pitch.length; i++) {
      final value = pitch[i];
      if (!value.isFinite) continue;
      final x = pitch.length == 1 ? 0.0 : (i / (pitch.length - 1)) * size.width;
      final normalized = span <= 0 ? 0.5 : (value - minPitch) / span;
      final y = size.height * (0.62 - normalized * 0.42);
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }
    if (!started) return;

    canvas.drawPath(
      path,
      Paint()
        ..color = pitchColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawStressMarkers(Canvas canvas, Size size) {
    final stress = prosody?.stress;
    if (stress == null || stress.isEmpty || syllables.isEmpty) return;

    final markerPaint = Paint()..color = stressColor.withValues(alpha: 0.8);
    for (var i = 0; i < syllables.length && i < stress.length; i++) {
      final value = stress[i];
      if (!value.isFinite) continue;
      final syllable = syllables[i];
      final centerMs = (syllable.startMs + syllable.endMs) / 2;
      final x = (centerMs / totalDurationMs) * size.width;
      final radius = 3 + value.clamp(0.0, 1.0) * 5;
      canvas.drawCircle(Offset(x, size.height - 18), radius, markerPaint);
    }
  }
}
