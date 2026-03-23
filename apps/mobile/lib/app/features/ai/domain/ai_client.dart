import '../../settings/domain/ai_settings.dart';
import 'ai_parse_result.dart';

abstract class AIClient {
  Future<AIParseResult> parseTask({
    required String rawText,
    required AISettings settings,
  });
}
