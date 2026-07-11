// AI-Generate
import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:syllable_repeater_app/features/progress/ai_settings_service.dart';
import 'package:syllable_repeater_app/shared/infra/keychain_secure_store.dart';
import 'package:syllable_repeater_app/shared/infra/openai_responses_client.dart';

void main() {
  group('KeychainSecureStore（task-split 7.2 / M10）', () {
    test('AT-07-02 key 經 backend 寫入與讀回，不落 app 記憶副本', () async {
      final backend = _FakeSecureStorageBackend();
      final store = KeychainSecureStore(backend: backend);

      await store.write(AIService.credentialKey, 'sk-test-secret');

      expect(backend.values, {AIService.credentialKey: 'sk-test-secret'});
      expect(await store.read(AIService.credentialKey), 'sk-test-secret');
    });

    test('backend 失敗時轉成 DomainException，錯誤訊息不含 credential', () async {
      final backend = _FakeSecureStorageBackend(failWrites: true);
      final store = KeychainSecureStore(backend: backend);

      await expectLater(
        store.write(AIService.credentialKey, 'sk-secret-must-not-leak'),
        throwsA(
          isA<DomainException>()
              .having((e) => e.code, 'code', ErrorCodes.aiCallFailed)
              .having(
                (e) => e.message,
                'message',
                isNot(contains('sk-secret')),
              ),
        ),
      );
    });
  });

  group('OpenAiResponsesClient（task-split 7.2 / AT-07-04）', () {
    test('送 Responses API JSON 並解析 output_text', () async {
      late http.Request captured;
      final client = OpenAiResponsesClient(
        MockClient((request) async {
          captured = request;
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({'output_text': '你好', 'model': 'gpt-5.4-mini'}),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final result = await client.translate(
        AiClientRequest(
          baseUrl: Uri.parse('https://api.openai.com/v1/responses'),
          credential: 'sk-live-secret',
          model: 'gpt-5.4-mini',
          text: 'hello',
          targetLang: 'zh-TW',
        ),
      );

      expect(result.text, '你好');
      expect(result.modelName, 'gpt-5.4-mini');
      expect(captured.method, 'POST');
      expect(captured.url.host, 'api.openai.com');
      expect(captured.headers['authorization'], 'Bearer sk-live-secret');
      expect(captured.headers['content-type'], contains('application/json'));

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['model'], 'gpt-5.4-mini');
      expect(body['store'], isFalse);
      expect(jsonEncode(body), contains('zh-TW'));
      expect(jsonEncode(body), contains('hello'));
    });

    test('支援 Responses API output.content[].text 結構', () async {
      final client = OpenAiResponsesClient(
        MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'model': 'gpt-5.4-mini',
                'output': [
                  {
                    'type': 'message',
                    'content': [
                      {'type': 'output_text', 'text': '第一段'},
                      {'type': 'output_text', 'text': '第二段'},
                    ],
                  },
                ],
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );

      final result = await client.translate(
        AiClientRequest(
          baseUrl: Uri.parse('https://api.openai.com/v1/responses'),
          credential: 'sk-live-secret',
          model: 'gpt-5.4-mini',
          text: 'hello',
          targetLang: 'zh-TW',
        ),
      );

      expect(result.text, '第一段\n第二段');
    });

    test('provider failure 回 ERR_AI_CALL_FAILED 且不洩漏 credential', () async {
      final client = OpenAiResponsesClient(
        MockClient((_) async => http.Response('bad key sk-secret', 401)),
      );

      await expectLater(
        client.translate(
          AiClientRequest(
            baseUrl: Uri.parse('https://api.openai.com/v1/responses'),
            credential: 'sk-secret',
            model: 'gpt-5.4-mini',
            text: 'hello',
            targetLang: 'zh-TW',
          ),
        ),
        throwsA(
          isA<DomainException>()
              .having((e) => e.code, 'code', ErrorCodes.aiCallFailed)
              .having(
                (e) => e.message,
                'message',
                isNot(contains('sk-secret')),
              ),
        ),
      );
    });
  });

  test('AI settings providers 預設接真 Keychain 與 OpenAI Responses adapter', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(aiSecureStoreProvider), isA<KeychainSecureStore>());
    expect(container.read(aiClientProvider), isA<OpenAiResponsesClient>());
    final config = container.read(aiProviderConfigProvider);
    expect(config.baseUrl, Uri.parse('https://api.openai.com/v1/responses'));
    expect(config.model, 'gpt-5.4-mini');
  });
}

class _FakeSecureStorageBackend implements SecureStorageBackend {
  _FakeSecureStorageBackend({this.failWrites = false});

  final bool failWrites;
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) {
      throw StateError('platform failed');
    }
    values[key] = value;
  }
}
