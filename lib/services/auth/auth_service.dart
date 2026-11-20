import 'dart:async';
import '../../data/local_storage.dart';
import '../../models/app_user.dart';
import '../supabase/supabase_auth_provider.dart';
import 'auth_provider.dart';
import 'secure_auth_storage.dart';

/// Central production Authentication Service providing unified Supabase Auth,
/// secure local token caching via [SecureAuthStorage], offline session recovery,
/// and reactive authentication state broadcasting.
class AuthService {
  static AuthService? _instance;
  final AuthProvider _provider;
  final SecureAuthStorage _secureStorage;

  AuthService({AuthProvider? provider, SecureAuthStorage? secureStorage})
    : _provider = provider ?? SupabaseAuthProvider(),
      _secureStorage = secureStorage ?? SecureAuthStorage.instance;

  /// Global singleton accessor.
  static AuthService get instance {
    _instance ??= AuthService();
    return _instance!;
  }

  /// Sets custom singleton instance (useful for unit tests).
  static void setInstance(AuthService service) {
    _instance = service;
  }

  /// Reactive stream of authentication state changes.
  Stream<AppUser?> get authStateChanges => _provider.authStateChanges;

  /// Returns currently cached user identity synchronously from local cache.
  AppUser? get currentUser => LocalStorage.getAppUser();

  /// Whether a user session is active.
  bool get isAuthenticated => currentUser != null;

  /// Registers a new user with email, password, and optional display name.
  Future<AppUser> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final user = await _provider.signUp(
      email: email,
      password: password,
      displayName: displayName,
    );
    await LocalStorage.saveAppUser(user);
    return user;
  }

  /// Authenticates an existing user with email and password credentials.
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final user = await _provider.signIn(email: email, password: password);
    await LocalStorage.saveAppUser(user);
    return user;
  }

  /// Signs out the active user and clears tokens across secure and local storage.
  Future<void> signOut() async {
    await _provider.signOut();
    await _secureStorage.clearTokens();
    await LocalStorage.clearAppUser();
  }

  /// Retrieves the current user from the provider or local fallback.
  Future<AppUser?> getCurrentUser() async {
    final remoteUser = await _provider.getCurrentUser();
    if (remoteUser != null) {
      await LocalStorage.saveAppUser(remoteUser);
      return remoteUser;
    }
    return LocalStorage.getAppUser();
  }

  /// Dispatches a password reset email to the specified address.
  Future<void> resetPassword({required String email}) async {
    await _provider.resetPassword(email: email);
  }

  /// Permanently deletes the current user account and purges local credentials.
  Future<void> deleteAccount() async {
    await _provider.deleteAccount();
    await _secureStorage.clearTokens();
    await LocalStorage.clearAppUser();
  }

  /// Restores session on app startup, verifying tokens and offline cache.
  Future<AppUser?> restoreSession() async {
    final cached = LocalStorage.getAppUser();
    try {
      final restored = await _provider.restoreSession();
      if (restored != null) {
        final mergedUser =
            (cached != null &&
                cached.id == restored.id &&
                restored.displayName.isEmpty &&
                cached.displayName.isNotEmpty)
            ? restored.copyWith(displayName: cached.displayName)
            : restored;
        await LocalStorage.saveAppUser(mergedUser);
        return mergedUser;
      }
    } catch (_) {
      // Offline fallback: check local storage if network is unreachable
    }

    final localUser = LocalStorage.getAppUser();
    if (localUser != null) {
      return localUser;
    }
    return null;
  }
}
