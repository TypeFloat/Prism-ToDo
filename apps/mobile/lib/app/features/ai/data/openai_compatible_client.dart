import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
    final preflight = await preflightCheck(uri, settings);
    if (preflight != null) return preflight;

    final payload = buildChatCompletionsPayload(
      rawText: '请回复一个简短的 ok，用于验证 API 连通性。',
      settings: settings,
    );

    try {
      final response = await _client
          .post(uri, headers: buildHeaders(settings), body: jsonEncode(payload))
          .timeout(Duration(seconds: int.tryParse(settings.timeoutSeconds) ?? 30));

      final decodedBody = decodeResponseBody(response);
      if (response.statusCode == 404) {
        return AIConnectionResult(
          success: false,
          message: 'URL 不兼容：/v1/chat/completions 返回 404。请检查 Base URL 是否为 OpenAI 兼容网关。',
          statusCode: response.statusCode,
          rawResponse: decodedBody,
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AIConnectionResult(
          success: false,
          message: 'HTTP 错误：${response.statusCode}。',
          statusCode: response.statusCode,
          rawResponse: decodedBody,
        );
      }

      final content = extractAssistantContent(decodedBody);
      return AIConnectionResult(
        success: true,
        message: content.isEmpty ? '连接成功，但响应为空。' : '连接成功：$content',
        statusCode: response.statusCode,
        rawResponse: decodedBody,
      );
    } on TimeoutException {
      return AIConnectionResult(success: false, message: '请求超时：连接在设定时间内无响应（默认 30 秒）。');
    } on SocketException catch (error) {
      return AIConnectionResult(success: false, message: 'DNS/网络错误：${error.message}');
    } on HandshakeException catch (error) {
      return AIConnectionResult(success: false, message: 'TLS/证书握手错误：$error');
    } on AIRequestError catch (error) {
      return AIConnectionResult(success: false, message: error.message);
    } catch (error) {
      return AIConnectionResult(success: false, message: '请求异常：$error');
    }
  }

  @override
  Future<AIParseResult> parseTask({required String rawText, required AISettings settings}) async {
    final validationError = validateSettings(settings);
    if (validationError != null) throw AIRequestError(validationError);

    final uri = buildChatCompletionsUri(settings);
    final payload = buildChatCompletionsPayload(rawText: rawText, settings: settings);

    try {
      final response = await _client
          .post(uri, headers: buildHeaders(settings), body: jsonEncode(payload))
          .timeout(Duration(seconds: int.tryParse(settings.timeoutSeconds) ?? 30));

      final decodedBody = decodeResponseBody(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 404) {
          throw const AIRequestError('URL 不兼容：/v1/chat/completions 不可用（404）。');
        }
        throw AIRequestError('HTTP 错误：${response.statusCode} $decodedBody');
      }

      final content = extractAssistantContent(decodedBody);
      if (content.isEmpty) {
        throw const AIRequestError('AI 返回成功，但没有可解析内容。');
      }

      final parsed = parseStructuredContent(content);
      final normalized = (parsed['title'] as String?)?.trim();
      final deadline = (parsed['deadline'] as String?)?.trim();
      final priority = (parsed['priority'] as String?)?.trim();
      final location = (parsed['location'] as String?)?.trim();
      final notes = (parsed['notes'] as String?)?.trim();
      return AIParseResult(
        normalizedTitle: normalized == null || normalized.isEmpty ? rawText.trim().replaceAll(RegExp(r'\s+'), ' ') : normalized,
        summary: buildReadableSummary(deadline: deadline, priority: priority, location: location, notes: notes),
        deadline: _nonEmpty(deadline),
        priority: _nonEmpty(priority),
        location: _nonEmpty(location),
        notes: _nonEmpty(notes),
      );
    } on SocketException catch (error) {
      throw AIRequestError('DNS/网络错误：${error.message}');
    } on HandshakeException catch (error) {
      throw AIRequestError('TLS/证书握手错误：$error');
    }
  }

  String? validateSettings(AISettings settings) {
    if (!settings.enabled) return '请先启用 AI 解析。';
    if (settings.effectiveBaseUrl.trim().isEmpty) return '请填写 Base URL，或设置环境变量 PRISM_TODO_AI_URL。';
    if (settings.advancedMode && settings.effectiveApiKey.trim().isEmpty) {
      return '请填写 API Key / Token，或设置环境变量 PRISM_TODO_AI_TOKEN。';
    }
    if (settings.model.trim().isEmpty) return '请填写 Model。';
    final uri = Uri.tryParse(settings.effectiveBaseUrl.trim());
    if (uri == null || !(uri.hasScheme && uri.hasAuthority)) {
      return 'Base URL 格式不正确。';
    }
    return null;
  }

  Future<AIConnectionResult?> preflightCheck(Uri uri, AISettings settings) async {
    try {
      await InternetAddress.lookup(uri.host);
    } on SocketException catch (error) {
      return AIConnectionResult(success: false, message: 'DNS 错误：无法解析域名 ${uri.host}（${error.message}）');
    }

    try {
      final probe = await _client.get(uri).timeout(Duration(seconds: int.tryParse(settings.timeoutSeconds) ?? 30));
      if (probe.statusCode == 404) {
        return AIConnectionResult(
          success: false,
          message: 'URL 预检失败：$uri 返回 404，可能不是 OpenAI 兼容接口。',
          statusCode: probe.statusCode,
          rawResponse: decodeResponseBody(probe),
        );
      }
    } on HandshakeException catch (error) {
      return AIConnectionResult(success: false, message: 'TLS 预检失败：$error');
    } on SocketException catch (error) {
      return AIConnectionResult(success: false, message: '网络预检失败：${error.message}');
    } catch (_) {
      // 某些服务不支持 GET 探测，这里不阻断，继续走 POST。
    }

    return null;
  }

  Uri buildChatCompletionsUri(AISettings settings) {
    final base = settings.effectiveBaseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    final uri = Uri.parse(base);
    final normalizedPath = uri.path.replaceAll(RegExp(r'/+$'), '');

    if (normalizedPath.endsWith('/chat/completions')) return uri.replace(path: normalizedPath);
    if (normalizedPath.endsWith('/v1')) return uri.replace(path: '$normalizedPath/chat/completions');
    if (normalizedPath.contains('/v1/')) return uri.replace(path: '$normalizedPath/chat/completions');

    final prefix = normalizedPath.isEmpty ? '' : normalizedPath;
    return uri.replace(path: '$prefix/v1/chat/completions');
  }

  Map<String, String> buildHeaders(AISettings settings) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (settings.effectiveApiKey.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${settings.effectiveApiKey.trim()}';
    }
    return headers;
  }

  Map<String, dynamic> buildChatCompletionsPayload({required String rawText, required AISettings settings}) {
    return {
      'model': settings.model,
      'temperature': double.tryParse(settings.temperature) ?? 0.2,
      'response_format': {'type': 'json_object'},
      'messages': [
        {'role': 'system', 'content': 'Extract a todo into JSON with keys: title, deadline, priority, location, notes. Return valid JSON only.'},
        {'role': 'user', 'content': rawText},
      ],
    };
  }

  String decodeResponseBody(http.Response response) => utf8.decode(response.bodyBytes);

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

  Map<String, dynamic> parseStructuredContent(String content) {
    final decoded = jsonDecode(content);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const AIRequestError('AI 返回内容不是合法 JSON 对象。');
  }

  String buildReadableSummary({String? deadline, String? priority, String? location, String? notes}) {
    final parts = <String>[];
    final d = _nonEmpty(deadline);
    final p = _nonEmpty(priority);
    final l = _nonEmpty(location);
    final n = _nonEmpty(notes);

    if (d != null) parts.add('截止：$d');
    if (p != null) parts.add('优先级：$p');
    if (l != null) parts.add('地点：$l');
    if (n != null) parts.add('备注：$n');

    if (parts.isEmpty) return 'AI 已解析任务标题，可继续补充细节。';
    return parts.join('；');
  }

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
