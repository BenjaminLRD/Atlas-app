import 'mock_sync_provider.dart';
import 'sync_metadata.dart';
import 'sync_provider.dart';
import 'sync_queue.dart';

/// Central service coordinating local data changes and remote cloud synchronization,
/// processing pending sync queues, performing timestamp conflict resolution,
/// and updating sync metadata status.
class SyncService {
  final SyncProvider _provider;
  final SyncQueue _queue;
  SyncMetadata _metadata;

  SyncService({
    SyncProvider? provider,
    SyncQueue? queue,
    String? deviceId,
  })  : _provider = provider ?? MockSyncProvider(),
        _queue = queue ?? SyncQueue(),
        _metadata = SyncMetadata.initial(deviceId: deviceId);

  /// Current device synchronization metadata.
  SyncMetadata get metadata => _metadata;

  /// Active pending sync queue.
  SyncQueue get queue => _queue;

  /// Associated sync provider.
  SyncProvider get provider => _provider;

  /// Current sync status.
  SyncStatus get status => _metadata.syncStatus;

  /// Timestamp of last successful sync.
  DateTime? get lastSyncTime => _metadata.lastSyncTime;

  /// Number of pending changes queued for sync.
  int get pendingChangesCount => _queue.length;

  /// Record a local data change into the pending sync queue.
  void recordLocalChange({
    required String key,
    required dynamic payload,
    String type = 'upload',
  }) {
    final operation = SyncOperation(
      operationId: 'op_${DateTime.now().microsecondsSinceEpoch}',
      type: type,
      key: key,
      createdAt: DateTime.now(),
      payload: payload,
    );
    _queue.addOperation(operation);
    _metadata = _metadata.copyWith(
      pendingChanges: _queue.length,
    );
  }

  /// Resolve conflict between local payload and remote payload using timestamp comparison.
  /// The payload with the more recent timestamp wins. If equal, local payload wins.
  dynamic resolveConflict({
    required dynamic localPayload,
    required DateTime localTimestamp,
    required dynamic remotePayload,
    required DateTime remoteTimestamp,
  }) {
    if (remoteTimestamp.isAfter(localTimestamp)) {
      return remotePayload;
    }
    return localPayload;
  }

  /// Flushes pending queued operations to remote cloud provider.
  Future<void> processSyncQueue() async {
    final pending = List<SyncOperation>.from(_queue.getPendingOperations());
    final failedOps = <SyncOperation>[];

    for (final op in pending) {
      try {
        if (op.type == 'upload') {
          await _provider.upload(op.payload, op.key);
        }
        _queue.removeOperation(op.operationId);
      } catch (_) {
        failedOps.add(op);
      }
    }

    _metadata = _metadata.copyWith(
      pendingChanges: _queue.length,
    );

    if (failedOps.isNotEmpty) {
      throw SyncException(
          'Failed to process ${failedOps.length} queued sync operation(s).');
    }
  }

  /// Execute complete synchronization pass.
  /// 1. Updates metadata state to [SyncStatus.syncing].
  /// 2. Processes queued local operations.
  /// 3. Calls remote provider [syncAll].
  /// 4. Updates metadata to [SyncStatus.synced] with timestamp on success.
  /// 5. Transitions metadata to [SyncStatus.offline] or [SyncStatus.error] on failure.
  Future<SyncMetadata> synchronize({
    Map<String, dynamic>? localDataToUpload,
  }) async {
    _metadata = _metadata.copyWith(
      syncStatus: SyncStatus.syncing,
      clearLastError: true,
    );

    if (localDataToUpload != null) {
      localDataToUpload.forEach((key, val) {
        recordLocalChange(key: key, payload: val);
      });
    }

    try {
      await processSyncQueue();
      await _provider.syncAll();

      final now = DateTime.now();
      _metadata = _metadata.copyWith(
        lastSyncTime: now,
        syncStatus: SyncStatus.synced,
        pendingChanges: _queue.length,
        clearLastError: true,
      );
      return _metadata;
    } on SyncException catch (e) {
      final isOffline = e.message.toLowerCase().contains('offline');
      _metadata = _metadata.copyWith(
        syncStatus: isOffline ? SyncStatus.offline : SyncStatus.error,
        pendingChanges: _queue.length,
        lastError: e.message,
      );
      rethrow;
    } catch (e) {
      _metadata = _metadata.copyWith(
        syncStatus: SyncStatus.error,
        pendingChanges: _queue.length,
        lastError: e.toString(),
      );
      rethrow;
    }
  }

  /// Direct upload helper.
  Future<void> upload<T>(T data, String key) async {
    try {
      await _provider.upload<T>(data, key);
      _queue.removeOperation(key);
      _metadata = _metadata.copyWith(
        pendingChanges: _queue.length,
      );
    } catch (e) {
      recordLocalChange(key: key, payload: data);
      rethrow;
    }
  }

  /// Direct download helper.
  Future<T?> download<T>(String key) async {
    return await _provider.download<T>(key);
  }
}
