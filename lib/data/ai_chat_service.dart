import '../models/chat_message.dart';
import 'ai_chat_repository.dart';

/// High-level service handling AI Coach chat history and response generation.
/// Architecture is ready for seamless integration with real AI backends (e.g. Gemini / Firebase AI Logic).
class AIChatService {
  final AIChatRepository _repository;

  AIChatService([AIChatRepository? repository])
      : _repository = repository ?? LocalAIChatRepository();

  /// Retrieve chat history as strongly-typed ChatMessage objects
  List<ChatMessage> getChatHistory() {
    return _repository.getChatHistory();
  }

  /// Persist updated chat history
  Future<void> saveChatHistory(List<ChatMessage> history) async {
    await _repository.saveChatHistory(history);
  }

  /// Clear all stored chat history
  Future<void> clearChatHistory() async {
    await _repository.clearChatHistory();
  }

  /// Generate response message from user input prompt
  Future<ChatMessage> generateResponse(String userText) async {
    await Future.delayed(const Duration(seconds: 1));
    final lower = userText.toLowerCase();
    String responseText = "That's a great request! Let me process that for you.";
    List<String>? tags;
    bool routineCard = false;

    if (lower.contains("generate today's workout") || lower.contains("workout")) {
      responseText =
          "I've generated Today's Hypertrophy Protocol for you. Let's make sure we hit the proper form on target compound lifts.";
      tags = ['Hypertrophy Protocol', 'Compound Lifts'];
    } else if (lower.contains("analyze my progress") || lower.contains("progress")) {
      responseText =
          "Your metrics indicate consistency. You've completed 80% of your goals and your body fat is trending downwards nicely.";
      tags = ['Consistent Trend', '80% Progress'];
    } else if (lower.contains("diet") ||
        lower.contains("protein") ||
        lower.contains("improve my diet")) {
      responseText =
          "To optimize recovery, make sure you hit your goal of 140g of protein. Focus on lean sources like chicken breast, eggs, and whey.";
      tags = ['Diet Focus', '140g Target'];
    } else if (lower.contains("replace") || lower.contains("exercise")) {
      responseText =
          "Certainly. We can swap squats for Romanian Deadlifts or Leg Press to reduce knee loading while maintaining hypertrophy stimulus.";
      routineCard = true;
    } else if (lower.contains("form") || lower.contains("proper form")) {
      responseText =
          "Keep your spine neutral, drive through your heels, and maintain tension throughout the eccentric phase of the lift.";
      tags = ['Form Check', 'Neutral Spine'];
    }

    return ChatMessage(
      sender: 'bot',
      text: responseText,
      tags: tags,
      routineCard: routineCard ? true : null,
    );
  }
}
