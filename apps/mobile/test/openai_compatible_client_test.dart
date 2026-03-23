import 'dart:convert';

import 'package:ai_todo_mobile/app/features/ai/data/openai_compatible_client.dart';
import 'package:ai_todo_mobile/app/features/settings/domain/ai_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('builds OpenAI compatible url from base /v1 root', () {
    const client = OpenAICompatibleClient();
    const settings = AISettings(
      enabled: true,
      advancedMode: true,
      baseUrl: 'https://api.openai.com/v1',
      apiKey: 'token',
      model: 'gpt-4o-mini',
    );

    final uri = client.buildChatCompletionsUri(settings);
    expect(uri.toString(), 'https://api.openai.com/v1/chat/completions');
  });

  test('returns validation error when api key missing in advanced mode', () async {
    const client = OpenAICompatibleClient();
    const settings = AISettings(
      enabled: true,
      advancedMode: true,
      baseUrl: 'https://api.openai.com',
      apiKey: '',
      model: 'gpt-4o-mini',
    );

    final result = await client.testConnection(settings: settings);
    expect(result.success, isFalse);
    expect(result.message, contains('API Key'));
  });

  test('testConnection parses successful response', () async {
    final mock = MockClient((request) async {
      expect(request.url.toString(), 'https://example.com/v1/chat/completions');
      expect(request.headers['Authorization'], 'Bearer token');
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {'content': 'ok'}
            }
          ]
        }),
        200,
      );
    });

    final client = OpenAICompatibleClient(httpClient: mock);
    const settings = AISettings(
      enabled: true,
      advancedMode: true,
      baseUrl: 'https://example.com',
      apiKey: 'token',
      model: 'gpt-4o-mini',
    );

    final result = await client.testConnection(settings: settings);
    expect(result.success, isTrue);
    expect(result.message, contains('ok'));
  });
}
