import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud_session.dart';

/// One pending change to push to the backend.
class CloudWrite {
  /// Table to write to.
  final String table;

  /// `upsert` or `delete`.
  final String op;

  /// Row to upsert (includes the key columns), or the key columns to delete.
  final Map<String, dynamic> row;

  /// Comma-separated key columns, e.g. `user_id,id`.
  final String keyColumns;

  const CloudWrite({
    required this.table,
    required this.op,
    required this.row,
    required this.keyColumns,
  });

  const CloudWrite.upsert(this.table, this.row, {required this.keyColumns})
    : op = 'upsert';

  const CloudWrite.delete(this.table, this.row, {required this.keyColumns})
    : op = 'delete';

  /// Identifies the record this write targets, so a newer write to the same
  /// record replaces an older pending one.
  String get recordKey =>
      '$table|${keyColumns.split(',').map((c) => row[c.trim()]).join('|')}';

  Map<String, dynamic> toJson() => {
    'table': table,
    'op': op,
    'row': row,
    'key_columns': keyColumns,
  };

  factory CloudWrite.fromJson(Map<String, dynamic> json) => CloudWrite(
    table: json['table'] as String,
    op: json['op'] as String,
    row: Map<String, dynamic>.from(json['row'] as Map),
    keyColumns: json['key_columns'] as String,
  );
}

/// Performs writes against the backend. Swappable so tests run offline.
abstract class CloudWriter {
  Future<void> apply(CloudWrite write);
}

/// [CloudWriter] backed by the Supabase client. Row Level Security limits
/// every write to the signed-in user's own rows.
class SupabaseCloudWriter implements CloudWriter {
  const SupabaseCloudWriter();

  @override
  Future<void> apply(CloudWrite write) async {
    final client = CloudSession.client;
    if (client == null) {
      throw StateError('Supabase is not initialized');
    }
    final table = client.from(write.table);
    if (write.op == 'delete') {
      final match = <String, Object>{
        for (final c in write.keyColumns.split(','))
          c.trim(): write.row[c.trim()] as Object,
      };
      await table.delete().match(match);
    } else {
      await table.upsert(write.row, onConflict: write.keyColumns);
    }
  }
}

/// Persistent outbox of local changes waiting to reach the backend.
///
/// Saves always land in local storage first; the matching cloud write is
/// queued here and pushed in order. Entries survive restarts and are retried
/// on the next [flush] until they succeed. A newer write to the same record
/// replaces the pending older one.
class CloudSyncQueue {
  static const String prefsKey = 'cloud_sync_outbox_v1';

  static CloudSyncQueue? _instance;
  static CloudSyncQueue get instance =>
      _instance ??= CloudSyncQueue(const SupabaseCloudWriter());
  static void setInstance(CloudSyncQueue queue) => _instance = queue;
  static void resetInstance() => _instance = null;

  final CloudWriter _writer;
  Future<bool>? _activeFlush;

  CloudSyncQueue(this._writer);

  /// Number of writes still waiting to be pushed.
  Future<int> get pendingCount async => (await _load()).length;

  /// Record keys with a pending write, used to protect unsynced local edits
  /// from being overwritten by a pull.
  Future<Set<String>> pendingRecordKeys() async =>
      (await _load()).map((w) => w.recordKey).toSet();

  /// Queues [write] and starts pushing in the background.
  Future<void> enqueue(CloudWrite write) async {
    final pending = await _load();
    pending.removeWhere((w) => w.recordKey == write.recordKey);
    pending.add(write);
    await _save(pending);
    unawaited(flush());
  }

  /// Pushes pending writes in order. Stops at the first failure and keeps it
  /// and everything after it for the next attempt. Returns true when the
  /// queue is empty afterwards.
  Future<bool> flush() async {
    // Let any in-progress flush finish, then run a fresh pass so this call
    // sees the current sign-in state and queue contents.
    while (_activeFlush != null) {
      await _activeFlush;
    }
    final pass = _flush();
    _activeFlush = pass;
    try {
      return await pass;
    } finally {
      if (identical(_activeFlush, pass)) _activeFlush = null;
    }
  }

  Future<bool> _flush() async {
    if (CloudSession.userId == null) return (await _load()).isEmpty;

    while (true) {
      final pending = await _load();
      if (pending.isEmpty) return true;
      final next = pending.first;
      try {
        await _writer.apply(next);
      } catch (e) {
        debugPrint(
          '[CloudSyncQueue] ${next.table} write failed, will retry: $e',
        );
        return false;
      }
      // Re-read: new writes may have been queued while this one was in flight.
      final latest = await _load();
      latest.removeWhere(
        (w) => w.recordKey == next.recordKey && _sameWrite(w, next),
      );
      await _save(latest);
    }
  }

  /// Drops all pending writes (used on sign-out so one account's changes
  /// never reach another).
  Future<void> clear() async => _save(const []);

  bool _sameWrite(CloudWrite a, CloudWrite b) =>
      jsonEncode(a.toJson()) == jsonEncode(b.toJson());

  Future<List<CloudWrite>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => CloudWrite.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<CloudWrite> writes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      prefsKey,
      jsonEncode(writes.map((w) => w.toJson()).toList()),
    );
  }
}
