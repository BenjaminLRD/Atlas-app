import 'package:flutter/foundation.dart';

import '../../data/local_storage.dart';
import '../../models/app_user.dart';
import '../../repositories/auth_repository.dart';
import 'auth_failure.dart';
import 'cloud_session.dart';

/// Whether real (Supabase) accounts can be used in this build.
///
/// The local auth provider accepts any email and a 6+ character password
/// without contacting a server. That is fine for debug runs and tests, but a
/// release build must never treat it as a real login: when Supabase is not
/// configured (missing dart-defines, or initialization failed) accounts are
/// unavailable and only Showcase Mode is offered.
class AuthAvailability {
  const AuthAvailability._();

  /// Overrides [kReleaseMode]. Only for tests.
  @visibleForTesting
  static bool? releaseModeOverride;

  static bool get isReleaseBuild => releaseModeOverride ?? kReleaseMode;

  /// True when this is a release build without a working Supabase client.
  static bool get accountsUnavailable =>
      isReleaseBuild && CloudSession.client == null;

  static const String message =
      'Online accounts are unavailable right now. You can still explore '
      'Atlas in Showcase Mode.';

  static const CloudAuthException exception = CloudAuthException(
    message,
    kind: AuthFailureKind.accountsUnavailable,
  );
}

/// [AuthRepository] used by release builds when Supabase is not available.
/// It never signs anyone in; every account action fails with
/// [AuthAvailability.exception]. Local profile data (used by Showcase Mode)
/// still works.
class UnavailableAuthRepository implements AuthRepository {
  @override
  Stream<AppUser?> get authStateChanges => const Stream<AppUser?>.empty();

  @override
  AppUser? get currentUser => null;

  @override
  bool get isAuthenticated => false;

  @override
  Future<AppUser?> restoreSession() async => null;

  @override
  Future<AppUser> signIn({required String email, required String password}) =>
      Future.error(AuthAvailability.exception);

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    String? displayName,
  }) => Future.error(AuthAvailability.exception);

  @override
  Future<void> signOut() => LocalStorage.clearAppUser();

  @override
  Future<void> updateUserProfile(AppUser updatedUser) =>
      LocalStorage.saveAppUser(updatedUser);

  @override
  Future<void> resetPassword({required String email}) =>
      Future.error(AuthAvailability.exception);

  @override
  Future<void> deleteAccount() => Future.error(AuthAvailability.exception);
}
