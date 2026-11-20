import 'dart:async';
import 'supabase_env.dart';

/// Exception thrown when Row Level Security (RLS) policies are violated.
class PostgresSecurityException implements Exception {
  final String message;
  final String? table;
  final String? operation;

  const PostgresSecurityException(this.message, {this.table, this.operation});

  @override
  String toString() =>
      'PostgresSecurityException: $message (Table: $table, Operation: $operation)';
}

/// Supabase Storage Bucket Client for uploading, downloading, and deleting files.
class SupabaseStorageBucket {
  final String bucketId;
  final Map<String, List<int>> _fileStore = {};
  final String? Function() _currentAuthUid;

  SupabaseStorageBucket(this.bucketId, this._currentAuthUid);

  /// Uploads binary data to [path] in this bucket.
  Future<String> upload(String path, List<int> bytes) async {
    final uid = _currentAuthUid();
    if (uid == null) {
      throw const PostgresSecurityException(
        'User must be authenticated to upload files to storage.',
      );
    }
    _fileStore[path] = bytes;
    return getPublicUrl(path);
  }

  /// Uploads UTF-8 string data.
  Future<String> uploadString(String path, String data) async {
    return upload(path, data.codeUnits);
  }

  /// Downloads binary data from [path].
  Future<List<int>?> download(String path) async {
    return _fileStore[path];
  }

  /// Deletes file at [path].
  Future<void> delete(String path) async {
    final uid = _currentAuthUid();
    if (uid == null) {
      throw const PostgresSecurityException(
        'User must be authenticated to delete files from storage.',
      );
    }
    if (bucketId == 'avatars' && !path.startsWith(uid)) {
      throw const PostgresSecurityException(
        'Users can only delete their own uploaded avatar files.',
      );
    }
    _fileStore.remove(path);
  }

  /// Returns public URL for file at [path].
  String getPublicUrl(String path) {
    return 'https://supabase.aizawlgym.com/storage/v1/object/public/$bucketId/$path';
  }
}

/// Supabase Storage Manager.
class SupabaseStorageClient {
  final Map<String, SupabaseStorageBucket> _buckets = {};
  final String? Function() _currentAuthUid;

  SupabaseStorageClient(this._currentAuthUid);

  SupabaseStorageBucket from(String bucketId) {
    return _buckets.putIfAbsent(
      bucketId,
      () => SupabaseStorageBucket(bucketId, _currentAuthUid),
    );
  }
}

