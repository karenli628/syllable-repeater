// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';

import '../../../shared/tokens.dart';
import '../waveform_node_range.dart';

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
    this.selectedSyllableIndex,
    this.selectedTimeRange,
    this.playheadMs,
    this.onSelectSyllable,
    this.onTimeSelectionStart,
    this.onTimeSelectionUpdate,
    this.onTimeSelectionEnd,
    this.onRemoveBoundary,
    this.onInsertBoundary,
    this.hitToleranceDp = 12,
  });

  final List<WaveformPeak> peaks;
  final List<Syllable> syllables;
  final int totalDurationMs;
  final int? draggingBoundaryIndex;
  final int? draggingPreviewMs;
  final Prosody? prosody;

  /// 目前共用選取的音節 index（frontend-design FP12、AT-13-01）。
  final int? selectedSyllableIndex;

  /// 波形框選的半開時間範圍（REQ-17／AT-17-01）。
  final TimeRange? selectedTimeRange;

  /// 播放中的原音位置；只負責顯示，不改動音訊或切點（REQ-13）。
  final int? playheadMs;

  /// 點選波形音節區段時通知 controller（REQ-13、AT-13-01）。
  final ValueChanged<int>? onSelectSyllable;

  final ValueChanged<int>? onTimeSelectionStart;
  final ValueChanged<int>? onTimeSelectionUpdate;
  final VoidCallback? onTimeSelectionEnd;

  /// 按下邊界上的「×」時通知 controller（REQ-13、AT-13-02）。
  final ValueChanged<int>? onRemoveBoundary;

  /// 按下音節內「＋」時通知 controller（REQ-13、AT-13-05）。
  final void Function(int syllableIndex, int atMs)? onInsertBoundary;

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

  int? _syllableIndexAt(double dx, double width) {
    if (syllables.isEmpty || totalDurationMs <= 0 || width <= 0) return null;
    final atMs = _pixelToMs(dx, width);
    for (var i = 0; i < syllables.length; i++) {
      final range = waveformNodeRange(
        syllables: syllables,
        syllableIndex: i,
        totalDurationMs: totalDurationMs,
      );
      if (atMs >= range.startMs && atMs < range.endMs) return i;
    }
    return atMs == totalDurationMs ? syllables.length - 1 : null;
  }

  bool _canInsertAt(TimeRange range, int atMs) {
    // AT-13-05：前端預防距兩側少於 50ms；Domain 仍會再次驗證。
    return atMs - range.startMs >= 50 && range.endMs - atMs >= 50;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height =
            (constraints.hasBoundedHeight ? constraints.maxHeight : 180)
                .toDouble();
        final painter = _WaveformPainter(
          peaks: peaks,
          syllables: syllables,
          totalDurationMs: totalDurationMs,
          draggingBoundaryIndex: draggingBoundaryIndex,
          draggingPreviewMs: draggingPreviewMs,
          selectedSyllableIndex: selectedSyllableIndex,
          selectedTimeRange: selectedTimeRange,
          prosody: prosody,
          waveformColor: colorScheme.primary,
          needsReviewColor: AppTokens.needsReview,
          selectedColor: AppTokens.selectedHighlight,
          invalidSyllableColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.7,
          ),
          boundaryColor: colorScheme.outline,
          draggingColor: colorScheme.tertiary,
          pitchColor: colorScheme.secondary,
          stressColor: colorScheme.tertiary,
          surfaceColor: colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
        );
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanDown: (details) {
            final index = _hitTestBoundary(details.localPosition.dx, width);
            if (index != null) {
              onDragStart(index);
              return;
            }
            // 以 pan down 作為選取手勢，避免另掛 Tap recognizer 影響既有
            // 邊界拖曳的 gesture arena；點擊音節時不需等到放開才高亮。
            final syllableIndex = _syllableIndexAt(
              details.localPosition.dx,
              width,
            );
            if (syllableIndex != null) {
              final atMs = _pixelToMs(details.localPosition.dx, width);
              if (onTimeSelectionStart != null) {
                onTimeSelectionStart?.call(atMs);
              } else {
                onSelectSyllable?.call(syllableIndex);
              }
            }
          },
          onPanUpdate: (details) {
            // controller 端會忽略未由 onPanDown 命中的更新；保持 gesture
            // recognizer 在 StatefulBuilder 重建時仍能送出本地預覽。
            final atMs = _pixelToMs(details.localPosition.dx, width);
            onDragUpdate(atMs);
            onTimeSelectionUpdate?.call(atMs);
          },
          onPanEnd: (_) {
            if (draggingBoundaryIndex != null) onDragEnd();
            onTimeSelectionEnd?.call();
          },
          onPanCancel: () {
            if (draggingBoundaryIndex != null) onDragEnd();
            onTimeSelectionEnd?.call();
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              RepaintBoundary(
                child: CustomPaint(painter: painter, size: Size(width, height)),
              ),
              if (playheadMs != null && totalDurationMs > 0)
                Positioned(
                  key: const ValueKey('editor-playhead'),
                  left:
                      (playheadMs!.clamp(0, totalDurationMs) /
                          totalDurationMs) *
                      width,
                  top: 0,
                  bottom: 0,
                  child: const IgnorePointer(
                    child: SizedBox(
                      width: 1,
                      child: CustomPaint(painter: _RedDashedAxisPainter()),
                    ),
                  ),
                ),
              for (var i = 0; i < syllables.length - 1; i++)
                if (onRemoveBoundary != null)
                  _buildBoundaryButton(context, i, width, height),
              for (var i = 0; i < syllables.length; i++)
                if (onInsertBoundary != null)
                  _buildInsertButton(context, i, width, height),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBoundaryButton(
    BuildContext context,
    int boundaryIndex,
    double width,
    double height,
  ) {
    final x = totalDurationMs <= 0
        ? 0.0
        : (syllables[boundaryIndex].endMs / totalDurationMs) * width;
    final label = '刪除切點 ${boundaryIndex + 1}';
    return Positioned(
      left: (x - 20).clamp(0.0, (width - 40).clamp(0.0, width)),
      top: 0,
      width: 40,
      height: 40,
      child: Tooltip(
        message: label,
        child: IconButton(
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          onPressed: () => onRemoveBoundary?.call(boundaryIndex),
          icon: const Icon(Icons.close),
        ),
      ),
    );
  }

  Widget _buildInsertButton(
    BuildContext context,
    int syllableIndex,
    double width,
    double height,
  ) {
    final range = waveformNodeRange(
      syllables: syllables,
      syllableIndex: syllableIndex,
      totalDurationMs: totalDurationMs,
    );
    final atMs = ((range.startMs + range.endMs) / 2).round();
    final enabled = totalDurationMs > 0 && _canInsertAt(range, atMs);
    final centerMs = (range.startMs + range.endMs) / 2;
    final x = totalDurationMs <= 0 ? 0.0 : (centerMs / totalDurationMs) * width;
    final label = '新增切點 ${syllableIndex + 1}';
    return Positioned(
      left: (x - 20).clamp(0.0, (width - 40).clamp(0.0, width)),
      top: (height - 40).clamp(0.0, height),
      width: 40,
      height: 40,
      child: Tooltip(
        message: label,
        child: IconButton(
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          onPressed: enabled
              ? () => onInsertBoundary?.call(syllableIndex, atMs)
              : null,
          icon: const Icon(Icons.add),
        ),
      ),
    );
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
      canvas.drawLine(Offset(0, y), Offset(0, y + 4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.peaks,
    required this.syllables,
    required this.totalDurationMs,
    required this.draggingBoundaryIndex,
    required this.draggingPreviewMs,
    required this.selectedSyllableIndex,
    required this.selectedTimeRange,
    required this.prosody,
    required this.waveformColor,
    required this.needsReviewColor,
    required this.selectedColor,
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
  final int? selectedSyllableIndex;
  final TimeRange? selectedTimeRange;
  final Prosody? prosody;
  final Color waveformColor;
  final Color needsReviewColor;
  final Color selectedColor;
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

    // AT-13-01：共用選取音節以黃色區段高亮，保留 needsReview/韻律底色資訊。
    final selectedRange = _effectiveSelectedRange();
    if (selectedRange != null) {
      final left = (selectedRange.startMs / totalDurationMs) * size.width;
      final right = (selectedRange.endMs / totalDurationMs) * size.width;
      canvas.drawRect(
        Rect.fromLTRB(left, 0, right, size.height),
        Paint()..color = selectedColor.withValues(alpha: 0.24),
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
      final selectedBoundary =
          selectedRange != null &&
          boundaryMs >= selectedRange.startMs &&
          boundaryMs <= selectedRange.endMs;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        selectedBoundary
            ? (Paint()
                ..color = selectedColor
                ..strokeWidth = 2)
            : boundaryPaint,
      );
      canvas.drawCircle(
        Offset(x, 18),
        10,
        Paint()..color = selectedBoundary ? selectedColor : boundaryColor,
      );
      final numberPainter = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      numberPainter.paint(
        canvas,
        Offset(x - numberPainter.width / 2, 18 - numberPainter.height / 2),
      );
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
        old.draggingPreviewMs != draggingPreviewMs ||
        old.selectedSyllableIndex != selectedSyllableIndex ||
        old.selectedTimeRange != selectedTimeRange;
  }

  TimeRange? _effectiveSelectedRange() {
    final selected = selectedSyllableIndex;
    if (selected == null || selected < 0 || selected >= syllables.length) {
      return selectedTimeRange;
    }
    final rawRange = syllables[selected].range;
    if (selectedTimeRange != null && selectedTimeRange != rawRange) {
      return selectedTimeRange;
    }
    return waveformNodeRange(
      syllables: syllables,
      syllableIndex: selected,
      totalDurationMs: totalDurationMs,
    );
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
