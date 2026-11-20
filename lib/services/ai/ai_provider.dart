import '../../models/coach_message.dart';
import '../../models/fitness_context.dart';
import 'multimodal/chat_attachment.dart';

/// Abstract interface defining the AI Provider contract for fitness coaching responses.
abstract class AIProvider {
  /// Name of the AI provider engine (e.g. 'Google Gemini' or 'Mock Offline Fallback').
  String get providerName;

  /// Whether this provider is configured to connect to a live remote AI API.
  bool get isOnline;

  /// Generates a context-aware response based on the user's input message,
  /// current [FitnessContext], previous conversation [history], and optional [attachment].
  Future<String> generateResponse({
    required String message,
    required FitnessContext context,
    required List<CoachMessage> history,
    ChatAttachment? attachment,
  });
}