/// Supabase Realtime Channel for live event streaming.
class SupabaseRealtimeChannel {
  final String topic;
  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  SupabaseRealtimeChannel(this.topic);

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  void broadcast(String event, Map<String, dynamic> payload) {
    _controller.add({
      'event': event,
      'topic': topic,
      'payload': payload,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void close() {
    _controller.close();
  }
}

/// Database table query interface with simulated RLS and network simulation.
class SupabaseTableQuery {
  final String tableName;
  final Map<String, List<Map<String, dynamic>>> _dbStore;
  final String? Function() _currentAuthUid;
  final bool Function() _isNetworkErrorSimulated;
  final void Function(String event, Map<String, dynamic> payload)? _onMutation;

  SupabaseTableQuery(
    this.tableName,
    this._dbStore,
    this._currentAuthUid,
    this._isNetworkErrorSimulated, [
    this._onMutation,
  ]);

  void _checkNetwork() {
    if (_isNetworkErrorSimulated()) {
      throw const FormatException('Network connection unavailable (Offline)');
    }
  }

  /// List of tables that require user_id isolation under RLS.
  static const List<String> userIsolatedTables = [
    'profiles',
    'fitness_profiles',
    'user_preferences',
    'user_goals',
    'weight_goals',
    'workout_sessions',
    'workout_exercises',
    'workout_sets',
    'personal_records',
    'nutrition_logs',
    'meal_entries',
    'ai_memory',
    'ai_conversations',
    'ai_feedback',
    'health_metrics',
    'body_metrics',
    'recovery_scores',
    'saved_content',
    'user_challenges',
    'challenge_participants',
    'analytics_events',
    'posts',
    'community_posts',
    'comments',
  ];

  /// Select records from table matching optional filter.
  Future<List<Map<String, dynamic>>> select([
    String? column,
    dynamic value,
  ]) async {
    _checkNetwork();
    final rows = _dbStore[tableName] ?? [];
    final uid = _currentAuthUid();

    Iterable<Map<String, dynamic>> visibleRows = rows;

    if (userIsolatedTables.contains(tableName)) {
      if (uid != null &&
          tableName != 'posts' &&
          tableName != 'community_posts' &&
          tableName != 'comments') {
        visibleRows = visibleRows.where((r) {
          if (tableName == 'profiles' || tableName == 'fitness_profiles') {
            return (r['id'] == uid || r['user_id'] == uid);
          }
          return r.containsKey('user_id') ? r['user_id'] == uid : true;
        });
      }
    }

    if (column != null && value != null) {
      visibleRows = visibleRows.where((row) => row[column] == value);
    }
    return visibleRows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  /// Insert a record into table with RLS validation.
  Future<Map<String, dynamic>> insert(Map<String, dynamic> data) async {
    _checkNetwork();
    final uid = _currentAuthUid();

    // RLS check on insertion
    if (tableName != 'users' && uid != null) {
      if (tableName == 'profiles') {
        final profileId = data['id'] ?? data['user_id'];
        if (profileId != null && profileId != uid) {
          throw PostgresSecurityException(
            'RLS Violation: Cannot insert profile with id $profileId when authenticated as $uid',
            table: tableName,
            operation: 'INSERT',
          );
        }
      } else if (data.containsKey('user_id') && data['user_id'] != null && data['user_id'] != uid) {
        throw PostgresSecurityException(
          'RLS Violation: Cannot insert record with user_id ${data['user_id']} when authenticated as $uid',
          table: tableName,
          operation: 'INSERT',
        );
      }
    }

    final rows = _dbStore.putIfAbsent(tableName, () => []);
    if (data.containsKey('id') && data['id'] != null) {
      rows.removeWhere((row) => row['id'] == data['id']);
    }
    final record = Map<String, dynamic>.from(data);
    rows.add(record);
    _onMutation?.call('INSERT', record);
    return record;
  }

  /// Update record in table matching filter [column] and [value] with RLS check.
  Future<List<Map<String, dynamic>>> update(
    Map<String, dynamic> data,
    String column,
    dynamic value,
  ) async {
    _checkNetwork();
    final uid = _currentAuthUid();
    final rows = _dbStore[tableName] ?? [];
    final updated = <Map<String, dynamic>>[];

    for (final row in rows) {
      if (row[column] == value) {
        if (uid != null) {
          if (tableName == 'profiles' && row['id'] != uid && row['user_id'] != uid) {
            throw PostgresSecurityException(
              'RLS Violation: User $uid cannot update profile owned by ${row['id']}',
              table: tableName,
              operation: 'UPDATE',
            );
          }
          if (row.containsKey('user_id') && row['user_id'] != uid) {
            throw PostgresSecurityException(
              'RLS Violation: User $uid cannot update record owned by ${row['user_id']}',
              table: tableName,
              operation: 'UPDATE',
            );
          }
        }
        row.addAll(data);
        final copy = Map<String, dynamic>.from(row);
        updated.add(copy);
        _onMutation?.call('UPDATE', copy);
      }
    }
    return updated;
  }

  /// Upsert record into table matching primary key [onConflictColumn].
  Future<Map<String, dynamic>> upsert(
    Map<String, dynamic> data, {
    String onConflictColumn = 'id',
  }) async {
    _checkNetwork();
    final uid = _currentAuthUid();

    // RLS validation
    if (tableName != 'users' && uid != null) {
      if (tableName == 'profiles') {
        final profileId = data['id'] ?? data['user_id'];
        if (profileId != null && profileId != uid) {
          throw PostgresSecurityException(
            'RLS Violation: Cannot upsert profile for user $profileId when authenticated as $uid',
            table: tableName,
            operation: 'UPSERT',
          );
        }
      } else if (data.containsKey('user_id') && data['user_id'] != null && data['user_id'] != uid) {
        throw PostgresSecurityException(
          'RLS Violation: Cannot upsert record for user ${data['user_id']} when authenticated as $uid',
          table: tableName,
          operation: 'UPSERT',
        );
      }
    }

    final rows = _dbStore.putIfAbsent(tableName, () => []);
    final matchValue = data[onConflictColumn];
    if (matchValue != null) {
      rows.removeWhere((row) => row[onConflictColumn] == matchValue);
    }
    final record = Map<String, dynamic>.from(data);
    rows.add(record);
    _onMutation?.call('UPSERT', record);
    return record;
  }

  /// Delete records matching filter [column] and [value] with RLS check.
  Future<int> delete(String column, dynamic value) async {
    _checkNetwork();
    final uid = _currentAuthUid();
    final rows = _dbStore[tableName] ?? [];
    final beforeCount = rows.length;

    if (uid != null) {
      for (final row in rows) {
        if (row[column] == value) {
          if (tableName == 'profiles' && row['id'] != uid && row['user_id'] != uid) {
            throw PostgresSecurityException(
              'RLS Violation: User $uid cannot delete profile owned by ${row['id']}',
              table: tableName,
              operation: 'DELETE',
            );
          }
          if (row.containsKey('user_id') && row['user_id'] != uid) {
            throw PostgresSecurityException(
              'RLS Violation: User $uid cannot delete record owned by ${row['user_id']}',
              table: tableName,
              operation: 'DELETE',
            );
          }
        }
      }
    }

    rows.removeWhere((row) => row[column] == value);
    return beforeCount - rows.length;
  }
}

/// Singleton manager for Supabase client configuration, database table access,
/// Storage buckets, Realtime channels, and Stored Procedures (RPC).
class SupabaseClientManager {
  static SupabaseClientManager? _instance;

  SupabaseEnv _env;
  bool _isInitialized = false;
  String? _authenticatedUid;
  bool _simulateNetworkError = false;

  final Map<String, List<Map<String, dynamic>>> _dbStore = {};
  final Map<String, SupabaseRealtimeChannel> _channels = {};
  late final SupabaseStorageClient _storage;

  SupabaseClientManager._({SupabaseEnv? env})
    : _env = env ?? SupabaseEnv.dev() {
    _storage = SupabaseStorageClient(() => _authenticatedUid);
  }

  /// Singleton instance accessor.
  static SupabaseClientManager get instance {
    _instance ??= SupabaseClientManager._();
    return _instance!;
  }

  /// Reset singleton instance.
  static void resetInstance() {
    _instance = null;
  }

  /// Current environment configuration.
  SupabaseEnv get env => _env;

  /// Initialization state indicator.
  bool get isInitialized => _isInitialized;

  /// In-memory table store view.
  Map<String, List<Map<String, dynamic>>> get dbStore => _dbStore;

  /// Active authenticated user UID for RLS evaluation.
  String? get authenticatedUid => _authenticatedUid;

  /// Storage client accessor.
  SupabaseStorageClient get storage => _storage;

  /// Sets current authenticated UID for RLS context.
  void setAuthUid(String? uid) {
    _authenticatedUid = uid;
  }

  /// Simulates offline / network errors for testing.
  void setSimulateNetworkError(bool simulate) {
    _simulateNetworkError = simulate;
  }

  /// Initialize Supabase client with [env] configuration.
  void initialize(SupabaseEnv env) {
    _env = env;
    _isInitialized = true;
  }

  /// Access a table builder for database queries.
  SupabaseTableQuery from(String table) {
    return SupabaseTableQuery(
      table,
      _dbStore,
      () => _authenticatedUid,
      () => _simulateNetworkError,
      (event, payload) {
        if (_channels.containsKey(table)) {
          _channels[table]!.broadcast(event, payload);
        }
        if (table == 'posts' || table == 'community_posts') {
          if (_channels.containsKey('posts') && table != 'posts') {
            _channels['posts']!.broadcast(event, payload);
          }
          if (_channels.containsKey('community_posts') && table != 'community_posts') {
            _channels['community_posts']!.broadcast(event, payload);
          }
        }
      },
    );
  }

  /// Call a PostgreSQL stored procedure / function.
  Future<dynamic> rpc(String functionName, [Map<String, dynamic>? params]) async {
    if (_simulateNetworkError) {
      throw const FormatException('Network connection unavailable (Offline)');
    }

    final p = params ?? {};
    final uid = (p['p_user_id']?.toString()) ?? _authenticatedUid ?? 'usr_local_01';

    switch (functionName) {
      case 'calculate_weekly_volume':
        final sessions = _dbStore['workout_sessions'] ?? [];
        final userSessions = sessions.where((s) => s['user_id'] == uid);
        double sum = 0.0;
        for (final s in userSessions) {
          sum += (s['total_volume'] as num?)?.toDouble() ??
                 (s['total_volume_kg'] as num?)?.toDouble() ?? 0.0;
        }
        return sum;

      case 'calculate_training_streak':
        final sessions = _dbStore['workout_sessions'] ?? [];
        final userSessions = sessions.where((s) => s['user_id'] == uid).toList();
        return userSessions.length;

      case 'calculate_leaderboard_rank':
        final entries = _dbStore['leaderboards'] ?? [];
        final userEntry = entries.firstWhere((e) => e['user_id'] == uid, orElse: () => {});
        if (userEntry.isEmpty) return 0;
        final userXp = (userEntry['total_xp'] as num?)?.toInt() ?? 0;
        final higher = entries.where((e) => ((e['total_xp'] as num?)?.toInt() ?? 0) > userXp);
        return higher.length + 1;

      case 'record_ai_memory':
        final memType = p['p_memory_type']?.toString() ?? 'general';
        final memVal = p['p_memory_value'] as Map<String, dynamic>? ?? {};
        final confidence = (p['p_confidence'] as num?)?.toDouble() ?? 1.0;
        final id = 'mem_${DateTime.now().millisecondsSinceEpoch}';
        await from('ai_memory').insert({
          'id': id,
          'user_id': uid,
          'memory_type': memType,
          'memory_value': memVal,
          'confidence': confidence,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        return id;

      case 'get_user_readiness_summary':
        final scores = _dbStore['recovery_scores'] ?? [];
        final metrics = _dbStore['health_metrics'] ?? [];
        final userScore = scores.firstWhere((s) => s['user_id'] == uid, orElse: () => {});
        final userMetric = metrics.firstWhere((m) => m['user_id'] == uid, orElse: () => {});
        return {
          'recovery_score': userScore['score'] ?? userScore['recovery_score'] ?? 85,
          'readiness_state': userScore['readiness_state'] ?? 'optimal',
          'resting_heart_rate': userMetric['resting_heart_rate'] ?? 58,
          'sleep_hours': userMetric['sleep_hours'] ?? 7.5,
          'steps': userMetric['steps'] ?? 8500,
        };

      default:
        return null;
    }
  }

  /// Access or create a Realtime channel for [topic].
  SupabaseRealtimeChannel channel(String topic) {
    return _channels.putIfAbsent(topic, () => SupabaseRealtimeChannel(topic));
  }

  /// Clear in-memory database store.
  void clearData() {
    _dbStore.clear();
    _authenticatedUid = null;
    _simulateNetworkError = false;
  }
}
