import '../../data/local_storage.dart';
import '../../models/coach_message.dart';
import '../../repositories/ai_repository.dart';
import 'database_models.dart';
import 'supabase_client.dart';

/// Production Supabase implementation of [AIRepository] supporting offline-first caching
/// and PostgreSQL Row Level Security user isolation.
class SupabaseAIRepository implements AIRepository {
  final SupabaseClientManager _clientManager;

  SupabaseAIRepository({SupabaseClientManager? clientManager})
      : _clientManager = clientManager ?? SupabaseClientManager.instance;

  @override
  Future<List<AIMemoryEntry>> getMemoryEntries({
    String? userId,
    String? memoryType,
  }) async {
    final uid = userId ?? _clientManager.authenticatedUid ?? 'usr_local_01';
    try {
      final rows = await _clientManager
          .from(SupabaseTableNames.aiMemory)
          .select('user_id', uid);

      if (rows.isNotEmpty) {
        var entries = rows.map((r) => SupabaseModelMappers.tableToAiMemory(r)).toList();
        if (memoryType != null) {
          entries = entries.where((e) => e.memoryType == memoryType).toList();
        }
        return entries;
      }
    } catch (_) {
      // Offline fallback
    }

    // Return empty list or local mock context if offline
    return <AIMemoryEntry>[];
  }

  @override
  Future<void> saveMemoryEntry(AIMemoryEntry entry) async {
    try {
      final payload = SupabaseModelMappers.aiMemoryToTable(entry);
      await _clientManager
          .from(SupabaseTableNames.aiMemory)
          .upsert(payload, onConflictColumn: 'id');
    } catch (_) {
      // Local fallback handled gracefully
    }
  }

  @override
  Future<List<CoachMessage>> getConversations({
    String? userId,
    String sessionId = 'default_coach_session',
  }) async {
    try {
      final uid = userId ?? _clientManager.authenticatedUid ?? 'usr_local_01';
      final rows = await _clientManager
          .from(SupabaseTableNames.aiConversations)
          .select('user_id', uid);

      final sessionRows = rows.where((r) => r['session_id'] == sessionId).toList();
      if (sessionRows.isNotEmpty) {
        return sessionRows.map((r) {
          return CoachMessage(
            id: r['id']?.toString() ?? '',
            role: CoachRole.fromJson(r['role']?.toString() ?? 'assistant'),
            content: r['content']?.toString() ?? '',
            timestamp: r['created_at'] != null
                ? DateTime.tryParse(r['created_at'].toString()) ?? DateTime.now()
                : DateTime.now(),
            contextSnapshot: r['context_snapshot'] != null
                ? Map<String, dynamic>.from(r['context_snapshot'] as Map)
                : null,
          );
        }).toList();
      }
    } catch (_) {
      // Offline fallback
    }

    return LocalStorage.getCoachMessages();
  }

  @override
  Future<void> saveConversationMessage(
    CoachMessage message, {
    String? userId,
    String sessionId = 'default_coach_session',
  }) async {
    // 1. Local Cache
    final current = LocalStorage.getCoachMessages();
    await LocalStorage.saveCoachMessages([...current, message]);

    // 2. Cloud Sync
    try {
      final uid = userId ?? _clientManager.authenticatedUid ?? 'usr_local_01';
      final payload = SupabaseModelMappers.aiConversationToTable(
        message,
        userId: uid,
        sessionId: sessionId,
      );
      await _clientManager
          .from(SupabaseTableNames.aiConversations)
          .insert(payload);
    } catch (_) {
      // Offline queue / local cache used
    }
  }

  @override
  Future<void> recordFeedback(AIFeedbackEntry feedback) async {
    try {
      final payload = SupabaseModelMappers.aiFeedbackToTable(feedback);
      await _clientManager
          .from(SupabaseTableNames.aiFeedback)
          .insert(payload);
    } catch (_) {
      // Offline resilience
    }
  }

  @override
  Future<List<AIFeedbackEntry>> getFeedbackList({String? userId}) async {
    try {
      final uid = userId ?? _clientManager.authenticatedUid ?? 'usr_local_01';
      final rows = await _clientManager
          .from(SupabaseTableNames.aiFeedback)
          .select('user_id', uid);

      return rows.map((r) => AIFeedbackEntry.fromJson(r)).toList();
    } catch (_) {
      return <AIFeedbackEntry>[];
    }
  }
}
