import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/services/auth/auth_service.dart';
import '../mocks/mock_auth_provider.dart';
import 'package:atlas/services/auth/secure_auth_storage.dart';
import 'package:atlas/services/supabase/supabase_auth_provider.dart';
import 'package:atlas/services/supabase/supabase_client.dart';
import 'package:atlas/repositories/auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureAuthStorage secureStorage;
  late SupabaseClientManager clientManager;
  late SupabaseAuthProvider supabaseAuthProvider;
  late AuthService authService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();

    secureStorage = SecureAuthStorage.inMemory();
    SecureAuthStorage.setInstance(secureStorage);

    clientManager = SupabaseClientManager.instance;
    clientManager.clearData();

    supabaseAuthProvider = SupabaseAuthProvider(
      clientManager: clientManager,
      secureStorage: secureStorage,
    );

    authService = AuthService(
      provider: supabaseAuthProvider,
      secureStorage: secureStorage,
    );
    AuthService.setInstance(authService);
  });

  group('AuthService — Production Supabase Authentication', () {
    test(
      'signUp creates user, saves to local storage, and stores tokens securely',
      () async {
        final user = await authService.signUp(
          email: 'athlete@Atlas.app',
          password: 'password123',
          displayName: 'Aizawl Beast',
        );

        expect(user.email, 'athlete@Atlas.app');
        expect(user.displayName, 'Aizawl Beast');
        expect(authService.isAuthenticated, isTrue);
        expect(authService.currentUser?.email, 'athlete@Atlas.app');

        // Verify token storage
        final hasSession = await secureStorage.hasValidSession();
        expect(hasSession, isTrue);

        final token = await secureStorage.getAccessToken();
        expect(token, isNotNull);
        expect(token!.contains('sp_access_'), isTrue);

        // Verify LocalStorage cache
        final cachedUser = LocalStorage.getAppUser();
        expect(cachedUser?.email, 'athlete@Atlas.app');
      },
    );

    test(
      'signIn authenticates existing user and updates active session',
      () async {
        // First sign up
        await authService.signUp(
          email: 'warrior@Atlas.app',
          password: 'securePass123',
          displayName: 'Lalramdina',
        );

        // Sign out
        await authService.signOut();
        expect(authService.isAuthenticated, isFalse);
        expect(await secureStorage.hasValidSession(), isFalse);

        // Sign in again
        final loggedIn = await authService.signIn(
          email: 'warrior@Atlas.app',
          password: 'securePass123',
        );

        expect(loggedIn.email, 'warrior@Atlas.app');
        expect(authService.isAuthenticated, isTrue);
        expect(await secureStorage.hasValidSession(), isTrue);
      },
    );

    test(
      'signUp / signIn throws FormatException on empty email or password',
      () async {
        expect(
          () => authService.signUp(email: '', password: '123'),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => authService.signIn(email: 'user@test.com', password: ''),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test(
      'signOut terminates session and purges tokens across secure & local storage',
      () async {
        await authService.signUp(
          email: 'logout_test@Atlas.app',
          password: 'password123',
        );
        expect(authService.isAuthenticated, isTrue);

        await authService.signOut();

        expect(authService.isAuthenticated, isFalse);
        expect(authService.currentUser, isNull);
        expect(await secureStorage.getAccessToken(), isNull);
        expect(LocalStorage.getAppUser(), isNull);
      },
    );

    test(
      'resetPassword validates email and dispatches without error',
      () async {
        expect(
          () => authService.resetPassword(email: ''),
          throwsA(isA<FormatException>()),
        );

        await expectLater(
          authService.resetPassword(email: 'recovery@Atlas.app'),
          completes,
        );
      },
    );

    test(
      'deleteAccount purges remote records and clears local credentials',
      () async {
        final user = await authService.signUp(
          email: 'delete_me@Atlas.app',
          password: 'password123',
        );

        expect(user.email, 'delete_me@Atlas.app');
        expect(authService.isAuthenticated, isTrue);
        await authService.deleteAccount();

        expect(authService.isAuthenticated, isFalse);
        expect(LocalStorage.getAppUser(), isNull);
        expect(await secureStorage.hasValidSession(), isFalse);
      },
    );

    test(
      'restoreSession recovers authenticated user from secure tokens',
      () async {
        final user = await authService.signUp(
          email: 'session_restore@Atlas.app',
          password: 'password123',
          displayName: 'Restore Tester',
        );
        expect(user.displayName, 'Restore Tester');

        // Simulate app restart by instantiating new service with same storage
        final newAuthService = AuthService(
          provider: SupabaseAuthProvider(
            clientManager: clientManager,
            secureStorage: secureStorage,
          ),
          secureStorage: secureStorage,
        );

        final restored = await newAuthService.restoreSession();
        expect(restored, isNotNull);
        expect(restored?.email, 'session_restore@Atlas.app');
        expect(newAuthService.isAuthenticated, isTrue);
      },
    );

    test('restoreSession returns null when no tokens exist', () async {
      await secureStorage.clearTokens();
      await LocalStorage.clearAppUser();

      final restored = await authService.restoreSession();
      expect(restored, isNull);
      expect(authService.isAuthenticated, isFalse);
    });
  });

  group('SupabaseAuthRepository & LocalAuthRepository Delegation', () {
    test('SupabaseAuthRepository coordinates with AuthService', () async {
      final repo = SupabaseAuthRepository(authService: authService);

      final user = await repo.signUp(
        email: 'repo_test@Atlas.app',
        password: 'password123',
        displayName: 'Repo User',
      );

      expect(user.email, 'repo_test@Atlas.app');
      expect(repo.isAuthenticated, isTrue);
      expect(repo.currentUser?.displayName, 'Repo User');

      await repo.signOut();
      expect(repo.isAuthenticated, isFalse);
    });

    test(
      'LocalAuthRepository works seamlessly with MockAuthProvider in dev/test',
      () async {
        final mockProvider = MockAuthProvider(secureStorage: secureStorage);
        final repo = LocalAuthRepository(provider: mockProvider);

        final user = await repo.signUp(
          email: 'mock_user@Atlas.app',
          password: 'password123',
          displayName: 'Mock Athlete',
        );

        expect(user.email, 'mock_user@Atlas.app');
        expect(repo.isAuthenticated, isTrue);

        await repo.resetPassword(email: 'mock_user@Atlas.app');
        await repo.signOut();
        expect(repo.isAuthenticated, isFalse);
      },
    );
  });
}
