// AI-Generate
import '../model/pcm.dart';
import '../model/segment.dart';
import '../model/word.dart';

/// 本地語音辨識引擎插座（backend-design.md §3.1.1、REQ-17/M13）。
abstract interface class TranscriberEngine {
  /// 引擎可讀名稱（REQ-17）。
  String get engineName;

  /// 此引擎明確支援的語言代碼（REQ-17/M14）。
  Set<String> get supportedLanguages;

  /// 將 PCM 轉成詞級時間戳（backend-design.md §3.1.1）。
  Future<List<Word>> transcribe(
    Pcm pcm, {
    required String language,
    String? transcript,
  });

  /// 將 PCM 轉成句子級時間戳（REQ-11、REQ-17）。
  Future<List<Segment>> segment(
    Pcm pcm, {
    required String language,
  });
}
