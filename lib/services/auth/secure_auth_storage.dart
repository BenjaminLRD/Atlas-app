import 'dart:io' show Platform;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure token and credentials repository backed by Android Keystore and iOS Keychain.
class SecureAuthStorage {
  static SecureAuthStorage? _instance;

  final FlutterSecureStorage _storage;
  final Map<String, String> _inMemoryFallback = {};
  bool _useInMemoryFallback;

  SecureAuthStorage._({
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
  static SecureAuthStorage get instance {
    _instance ??= SecureAuthStorage._();
    return _instance!;
  }

  /// Sets a custom or mock instance (useful for testing).
  static void setInstance(SecureAuthStorage storage) {
    _instance = storage;
  }

  /// Creates an in-memory instance for testing environments.
  factory SecureAuthStorage.inMemory() {
    return SecureAuthStorage._(useInMemoryFallback: true);
  }

  // Storage Keys
  static const String _keyAccessToken = 'auth_access_token';
  static const String _keyRefreshToken = 'auth_refresh_token';
  static const String _keyUserId = 'auth_user_id';

  /// Saves the active authentication access token securely.
  Future<void> saveAccessToken(String token) async {
    if (_useInMemoryFallback) {
      _inMemoryFallback[_keyAccessToken] = token;
      return;
    }
    try {
      await _storage.write(key: _keyAccessToken, value: token);
    } catch (_) {
      _useInMemoryFallback = true;
      _inMemoryFallback[_keyAccessToken] = token;
    }
  }

  /// Retrieves the saved access token.
  Future<String?> getAccessToken() async {
    if (_useInMemoryFallback) {
      return _inMemoryFallback[_keyAccessToken];
    }
    try {
      return await _storage.read(key: _keyAccessToken);
    } catch (_) {
      _useInMemoryFallback = true;
      return _inMemoryFallback[_keyAccessToken];
    }
  }

  /// Saves the authentication refresh token securely.
  Future<void> saveRefreshToken(String token) async {
    if (_useInMemoryFallback) {
      _inMemoryFallback[_keyRefreshToken] = token;
      return;
    }
    try {
      await _storage.write(key: _keyRefreshToken, value: token);
    } catch (_) {
      _useInMemoryFallback = true;
      _inMemoryFallback[_keyRefreshToken] = token;
    }
  }

  /// Retrieves the saved refresh token.
  Future<String?> getRefreshToken() async {
    if (_useInMemoryFallback) {
      return _inMemoryFallback[_keyRefreshToken];
    }
    try {
      return await _storage.read(key: _keyRefreshToken);
    } catch (_) {
      _useInMemoryFallback = true;
      return _inMemoryFallback[_keyRefreshToken];
    }
  }

  /// Persists full auth session tokens and user identity securely.
  Future<void> saveAuthSession({
    required String accessToken,
    String? refreshToken,
    required String userId,
  }) async {
    await saveAccessToken(accessToken);
    if (refreshToken != null) {
      await saveRefreshToken(refreshToken);
    }
    if (_useInMemoryFallback) {
      _inMemoryFallback[_keyUserId] = userId;
    } else {
      try {
        await _storage.write(key: _keyUserId, value: userId);
      } catch (_) {
        _useInMemoryFallback = true;
        _inMemoryFallback[_keyUserId] = userId;
      }
    }
  }

  /// Retrieves the stored user id associated with the active token.
  Future<String?> getUserId() async {
    if (_useInMemoryFallback) {
      return _inMemoryFallback[_keyUserId];
    }
    try {
      return await _storage.read(key: _keyUserId);
    } catch (_) {
      _useInMemoryFallback = true;
      return _inMemoryFallback[_keyUserId];
    }
  }

  /// Checks whether a valid access token exists in secure storage.
  Future<bool> hasValidSession() async {
    final token = await getAccessToken();
    return token != null && token.trim().isNotEmpty;
  }

  /// Purges all authentication tokens and secure session identifiers.
  Future<void> clearTokens() async {
    _inMemoryFallback.clear();
    try {
      await _storage.delete(key: _keyAccessToken);
      await _storage.delete(key: _keyRefreshToken);
      await _storage.delete(key: _keyUserId);
    } catch (_) {
      // In-memory fallback already cleared
    }
  }
}
