import '../data/local_storage.dart';
import '../models/coach_message.dart';

/// Repository interface for AI Coach conversation persistence.
abstract class CoachConversationRepository {
  List<CoachMessage> getMessages();
  Future<void> saveMessages(List<CoachMessage> messages);
  Future<void> clearConversation();
}

/// Local storage backed implementation of [CoachConversationRepository].
class LocalCoachConversationRepository implements CoachConversationRepository {
  const LocalCoachConversationRepository();

  @override
  List<CoachMessage> getMessages() {
    return LocalStorage.getCoachMessages();
  }

  @override
  Future<void> saveMessages(List<CoachMessage> messages) async {
    await LocalStorage.saveCoachMessages(messages);
  }

  @override
  Future<void> clearConversation() async {
    await LocalStorage.clearCoachMessages();
  }
}
