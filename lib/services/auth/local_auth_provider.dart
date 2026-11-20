import 'dart:async';
import '../../data/local_storage.dart';
import '../../models/app_user.dart';
import 'auth_provider.dart';
import 'secure_auth_storage.dart';

/// Local offline-first implementation of [AuthProvider] providing session management,
/// credential validation, and reactive [authStateChanges] stream.
class LocalAuthProvider implements AuthProvider {
  final StreamController<AppUser?> _controller =
      StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;
  final SecureAuthStorage _secureStorage;

  LocalAuthProvider({AppUser? initialUser, SecureAuthStorage? secureStorage})
    : _currentUser = initialUser,
      _secureStorage = secureStorage ?? SecureAuthStorage.instance;

  @override
  Stream<AppUser?> get authStateChanges => _controller.stream;

  @override
  Future<AppUser?> getCurrentUser() async => _currentUser;

  @override
  Future<bool> isAuthenticated() async => _currentUser != null;

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      throw const FormatException('Invalid email address format.');
    }
    if (password.trim().length < 6) {
      throw const FormatException('Password must be at least 6 characters.');
    }

    final user = AppUser(
      id: 'usr_${trimmedEmail.hashCode.abs()}',
      email: trimmedEmail,
      displayName: _currentUser?.displayName ?? '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _currentUser = user;
    await _secureStorage.saveAuthSession(
      accessToken:
          'local_token_${user.id}_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'local_refresh_${user.id}',
      userId: user.id,
    );
    _controller.add(_currentUser);
    return user;
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      throw const FormatException('Invalid email address format.');
    }
    if (password.trim().length < 6) {
      throw const FormatException('Password must be at least 6 characters.');
    }

    final name = displayName?.trim() ?? '';

    final user = AppUser(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      email: trimmedEmail,
      displayName: name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _currentUser = user;
    await _secureStorage.saveAuthSession(
      accessToken:
          'local_token_${user.id}_${DateTime.now().millisecondsSinceEpoch}',
      refreshToken: 'local_refresh_${user.id}',
      userId: user.id,
    );
    _controller.add(_currentUser);
    return user;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    await _secureStorage.clearTokens();
    _controller.add(null);
  }

  @override
  Future<void> resetPassword({required String email}) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      throw const FormatException('Please enter a valid email address.');
    }
  }

  @override
  Future<void> deleteAccount() async {
    _currentUser = null;
    await _secureStorage.clearTokens();
    _controller.add(null);
  }

  @override
  Future<AppUser?> restoreSession() async {
    final hasSession = await _secureStorage.hasValidSession();
    if (!hasSession) {
      _currentUser = null;
      _controller.add(null);
      return null;
    }
    final userId = await _secureStorage.getUserId();
    if (userId != null && _currentUser == null) {
      final cached = LocalStorage.getAppUser();
      if (cached != null && cached.id == userId) {
        _currentUser = cached;
      } else {
        _currentUser = AppUser(
          id: userId,
          email: 'user@atlas.app',
          displayName: 'Athlete',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
    }
    _controller.add(_currentUser);
    return _currentUser;
  }

  /// Sets current user session explicitly.
  void setCurrentUser(AppUser? user) {
    _currentUser = user;
    _controller.add(_currentUser);
  }

  void dispose() {
    _controller.close();
  }
}
