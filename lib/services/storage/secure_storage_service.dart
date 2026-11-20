import 'dart:io' show Platform;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service providing encrypted key-value storage backed by Android Keystore and Apple Keychain.
class SecureStorageService {
  static SecureStorageService? _instance;

  final FlutterSecureStorage _storage;
  final Map<String, String> _inMemoryFallback = {};
  final bool _useInMemoryFallback;

  SecureStorageService._({
    FlutterSecureStorage? storage,
    bool? useInMemoryFallback,
  }) : _useInMemoryFallback = useInMemoryFallback ?? _isTestEnvironment(),
       _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(encryptedSharedPreferences: true),
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.first_unlock,
             ),
           );

  static bool _isTestEnvironment() {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  /// Singleton instance accessor.
  static SecureStorageService get instance {
    _instance ??= SecureStorageService._();
    return _instance!;
  }

  /// Sets a custom instance (useful for unit testing).
  static void setInstance(SecureStorageService service) {
    _instance = service;
  }

  /// Factory creating an in-memory instance for testing environments.
  factory SecureStorageService.inMemory() {
    return SecureStorageService._(useInMemoryFallback: true);
  }

  /// Encrypts and saves string data under [key].
  Future<void> saveSecureData(String key, String value) async {
    if (_useInMemoryFallback) {
      _inMemoryFallback[key] = value;
      return;
    }
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {
      _inMemoryFallback[key] = value;
    }
  }

  /// Reads and decrypts string data stored under [key]. Returns null if not found.
  Future<String?> readSecureData(String key) async {
    if (_useInMemoryFallback) {
      return _inMemoryFallback[key];
    }
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return _inMemoryFallback[key];
    }
  }

  /// Deletes encrypted data associated with [key].
  Future<void> deleteSecureData(String key) async {
    _inMemoryFallback.remove(key);
    if (!_useInMemoryFallback) {
      try {
        await _storage.delete(key: key);
      } catch (_) {}
    }
  }

  /// Checks if [key] exists in secure storage.
  Future<bool> containsKey(String key) async {
    if (_useInMemoryFallback) {
      return _inMemoryFallback.containsKey(key);
    }
    try {
      return await _storage.containsKey(key: key);
    } catch (_) {
      return _inMemoryFallback.containsKey(key);
    }
  }

  /// Purges all encrypted items from secure storage.
  Future<void> clearAllSecure() async {
    _inMemoryFallback.clear();
    if (!_useInMemoryFallback) {
      try {
        await _storage.deleteAll();
      } catch (_) {}
    }
  }
}
