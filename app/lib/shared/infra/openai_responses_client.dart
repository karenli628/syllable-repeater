// AI-Generate
import 'dart:async';
import 'dart:convert';

import 'package:domain/domain.dart';
import 'package:http/http.dart' as http;

/// OpenAiResponsesClient（backend-design.md §3.2.5）：Responses API 文字翻譯 adapter。
class OpenAiResponsesClient implements AiClient {
  OpenAiResponsesClient(
    this._client, {
    this.timeout = const Duration(seconds: 30),
  });

  final http.Client _client;
  final Duration timeout;

  @override
  Future<AiClientResponse> translate(AiClientRequest request) async {
    try {
      final response = await _client
          .post(
            request.baseUrl,
            headers: {
              'authorization': 'Bearer ${request.credential}',
              'content-type': 'application/json',
            },
            body: jsonEncode(_requestBody(request)),
          )
          .timeout(timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _providerFailure('http-${response.statusCode}');
      }

      final rawJson = jsonDecode(response.body);
      if (rawJson is! Map) {
        throw _providerFailure('invalid-json');
      }
      final decoded = Map<String, dynamic>.from(rawJson);

      final text = _extractOutputText(decoded).trim();
      if (text.isEmpty) {
        throw _providerFailure('empty-output');
      }

      return AiClientResponse(
        text: text,
        modelName: decoded['model'] is String
            ? decoded['model'] as String
            : null,
      );
    } on DomainException {
      rethrow;
    } on TimeoutException {
      throw _providerFailure('timeout');
    } catch (_) {
      throw _providerFailure('request-failed');
    }
  }

  Map<String, dynamic> _requestBody(AiClientRequest request) => {
    'model': request.model,
    'store': false,
    'instructions':
        'Translate the user-provided text into the target language. '
        'Return only the translated text, without explanations.',
    'input': [
      {
        'role': 'user',
        'content': [
          {
            'type': 'input_text',
            'text':
                'Target language: ${request.targetLang}\n'
                'Text:\n${request.text}',
          },
        ],
      },
    ],
  };

  String _extractOutputText(Map<String, dynamic> decoded) {
    final outputText = decoded['output_text'];
    if (outputText is String) {
      return outputText;
    }

    final output = decoded['output'];
    if (output is! List) {
      return '';
    }

    final parts = <String>[];
    for (final item in output) {
      if (item is! Map) {
        continue;
      }
      final content = item['content'];
      if (content is! List) {
        continue;
      }
      for (final part in content) {
        if (part is Map && part['text'] is String) {
          parts.add(part['text'] as String);
        }
      }
    }
    return parts.join('\n');
  }
}

DomainException _providerFailure(String reason) =>
    DomainException(ErrorCodes.aiCallFailed, '翻譯服務暫時無法使用（provider-$reason）');
