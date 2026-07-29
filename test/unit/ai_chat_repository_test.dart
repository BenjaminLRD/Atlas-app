import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/data/ai_chat_repository.dart';
import 'package:aizawl_gym/data/ai_chat_service.dart';
import 'package:aizawl_gym/models/chat_message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('AIChatRepository & AIChatService Tests', () {
    test('AIChatService retrieves default chat history', () {
      final repo = LocalAIChatRepository();
      final service = AIChatService(repo);

      final history = service.getChatHistory();
      expect(history.isNotEmpty, isTrue);
      expect(history.first.sender, equals('bot'));
    });

    test('AIChatService saves and clears chat history', () async {
      final service = AIChatService();

      final customMessages = [
        ChatMessage(sender: 'user', text: 'Hello AI'),
        ChatMessage(sender: 'bot', text: 'Hello User'),
      ];

      await service.saveChatHistory(customMessages);
      final retrieved = service.getChatHistory();
      expect(retrieved.length, equals(2));
      expect(retrieved.first.text, equals('Hello AI'));

      await service.clearChatHistory();
      final cleared = service.getChatHistory();
      expect(cleared.isEmpty, isTrue);
    });

    test('AIChatService generates response for prompts', () async {
      final service = AIChatService();

      final response = await service.generateResponse("generate today's workout");
      expect(response.sender, equals('bot'));
      expect(response.text, contains("Today's Hypertrophy Protocol"));
      expect(response.tags, contains('Hypertrophy Protocol'));
    });
  });
}
