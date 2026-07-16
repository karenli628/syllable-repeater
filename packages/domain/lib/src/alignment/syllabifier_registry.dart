// AI-Generate
import '../errors.dart';
import '../ports/syllabifier.dart';

/// 依語言路由音節切分器的註冊表（backend-design.md §3.2.4）。
class SyllabifierRegistry {
  final Map<String, Syllabifier> _byLanguage;
  final Set<String> registeredLanguages;

  /// 建立固定且不可在執行中變動的切分器註冊表（REQ-17/M14）。
  factory SyllabifierRegistry(Iterable<Syllabifier> syllabifiers) {
    final indexed = _indexSyllabifiers(syllabifiers);
    return SyllabifierRegistry._(indexed);
  }

  SyllabifierRegistry._(this._byLanguage)
      : registeredLanguages = Set.unmodifiable(
          _byLanguage.keys.toList()..sort(),
        );

  /// 解析指定語言；查無時明確拒絕並列出已註冊語言（AT-17-02/03）。
  Syllabifier resolve(String language) {
    final normalized = _normalizeLanguage(language);
    final syllabifier = _byLanguage[normalized];
    if (syllabifier != null) {
      return syllabifier;
    }
    throw DomainException(
      ErrorCodes.languageUnsupported,
      '不支援「$normalized」：缺少音節切分器。目前支援：${_languageSummary(registeredLanguages)}',
    );
  }

  static Map<String, Syllabifier> _indexSyllabifiers(
    Iterable<Syllabifier> syllabifiers,
  ) {
    final indexed = <String, Syllabifier>{};
    for (final syllabifier in syllabifiers) {
      for (final rawLanguage in syllabifier.supportedLanguages) {
        final language = _normalizeLanguage(rawLanguage);
        if (indexed.containsKey(language)) {
          throw ArgumentError('語言 $language 已註冊音節切分器，不能重複註冊');
        }
        indexed[language] = syllabifier;
      }
    }
    return Map.unmodifiable(indexed);
  }

  static String _normalizeLanguage(String language) {
    final normalized = language.trim().toLowerCase();
    if (normalized.isEmpty) {
      throw ArgumentError('language 不可空白（got "$language"）');
    }
    return normalized;
  }

  static String _languageSummary(Set<String> languages) =>
      languages.isEmpty ? '無' : languages.join('、');
}
