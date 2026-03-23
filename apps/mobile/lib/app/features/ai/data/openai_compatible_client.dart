import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../settings/domain/ai_settings.dart';
import '../domain/ai_client.dart';
import '../domain/ai_connection_result.dart';
import '../domain/ai_parse_result.dart';
import '../domain/ai_request_error.dart';

class OpenAICompatibleClient implements AIClient {
  const OpenAICompatibleClient({http.Client? httpClient}) : _httpClient = httpClient;

  final http.Client? _httpClient;

  http.Client get _client => _httpClient ?? http.Client();

  @override
  Future<AIConnectionResult> testConnection({required AISettings settings}) async {
    final validationError = validateSettings(settings);
    if (validationError != null) {
      return AIConnectionResult(success: false, message: validationError);
    }

    final uri = buildChatCompletionsUri(settings);
    final payload = buildChatCompletionsPayload(
      rawText: '请回复一个简短的 ok，用于验证 API 连通性。',
      settings: settings,
    );

    try {
      final response = await _client
          .post(
            uri,
            headers: buildHeaders(settings),
            body: jsonEncode(payload),
          )
          .timeout(Duration(seconds: int.tryParse(settings.timeoutSeconds) ?? 30));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AIConnectionResult(
          success: false,
          message: '请求失败：HTTP ${response.statusCode}',
          statusCode: response.statusCode,
          rawResponse: response.body,
        );
      }

      final content = extractAssistantContent(response.body);
      return AIConnectionResult(
        success: true,
        message: content.isEmpty ? '连接成功，但响应为空。' : '连接成功：$content',
        statusCode: response.statusCode,
        rawResponse: response.body,
      );
    } on AIRequestError catch (error) {
      return AIConnectionResult(success: false, message: error.message);
    } catch (error) {
      return AIConnectionResult(success: false, message: '请求异常：$error');
    }
  }

  @override
  Future<AIParseResult> parseTask({
    required String rawText,
    required AISettings settings,
  }) async {
    final validationError = validateSettings(settings);
    if (validationError != null) {
      throw AIRequestError(validationError);
    }

    final uri = buildChatCompletionsUri(settings);
    final payload = buildChatCompletionsPayload(rawText: rawText, settings: settings);

    final response = await _client
        .post(
          uri,
          headers: buildHeaders(settings),
          body: jsonEncode(payload),
        )
        .timeout(Duration(seconds: int.tryParse(settings.timeoutSeconds) ?? 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AIRequestError('AI 请求失败：HTTP ${response.statusCode} ${response.body}');
    }

    final content = extractAssistantContent(response.body);
    if (content.isEmpty) {
      throw const AIRequestError('AI 返回成功，但没有可解析内容。');
    }

    final normalized = rawText.trim().replaceAll(RegExp(r'\s+'), ' ');
    return AIParseResult(
      normalizedTitle: normalized,
      summary: content,
      deadline: null,
      priority: null,
      location: null,
    );
  }

  String? validateSettings(AISettings settings) {
    if (!settings.enabled) return '请先启用 AI 解析。';
    if (settings.baseUrl.trim().isEmpty) return '请填写 Base URL。';
    if (settings.advancedMode && settings.apiKey.trim().isEmpty) return '请填写 API Key / Token。';
    if (settings.model.trim().isEmpty) return '请填写 Model。';
    final uri = Uri.tryParse(settings.baseUrl.trim());
    if (uri == null || !(uri.hasScheme && uri.hasAuthority)) {
      return 'Base URL 格式不正确。';
    }
    return null;
  }

  Uri buildChatCompletionsUri(AISettings settings) {
    final base = settings.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse(base);
    if (uri.path.endsWith('/v1/chat/completions')) return uri;
    if (uri.path.endsWith('/v1')) {
      return uri.replace(path: '${uri.path}/chat/completions');
    }
    return uri.replace(path: '${uri.path}/v1/chat/completions');
  }

  Map<String, String> buildHeaders(AISettings settings) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (settings.apiKey.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${settings.apiKey.trim()}';
    }
    return headers;
  }

  Map<String, dynamic> buildChatCompletionsPayload({
    required String rawText,
    required AISettings settings,
  }) {
    return {
      'model': settings.model,
      'temperature': double.tryParse(settings.temperature) ?? 0.2,
      'messages': [
        {
          'role': 'system',
          'content': 'You extract todo metadata such as title, deadline, priority and location. Reply briefly and clearly.',
        },
        {
          'role': 'user',
          'content': rawText,
        },
      ],
    };
  }

  String extractAssistantContent(String responseBody) {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) return '';
    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map<String, dynamic>) {
        final message = first['message'];
        if (message is Map<String, dynamic>) {
          return (message['content'] as String? ?? '').trim();
        }
      }
    }
    return '';
  }
}
