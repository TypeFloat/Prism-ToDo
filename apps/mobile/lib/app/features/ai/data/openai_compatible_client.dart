import '../domain/ai_client.dart';
import '../domain/ai_parse_result.dart';
import '../../settings/domain/ai_settings.dart';

class OpenAICompatibleClient implements AIClient {
  const OpenAICompatibleClient();

  @override
  Future<AIParseResult> parseTask({
    required String rawText,
    required AISettings settings,
  }) async {
    final normalized = rawText.trim().replaceAll(RegExp(r'\s+'), ' ');
    return AIParseResult(
      normalizedTitle: normalized,
      summary: 'OpenAI 兼容接口骨架已就位。待填入 Base URL / API Key / Model 后接通真实解析。',
      deadline: null,
      priority: null,
      location: null,
    );
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
          'content': 'You extract todo metadata such as title, deadline, priority and location.',
        },
        {
          'role': 'user',
          'content': rawText,
        },
      ],
    };
  }
}
