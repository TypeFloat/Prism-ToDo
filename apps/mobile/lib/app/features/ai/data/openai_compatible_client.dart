import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../settings/domain/ai_settings.dart';
import '../domain/ai_client.dart';
import '../domain/ai_connection_result.dart';
import '../domain/ai_parse_result.dart';
import '../domain/ai_request_error.dart';

enum _GatewayEndpointKind { chatCompletions, responses }

class _GatewayAttempt {
  const _GatewayAttempt({required this.uri, required this.kind});

  final Uri uri;
  final _GatewayEndpointKind kind;
}

class _GatewayResponse {
  const _GatewayResponse({
    required this.response,
    required this.kind,
    required this.endpoint,
    required this.attemptedEndpoints,
  });

  final http.Response response;
  final _GatewayEndpointKind kind;
  final Uri endpoint;
  final List<Uri> attemptedEndpoints;
}

class OpenAICompatibleClient implements AIClient {
  const OpenAICompatibleClient({http.Client? httpClient})
    : _httpClient = httpClient;

  final http.Client? _httpClient;

  http.Client get _client => _httpClient ?? http.Client();

  @override
  Future<AIConnectionResult> testConnection({
    required AISettings settings,
  }) async {
    final validationError = validateSettings(settings);
    if (validationError != null) {
      return AIConnectionResult(success: false, message: validationError);
    }

    final uri = buildChatCompletionsUri(settings);
    final preflight = await preflightCheck(uri, settings);
    if (preflight != null) return preflight;

    try {
      final endpointResponse = await _postWithFallback(
        settings: settings,
        rawText: '请回复一个简短的 ok，用于验证 API 连通性。',
      );
      final response = endpointResponse.response;
      final decodedBody = decodeResponseBody(response);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (_isCompatibilityStatus(response.statusCode)) {
          return AIConnectionResult(
            success: false,
            message:
                'URL 不兼容或方法不支持：尝试了 ${_formatEndpoints(endpointResponse.attemptedEndpoints)}，均未成功（最终 ${response.statusCode}）。',
            statusCode: response.statusCode,
            rawResponse: decodedBody,
          );
        }
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
      return AIConnectionResult(
        success: false,
        message: '请求超时：连接在设定时间内无响应（默认 30 秒）。',
      );
    } on SocketException catch (error) {
      return AIConnectionResult(
        success: false,
        message: 'DNS/网络错误：${error.message}',
      );
    } on HandshakeException catch (error) {
      return AIConnectionResult(success: false, message: 'TLS/证书握手错误：$error');
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
    if (validationError != null) throw AIRequestError(validationError);

    try {
      final endpointResponse = await _postWithFallback(
        settings: settings,
        rawText: rawText,
      );
      final response = endpointResponse.response;
      final decodedBody = decodeResponseBody(response);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (_isCompatibilityStatus(response.statusCode)) {
          throw AIRequestError(
            'URL 不兼容或方法不支持：尝试了 ${_formatEndpoints(endpointResponse.attemptedEndpoints)}，最终返回 ${response.statusCode}。请检查网关地址与接口类型。',
          );
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
        normalizedTitle: normalized == null || normalized.isEmpty
            ? rawText.trim().replaceAll(RegExp(r'\s+'), ' ')
            : normalized,
        summary: buildReadableSummary(
          deadline: deadline,
          priority: priority,
          location: location,
          notes: notes,
        ),
        deadline: _nonEmpty(deadline),
        priority: _nonEmpty(priority),
        location: _nonEmpty(location),
        notes: _nonEmpty(notes),
      );
    } on TimeoutException {
      throw const AIRequestError('请求超时：连接在设定时间内无响应（默认 30 秒）。');
    } on SocketException catch (error) {
      throw AIRequestError('DNS/网络错误：${error.message}');
    } on HandshakeException catch (error) {
      throw AIRequestError('TLS/证书握手错误：$error');
    }
  }

  String? validateSettings(AISettings settings) {
    if (!settings.enabled) return '请先启用 AI 解析。';
    if (settings.effectiveBaseUrl.trim().isEmpty) {
      return '请填写 Base URL，或设置环境变量 PRISM_TODO_AI_URL。';
    }
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

  Future<AIConnectionResult?> preflightCheck(
    Uri uri,
    AISettings settings,
  ) async {
    try {
      await InternetAddress.lookup(uri.host);
    } on SocketException catch (error) {
      return AIConnectionResult(
        success: false,
        message: 'DNS 错误：无法解析域名 ${uri.host}（${error.message}）',
      );
    }

    try {
      final probe = await _client
          .get(uri)
          .timeout(
            Duration(seconds: int.tryParse(settings.timeoutSeconds) ?? 30),
          );
      // 注意：很多 OpenAI 兼容网关不支持 GET /chat/completions，会返回 404/405。
      // 这里仅做弱探测，不据此判失败，最终以后续 POST 结果为准。
      if (probe.statusCode >= 500) {
        return AIConnectionResult(
          success: false,
          message: '网关预检失败：$uri 返回 ${probe.statusCode}。',
          statusCode: probe.statusCode,
          rawResponse: decodeResponseBody(probe),
        );
      }
    } on HandshakeException catch (error) {
      return AIConnectionResult(success: false, message: 'TLS 预检失败：$error');
    } on SocketException catch (error) {
      return AIConnectionResult(
        success: false,
        message: '网络预检失败：${error.message}',
      );
    } catch (_) {
      // 某些服务不支持 GET 探测，这里不阻断，继续走 POST。
    }

    return null;
  }

  Uri buildChatCompletionsUri(AISettings settings) {
    final candidates = buildChatCompletionsUriCandidates(settings);
    return candidates.first;
  }

  List<Uri> buildChatCompletionsUriCandidates(AISettings settings) {
    final base = settings.effectiveBaseUrl.trim().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    final uri = Uri.parse(base);
    final normalizedPath = uri.path.replaceAll(RegExp(r'/+$'), '');

    final candidates = <Uri>[];

    void addPath(String path) {
      final normalized = path.isEmpty ? '/' : path;
      final candidate = uri.replace(path: normalized);
      if (!candidates.any((u) => u.toString() == candidate.toString())) {
        candidates.add(candidate);
      }
    }

    if (normalizedPath.endsWith('/chat/completions')) {
      addPath(normalizedPath);
    } else if (normalizedPath.endsWith('/responses')) {
      addPath(
        normalizedPath.replaceFirst(
          RegExp(r'/responses$'),
          '/chat/completions',
        ),
      );
      addPath('/v1/chat/completions');
    } else if (normalizedPath.endsWith('/v1')) {
      addPath('$normalizedPath/chat/completions');
      addPath('/v1/chat/completions');
    } else if (normalizedPath.contains('/v1/')) {
      addPath(normalizedPath);
      addPath(_replaceAfterV1(normalizedPath, 'chat/completions'));
      addPath('/v1/chat/completions');
    } else {
      final prefix = normalizedPath.isEmpty ? '' : normalizedPath;
      addPath('$prefix/v1/chat/completions');
      addPath('$prefix/chat/completions');
      addPath('/v1/chat/completions');
      addPath('/chat/completions');
    }

    return candidates;
  }

  List<Uri> buildResponsesUriCandidates(AISettings settings) {
    final base = settings.effectiveBaseUrl.trim().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    final uri = Uri.parse(base);
    final normalizedPath = uri.path.replaceAll(RegExp(r'/+$'), '');

    final candidates = <Uri>[];

    void addPath(String path) {
      final normalized = path.isEmpty ? '/' : path;
      final candidate = uri.replace(path: normalized);
      if (!candidates.any((u) => u.toString() == candidate.toString())) {
        candidates.add(candidate);
      }
    }

    if (normalizedPath.endsWith('/responses')) {
      addPath(normalizedPath);
    } else if (normalizedPath.endsWith('/chat/completions')) {
      addPath(
        normalizedPath.replaceFirst(
          RegExp(r'/chat/completions$'),
          '/responses',
        ),
      );
      addPath('/v1/responses');
    } else if (normalizedPath.endsWith('/v1')) {
      addPath('$normalizedPath/responses');
      addPath('/v1/responses');
    } else if (normalizedPath.contains('/v1/')) {
      addPath(_replaceAfterV1(normalizedPath, 'responses'));
      addPath('/v1/responses');
    } else {
      final prefix = normalizedPath.isEmpty ? '' : normalizedPath;
      addPath('$prefix/v1/responses');
      addPath('$prefix/responses');
      addPath('/v1/responses');
      addPath('/responses');
    }

    return candidates;
  }

  Map<String, String> buildHeaders(AISettings settings) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = settings.effectiveApiKey.trim();
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
      // 兼容部分网关仅接受 key 头。
      headers['api-key'] = token;
      headers['x-api-key'] = token;
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
          'content':
              'Extract a todo into JSON with keys: title, deadline, priority, location, notes. Return valid JSON only.',
        },
        {'role': 'user', 'content': rawText},
      ],
    };
  }

  Map<String, dynamic> buildResponsesPayload({
    required String rawText,
    required AISettings settings,
  }) {
    return {
      'model': settings.model,
      'temperature': double.tryParse(settings.temperature) ?? 0.2,
      'input': [
        {
          'role': 'system',
          'content':
              'Extract a todo into JSON with keys: title, deadline, priority, location, notes. Return valid JSON only.',
        },
        {'role': 'user', 'content': rawText},
      ],
    };
  }

  String decodeResponseBody(http.Response response) =>
      utf8.decode(response.bodyBytes);

  String extractAssistantContent(String responseBody) {
    final decoded = jsonDecode(responseBody);
    return extractAssistantContentFromDecoded(decoded);
  }

  String extractAssistantContentFromDecoded(Object? decoded) {
    if (decoded is! Map<String, dynamic>) return '';

    final fromChatChoices = _extractFromChatChoices(decoded);
    if (fromChatChoices.isNotEmpty) return fromChatChoices;

    final outputText = _nonEmpty(decoded['output_text'] as String?);
    if (outputText != null) return outputText;

    final fromResponsesOutput = _extractFromResponsesOutput(decoded['output']);
    if (fromResponsesOutput.isNotEmpty) return fromResponsesOutput;

    return '';
  }

  Map<String, dynamic> parseStructuredContent(String content) {
    final decoded = jsonDecode(content);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const AIRequestError('AI 返回内容不是合法 JSON 对象。');
  }

  String buildReadableSummary({
    String? deadline,
    String? priority,
    String? location,
    String? notes,
  }) {
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

  Future<_GatewayResponse> _postWithFallback({
    required AISettings settings,
    required String rawText,
  }) async {
    final timeout = Duration(
      seconds: int.tryParse(settings.timeoutSeconds) ?? 30,
    );
    final attempts = _buildAttempts(settings);

    for (var i = 0; i < attempts.length; i++) {
      final attempt = attempts[i];
      final payload = attempt.kind == _GatewayEndpointKind.chatCompletions
          ? buildChatCompletionsPayload(rawText: rawText, settings: settings)
          : buildResponsesPayload(rawText: rawText, settings: settings);

      final response = await _client
          .post(
            attempt.uri,
            headers: buildHeaders(settings),
            body: jsonEncode(payload),
          )
          .timeout(timeout);

      final isOk = response.statusCode >= 200 && response.statusCode < 300;
      final canRetry = i < attempts.length - 1;

      if (isOk) {
        return _GatewayResponse(
          response: response,
          kind: attempt.kind,
          endpoint: attempt.uri,
          attemptedEndpoints: attempts
              .map((item) => item.uri)
              .toList(growable: false),
        );
      }

      if (canRetry && _isCompatibilityStatus(response.statusCode)) {
        continue;
      }

      return _GatewayResponse(
        response: response,
        kind: attempt.kind,
        endpoint: attempt.uri,
        attemptedEndpoints: attempts
            .map((item) => item.uri)
            .toList(growable: false),
      );
    }

    throw const AIRequestError('未找到可用的 AI 网关 endpoint。');
  }

  List<_GatewayAttempt> _buildAttempts(AISettings settings) {
    final attempts = <_GatewayAttempt>[];

    void addAttempt(Uri uri, _GatewayEndpointKind kind) {
      final key = '${kind.name}:${uri.toString()}';
      final exists = attempts.any(
        (item) => '${item.kind.name}:${item.uri.toString()}' == key,
      );
      if (!exists) {
        attempts.add(_GatewayAttempt(uri: uri, kind: kind));
      }
    }

    for (final uri in buildChatCompletionsUriCandidates(settings)) {
      addAttempt(uri, _GatewayEndpointKind.chatCompletions);
    }
    for (final uri in buildResponsesUriCandidates(settings)) {
      addAttempt(uri, _GatewayEndpointKind.responses);
    }

    return attempts;
  }

  bool _isCompatibilityStatus(int statusCode) =>
      statusCode == 404 ||
      statusCode == 405 ||
      statusCode == 415 ||
      statusCode == 422;

  String _extractFromChatChoices(Map<String, dynamic> decoded) {
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) return '';

    final first = choices.first;
    if (first is! Map<String, dynamic>) return '';

    final message = first['message'];
    if (message is! Map<String, dynamic>) return '';

    return _extractTextFromContent(message['content']);
  }

  String _extractFromResponsesOutput(Object? output) {
    if (output is! List) return '';

    final parts = <String>[];
    for (final item in output) {
      if (item is! Map<String, dynamic>) continue;

      final directText = _nonEmpty(item['text'] as String?);
      if (directText != null) {
        parts.add(directText);
        continue;
      }

      final contentText = _extractTextFromContent(item['content']);
      if (contentText.isNotEmpty) {
        parts.add(contentText);
      }
    }

    return parts.join('\n').trim();
  }

  String _extractTextFromContent(Object? content) {
    if (content is String) {
      return content.trim();
    }

    if (content is List) {
      final parts = <String>[];
      for (final item in content) {
        if (item is String) {
          final trimmed = item.trim();
          if (trimmed.isNotEmpty) parts.add(trimmed);
          continue;
        }

        if (item is Map<String, dynamic>) {
          final text =
              _nonEmpty(item['text'] as String?) ??
              _nonEmpty(item['output_text'] as String?);
          if (text != null) parts.add(text);
        }
      }
      return parts.join('\n').trim();
    }

    return '';
  }

  String _replaceAfterV1(String normalizedPath, String suffix) {
    final marker = '/v1/';
    final index = normalizedPath.lastIndexOf(marker);
    if (index < 0) return normalizedPath;
    final prefix = normalizedPath.substring(0, index + marker.length - 1);
    return '$prefix/$suffix';
  }

  String _formatEndpoints(List<Uri> endpoints) =>
      endpoints.map((uri) => uri.path).join(' -> ');

  String? _nonEmpty(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
