// AI-Generate
import '../model/pcm.dart';

/// 錄音暫存檔讀取/刪除抽象（REQ-06 / M10）。
///
/// Domain 透過本 port 取得錄音 PCM 並在 `finally` 呼叫 [delete]；實際檔案
/// 系統、WAV/平台格式解碼都放在 infra/app 端，避免破壞 M5 domain purity。
abstract interface class RecordingAudioSource {
  Future<Pcm> readPcm(String path);

  Future<void> delete(String path);
}
