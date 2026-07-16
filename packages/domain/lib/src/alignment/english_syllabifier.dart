// AI-Generate
import '../errors.dart';
import '../model/word.dart';
import '../ports/syllabifier.dart';
import 'alignment_engine.dart';

/// 沿用 v1 CMUdict＋母音團兜底的英文切分器（backend-design.md §3.2.4）。
class EnglishSyllabifier implements Syllabifier {
  final AlignmentEngine _alignmentEngine;

  /// 先包裝既有引擎以維持 AT-17-01 逐位不變。
  EnglishSyllabifier({AlignmentEngine? alignmentEngine})
      : _alignmentEngine = alignmentEngine ?? AlignmentEngine();

  @override
  Set<String> get supportedLanguages => const {'en'};

  /// 切分英文單字；非英文輸入明確拒絕，不做英文 fallback（M14）。
  @override
  SyllabifyResult syllabify(
    Word word, {
    required String language,
  }) {
    final normalized = language.trim().toLowerCase();
    if (!supportedLanguages.contains(normalized)) {
      throw DomainException(
        ErrorCodes.languageUnsupported,
        '不支援「$normalized」：EnglishSyllabifier 僅支援 en',
      );
    }
    final result = _alignmentEngine.alignWords([word]);
    return SyllabifyResult(syllables: result.syllables);
  }
}
