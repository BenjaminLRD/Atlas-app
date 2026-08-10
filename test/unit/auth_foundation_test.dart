import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/models/app_user.dart';
import 'package:aizawl_gym/models/user_goal.dart';
import 'package:aizawl_gym/providers/fitness_provider.dart';
import 'package:aizawl_gym/repositories/auth_repository.dart';
import 'package:aizawl_gym/services/auth/mock_auth_provider.dart';
import 'package:aizawl_gym/screens/auth/login_screen.dart';
import 'package:aizawl_gym/screens/auth/signup_screen.dart';
import 'package:aizawl_gym/screens/auth/profile_setup_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    FitnessProvider.resetInstance();
  });

  group('AppUser Model Serialization Tests', () {
    test('AppUser toJson and fromJson round-trip', () {
      final now = DateTime(2026, 8, 8, 3, 30);
      final user = AppUser(
        id: 'usr_123',
        email: 'member@aizawlgym.com',
        displayName: 'Zothana Sailo',
        profileImageUrl: 'https://example.com/avatar.png',
        createdAt: now,
        updatedAt: now,
      );

      final json = user.toJson();
      expect(json['id'], equals('usr_123'));
      expect(json['email'], equals('member@aizawlgym.com'));
      expect(json['displayName'], equals('Zothana Sailo'));

      final restored = AppUser.fromJson(json);
      expect(restored.id, equals(user.id));
      expect(restored.email, equals(user.email));
      expect(restored.displayName, equals(user.displayName));
      expect(restored.profileImageUrl, equals(user.profileImageUrl));
    });

    test('AppUser copyWith updates targeted fields', () {
      final now = DateTime(2026, 8, 8);
      final user = AppUser(
        id: 'usr_1',
        email: 'old@aizawlgym.com',
        displayName: 'Old Name',
        createdAt: now,
        updatedAt: now,
      );

      final updated = user.copyWith(
        displayName: 'New Name',
        email: 'new@aizawlgym.com',
      );

      expect(updated.id, equals('usr_1'));
      expect(updated.displayName, equals('New Name'));
      expect(updated.email, equals('new@aizawlgym.com'));
    });
  });

  group('MockAuthProvider & AuthRepository Tests', () {
    test('signUp registers new user and broadcasts authStateChanges stream', () async {
      final mockProvider = MockAuthProvider();
      final repo = LocalAuthRepository(provider: mockProvider);

      expect(repo.isAuthenticated, isFalse);

      final streamFuture = repo.authStateChanges.first;
      final user = await repo.signUp(
        email: 'newmember@aizawlgym.com',
        password: 'password123',
        displayName: 'New Member',
      );

      final streamedUser = await streamFuture;
      expect(user.email, equals('newmember@aizawlgym.com'));
      expect(user.displayName, equals('New Member'));
      expect(streamedUser?.email, equals('newmember@aizawlgym.com'));
      expect(repo.isAuthenticated, isTrue);

      // Verify session stored in LocalStorage
      expect(LocalStorage.getAppUser()?.email, equals('newmember@aizawlgym.com'));
    });

    test('signIn authenticates user and signOut clears session', () async {
      final repo = LocalAuthRepository(provider: MockAuthProvider());

      final user = await repo.signIn(
        email: 'test@aizawlgym.com',
        password: 'securePassword123',
      );

      expect(user.email, equals('test@aizawlgym.com'));
      expect(repo.isAuthenticated, isTrue);
      expect(LocalStorage.getAppUser(), isNotNull);

      await repo.signOut();
      expect(repo.isAuthenticated, isFalse);
      expect(LocalStorage.getAppUser(), isNull);
    });

    test('restoreSession recovers persisted session on app restart', () async {
      final initialUser = AppUser(
        id: 'usr_restored',
        email: 'restored@aizawlgym.com',
        displayName: 'Restored User',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await LocalStorage.saveAppUser(initialUser);

      final repo = LocalAuthRepository();
      final restored = await repo.restoreSession();

      expect(restored, isNotNull);
      expect(restored?.email, equals('restored@aizawlgym.com'));
      expect(repo.isAuthenticated, isTrue);
    });
  });

  group('FitnessProvider Auth Integration Tests', () {
    test('login, signup, and logout update provider state reactively', () async {
      final provider = FitnessProvider.instance;
      expect(provider.isAuthenticated, isFalse);
      expect(provider.currentUser, isNull);

      final user = await provider.signup(
        email: 'provider@aizawlgym.com',
        password: 'password123',
        displayName: 'Provider Test User',
      );

      expect(user, isNotNull);
      expect(provider.isAuthenticated, isTrue);
      expect(provider.currentUser?.email, equals('provider@aizawlgym.com'));

      await provider.logout();
      expect(provider.isAuthenticated, isFalse);
      expect(provider.currentUser, isNull);

      await provider.login(
        email: 'provider@aizawlgym.com',
        password: 'password123',
      );

      expect(provider.isAuthenticated, isTrue);
      expect(provider.currentUser?.email, equals('provider@aizawlgym.com'));
    });
  });

  group('Auth Routing Decision Logic Tests', () {
    test('Unauthenticated user routes to LoginScreen', () {
      final isAuth = FitnessProvider.instance.isAuthenticated;
      final isGoalDone = LocalStorage.isGoalOnboardingCompleted();

      Widget initialScreen;
      if (!isAuth) {
        initialScreen = const LoginScreen();
      } else if (!isGoalDone) {
        initialScreen = const Text('GoalFlow');
      } else {
        initialScreen = const Text('MainShell');
      }

      expect(initialScreen, isA<LoginScreen>());
    });

    test('Authenticated user without goal routes to GoalFlow', () async {
      await FitnessProvider.instance.login(
        email: 'nogoal@aizawlgym.com',
        password: 'password123',
      );
      await LocalStorage.setGoalOnboardingCompleted(false);

      final isAuth = FitnessProvider.instance.isAuthenticated;
      final isGoalDone = LocalStorage.isGoalOnboardingCompleted() ||
          FitnessProvider.instance.currentGoal != null;

      Widget initialScreen;
      if (!isAuth) {
        initialScreen = const LoginScreen();
      } else if (!isGoalDone) {
        initialScreen = const Text('GoalFlow');
      } else {
        initialScreen = const Text('MainShell');
      }

      expect(initialScreen, isA<Text>());
      expect((initialScreen as Text).data, equals('GoalFlow'));
    });

    test('Authenticated user with goal routes to MainShell', () async {
      await FitnessProvider.instance.login(
        email: 'withgoal@aizawlgym.com',
        password: 'password123',
      );
      await FitnessProvider.instance.saveGoal(UserGoal.initial());

      final isAuth = FitnessProvider.instance.isAuthenticated;
      final isGoalDone = LocalStorage.isGoalOnboardingCompleted() ||
          FitnessProvider.instance.currentGoal != null;

      Widget initialScreen;
      if (!isAuth) {
        initialScreen = const LoginScreen();
      } else if (!isGoalDone) {
        initialScreen = const Text('GoalFlow');
      } else {
        initialScreen = const Text('MainShell');
      }

      expect(initialScreen, isA<Text>());
      expect((initialScreen as Text).data, equals('MainShell'));
    });
  });

  group('Auth UI Screens Widget Tests', () {
    testWidgets('LoginScreen renders email, password, and sign in button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      expect(find.text('AIZAWL GYM'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('SIGN IN'), findsOneWidget);
    });

    testWidgets('SignupScreen renders full name, email, and create account button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SignupScreen(),
        ),
      );

      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    });

    testWidgets('ProfileSetupScreen renders avatar selection and continue button', (tester) async {
      await FitnessProvider.instance.login(
        email: 'setup@aizawlgym.com',
        password: 'password123',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: ProfileSetupScreen(),
        ),
      );

      expect(find.text('Welcome to Aizawl Gym!'), findsOneWidget);
      expect(find.text('Choose Your Avatar'), findsOneWidget);
      expect(find.text('CONTINUE TO GOAL SETUP'), findsOneWidget);
    });
  });
}
