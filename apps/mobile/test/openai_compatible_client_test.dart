import 'dart:convert';

import 'package:ai_todo_mobile/app/features/ai/data/openai_compatible_client.dart';
import 'package:ai_todo_mobile/app/features/settings/domain/ai_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() {
    AISettings.environmentReader = () => const {};
  });

  tearDown(() {
    AISettings.environmentReader = () => const {};
  });

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

  test('prefers in-app values over environment variables', () {
    AISettings.environmentReader = () => {
          AISettings.envBaseUrlKey: 'https://env.example.com',
          AISettings.envApiKeyKey: 'env-token',
        };

    const settings = AISettings(
      enabled: true,
      advancedMode: true,
      baseUrl: 'https://local.example.com',
      apiKey: 'local-token',
      model: 'gpt-4o-mini',
    );

    expect(settings.effectiveBaseUrl, 'https://local.example.com');
    expect(settings.effectiveApiKey, 'local-token');
  });

  test('falls back to environment variables when in-app values are empty', () {
    AISettings.environmentReader = () => {
          AISettings.envBaseUrlKey: 'https://env.example.com',
          AISettings.envApiKeyKey: 'env-token',
        };

    const settings = AISettings(
      enabled: true,
      advancedMode: true,
      baseUrl: '',
      apiKey: '',
      model: 'gpt-4o-mini',
    );

    expect(settings.effectiveBaseUrl, 'https://env.example.com');
    expect(settings.effectiveApiKey, 'env-token');
    expect(settings.usingEnvBaseUrl, isTrue);
    expect(settings.usingEnvApiKey, isTrue);
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
      if (request.method == 'GET') {
        return http.Response('ok', 200);
      }
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

  test('dns failure returns typed hint', () async {
    const client = OpenAICompatibleClient();
    const settings = AISettings(
      enabled: true,
      advancedMode: true,
      baseUrl: 'https://nonexistent-prism-ai.invalid/v1',
      apiKey: 'token',
      model: 'gpt-4o-mini',
      timeoutSeconds: '5',
    );

    final result = await client.testConnection(settings: settings);
    expect(result.success, isFalse);
    expect(result.message, anyOf(contains('DNS'), contains('无法解析域名')));
  });

  test('url preflight returns incompatible hint when endpoint is 404', () async {
    final mock = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response('404 page not found', 404);
      }
      return http.Response('404 page not found', 404);
    });

    final client = OpenAICompatibleClient(httpClient: mock);
    const settings = AISettings(
      enabled: true,
      advancedMode: true,
      baseUrl: 'https://example.com/v1',
      apiKey: 'token',
      model: 'gpt-4o-mini',
    );

    final result = await client.testConnection(settings: settings);
    expect(result.success, isFalse);
    expect(result.message, contains('URL 预检失败'));
  });

  test('parseTask extracts structured fields from JSON content', () async {
    final mock = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response('ok', 200);
      }
      return http.Response.bytes(
        utf8.encode(jsonEncode({
          'choices': [
            {
              'message': {
                'content': jsonEncode({
                  'title': '发送项目周报给 Alice',
                  'deadline': '明天下午3点前',
                  'priority': '高',
                  'location': '公司',
                  'notes': '需要附上燃尽图'
                })
              }
            }
          ]
        })),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
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

    final result = await client.parseTask(
      rawText: '明天下午3点前把项目周报发给Alice，优先级高，在公司处理，备注：需要附上燃尽图。',
      settings: settings,
    );

    expect(result.normalizedTitle, '发送项目周报给 Alice');
    expect(result.deadline, '明天下午3点前');
    expect(result.priority, '高');
    expect(result.location, '公司');
    expect(result.notes, '需要附上燃尽图');
  });
}
