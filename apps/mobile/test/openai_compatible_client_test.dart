import 'dart:convert';

import 'package:ai_todo_mobile/app/features/ai/data/openai_compatible_client.dart';
import 'package:ai_todo_mobile/app/features/ai/domain/ai_request_error.dart';
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

  test(
    'returns validation error when api key missing in advanced mode',
    () async {
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
    },
  );

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
              'message': {'content': 'ok'},
            },
          ],
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

  test(
    'get preflight 404 should not block; final POST 404 returns incompatible hint',
    () async {
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
      expect(result.message, contains('URL 不兼容'));
    },
  );

  test('parseTask extracts structured fields from JSON content', () async {
    const sharedPrompt = 'from-shared-prompt';
    final mock = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response('ok', 200);
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final messages = body['messages'] as List<dynamic>;
      expect((messages.first as Map<String, dynamic>)['content'], sharedPrompt);
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode([
                    {
                      'title': '发送项目周报给 Alice',
                      'date': '2026-03-29',
                      'time': '15:00',
                      'priority': '高',
                      'location': '公司',
                      'note': '需要附上燃尽图',
                      'list': [
                        {
                          'title': '附上燃尽图',
                          'date': '2026-03-29',
                          'time': '',
                          'priority': '中',
                          'location': '',
                          'note': '从看板导出最新版本',
                          'list': [],
                        },
                      ],
                    },
                  ]),
                },
              },
            ],
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final client = OpenAICompatibleClient(
      httpClient: mock,
      promptLoader: () async => sharedPrompt,
    );
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
    expect(result.deadline, '2026-03-29T15:00:00');
    expect(result.priority, '高');
    expect(result.location, '公司');
    expect(result.notes, '需要附上燃尽图');
    expect(result.subtasks.length, 1);
    expect(result.subtasks.first.title, '附上燃尽图');
  });

  test(
    'parseTask falls back to /responses when /chat/completions returns 405',
    () async {
      final requestedPaths = <String>[];
      final mock = MockClient((request) async {
        requestedPaths.add(request.url.path);
        if (request.method == 'POST' &&
            request.url.path.endsWith('/chat/completions')) {
          return http.Response('method not allowed', 405);
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/responses')) {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final input = body['input'] as List<dynamic>;
          expect((input.first as Map<String, dynamic>)['content'], 'shared');
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'output_text': jsonEncode([
                  {
                    'title': '准备周会材料',
                    'date': '2026-03-30',
                    'time': '09:30',
                    'priority': '中',
                    'location': '会议室',
                    'note': '带上上周行动项',
                    'list': [],
                  },
                ]),
              }),
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('not found', 404);
      });

      final client = OpenAICompatibleClient(
        httpClient: mock,
        promptLoader: () async => 'shared',
      );
      const settings = AISettings(
        enabled: true,
        advancedMode: true,
        baseUrl: 'https://example.com/v1',
        apiKey: 'token',
        model: 'gpt-4o-mini',
      );

      final result = await client.parseTask(
        rawText: '下周一晨会前准备周会材料。',
        settings: settings,
      );

      expect(result.normalizedTitle, '准备周会材料');
      expect(result.deadline, '2026-03-30T09:30:00');
      expect(result.priority, '中');
      expect(requestedPaths, contains('/v1/chat/completions'));
      expect(requestedPaths, contains('/v1/responses'));
    },
  );

  test('parseTask rejects invalid date/time/priority format', () async {
    final mock = MockClient((request) async {
      if (request.method == 'GET') {
        return http.Response('ok', 200);
      }
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'content': jsonEncode([
                    {
                      'title': '坏格式任务',
                      'date': '今天15:00',
                      'time': '99:00',
                      'priority': '紧急',
                      'location': '',
                      'note': '',
                      'list': [],
                    },
                  ]),
                },
              },
            ],
          }),
        ),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final client = OpenAICompatibleClient(
      httpClient: mock,
      promptLoader: () async => 'shared',
    );
    const settings = AISettings(
      enabled: true,
      advancedMode: true,
      baseUrl: 'https://example.com',
      apiKey: 'token',
      model: 'gpt-4o-mini',
    );

    await expectLater(
      client.parseTask(rawText: '测试', settings: settings),
      throwsA(
        isA<AIRequestError>().having(
          (e) => e.message,
          'message',
          contains('格式错误'),
        ),
      ),
    );
  });
}
