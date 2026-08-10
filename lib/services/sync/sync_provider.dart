/// Abstract interface defining the standard contract for remote data synchronization.
abstract class SyncProvider {
  /// Upload typed data payload to remote cloud storage under [key].
  Future<void> upload<T>(T data, String key);

  /// Download typed data payload from remote cloud storage associated with [key].
  Future<T?> download<T>(String key);

  /// Execute a full remote synchronization pass.
  Future<void> syncAll();
}
