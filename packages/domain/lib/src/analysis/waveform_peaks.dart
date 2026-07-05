// AI-Generate
import 'dart:math' as math;

import '../model/pcm.dart';

/// 前端 CustomPainter 使用的波形峰值快取（task-split 3.5）。
class WaveformPeak {
  final double min;
  final double max;

  WaveformPeak(this.min, this.max) {
    if (min < -1 || min > 1 || max < -1 || max > 1 || min > max) {
      throw ArgumentError('WaveformPeak 需滿足 -1 <= min <= max <= 1');
    }
  }
}

List<WaveformPeak> computeWaveformPeaks(Pcm pcm, {required int bucketCount}) {
  if (bucketCount < 1) {
    throw ArgumentError('bucketCount 必須 >= 1');
  }
  if (pcm.samples.isEmpty) {
    return const [];
  }

  final buckets = math.min(bucketCount, pcm.samples.length);
  final peaks = <WaveformPeak>[];
  for (var i = 0; i < buckets; i++) {
    final start = (pcm.samples.length * i) ~/ buckets;
    final end = i == buckets - 1
        ? pcm.samples.length
        : (pcm.samples.length * (i + 1)) ~/ buckets;

    var minValue = 32767;
    var maxValue = -32768;
    for (var j = start; j < end; j++) {
      final sample = pcm.samples[j];
      if (sample < minValue) {
        minValue = sample;
      }
      if (sample > maxValue) {
        maxValue = sample;
      }
    }
    peaks.add(WaveformPeak(minValue / 32768, maxValue / 32767));
  }
  return List.unmodifiable(peaks);
}
