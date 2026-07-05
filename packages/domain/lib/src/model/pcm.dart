// AI-Generate
import 'dart:typed_data';

/// 解碼後的原音 PCM（16-bit / mono；取樣率預設 44100，backend-design.md §3.2.1 依賴介面）。
/// §0.1/M1：一切練習音訊的唯一來源；分析模組只讀不寫。
class Pcm {
  final Int16List samples;
  final int sampleRate;

  const Pcm(this.samples, {this.sampleRate = 44100});

  int get durationMs => (samples.length * 1000) ~/ sampleRate;

  /// 毫秒 → sample index（下取整）。
  int sampleIndexAtMs(int ms) => (ms * sampleRate) ~/ 1000;
}
