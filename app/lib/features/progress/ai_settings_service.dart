// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../shared/infra/keychain_secure_store.dart';
import '../../shared/infra/openai_responses_client.dart';
import 'progress_service.dart';

final aiSecureStoreProvider = Provider<SecureStore>(
  (ref) => const KeychainSecureStore(),
);

final aiHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final aiClientProvider = Provider<AiClient>(
  (ref) => OpenAiResponsesClient(ref.watch(aiHttpClientProvider)),
);

final aiProviderConfigProvider = Provider<AiProviderConfig>(
  (ref) => AiProviderConfig(
    baseUrl: Uri.parse('https://api.openai.com/v1/responses'),
    model: 'gpt-5.4-mini',
  ),
);

final aiSettingsServiceProvider = Provider<AiSettingsService>((ref) {
  final repository = ref.watch(progressRepositoryProvider);
  final secureStore = ref.watch(aiSecureStoreProvider);
  final providerConfig = ref.watch(aiProviderConfigProvider);
  return DomainAiSettingsService(
    providerConfig,
    AIService(
      secureStore: secureStore,
      client: ref.watch(aiClientProvider),
      clock: const SystemClock(),
      rateLimit: const AiRateLimit(
        maxRequests: 5,
        window: Duration(minutes: 1),
      ),
      auditLogSink: repository,
    ),
  );
});

abstract interface class AiSettingsService {
  Future<void> configureCredential(String credential);

  Future<Translation> translate(String text, String targetLang);
}

class DomainAiSettingsService implements AiSettingsService {
  DomainAiSettingsService(this._providerConfig, this._service);

  final AiProviderConfig _providerConfig;
  final AIService _service;

  @override
  Future<void> configureCredential(String credential) {
    return _service.configure(credential, _providerConfig);
  }

  @override
  Future<Translation> translate(String text, String targetLang) =>
      _service.translate(text, targetLang);
}
