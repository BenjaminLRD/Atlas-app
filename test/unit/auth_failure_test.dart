import 'dart:async';
import 'dart:io';

import 'package:atlas/services/cloud/auth_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

void main() {
  AuthFailureKind kindOf(Object error) => AuthFailure.from(error).kind;

  group('AuthFailure classification by error code', () {
    test('invalid credentials', () {
      final result = AuthFailure.from(
        const sb.AuthApiException(
          'Invalid login credentials',
          statusCode: '400',
          code: 'invalid_credentials',
        ),
      );
      expect(result.kind, AuthFailureKind.invalidCredentials);
      expect(result.message, 'Incorrect email or password.');
    });

    test('email not confirmed', () {
      expect(
        kindOf(
          const sb.AuthApiException(
            'x',
            statusCode: '400',
            code: 'email_not_confirmed',
          ),
        ),
        AuthFailureKind.emailNotConfirmed,
      );
    });

    test('duplicate account by code', () {
      for (final code in ['user_already_exists', 'email_exists']) {
        expect(
          kindOf(sb.AuthApiException('x', statusCode: '422', code: code)),
          AuthFailureKind.accountExists,
        );
      }
    });

    test('weak password, with and without the dedicated exception', () {
      expect(
        kindOf(
          sb.AuthWeakPasswordException(
            message: 'Password should be at least 6 characters.',
            statusCode: '422',
            reasons: const ['length'],
          ),
        ),
        AuthFailureKind.weakPassword,
      );
      expect(
        kindOf(
          const sb.AuthApiException(
            'x',
            statusCode: '422',
            code: 'weak_password',
          ),
        ),
        AuthFailureKind.weakPassword,
      );
    });

    test('invalid email', () {
      for (final code in ['email_address_invalid', 'validation_failed']) {
        expect(
          kindOf(sb.AuthApiException('x', statusCode: '400', code: code)),
          AuthFailureKind.invalidEmail,
        );
      }
    });

    test('rate limits by code and by HTTP 429', () {
      expect(
        kindOf(
          const sb.AuthApiException(
            'email rate limit exceeded',
            statusCode: '429',
            code: 'over_email_send_rate_limit',
          ),
        ),
        AuthFailureKind.rateLimited,
      );
      expect(
        kindOf(const sb.AuthApiException('slow down', statusCode: '429')),
        AuthFailureKind.rateLimited,
      );
    });

    test('signup disabled', () {
      expect(
        kindOf(
          const sb.AuthApiException(
            'x',
            statusCode: '422',
            code: 'signup_disabled',
          ),
        ),
        AuthFailureKind.signupDisabled,
      );
    });
  });

  group('AuthFailure classification without a code (older servers)', () {
    test('falls back to the message text', () {
      expect(
        kindOf(const sb.AuthException('Invalid login credentials')),
        AuthFailureKind.invalidCredentials,
      );
      expect(
        kindOf(const sb.AuthException('User already registered')),
        AuthFailureKind.accountExists,
      );
      expect(
        kindOf(const sb.AuthException('Email not confirmed')),
        AuthFailureKind.emailNotConfirmed,
      );
    });
  });

  group('AuthFailure network and server problems', () {
    test('offline and timeout errors are reported as a connection problem', () {
      expect(
        kindOf(const SocketException('no route')),
        AuthFailureKind.network,
      );
      expect(kindOf(TimeoutException('slow')), AuthFailureKind.network);
      expect(
        kindOf(sb.AuthRetryableFetchException(message: 'ClientException')),
        AuthFailureKind.network,
      );
    });

    test('5xx responses are reported as a server problem', () {
      expect(
        kindOf(sb.AuthRetryableFetchException(statusCode: '503')),
        AuthFailureKind.unavailable,
      );
      expect(
        kindOf(
          const sb.AuthApiException(
            'Error sending confirmation email',
            statusCode: '500',
            code: 'unexpected_failure',
          ),
        ),
        AuthFailureKind.unavailable,
      );
    });
  });

  group('AuthFailure fallbacks', () {
    test('unknown Supabase errors never expose raw server text', () {
      final result = AuthFailure.from(
        const sb.AuthApiException(
          'internal detail: relation auth.foo missing',
          statusCode: '400',
          code: 'weird_code',
        ),
      );
      expect(result.kind, AuthFailureKind.unknown);
      expect(result.message, isNot(contains('internal detail')));
      expect(result.message, isNotEmpty);
    });

    test('non-auth exceptions never expose raw text', () {
      final result = AuthFailure.from(StateError('secret stack detail'));
      expect(result.message, isNot(contains('secret')));
      expect(result.kind, AuthFailureKind.unknown);
    });

    test('an existing CloudAuthException passes through unchanged', () {
      const original = CloudAuthException(
        'Custom',
        kind: AuthFailureKind.network,
      );
      expect(identical(AuthFailure.from(original), original), isTrue);
    });
  });

  group('AuthFailure messages', () {
    test('email confirmation is informational, not an error', () {
      expect(AuthFailure.confirmationRequired.isInfo, isTrue);
      expect(AuthFailure.accountExists.isInfo, isFalse);
    });

    test('messages never echo the email or password', () {
      const email = 'someone@example.com';
      const password = 'Sup3rSecret!';
      final result = AuthFailure.from(
        const sb.AuthApiException(
          'Invalid login credentials for someone@example.com Sup3rSecret!',
          statusCode: '400',
          code: 'invalid_credentials',
        ),
      );
      expect(result.message, isNot(contains(email)));
      expect(result.message, isNot(contains(password)));
    });
  });
}
