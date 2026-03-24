import '../../settings/domain/ai_settings.dart';
import 'ai_connection_result.dart';
import 'ai_parse_result.dart';

abstract class AIClient {
  Future<AIConnectionResult> testConnection({required AISettings settings});

  Future<AIParseResult> parseTask({
    required String rawText,
    required AISettings settings,
  });
}
