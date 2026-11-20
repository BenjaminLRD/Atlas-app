import '../../models/fitness_context.dart';
import 'ai_provider.dart';
import 'multimodal/chat_attachment.dart';

/// Standardized multi-model interface for AI providers in Atlas.
/// Prepares the architecture for orchestration across Google Gemini, OpenAI,
/// Claude, on-device/local models (e.g. MediaPipe / llama.cpp), and offline fallbacks.
abstract class AIModelProvider implements AIProvider {
  /// Unique identifier of the model family (e.g. 'gemini-1.5-flash', 'gpt-4o-mini', 'offline-heuristic').
  String get modelIdentifier;

  /// Maximum supported context window tokens.
  int get maxContextTokens;

  /// Whether the provider natively supports multimodal vision input.
  bool get supportsVision;

  /// Whether the provider natively supports structured tool / function calling.
  bool get supportsToolCalling;

  /// Analyzes an attached image directly and returns structured insights.
  Future<String> analyzeImage({
    required ChatAttachment attachment,
    required String prompt,
    required FitnessContext context,
  });

  /// Estimates token usage count for a given text snippet.
  int estimateTokens(String text);
}
