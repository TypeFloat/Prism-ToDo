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

class _PromptTodoNode {
  const _PromptTodoNode({
    required this.title,
    required this.date,
    required this.time,
    required this.priority,
    required this.location,
    required this.note,
    required this.list,
  });

  final String title;
  final String date;
  final String time;
  final String priority;
  final String location;
  final String note;
  final List<_PromptTodoNode> list;
}

class OpenAICompatibleClient implements AIClient {
  const OpenAICompatibleClient({
    http.Client? httpClient,
    Future<String> Function()? promptLoader,
  }) : _httpClient = httpClient,
       _promptLoader = promptLoader;

  final http.Client? _httpClient;
  final Future<String> Function()? _promptLoader;

  static const String _healthCheckPrompt =
      'You are a connectivity test assistant. Reply with a short "ok".';
  static const List<String> _sharedPromptCandidates = [
    'shared/prompts/todo.md',
    '../shared/prompts/todo.md',
    '../../shared/prompts/todo.md',
  ];

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
        systemPrompt: _healthCheckPrompt,
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
      final todoPrompt = await _loadSharedTodoPrompt();
      final endpointResponse = await _postWithFallback(
        settings: settings,
        systemPrompt: todoPrompt,
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

      final parsed = _parseStructuredContent(content);
      if (parsed.isEmpty) {
        throw const AIRequestError('AI 返回结构为空数组，无法生成任务。');
      }

      final primary = parsed.first;
      final normalized = _nonEmpty(primary.title);
      final deadline = _composeDeadline(primary.date, primary.time);
      final priority = _nonEmpty(primary.priority);
      final location = _nonEmpty(primary.location);
      final notes = _nonEmpty(primary.note);

      final parsedSubtasks = <_PromptTodoNode>[
        ...primary.list,
        ...parsed.skip(1),
      ];
      return AIParseResult(
        normalizedTitle: normalized == null || normalized.isEmpty
            ? rawText.trim().replaceAll(RegExp(r'\s+'), ' ')
            : normalized,
        summary: buildReadableSummary(
          location: location,
          notes: notes,
          subtaskCount: parsedSubtasks.length,
        ),
        deadline: _nonEmpty(deadline),
        priority: _nonEmpty(priority),
        location: _nonEmpty(location),
        notes: _nonEmpty(notes),
        subtasks: parsedSubtasks.map(_toSubtask).toList(growable: false),
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
    required String systemPrompt,
    required String rawText,
    required AISettings settings,
  }) {
    return {
      'model': settings.model,
      'temperature': double.tryParse(settings.temperature) ?? 0.2,
      'messages': [
        {
          'role': 'system',
          'content': systemPrompt,
        },
        {'role': 'user', 'content': rawText},
      ],
    };
  }

