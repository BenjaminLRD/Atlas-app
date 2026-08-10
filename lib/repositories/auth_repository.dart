import '../data/local_storage.dart';
import '../models/app_user.dart';
import '../services/auth/auth_provider.dart';
import '../services/auth/mock_auth_provider.dart';

/// Repository interface for authentication management and session persistence.
abstract class AuthRepository {
  Stream<AppUser?> get authStateChanges;
  AppUser? get currentUser;
  bool get isAuthenticated;

  Future<AppUser?> restoreSession();
  Future<AppUser> signIn({required String email, required String password});
  Future<AppUser> signUp({
    required String email,
    required String password,
    String? displayName,
  });
  Future<void> signOut();
  Future<void> updateUserProfile(AppUser updatedUser);
}

/// Local-first implementation of [AuthRepository] persisting session to [LocalStorage].
class LocalAuthRepository implements AuthRepository {
  final AuthProvider _provider;

  LocalAuthRepository({AuthProvider? provider})
      : _provider = provider ?? MockAuthProvider(initialUser: LocalStorage.getAppUser());

  @override
  Stream<AppUser?> get authStateChanges => _provider.authStateChanges;

  @override
  AppUser? get currentUser => LocalStorage.getAppUser();

  @override
  bool get isAuthenticated => currentUser != null;

  @override
  Future<AppUser?> restoreSession() async {
    final storedUser = LocalStorage.getAppUser();
    final p = _provider;
    if (p is MockAuthProvider) {
      p.setCurrentUser(storedUser);
    }
    return storedUser;
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final user = await _provider.signIn(email: email, password: password);
    await LocalStorage.saveAppUser(user);
    return user;
  }

  @override
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

  @override
  Future<void> signOut() async {
    await _provider.signOut();
    await LocalStorage.clearAppUser();
  }

  @override
  Future<void> updateUserProfile(AppUser updatedUser) async {
    await LocalStorage.saveAppUser(updatedUser);
    final p = _provider;
    if (p is MockAuthProvider) {
      p.setCurrentUser(updatedUser);
    }
  }
}
