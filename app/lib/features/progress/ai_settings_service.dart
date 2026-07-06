// AI-Generate
import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'progress_service.dart';

final aiSecureStoreProvider = Provider<SecureStore>(
  (ref) => InMemoryAiSecureStore(),
);

final aiSettingsServiceProvider = Provider<AiSettingsService>((ref) {
  final repository = ref.watch(progressRepositoryProvider);
  return DomainAiSettingsService(
    AIService(
      secureStore: ref.watch(aiSecureStoreProvider),
      client: const NoopAiClient(),
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
}

class DomainAiSettingsService implements AiSettingsService {
  DomainAiSettingsService(this._service);

  static final pendingProviderConfig = AiProviderConfig(
    baseUrl: Uri.parse('https://api.openai.com/v1/responses'),
    model: 'provider-pending',
  );

  final AIService _service;

  @override
  Future<void> configureCredential(String credential) {
    return _service.configure(credential, pendingProviderConfig);
  }
}

class InMemoryAiSecureStore implements SecureStore {
  final _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }
}

class NoopAiClient implements AiClient {
  const NoopAiClient();

  @override
  Future<AiClientResponse> translate(AiClientRequest request) {
    throw const DomainException(
      ErrorCodes.aiCallFailed,
      '尚未接上翻譯服務 provider adapter',
    );
  }
}
