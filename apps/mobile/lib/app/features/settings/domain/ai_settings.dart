class AISettings {
  const AISettings({
    this.enabled = false,
    this.advancedMode = false,
    this.baseUrl = 'https://api.openai.com',
    this.apiKey = '',
    this.model = 'gpt-4o-mini',
    this.temperature = '0.2',
    this.timeoutSeconds = '30',
  });

  final bool enabled;
  final bool advancedMode;
  final String baseUrl;
  final String apiKey;
  final String model;
  final String temperature;
  final String timeoutSeconds;

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
        baseUrl: json['baseUrl'] as String? ?? 'https://api.openai.com',
        apiKey: json['apiKey'] as String? ?? '',
        model: json['model'] as String? ?? 'gpt-4o-mini',
        temperature: json['temperature'] as String? ?? '0.2',
        timeoutSeconds: json['timeoutSeconds'] as String? ?? '30',
      );
}
