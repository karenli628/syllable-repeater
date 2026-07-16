// AI-Generate
import '../model/syllable.dart';
import '../model/word.dart';

/// 單字音節切分結果（backend-design.md §3.1.1、REQ-17）。
class SyllabifyResult {
  final List<Syllable> syllables;

  /// 建立不可變的音節切分結果（REQ-17/M13）。
  SyllabifyResult({required List<Syllable> syllables})
      : syllables = List.unmodifiable(syllables) {
    if (syllables.isEmpty) {
      throw ArgumentError('SyllabifyResult.syllables 不可為空');
    }
  }

  /// 音節數（REQ-17）。
  int get syllableCount => syllables.length;

  /// 是否有任何切分需由使用者覆核（REQ-17）。
  bool get needsReview => syllables.any((syllable) => syllable.needsReview);
}

/// 可依語言替換的音節切分插座（backend-design.md §3.1.1、REQ-17/M13）。
abstract interface class Syllabifier {
  /// 此切分器明確支援的語言代碼（REQ-17/M14）。
  Set<String> get supportedLanguages;

  /// 依指定語言切分單字；不得默默改用其他語言（REQ-17/M14）。
  SyllabifyResult syllabify(
    Word word, {
    required String language,
  });
}
