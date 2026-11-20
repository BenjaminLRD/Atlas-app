import 'dart:async';

import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/screens/login_screen.dart';
import 'package:atlas/services/cloud/auth_availability.dart';
import 'package:atlas/services/cloud/auth_failure.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    AppDependencies.reset();
    FitnessProvider.resetInstance();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    AuthSubmit? submit,
    Size size = const Size(360, 640),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: LoginScreen(submitOverride: submit),
      ),
    );
  }

  /// AppButton plays a press animation (forward, reverse) before calling
  /// onPressed, which takes three frames. Not pumpAndSettle: the loading
  /// spinner never settles.
  Future<void> pumpPress(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
  }

  Future<void> fill(WidgetTester tester, String email, String password) async {
    await tester.enterText(find.byKey(const Key('login_email')), email);
    await tester.enterText(find.byKey(const Key('login_password')), password);
  }

  testWidgets('shows validation errors before calling the backend', (
    tester,
  ) async {
    var calls = 0;
    await pumpScreen(
      tester,
      submit: ({required email, required password, required isSignUp}) async {
        calls++;
      },
    );

    await tapVisible(tester, find.text('Login'));
    await pumpPress(tester);

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('shows a friendly inline message for a failed login', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      submit: ({required email, required password, required isSignUp}) async {
        throw const CloudAuthException(
          'Incorrect email or password.',
          kind: AuthFailureKind.invalidCredentials,
        );
      },
    );

    await fill(tester, 'a@b.com', 'password123');
    await tapVisible(tester, find.text('Login'));
    await pumpPress(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth_notice')), findsOneWidget);
    expect(find.text('Incorrect email or password.'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('hides raw exception text behind a generic message', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      submit: ({required email, required password, required isSignUp}) async {
        throw StateError('boom internal detail');
      },
    );

    await fill(tester, 'a@b.com', 'password123');
    await tapVisible(tester, find.text('Login'));
    await pumpPress(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth_notice')), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
  });

  testWidgets('sign-up that needs email confirmation switches to log in', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      submit: ({required email, required password, required isSignUp}) async {
        expect(isSignUp, isTrue);
        throw AuthFailure.confirmationRequired;
      },
    );

    await tapVisible(tester, find.byKey(const Key('toggle_mode')));
    await tester.pump();
    expect(find.text('Create your account'), findsOneWidget);

    await fill(tester, 'a@b.com', 'password123');
    await tapVisible(tester, find.text('Create account'));
    await pumpPress(tester);
    await tester.pumpAndSettle();

    expect(find.text(AuthFailure.confirmationRequired.message), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.byIcon(Icons.mark_email_read_outlined), findsOneWidget);
    // The password is cleared, the email is kept.
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('login_password')))
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('login_email')))
          .controller!
          .text,
      'a@b.com',
    );
  });

  testWidgets('disables the form and blocks double submits while loading', (
    tester,
  ) async {
    final completer = Completer<void>();
    var calls = 0;
    await pumpScreen(
      tester,
      submit: ({required email, required password, required isSignUp}) {
        calls++;
        return completer.future;
      },
    );

    await fill(tester, 'a@b.com', 'password123');
    await tapVisible(tester, find.text('Login'));
    await pumpPress(tester);

    expect(calls, 1);
    final email = tester.widget<TextFormField>(
      find.byKey(const Key('login_email')),
    );
    expect(email.enabled, isFalse);

    completer.completeError(const CloudAuthException('Nope'));
    await tester.pumpAndSettle();
    expect(find.text('Nope'), findsOneWidget);
  });

  testWidgets('password visibility can be toggled', (tester) async {
    await pumpScreen(tester);

    EditableText field() => tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('login_password')),
        matching: find.byType(EditableText),
      ),
    );

    expect(field().obscureText, isTrue);
    await tapVisible(tester, find.byTooltip('Show password'));
    await tester.pump();
    expect(field().obscureText, isFalse);
  });

  testWidgets('keeps forgot password and Showcase Mode available', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text('Explore in Showcase Mode'), findsOneWidget);
  });

  for (final size in const [Size(320, 480), Size(360, 640), Size(411, 891)]) {
    testWidgets(
      'does not overflow at ${size.width.toInt()}x${size.height.toInt()} '
      'with keyboard, error and sign-up mode',
      (tester) async {
        await pumpScreen(
          tester,
          size: size,
          submit: ({required email, required password, required isSignUp}) async {
            throw const CloudAuthException(
              'Our servers are having trouble. Please try again in a moment.',
              kind: AuthFailureKind.unavailable,
            );
          },
        );

        // Simulate the on-screen keyboard taking 40% of the height.
        tester.view.viewInsets = FakeViewPadding(bottom: size.height * 0.4);
        addTearDown(tester.view.resetViewInsets);
        await tester.pump();

        await tapVisible(tester, find.byKey(const Key('toggle_mode')));
        await tester.pump();
        await fill(tester, 'a@b.com', 'password123');
        await tapVisible(tester, find.text('Create account'));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('auth_notice')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  accountsUnavailableTests();
}

void accountsUnavailableTests() {
  group('release build without Supabase', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.init();
      AuthAvailability.releaseModeOverride = true;
    });
    tearDown(() => AuthAvailability.releaseModeOverride = null);

    testWidgets('shows the unavailable notice, keeps Showcase Mode, and '
        'never submits', (tester) async {
      var calls = 0;
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: LoginScreen(
            submitOverride:
                ({required email, required password, required isSignUp}) async {
                  calls++;
                },
          ),
        ),
      );

      expect(find.text(AuthAvailability.message), findsOneWidget);
      expect(find.text('Explore in Showcase Mode'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('login_email')), 'a@b.com');
      await tester.enterText(
        find.byKey(const Key('login_password')),
        'password123',
      );
      await tester.ensureVisible(find.text('Login'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Login'));
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      expect(calls, 0);
      expect(find.text(AuthAvailability.message), findsOneWidget);
    });
  });
}
