// AI-Generate
import 'dart:math' as math;

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import '../../../shared/tokens.dart';

class OverlayChart extends StatelessWidget {
  const OverlayChart({super.key, required this.data});

  final OverlayData data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('差異疊圖', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppTokens.spaceSm),
        SizedBox(
          height: 180,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppTokens.radius),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: CustomPaint(
              painter: _OverlayChartPainter(
                data: data,
                colorScheme: colorScheme,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverlayChartPainter extends CustomPainter {
  _OverlayChartPainter({required this.data, required this.colorScheme});

  final OverlayData data;
  final ColorScheme colorScheme;

  @override
  void paint(Canvas canvas, Size size) {
    final chart = Offset.zero & size;
    final midY = chart.top + chart.height * 0.5;
    final waveHeight = chart.height * 0.34;
    final axisPaint = Paint()
      ..color = colorScheme.outlineVariant
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(chart.left, midY),
      Offset(chart.right, midY),
      axisPaint,
    );

    _drawDiffRanges(canvas, chart);
    _drawWave(
      canvas,
      data.referenceWave,
      chart,
      midY,
      waveHeight,
      colorScheme.primary.withValues(alpha: 0.8),
    );
    _drawWave(
      canvas,
      data.userWave,
      chart,
      midY,
      waveHeight,
      AppTokens.difference.withValues(alpha: 0.78),
    );
    _drawPitch(
      canvas,
      data.referencePitch,
      chart,
      colorScheme.primary.withValues(alpha: 0.45),
      chart.height * 0.18,
    );
    _drawPitch(
      canvas,
      data.userPitch,
      chart,
      AppTokens.difference.withValues(alpha: 0.45),
      chart.height * 0.1,
    );
  }

  void _drawDiffRanges(Canvas canvas, Rect chart) {
    if (data.diffRanges.isEmpty) {
      return;
    }
    final durationMs = data.diffRanges
        .map((range) => range.endMs)
        .fold<int>(1, math.max);
    final paint = Paint()
      ..color = AppTokens.difference.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    for (final range in data.diffRanges) {
      final left = chart.left + chart.width * range.startMs / durationMs;
      final right = chart.left + chart.width * range.endMs / durationMs;
      canvas.drawRect(
        Rect.fromLTRB(
          left,
          chart.top,
          right.clamp(left + 1, chart.right),
          chart.bottom,
        ),
        paint,
      );
    }
  }

  void _drawWave(
    Canvas canvas,
    List<double> samples,
    Rect chart,
    double midY,
    double amplitude,
    Color color,
  ) {
    if (samples.length < 2) {
      return;
    }
    final path = Path();
    for (var i = 0; i < samples.length; i++) {
      final x = chart.left + chart.width * i / (samples.length - 1);
      final y = midY - samples[i].clamp(-1.0, 1.0) * amplitude;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawPitch(
    Canvas canvas,
    List<double> pitches,
    Rect chart,
    Color color,
    double topInset,
  ) {
    if (pitches.length < 2) {
      return;
    }
    final minPitch = pitches.reduce(math.min);
    final maxPitch = pitches.reduce(math.max);
    final range = math.max(1.0, maxPitch - minPitch);
    final path = Path();
    for (var i = 0; i < pitches.length; i++) {
      final x = chart.left + chart.width * i / (pitches.length - 1);
      final normalized = (pitches[i] - minPitch) / range;
      final y = chart.top + topInset + (1 - normalized) * chart.height * 0.22;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _OverlayChartPainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.colorScheme != colorScheme;
  }
}
