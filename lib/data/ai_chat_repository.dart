import '../models/chat_message.dart';
import 'local_storage.dart';

/// Abstract interface for AI chat history persistence operations.
abstract class AIChatRepository {
  List<ChatMessage> getChatHistory();
  Future<void> saveChatHistory(List<ChatMessage> history);
  Future<void> clearChatHistory();
}

/// Default local implementation of AIChatRepository backed by LocalStorage.
class LocalAIChatRepository implements AIChatRepository {
  @override
  List<ChatMessage> getChatHistory() {
    return LocalStorage.getChatHistoryModels();
  }

  @override
  Future<void> saveChatHistory(List<ChatMessage> history) async {
    await LocalStorage.saveChatHistory(history);
  }

  @override
  Future<void> clearChatHistory() async {
    await LocalStorage.saveChatHistory(<ChatMessage>[]);
  }
}
