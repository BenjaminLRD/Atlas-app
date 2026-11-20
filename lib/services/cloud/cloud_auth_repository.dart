import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../data/local_storage.dart';
import '../../models/app_user.dart';
import '../../repositories/auth_repository.dart';
import 'auth_failure.dart';
import 'cloud_session.dart';
import 'cloud_sync_queue.dart';

export 'auth_failure.dart'
    show AuthFailure, AuthFailureKind, CloudAuthException;

/// [AuthRepository] backed by Supabase Auth (email and password).
///
/// The Supabase SDK persists and refreshes the session itself; the signed-in
/// user is mirrored into [LocalStorage] so the rest of the app can read it
/// synchronously.
class CloudAuthRepository implements AuthRepository {
  /// Where Supabase email links (confirm sign-up, reset password) send the
  /// user. Matches the intent filter in `AndroidManifest.xml` and must be
  /// listed under Authentication > URL Configuration > Redirect URLs.
  static const String authCallbackUri = 'com.atlasfitness.app://login-callback';

  sb.GoTrueClient get _auth {
    final client = CloudSession.client;
    if (client == null) {
      throw const CloudAuthException('Accounts are not available right now.');
    }
    return client.auth;
  }

  @override
  Stream<AppUser?> get authStateChanges => _auth.onAuthStateChange.map(
    (state) =>
        state.session?.user == null ? null : _toAppUser(state.session!.user),
  );

  @override
  AppUser? get currentUser {
    final user = CloudSession.client?.auth.currentUser;
    return user == null ? null : _toAppUser(user);
  }

  @override
  bool get isAuthenticated => CloudSession.client?.auth.currentUser != null;

  @override
  Future<AppUser?> restoreSession() async {
    final user = currentUser;
    if (user == null) {
      await LocalStorage.clearAppUser();
    } else {
      await LocalStorage.saveAppUser(user);
    }
    return user;
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const CloudAuthException('Sign-in failed. Please try again.');
      }
      final appUser = _toAppUser(user);
      await LocalStorage.saveAppUser(appUser);
      return appUser;
    } on CloudAuthException {
      rethrow;
    } catch (e) {
      throw AuthFailure.from(e, operation: 'signIn');
    }
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await _auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: authCallbackUri,
        data: {
          if (displayName != null && displayName.isNotEmpty)
            'display_name': displayName,
        },
      );
      final user = response.user;
      if (user == null) {
        throw const CloudAuthException('Could not create your account.');
      }
      // With email confirmation on, Supabase answers a repeat sign-up for an
      // existing address with a fake user that has no identities (to avoid
      // revealing which emails are registered). Report it as a duplicate.
      if (user.identities != null && user.identities!.isEmpty) {
        throw AuthFailure.accountExists;
      }
      if (response.session == null) {
        // Email confirmation is enabled on the project.
        throw AuthFailure.confirmationRequired;
      }
      final appUser = _toAppUser(user);
      await LocalStorage.saveAppUser(appUser);
      return appUser;
    } on CloudAuthException {
      rethrow;
    } catch (e) {
      throw AuthFailure.from(e, operation: 'signUp');
    }
  }

  @override
  Future<void> signOut() async {
    // Unsynced changes belong to the account that made them; drop them so
    // they can never be pushed into the next account that signs in.
    await CloudSyncQueue.instance.clear();
    await _auth.signOut();
    await LocalStorage.clearAppUser();
  }

  @override
  Future<void> updateUserProfile(AppUser updatedUser) async {
    await LocalStorage.saveAppUser(updatedUser);
    if (isAuthenticated) {
      await _auth.updateUser(
        sb.UserAttributes(data: {'display_name': updatedUser.displayName}),
      );
    }
  }

  @override
  Future<void> resetPassword({required String email}) async {
    try {
      await _auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: authCallbackUri,
      );
    } on CloudAuthException {
      rethrow;
    } catch (e) {
      throw AuthFailure.from(e, operation: 'resetPassword');
    }
  }

  /// Deletes the account and all its data through the `delete-account` Edge
  /// Function (deleting a user needs the service role, which the app never
  /// holds).
  @override
  Future<void> deleteAccount() async {
    final client = CloudSession.client;
    if (client == null || client.auth.currentUser == null) {
      throw const CloudAuthException('Sign in to delete your account.');
    }
    final response = await client.functions.invoke('delete-account');
    if (response.status != 200) {
      throw const CloudAuthException(
        'Could not delete your account. Please try again.',
      );
    }
    await CloudSyncQueue.instance.clear();
    await client.auth.signOut();
    await LocalStorage.clearAppUser();
  }

  static AppUser _toAppUser(sb.User user) {
    final meta = user.userMetadata ?? const {};
    return AppUser(
      id: user.id,
      email: user.email ?? '',
      displayName: (meta['display_name'] ?? meta['full_name'] ?? '') as String,
      createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
      updatedAt: DateTime.tryParse(user.updatedAt ?? '') ?? DateTime.now(),
    );
  }
}
