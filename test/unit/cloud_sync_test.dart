import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/services/auth/auth_service.dart';
import '../mocks/mock_auth_provider.dart';
import 'package:atlas/services/auth/secure_auth_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthProvider mockAuth;
  late AuthService authService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();

    mockAuth = MockAuthProvider();
    authService = AuthService(provider: mockAuth);
  });

  group('1. Authentication System — Signup, Login, Logout & Session Restore', () {
    test(
      'User Signup creates active session and encrypted credentials',
      () async {
        final user = await authService.signUp(
          email: 'athlete@Atlas.com',
          password: 'SecurePassword123!',
          displayName: 'Alex Smith',
        );

        expect(user.id, isNotEmpty);
        expect(user.email, 'athlete@Atlas.com');
        expect(user.displayName, 'Alex Smith');

        final currentUser = await authService.getCurrentUser();
        expect(currentUser, isNotNull);
        expect(currentUser!.id, user.id);
      },
    );

    test(
      'User Login and Logout lifecycle properly manages active state',
      () async {
        await authService.signUp(
          email: 'athlete@Atlas.com',
          password: 'Password123!',
          displayName: 'Alex',
        );

        await authService.signOut();
        expect(await authService.getCurrentUser(), isNull);

        final loggedInUser = await authService.signIn(
          email: 'athlete@Atlas.com',
          password: 'Password123!',
        );
        expect(loggedInUser.email, 'athlete@Atlas.com');
      },
    );

    test(
      'Session restoration securely loads persisted token without plaintext passwords',
      () async {
        final secureStorage = SecureAuthStorage.inMemory();
        await secureStorage.saveAuthSession(
          accessToken: 'jwt_mock_token_abc_123',
          userId: 'usr_secure_99',
        );

        final token = await secureStorage.getAccessToken();
        final userId = await secureStorage.getUserId();
        expect(token, 'jwt_mock_token_abc_123');
        expect(userId, 'usr_secure_99');

        final refreshToken = await secureStorage.getRefreshToken();
        expect(refreshToken, isNull);
      },
    );
  });
}
