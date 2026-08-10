import 'sync_provider.dart';

/// Exception thrown when remote sync operations fail (e.g. network disconnect or upload rejection).
class SyncException implements Exception {
  final String message;
  const SyncException(this.message);

  @override
  String toString() => 'SyncException: $message';
}

/// Development implementation of [SyncProvider] with in-memory cloud storage,
/// configurable online/offline state, and upload failure simulation.
class MockSyncProvider implements SyncProvider {
  final Map<String, dynamic> _cloudStorage = {};
  bool _isOnline = true;
  bool _shouldFailUpload = false;

  bool get isOnline => _isOnline;
  bool get shouldFailUpload => _shouldFailUpload;

  /// Unmodifiable view of current in-memory cloud state for verification.
  Map<String, dynamic> get cloudStorage => Map.unmodifiable(_cloudStorage);

  /// Toggle simulated network connectivity.
  void setOnline(bool online) {
    _isOnline = online;
  }

  /// Toggle simulated upload failures for error recovery testing.
  void setShouldFailUpload(bool fail) {
    _shouldFailUpload = fail;
  }

  /// Clear simulated remote storage state.
  void clearCloudState() {
    _cloudStorage.clear();
  }

  @override
  Future<void> upload<T>(T data, String key) async {
    if (!_isOnline) {
      throw const SyncException('Device is offline. Cannot upload to cloud.');
    }
    if (_shouldFailUpload) {
      throw const SyncException('Simulated cloud upload failure.');
    }
    _cloudStorage[key] = data;
  }

  @override
  Future<T?> download<T>(String key) async {
    if (!_isOnline) {
      throw const SyncException('Device is offline. Cannot download from cloud.');
    }
    final raw = _cloudStorage[key];
    if (raw is T) {
      return raw;
    }
    return null;
  }

  @override
  Future<void> syncAll() async {
    if (!_isOnline) {
      throw const SyncException('Device is offline. Remote sync pass aborted.');
    }
    if (_shouldFailUpload) {
      throw const SyncException('Simulated cloud sync failure during syncAll.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
