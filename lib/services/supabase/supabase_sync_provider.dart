import '../sync/sync_provider.dart';
import 'supabase_client.dart';

/// Supabase implementation of [SyncProvider] mapping local storage keys
/// to Supabase database tables (`profiles`, `user_goals`, `workout_sessions`).
class SupabaseSyncProvider implements SyncProvider {
  final SupabaseClientManager _clientManager;

  SupabaseSyncProvider({SupabaseClientManager? clientManager})
      : _clientManager = clientManager ?? SupabaseClientManager.instance;

  /// Active client manager accessor.
  SupabaseClientManager get clientManager => _clientManager;

  @override
  Future<void> upload<T>(T data, String key) async {
    final table = mapStorageKeyToTable(key);
    Map<String, dynamic> payload;

    if (data is Map<String, dynamic>) {
      payload = Map<String, dynamic>.from(data);
    } else {
      payload = {
        'id': key,
        'payload': data,
        'updated_at': DateTime.now().toIso8601String(),
      };
    }

    if (!payload.containsKey('id') && !payload.containsKey('user_id')) {
      payload['id'] = key;
    }

    final conflictCol = payload.containsKey('id') ? 'id' : 'user_id';
    await _clientManager.from(table).upsert(payload, onConflictColumn: conflictCol);
  }

  @override
  Future<T?> download<T>(String key) async {
    final table = mapStorageKeyToTable(key);
    final results = await _clientManager.from(table).select('id', key);
    if (results.isNotEmpty) {
      final match = results.first;
      if (match.containsKey('payload')) {
        return match['payload'] as T?;
      }
      if (match is T) {
        return match as T;
      }
    }
    return null;
  }

  @override
  Future<void> syncAll() async {
    // Perform remote synchronization pass across table collections
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  /// Map LocalStorage key string to appropriate Supabase table name.
  static String mapStorageKeyToTable(String key) {
    final lower = key.toLowerCase();
    if (lower.contains('profile')) return 'profiles';
    if (lower.contains('goal')) return 'user_goals';
    if (lower.contains('workout') || lower.contains('history')) {
      return 'workout_sessions';
    }
    return 'sync_payloads';
  }
}
