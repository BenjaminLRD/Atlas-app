/// Configuration settings for the Gemini AI Provider
class AIConfig {
  final String apiKey;
  final String model;
  final double temperature;

  const AIConfig({
    this.apiKey = '',
    this.model = 'gemini-1.5-flash',
    this.temperature = 0.7,
  });

  /// Factory loading configuration from environment variables or compile-time constants.
  factory AIConfig.fromEnvironment() {
    const key = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    const model = String.fromEnvironment('GEMINI_MODEL', defaultValue: 'gemini-1.5-flash');
    return const AIConfig(
      apiKey: key,
      model: model,
      temperature: 0.7,
    );
  }

  factory AIConfig.fromJson(Map<String, dynamic> json) {
    return AIConfig(
      apiKey: json['apiKey'] as String? ?? (json['api_key'] as String? ?? ''),
      model: json['model'] as String? ?? 'gemini-1.5-flash',
      temperature: (json['temperature'] as num? ?? 0.7).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'api_key': apiKey,
        'model': model,
        'temperature': temperature,
      };

  AIConfig copyWith({
    String? apiKey,
    String? model,
    double? temperature,
  }) {
    return AIConfig(
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
    );
  }

  bool get isValidKey => apiKey.isNotEmpty && apiKey.trim().length > 10;
}
