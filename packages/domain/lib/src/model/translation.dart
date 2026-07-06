// AI-Generate

/// 譯文來源（backend-design.md §3.1.1 Translation）。
enum TranslationSource {
  manual('manual'),
  ai('ai');

  final String value;

  const TranslationSource(this.value);

  static TranslationSource fromJson(String value) {
    for (final source in values) {
      if (source.value == value) {
        return source;
      }
    }
    throw ArgumentError('未知 TranslationSource: $value');
  }
}

/// 課件譯文；manual 永遠覆蓋 ai（REQ-07 AT-07-06）。
class Translation {
  final String text;
  final TranslationSource source;
  final String? modelName;
  final DateTime createdAt;

  Translation({
    required this.text,
    required this.source,
    this.modelName,
    required this.createdAt,
  }) {
    if (text.trim().isEmpty) {
      throw ArgumentError('Translation.text 不可空白');
    }
    if (source == TranslationSource.manual && modelName != null) {
      throw ArgumentError('manual 譯文不可帶 modelName');
    }
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'source': source.value,
        'modelName': modelName,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory Translation.fromJson(Map<String, dynamic> json) => Translation(
        text: json['text'] as String,
        source: TranslationSource.fromJson(json['source'] as String),
        modelName: json['modelName'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      );

  @override
  bool operator ==(Object other) =>
      other is Translation &&
      other.text == text &&
      other.source == source &&
      other.modelName == modelName &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(text, source, modelName, createdAt);
}
