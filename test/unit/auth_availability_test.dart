import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/cloud/auth_availability.dart';
import 'package:atlas/services/cloud/auth_failure.dart';
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

  tearDown(() {
    AuthAvailability.releaseModeOverride = null;
    FitnessProvider.resetInstance();
  });

  group('release build without Supabase', () {
    setUp(() => AuthAvailability.releaseModeOverride = true);

    test('accounts are reported unavailable', () {
      expect(AuthAvailability.accountsUnavailable, isTrue);
    });

    test('login and signup never succeed with a syntactically valid login', () {
      final provider = FitnessProvider.instance;
      expect(
        provider.login(email: 'someone@example.com', password: 'abcdef'),
        throwsA(
          isA<CloudAuthException>().having(
            (e) => e.kind,
            'kind',
            AuthFailureKind.accountsUnavailable,
          ),
        ),
      );
      expect(
        provider.signup(email: 'new@example.com', password: 'abcdefgh'),
        throwsA(isA<CloudAuthException>()),
      );
      expect(provider.isAuthenticated, isFalse);
    });

    test('password reset and account deletion are refused', () {
      final repo = UnavailableAuthRepository();
      expect(
        repo.resetPassword(email: 'a@b.com'),
        throwsA(isA<CloudAuthException>()),
      );
      expect(repo.deleteAccount(), throwsA(isA<CloudAuthException>()));
      expect(repo.isAuthenticated, isFalse);
      expect(repo.currentUser, isNull);
    });

    test('the message points to Showcase Mode', () {
      expect(AuthAvailability.message, contains('Showcase Mode'));
    });
  });

  group('debug and test builds', () {
    test('keep the local fallback so development works offline', () async {
      AuthAvailability.releaseModeOverride = false;
      expect(AuthAvailability.accountsUnavailable, isFalse);
      final user = await FitnessProvider.instance.login(
        email: 'dev@example.com',
        password: 'abcdef',
      );
      expect(user, isNotNull);
      expect(FitnessProvider.instance.isAuthenticated, isTrue);
      // login() starts a background cloud sync; let it finish before teardown.
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
  });
}
