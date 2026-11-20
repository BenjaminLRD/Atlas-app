import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// What went wrong during sign-in, sign-up or password recovery.
enum AuthFailureKind {
  invalidCredentials,
  emailNotConfirmed,

  /// Sign-up succeeded but the project requires the email to be confirmed
  /// before a session exists. Not an error: the account was created.
  emailConfirmationRequired,
  accountExists,
  weakPassword,
  invalidEmail,
  rateLimited,
  network,
  signupDisabled,
  unavailable,

  /// Release build without a working Supabase client: only Showcase Mode.
  accountsUnavailable,
  unknown,
}

/// Authentication error carrying a message that is safe to show to the user.
///
/// [kind] lets the UI react (for example offer to resend a confirmation
/// email); [isInfo] marks outcomes that are not failures.
class CloudAuthException implements Exception {
  final String message;
  final AuthFailureKind kind;

  const CloudAuthException(this.message, {this.kind = AuthFailureKind.unknown});

  bool get isInfo => kind == AuthFailureKind.emailConfirmationRequired;

  @override
  String toString() => message;
}

/// Turns any error raised by an auth call into a [CloudAuthException].
///
/// Classification uses the Supabase error `code` and HTTP status first and
/// only falls back to message text for older servers that omit the code. The
/// raw error is logged in debug builds only (type, status and code, never the
/// message body, which can echo an email address).
class AuthFailure {
  const AuthFailure._();

  static const String _generic =
      'Something went wrong on our side. Please try again in a moment.';

  static const _unavailable = CloudAuthException(
    'Our servers are having trouble. Please try again in a moment.',
    kind: AuthFailureKind.unavailable,
  );

  static const _weakPassword = CloudAuthException(
    'Choose a stronger password: at least 8 characters, hard to guess.',
    kind: AuthFailureKind.weakPassword,
  );

  /// Shown when sign-up targets an email that already has an account.
  static const accountExists = CloudAuthException(
    'An account with this email already exists. Try signing in instead.',
    kind: AuthFailureKind.accountExists,
  );

  /// Sign-up worked; the user must open the emailed link before signing in.
  static const confirmationRequired = CloudAuthException(
    'Account created. Open the confirmation link we emailed you, then sign in.',
    kind: AuthFailureKind.emailConfirmationRequired,
  );

  static CloudAuthException from(Object error, {String? operation}) {
    if (error is CloudAuthException) return error;
    final result = _classify(error);
    if (kDebugMode) {
      final code = error is sb.AuthException ? error.code : null;
      final status = error is sb.AuthException ? error.statusCode : null;
      debugPrint(
        '[Auth] ${operation ?? 'request'} failed: '
        'type=${error.runtimeType} status=$status code=$code '
        'kind=${result.kind.name}',
      );
    }
    return result;
  }

  static CloudAuthException _classify(Object error) {
    if (error is sb.AuthWeakPasswordException) return _weakPassword;
    if (error is sb.AuthRetryableFetchException) {
      // Also raised for 5xx responses, which are not the user's connection.
      final status = int.tryParse(error.statusCode ?? '');
      return status != null && status >= 500 ? _unavailable : _offline;
    }
    if (error is SocketException ||
        error is TimeoutException ||
        error is HttpException) {
      return _offline;
    }
    if (error is sb.AuthException) return _fromAuthException(error);
    return const CloudAuthException(_generic);
  }

  static const _offline = CloudAuthException(
    'Cannot reach Atlas. Check your internet connection and try again.',
    kind: AuthFailureKind.network,
  );

  static CloudAuthException _fromAuthException(sb.AuthException e) {
    final code = (e.code ?? '').toLowerCase();
    final status = int.tryParse(e.statusCode ?? '');
    final msg = e.message.toLowerCase();

    if (code == 'invalid_credentials' ||
        msg.contains('invalid login credentials')) {
      return const CloudAuthException(
        'Incorrect email or password.',
        kind: AuthFailureKind.invalidCredentials,
      );
    }
    if (code == 'email_not_confirmed' || msg.contains('email not confirmed')) {
      return const CloudAuthException(
        'Confirm your email first. Open the link we sent you, then sign in.',
        kind: AuthFailureKind.emailNotConfirmed,
      );
    }
    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        msg.contains('already registered') ||
        msg.contains('already exists')) {
      return accountExists;
    }
    if (code == 'weak_password' || msg.contains('weak password')) {
      return _weakPassword;
    }
    if (code == 'email_address_invalid' ||
        code == 'validation_failed' ||
        msg.contains('unable to validate email') ||
        msg.contains('invalid email')) {
      return const CloudAuthException(
        'That email address does not look valid. Check it and try again.',
        kind: AuthFailureKind.invalidEmail,
      );
    }
    if (code == 'over_email_send_rate_limit' ||
        code == 'over_request_rate_limit' ||
        code == 'over_sms_send_rate_limit' ||
        status == 429 ||
        msg.contains('rate limit') ||
        msg.contains('too many requests') ||
        msg.contains('security purposes')) {
      return const CloudAuthException(
        'Too many attempts. Wait a minute, then try again.',
        kind: AuthFailureKind.rateLimited,
      );
    }
    if (code == 'signup_disabled' || code == 'email_provider_disabled') {
      return const CloudAuthException(
        'New sign-ups are turned off right now. Please try again later.',
        kind: AuthFailureKind.signupDisabled,
      );
    }
    if (status != null && status >= 500) return _unavailable;
    return const CloudAuthException(_generic);
  }
}