  Map<String, dynamic> buildResponsesPayload({
    required String systemPrompt,
    required String rawText,
    required AISettings settings,
  }) {
    return {
      'model': settings.model,
      'temperature': double.tryParse(settings.temperature) ?? 0.2,
      'input': [
        {
          'role': 'system',
          'content': systemPrompt,
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

  List<_PromptTodoNode> _parseStructuredContent(String content) {
    final decoded = jsonDecode(content);
    if (decoded is! List) {
      throw const AIRequestError('AI 返回格式错误：最外层必须是 JSON 数组。');
    }
    return _validateTodoNodeList(decoded, path: r'$');
  }

  String buildReadableSummary({
    String? location,
    String? notes,
    int subtaskCount = 0,
  }) {
    final parts = <String>[];
    final l = _nonEmpty(location);
    final n = _nonEmpty(notes);

    if (n != null) parts.add(n);
    if (l != null) parts.add(l);
    if (subtaskCount > 0) parts.add('子任务 $subtaskCount 项');

    if (parts.isEmpty) return 'AI 已解析任务标题。';
    return parts.join('；');
  }

  Future<_GatewayResponse> _postWithFallback({
    required AISettings settings,
    required String systemPrompt,
    required String rawText,
  }) async {
    final timeout = Duration(
      seconds: int.tryParse(settings.timeoutSeconds) ?? 30,
    );
    final attempts = _buildAttempts(settings);

    for (var i = 0; i < attempts.length; i++) {
      final attempt = attempts[i];
      final payload = attempt.kind == _GatewayEndpointKind.chatCompletions
          ? buildChatCompletionsPayload(
              systemPrompt: systemPrompt,
              rawText: rawText,
              settings: settings,
            )
          : buildResponsesPayload(
              systemPrompt: systemPrompt,
              rawText: rawText,
              settings: settings,
            );

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

  Future<String> _loadSharedTodoPrompt() async {
    if (_promptLoader != null) {
      final loaded = await _promptLoader.call();
      final prompt = loaded.trim();
      if (prompt.isEmpty) {
        throw const AIRequestError('共享提示词为空：shared/prompts/todo.md。');
      }
      return prompt;
    }

    for (final path in _sharedPromptCandidates) {
      final file = File(path);
      if (!await file.exists()) continue;
      final content = await file.readAsString();
      final prompt = content.trim();
      if (prompt.isNotEmpty) return prompt;
    }

    throw const AIRequestError(
      '未找到共享提示词 shared/prompts/todo.md，请先同步该文件。',
    );
  }

  List<_PromptTodoNode> _validateTodoNodeList(
    List<dynamic> values, {
    required String path,
  }) {
    final items = <_PromptTodoNode>[];
    for (var i = 0; i < values.length; i++) {
      final itemPath = '$path[$i]';
      final raw = values[i];
      if (raw is! Map<String, dynamic>) {
        throw AIRequestError('$itemPath 必须是对象。');
      }
      final title = _readString(raw, itemPath, 'title');
      final date = _readString(raw, itemPath, 'date');
      final time = _readString(raw, itemPath, 'time');
      final priority = _readString(raw, itemPath, 'priority');
      final location = _readString(raw, itemPath, 'location');
      final note = _readString(raw, itemPath, 'note');
      final listRaw = raw['list'];
      if (listRaw is! List) {
        throw AIRequestError('$itemPath.list 必须是数组。');
      }

      _validateDate(date, '$itemPath.date');
      _validateTime(time, '$itemPath.time');
      _validatePriority(priority, '$itemPath.priority');

      items.add(
        _PromptTodoNode(
          title: title.trim(),
          date: date.trim(),
          time: time.trim(),
          priority: priority.trim(),
          location: location.trim(),
          note: note.trim(),
          list: _validateTodoNodeList(listRaw, path: '$itemPath.list'),
        ),
      );
    }
    return items;
  }

  String _readString(Map<String, dynamic> map, String path, String key) {
    if (!map.containsKey(key)) {
      throw AIRequestError('$path.$key 缺失。');
    }
    final value = map[key];
    if (value is! String) {
      throw AIRequestError('$path.$key 必须是字符串。');
    }
    return value;
  }

  void _validateDate(String value, String path) {
    final text = value.trim();
    if (text.isEmpty) return;
    final match = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text);
    if (!match) {
      throw AIRequestError('$path 格式错误，必须是 yyyy-mm-dd。');
    }

    final parts = text.split('-').map(int.parse).toList(growable: false);
    final year = parts[0];
    final month = parts[1];
    final day = parts[2];
    final date = DateTime.tryParse('${text}T00:00:00');
    if (date == null ||
        date.year != year ||
        date.month != month ||
        date.day != day) {
      throw AIRequestError('$path 日期无效。');
    }
  }

  void _validateTime(String value, String path) {
    final text = value.trim();
    if (text.isEmpty) return;
    final match = RegExp(r'^\d{2}:\d{2}$').firstMatch(text);
    if (match == null) {
      throw AIRequestError('$path 格式错误，必须是 hh:mm。');
    }
    final parts = text.split(':').map(int.parse).toList(growable: false);
    final hour = parts[0];
    final minute = parts[1];
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw AIRequestError('$path 时间无效。');
    }
  }

  void _validatePriority(String value, String path) {
    const allowed = {'高', '中', '低'};
    final text = value.trim();
    if (!allowed.contains(text)) {
      throw AIRequestError('$path 仅允许 高/中/低。');
    }
  }

  String? _composeDeadline(String date, String time) {
    final d = date.trim();
    if (d.isEmpty) return null;
    final t = time.trim();
    if (t.isEmpty) return d;
    return '${d}T$t:00';
  }

  AIParseSubtask _toSubtask(_PromptTodoNode node) {
    return AIParseSubtask(
      title: node.title,
      deadline: _composeDeadline(node.date, node.time),
      priority: _nonEmpty(node.priority),
      location: _nonEmpty(node.location),
      notes: _nonEmpty(node.note),
      subtasks: node.list.map(_toSubtask).toList(growable: false),
    );
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
