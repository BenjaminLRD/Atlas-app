import '../../models/app_user.dart';

/// Abstract authentication provider contract supporting reactive [authStateChanges]
/// streams for cloud authentication backends (e.g. Supabase Auth, OAuth).
abstract class AuthProvider {
  /// Stream broadcasting authentication state changes.
  Stream<AppUser?> get authStateChanges;

  /// Registers a new user with the given credentials.
  Future<AppUser> signUp({
    required String email,
    required String password,
    String? displayName,
  });

  /// Authenticates an existing user with email & password credentials.
  Future<AppUser> signIn({required String email, required String password});

  /// Terminates active user session.
  Future<void> signOut();

  /// Retrieves current authenticated user.
  Future<AppUser?> getCurrentUser();

  /// Checks if active session exists.
  Future<bool> isAuthenticated();

  /// Sends a password reset email/link to the specified address.
  Future<void> resetPassword({required String email});

  /// Permanently deletes the current user account and associated cloud data.
  Future<void> deleteAccount();

  /// Restores session from secure storage or local cache.
  Future<AppUser?> restoreSession();
}
