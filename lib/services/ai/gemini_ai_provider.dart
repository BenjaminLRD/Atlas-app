import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/coach_message.dart';
import '../../models/fitness_context.dart';
import 'ai_config.dart';
import 'ai_provider.dart';
import 'coach_memory.dart';
import 'coach_prompt_builder.dart';
import 'mock_ai_provider.dart';

/// Production AI Provider connecting to Google Gemini REST API with automatic fallback.
class GeminiAIProvider implements AIProvider {
  final AIConfig config;
  final CoachMemory memory;
  final CoachPromptBuilder promptBuilder;
  final AIProvider fallbackProvider;
  final http.Client? httpClient;

  const GeminiAIProvider({
    this.config = const AIConfig(),
    this.memory = const CoachMemory(),
    this.promptBuilder = const CoachPromptBuilder(),
    this.fallbackProvider = const MockAIProvider(),
    this.httpClient,
  });

  @override
  Future<String> generateResponse({
    required String message,
    required FitnessContext context,
    required List<CoachMessage> history,
  }) async {
    // If API key is missing or invalid, fallback immediately to MockAIProvider
    if (!config.isValidKey) {
      return fallbackProvider.generateResponse(
        message: message,
        context: context,
        history: history,
      );
    }

    try {
      final promptText = promptBuilder.buildPrompt(
        message: message,
        context: context,
        memory: memory,
      );

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/${config.model}:generateContent?key=${config.apiKey}',
      );

      final client = httpClient ?? http.Client();
      final response = await client
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': promptText}
                  ]
                }
              ],
              'generationConfig': {
                'temperature': config.temperature,
              }
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = body['candidates'] as List<dynamic>?;
        if (candidates != null && candidates.isNotEmpty) {
          final content = candidates.first['content'] as Map<String, dynamic>?;
          final parts = content?['parts'] as List<dynamic>?;
          if (parts != null && parts.isNotEmpty) {
            final text = parts.first['text'] as String?;
            if (text != null && text.trim().isNotEmpty) {
              return text.trim();
            }
          }
        }
      }

      // API returned error status or empty candidate -> fallback
      return fallbackProvider.generateResponse(
        message: message,
        context: context,
        history: history,
      );
    } catch (_) {
      // Network failure, timeout, or exception -> fallback to Mock
      return fallbackProvider.generateResponse(
        message: message,
        context: context,
        history: history,
      );
    }
  }
}
