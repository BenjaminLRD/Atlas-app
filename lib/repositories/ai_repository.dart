import '../models/coach_message.dart';
import '../services/supabase/database_models.dart';

/// Abstract repository interface for AI Memory, Conversations, and Feedback.
abstract class AIRepository {
  /// Fetches persistent AI memory entries for a user, optionally filtered by [memoryType].
  Future<List<AIMemoryEntry>> getMemoryEntries({String? userId, String? memoryType});

  /// Saves or updates an AI memory entry.
  Future<void> saveMemoryEntry(AIMemoryEntry entry);

  /// Fetches conversation messages for a user session.
  Future<List<CoachMessage>> getConversations({String? userId, String sessionId = 'default_coach_session'});

  /// Saves a conversation exchange message to the AI conversation store.
  Future<void> saveConversationMessage(CoachMessage message, {String? userId, String sessionId = 'default_coach_session'});

  /// Records user feedback on an AI recommendation.
  Future<void> recordFeedback(AIFeedbackEntry feedback);

  /// Fetches submitted feedback entries for the authenticated user.
  Future<List<AIFeedbackEntry>> getFeedbackList({String? userId});
}
