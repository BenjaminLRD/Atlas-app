import '../../models/coach_message.dart';
import '../../models/fitness_context.dart';
import '../../repositories/coach_conversation_repository.dart';
import 'ai_provider.dart';
import 'mock_ai_provider.dart';

/// Orchestrates AI Coach chat operations, history loading, message generation,
/// error handling, and persistence.
class CoachChatService {
  final AIProvider _aiProvider;
  final CoachConversationRepository _repository;

  const CoachChatService({
    AIProvider? aiProvider,
    CoachConversationRepository? repository,
  })  : _aiProvider = aiProvider ?? const MockAIProvider(),
        _repository = repository ?? const LocalCoachConversationRepository();

  /// Retrieves stored conversation messages.
  List<CoachMessage> getMessages() {
    return _repository.getMessages();
  }

  /// Sends a user message, passes current context to AI provider, creates response,
  /// and persists the conversation thread.
  Future<List<CoachMessage>> sendMessage({
    required String message,
    required FitnessContext context,
    List<CoachMessage>? currentMessages,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return currentMessages ?? getMessages();
    }

    final messages = List<CoachMessage>.from(currentMessages ?? getMessages());

    // 1. Create user CoachMessage
    final userMessage = CoachMessage(
      id: 'msg_user_${DateTime.now().millisecondsSinceEpoch}',
      role: CoachRole.user,
      content: trimmed,
      timestamp: DateTime.now(),
    );
    messages.add(userMessage);

    // Persist immediately after user message
    await _repository.saveMessages(messages);

    try {
      // 2. Query AI Provider with 10-second timeout
      final responseText = await _aiProvider
          .generateResponse(
            message: trimmed,
            context: context,
            history: List.unmodifiable(messages),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => const MockAIProvider().generateResponse(
              message: trimmed,
              context: context,
              history: List.unmodifiable(messages),
            ),
          );

      // 3. Create assistant CoachMessage
      final assistantMessage = CoachMessage(
        id: 'msg_assistant_${DateTime.now().millisecondsSinceEpoch}',
        role: CoachRole.assistant,
        content: responseText,
        timestamp: DateTime.now(),
      );
      messages.add(assistantMessage);
    } catch (_) {
      // Offline / Error fallback handling to MockAIProvider
      final fallbackText = await const MockAIProvider().generateResponse(
        message: trimmed,
        context: context,
        history: List.unmodifiable(messages),
      );

      final errorMessage = CoachMessage(
        id: 'msg_fallback_${DateTime.now().millisecondsSinceEpoch}',
        role: CoachRole.assistant,
        content: fallbackText,
        timestamp: DateTime.now(),
      );
      messages.add(errorMessage);
    }

    // 4. Persist complete conversation thread
    await _repository.saveMessages(messages);
    return messages;
  }

  /// Clears stored conversation thread.
  Future<void> clearConversation() async {
    await _repository.clearConversation();
  }
}
