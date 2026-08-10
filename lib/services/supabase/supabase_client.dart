import 'supabase_env.dart';

/// Lightweight database table query interface for Supabase client operations.
class SupabaseTableQuery {
  final String tableName;
  final Map<String, List<Map<String, dynamic>>> _dbStore;

  SupabaseTableQuery(this.tableName, this._dbStore);

  /// Select records from table matching optional filter.
  Future<List<Map<String, dynamic>>> select([String? column, dynamic value]) async {
    final rows = _dbStore[tableName] ?? [];
    if (column != null && value != null) {
      return rows.where((row) => row[column] == value).toList();
    }
    return List.from(rows);
  }

  /// Insert a record into table.
  Future<Map<String, dynamic>> insert(Map<String, dynamic> data) async {
    final rows = _dbStore.putIfAbsent(tableName, () => []);
    rows.removeWhere((row) => row['id'] != null && row['id'] == data['id']);
    rows.add(Map<String, dynamic>.from(data));
    return data;
  }

  /// Update record in table matching filter [column] and [value].
  Future<List<Map<String, dynamic>>> update(
      Map<String, dynamic> data, String column, dynamic value) async {
    final rows = _dbStore[tableName] ?? [];
    final updated = <Map<String, dynamic>>[];
    for (final row in rows) {
      if (row[column] == value) {
        row.addAll(data);
        updated.add(row);
      }
    }
    return updated;
  }

  /// Upsert record into table matching primary key [onConflictColumn].
  Future<Map<String, dynamic>> upsert(Map<String, dynamic> data,
      {String onConflictColumn = 'id'}) async {
    final rows = _dbStore.putIfAbsent(tableName, () => []);
    final matchVal = data[onConflictColumn];
    if (matchVal != null) {
      rows.removeWhere((r) => r[onConflictColumn] == matchVal);
    }
    rows.add(Map<String, dynamic>.from(data));
    return data;
  }

  /// Delete record from table matching filter [column] and [value].
  Future<void> delete(String column, dynamic value) async {
    final rows = _dbStore[tableName];
    if (rows != null) {
      rows.removeWhere((row) => row[column] == value);
    }
  }
}

/// Singleton manager for Supabase client configuration and database table access.
class SupabaseClientManager {
  static SupabaseClientManager? _instance;

  SupabaseEnv _env;
  bool _isInitialized = false;
  final Map<String, List<Map<String, dynamic>>> _dbStore = {};

  SupabaseClientManager._({SupabaseEnv? env})
      : _env = env ?? SupabaseEnv.dev();

  /// Singleton instance accessor.
  static SupabaseClientManager get instance {
    _instance ??= SupabaseClientManager._();
    return _instance!;
  }

  /// Reset singleton instance (useful for testing).
  static void resetInstance() {
    _instance = null;
  }

  /// Current environment configuration.
  SupabaseEnv get env => _env;

  /// Initialization state indicator.
  bool get isInitialized => _isInitialized;

  /// In-memory table store view (for test assertions).
  Map<String, List<Map<String, dynamic>>> get dbStore => _dbStore;

  /// Initialize Supabase client with [env] configuration.
  void initialize(SupabaseEnv env) {
    _env = env;
    _isInitialized = true;
  }

  /// Access a table builder for database queries.
  SupabaseTableQuery from(String table) {
    return SupabaseTableQuery(table, _dbStore);
  }

  /// Clear in-memory database store.
  void clearData() {
    _dbStore.clear();
  }
}
