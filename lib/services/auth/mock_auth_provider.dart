import 'dart:async';
import '../../models/app_user.dart';
import 'auth_provider.dart';

/// Development implementation of [AuthProvider] providing simulated authentication,
/// credential validation, and reactive [authStateChanges] stream.
class MockAuthProvider implements AuthProvider {
  final StreamController<AppUser?> _controller = StreamController<AppUser?>.broadcast();
  AppUser? _currentUser;

  MockAuthProvider({AppUser? initialUser}) : _currentUser = initialUser;

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
      throw Exception('Invalid email address format.');
    }
    if (password.trim().length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    final name = trimmedEmail.split('@').first;
    final formattedName = name.isNotEmpty
        ? name[0].toUpperCase() + name.substring(1)
        : 'Gym Member';

    final user = AppUser(
      id: 'usr_${trimmedEmail.hashCode.abs()}',
      email: trimmedEmail,
      displayName: _currentUser?.displayName.isNotEmpty == true
          ? _currentUser!.displayName
          : formattedName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _currentUser = user;
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
      throw Exception('Invalid email address format.');
    }
    if (password.trim().length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    final name = displayName?.trim().isNotEmpty == true
        ? displayName!.trim()
        : trimmedEmail.split('@').first;

    final user = AppUser(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      email: trimmedEmail,
      displayName: name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _currentUser = user;
    _controller.add(_currentUser);
    return user;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }

  /// Sets current user session explicitly (useful for local storage restoration).
  void setCurrentUser(AppUser? user) {
    _currentUser = user;
    _controller.add(_currentUser);
  }

  void dispose() {
    _controller.close();
  }
}
