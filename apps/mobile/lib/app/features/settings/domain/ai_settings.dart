import 'dart:io';

typedef AIEnvironmentReader = Map<String, String> Function();

class AISettings {
  const AISettings({
    this.enabled = false,
    this.advancedMode = false,
    this.baseUrl = '',
    this.apiKey = '',
    this.model = 'gpt-4o-mini',
    this.temperature = '0.2',
    this.timeoutSeconds = '30',
  });

  static const envBaseUrlKey = 'PRISM_TODO_AI_URL';
  static const envApiKeyKey = 'PRISM_TODO_AI_TOKEN';
  static const defaultBaseUrl = 'https://api.openai.com';
  static AIEnvironmentReader environmentReader = _defaultEnvironmentReader;

  static Map<String, String> _defaultEnvironmentReader() => Platform.environment;

  final bool enabled;
  final bool advancedMode;
  final String baseUrl;
  final String apiKey;
  final String model;
  final String temperature;
  final String timeoutSeconds;

  String get effectiveBaseUrl {
    final local = baseUrl.trim();
    if (local.isNotEmpty) return local;
    final env = environmentReader()[envBaseUrlKey]?.trim() ?? '';
    if (env.isNotEmpty) return env;
    return defaultBaseUrl;
  }

  String get effectiveApiKey {
    final local = apiKey.trim();
    if (local.isNotEmpty) return local;
    return environmentReader()[envApiKeyKey]?.trim() ?? '';
  }

  bool get usingEnvBaseUrl => baseUrl.trim().isEmpty && ((environmentReader()[envBaseUrlKey]?.trim().isNotEmpty) ?? false);
  bool get usingEnvApiKey => apiKey.trim().isEmpty && ((environmentReader()[envApiKeyKey]?.trim().isNotEmpty) ?? false);

  AISettings copyWith({
    bool? enabled,
    bool? advancedMode,
    String? baseUrl,
    String? apiKey,
    String? model,
    String? temperature,
    String? timeoutSeconds,
  }) {
    return AISettings(
      enabled: enabled ?? this.enabled,
      advancedMode: advancedMode ?? this.advancedMode,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'advancedMode': advancedMode,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'temperature': temperature,
        'timeoutSeconds': timeoutSeconds,
      };

  factory AISettings.fromJson(Map<String, dynamic> json) => AISettings(
        enabled: json['enabled'] as bool? ?? false,
        advancedMode: json['advancedMode'] as bool? ?? false,
        baseUrl: json['baseUrl'] as String? ?? '',
        apiKey: json['apiKey'] as String? ?? '',
        model: json['model'] as String? ?? 'gpt-4o-mini',
        temperature: json['temperature'] as String? ?? '0.2',
        timeoutSeconds: json['timeoutSeconds'] as String? ?? '30',
      );
}
