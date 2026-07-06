// AI-Generate

/// AI 服務商設定（backend-design.md §3.2.5 介面 11/12）。
class AiProviderConfig {
  final Uri baseUrl;
  final String model;

  AiProviderConfig({
    required this.baseUrl,
    required this.model,
  }) {
    if (model.trim().isEmpty) {
      throw ArgumentError('AiProviderConfig.model 不可空白');
    }
  }
}

/// 送往 AI client port 的翻譯請求。
class AiClientRequest {
  final Uri baseUrl;
  final String credential;
  final String model;
  final String text;
  final String targetLang;

  const AiClientRequest({
    required this.baseUrl,
    required this.credential,
    required this.model,
    required this.text,
    required this.targetLang,
  });
}

/// AI client port 回傳的翻譯結果。
class AiClientResponse {
  final String text;
  final String? modelName;

  const AiClientResponse({
    required this.text,
    this.modelName,
  });
}

/// AI 翻譯外部呼叫 port；真 HTTP/provider adapter 不放在 Domain。
abstract interface class AiClient {
  Future<AiClientResponse> translate(AiClientRequest request);
}
