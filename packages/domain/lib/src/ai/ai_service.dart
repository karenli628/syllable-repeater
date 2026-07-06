// AI-Generate
import '../errors.dart';
import '../model/audit_log.dart';
import '../model/translation.dart';
import '../ports/ai_client.dart';
import '../ports/audit_log_sink.dart';
import '../ports/clock.dart';
import '../ports/secure_store.dart';

/// AIService 內部節流設定（task-split 8.4.3）。
class AiRateLimit {
  final int maxRequests;
  final Duration window;

  const AiRateLimit({
    required this.maxRequests,
    required this.window,
  }) : assert(maxRequests > 0);
}

/// AIService：文字翻譯與 key/config 編排；不得觸碰音訊（REQ-07 §0.1）。
// ignore: camel_case_types
class AIService {
  static const String credentialKey = 'ai.apiKey';
  static const Set<String> defaultAllowedHosts = {
    'api.openai.com',
    'api.anthropic.com',
  };

  final SecureStore secureStore;
  final AiClient client;
  final Clock clock;
  final AiRateLimit rateLimit;
  final Set<String> allowedHosts;
  final AuditLogSink? auditLogSink;
  final List<DateTime> _requestTimes = [];

  AiProviderConfig? _config;

  AIService({
    required this.secureStore,
    required this.client,
    required this.clock,
    required this.rateLimit,
    this.auditLogSink,
    Set<String> allowedHosts = defaultAllowedHosts,
  }) : allowedHosts = Set.unmodifiable(
          allowedHosts.map((host) => host.toLowerCase()),
        ) {
    if (rateLimit.maxRequests <= 0 || rateLimit.window.inMicroseconds <= 0) {
      throw ArgumentError('AiRateLimit 必須有正數 maxRequests 與 window');
    }
  }

  Future<void> configure(String credential, AiProviderConfig cfg) async {
    if (credential.trim().isEmpty) {
      throw const DomainException(
        ErrorCodes.aiKeyMissing,
        '尚未設定 AI 金鑰（手動輸入譯文不受影響）',
      );
    }

    await secureStore.write(credentialKey, credential);
    _config = cfg;
    await auditLogSink?.appendAuditLog(
      AuditLogEntry(
        occurredAt: clock.now().toUtc(),
        actor: AuditLogEntry.localActor,
        action: 'ai_credential_configured',
        targetType: 'ai_service',
        targetId: 'provider_config',
        metadata: {
          'host': cfg.baseUrl.host,
          'model': cfg.model,
          'stored': 'true',
        },
      ),
    );
  }

  Future<Translation> translate(String text, String targetLang) async {
    final cfg = _config;
    final credential = await secureStore.read(credentialKey);
    if (cfg == null || credential == null || credential.trim().isEmpty) {
      throw const DomainException(
        ErrorCodes.aiKeyMissing,
        '尚未設定 AI 金鑰（手動輸入譯文不受影響）',
      );
    }

    final normalizedText = text.trim();
    final normalizedTargetLang = targetLang.trim();
    if (normalizedText.isEmpty || normalizedTargetLang.isEmpty) {
      throw _aiCallFailed('invalid-request');
    }
    if (_looksLikePromptInjection(normalizedText)) {
      throw _aiCallFailed('prompt-injection-review-required');
    }
    if (!_isAllowedEndpoint(cfg.baseUrl)) {
      throw _aiCallFailed('host-blocked');
    }
    _checkRateLimit();

    try {
      final response = await client.translate(
        AiClientRequest(
          baseUrl: cfg.baseUrl,
          credential: credential,
          model: cfg.model,
          text: normalizedText,
          targetLang: normalizedTargetLang,
        ),
      );
      if (response.text.trim().isEmpty) {
        throw _aiCallFailed('empty-response');
      }

      return Translation(
        text: response.text,
        source: TranslationSource.ai,
        modelName: response.modelName ?? cfg.model,
        createdAt: clock.now().toUtc(),
      );
    } on DomainException {
      rethrow;
    } catch (_) {
      throw _aiCallFailed('provider-failed');
    }
  }

  static Translation mergeTranslation({
    required Translation? existing,
    required Translation incomingAi,
  }) {
    if (incomingAi.source != TranslationSource.ai) {
      throw ArgumentError('incomingAi.source 必須為 ai');
    }
    if (existing?.source == TranslationSource.manual) {
      return existing!;
    }
    return incomingAi;
  }

  void _checkRateLimit() {
    final now = clock.now().toUtc();
    _requestTimes.removeWhere(
      (time) => now.difference(time.toUtc()) >= rateLimit.window,
    );
    if (_requestTimes.length >= rateLimit.maxRequests) {
      throw _aiCallFailed('rate-limit');
    }
    _requestTimes.add(now);
  }

  bool _isAllowedEndpoint(Uri baseUrl) =>
      baseUrl.scheme == 'https' &&
      allowedHosts.contains(baseUrl.host.toLowerCase());

  bool _looksLikePromptInjection(String text) {
    final lowered = text.toLowerCase();
    const suspiciousTokens = [
      'ignore previous instructions',
      'system:',
      'developer:',
      '</s>',
      '<|system|>',
      '<|developer|>',
    ];
    return suspiciousTokens.any(lowered.contains);
  }
}

DomainException _aiCallFailed(String reason) => DomainException(
      ErrorCodes.aiCallFailed,
      '翻譯服務暫時無法使用（$reason）',
    );
