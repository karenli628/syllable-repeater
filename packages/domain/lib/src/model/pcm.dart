// AI-Generate
import 'dart:typed_data';

import 'time_range.dart';

/// 解碼後的原音 PCM（16-bit / mono；取樣率預設 44100，backend-design.md §3.2.1 依賴介面）。
/// §0.1/M1：一切練習音訊的唯一來源；分析模組只讀不寫。
class Pcm {
  final Int16List samples;
  final int sampleRate;

  const Pcm(this.samples, {this.sampleRate = 44100});

  int get durationMs => (samples.length * 1000) ~/ sampleRate;

  /// 毫秒 → sample index（下取整）。
  int sampleIndexAtMs(int ms) => (ms * sampleRate) ~/ 1000;

  /// 依原音時間範圍取 sample 子集；不改寫來源 PCM（REQ-12、M1）。
  Pcm slice(TimeRange range) {
    if (range.endMs > durationMs) {
      throw ArgumentError(
        'TimeRange 不可超過 PCM 時長（got ${range.endMs}ms、duration=${durationMs}ms）',
      );
    }
    final start = sampleIndexAtMs(range.startMs);
    final end = sampleIndexAtMs(range.endMs);
    if (end <= start || start < 0 || end > samples.length) {
      throw ArgumentError(
        'TimeRange 無法映射為有效 sample 範圍（got ${range.startMs}..${range.endMs}ms）',
      );
    }
    return Pcm(
      Int16List.fromList(samples.sublist(start, end)),
      sampleRate: sampleRate,
    );
  }
}
