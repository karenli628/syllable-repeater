// AI-Generate
import '../analysis/waveform_peaks.dart';

/// 波形 peaks 快取抽象（frontend-design 三-3「peaks 預算快取」；task-split
/// FP3）——避免重新開啟 App／重新進入 editor 時對同一原音重算 peaks。
///
/// - 落點屬 infra 端（走檔案 IO）；Domain 只認抽象 port（M5 純 Dart 防線）。
/// - key 建議由呼叫端從音檔內容衍生（例如 path＋size＋mtime 的 hash），
///   對同一原檔穩定；不同原檔互不覆蓋。
abstract interface class WaveformPeaksCache {
  /// 若有對應 [key] 快取則回傳；否則回 null。
  Future<List<WaveformPeak>?> load(String key);

  /// 將 [peaks] 以 [key] 存入快取。實作端負責原子寫入。
  Future<void> save(String key, List<WaveformPeak> peaks);
}
