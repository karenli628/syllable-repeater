// AI-Generate
import '../model/pcm.dart';

/// 零交越吸附搜尋窗上限（requirement §2.5 M1 允許的收尾處理；backend-design §0.1
/// 明訂「≤10ms fade 除外」）。此常數同時作為切點吸附與 renderStep 端點 fade 的
/// 對稱時間窗，跨 3.7／4.4 共用。
const int kZeroCrossingSearchWindowMs = 10;

/// 從 [targetMs] 出發，對稱搜尋 ≤±[kZeroCrossingSearchWindowMs] 內最近的零交越
/// sample（相鄰兩 sample 值變號或前一 sample 為 0 均算），回傳其對應毫秒；
/// 找不到則回傳原 [targetMs]（不吸附，仍由呼叫端決定是否 fade 收尾）。
///
/// 純函式，無 dart:io／無 flutter 依賴（M5 Domain 純 Dart 防線 domain_purity_test
/// 會掃描此檔）。
int findNearestZeroCrossingMs(Pcm pcm, {required int targetMs}) {
  final samples = pcm.samples;
  if (samples.isEmpty) return targetMs;

  final windowSamples = (kZeroCrossingSearchWindowMs * pcm.sampleRate) ~/ 1000;
  final anchor = pcm.sampleIndexAtMs(targetMs).clamp(0, samples.length - 1);
  final lower = (anchor - windowSamples).clamp(0, samples.length - 1);
  final upper = (anchor + windowSamples).clamp(0, samples.length - 1);

  int? bestIndex;
  int bestDistance = 1 << 30;
  for (var i = lower; i <= upper; i++) {
    final prev = i > 0 ? samples[i - 1] : 0;
    final curr = samples[i];
    final isCrossing =
        (prev == 0 && curr != 0) ||
            (prev > 0 && curr <= 0) ||
            (prev < 0 && curr >= 0);
    if (!isCrossing) continue;
    final distance = (i - anchor).abs();
    if (distance < bestDistance) {
      bestDistance = distance;
      bestIndex = i;
    }
  }

  if (bestIndex == null) return targetMs;
  return (bestIndex * 1000) ~/ pcm.sampleRate;
}
