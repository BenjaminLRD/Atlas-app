import '../data/local_storage.dart';
import '../models/app_user.dart';
import '../services/auth/auth_provider.dart';
import '../services/auth/auth_service.dart';
import '../services/auth/local_auth_provider.dart';
import '../services/supabase/supabase_auth_provider.dart';

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
  Future<void> resetPassword({required String email});
  Future<void> deleteAccount();
}

/// Local-first implementation of [AuthRepository] persisting session to [LocalStorage].
class LocalAuthRepository implements AuthRepository {
  final AuthProvider _provider;

  LocalAuthRepository({AuthProvider? provider})
    : _provider =
          provider ?? LocalAuthProvider(initialUser: LocalStorage.getAppUser());

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
    if (p is LocalAuthProvider) {
      p.setCurrentUser(storedUser);
    } else {
      await _provider.restoreSession();
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
    if (p is LocalAuthProvider) {
      p.setCurrentUser(updatedUser);
    }
  }

  @override
  Future<void> resetPassword({required String email}) async {
    await _provider.resetPassword(email: email);
  }

  @override
  Future<void> deleteAccount() async {
    await _provider.deleteAccount();
    await LocalStorage.clearAppUser();
  }
}

/// Production Supabase-backed implementation of [AuthRepository].
class SupabaseAuthRepository implements AuthRepository {
  final AuthService _authService;

  SupabaseAuthRepository({
    AuthService? authService,
    SupabaseAuthProvider? provider,
  }) : _authService =
           authService ??
           (provider != null
               ? AuthService(provider: provider)
               : AuthService.instance);

  @override
  Stream<AppUser?> get authStateChanges => _authService.authStateChanges;

  @override
  AppUser? get currentUser => _authService.currentUser;

  @override
  bool get isAuthenticated => _authService.isAuthenticated;

  @override
  Future<AppUser?> restoreSession() => _authService.restoreSession();

  @override
  Future<AppUser> signIn({required String email, required String password}) =>
      _authService.signIn(email: email, password: password);

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    String? displayName,
  }) => _authService.signUp(
    email: email,
    password: password,
    displayName: displayName,
  );

  @override
  Future<void> signOut() => _authService.signOut();

  @override
  Future<void> updateUserProfile(AppUser updatedUser) async {
    await LocalStorage.saveAppUser(updatedUser);
  }

  @override
  Future<void> resetPassword({required String email}) =>
      _authService.resetPassword(email: email);

  @override
  Future<void> deleteAccount() => _authService.deleteAccount();
}
