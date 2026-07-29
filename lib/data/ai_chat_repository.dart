import '../models/chat_message.dart';
import 'local_storage.dart';

/// Abstract interface for AI chat history persistence operations.
abstract class AIChatRepository {
  List<Map<String, dynamic>> getChatHistory();
  List<ChatMessage> getChatHistoryModels();
  Future<void> saveChatHistory(dynamic history);
  Future<void> clearChatHistory();
}

/// Default local implementation of AIChatRepository backed by LocalStorage.
class LocalAIChatRepository implements AIChatRepository {
  @override
  List<Map<String, dynamic>> getChatHistory() {
    return LocalStorage.getChatHistory();
  }

  @override
  List<ChatMessage> getChatHistoryModels() {
    return LocalStorage.getChatHistoryModels();
  }

  @override
  Future<void> saveChatHistory(dynamic history) async {
    await LocalStorage.saveChatHistory(history);
  }

  @override
  Future<void> clearChatHistory() async {
    await LocalStorage.saveChatHistory([]);
  }
}
