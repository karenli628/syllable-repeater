// AI-Generate
import '../errors.dart';
import '../ports/transcriber_engine.dart';

/// 依語言路由本地辨識引擎的註冊表（backend-design.md §3.2.4）。
class TranscriberRegistry {
  final Map<String, TranscriberEngine> _byLanguage;
  final Set<String> registeredLanguages;

  /// 建立固定且不可在執行中變動的辨識引擎註冊表（REQ-17/M14）。
  factory TranscriberRegistry(Iterable<TranscriberEngine> engines) {
    final indexed = _indexEngines(engines);
    return TranscriberRegistry._(indexed);
  }

  TranscriberRegistry._(this._byLanguage)
      : registeredLanguages = Set.unmodifiable(
          _byLanguage.keys.toList()..sort(),
        );

  /// 解析指定語言；查無時明確拒絕並列出已註冊語言（AT-17-02）。
  TranscriberEngine resolve(String language) {
    final normalized = _normalizeLanguage(language);
    final engine = _byLanguage[normalized];
    if (engine != null) {
      return engine;
    }
    throw DomainException(
      ErrorCodes.languageUnsupported,
      '不支援「$normalized」：缺少辨識引擎。目前支援：${_languageSummary(registeredLanguages)}',
    );
  }

  static Map<String, TranscriberEngine> _indexEngines(
    Iterable<TranscriberEngine> engines,
  ) {
    final indexed = <String, TranscriberEngine>{};
    for (final engine in engines) {
      if (engine.engineName.trim().isEmpty) {
        throw ArgumentError('TranscriberEngine.engineName 不可空白');
      }
      for (final rawLanguage in engine.supportedLanguages) {
        final language = _normalizeLanguage(rawLanguage);
        final existing = indexed[language];
        if (existing != null) {
          throw ArgumentError(
            '語言 $language 已由 ${existing.engineName} 註冊，不能再註冊 ${engine.engineName}',
          );
        }
        indexed[language] = engine;
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
