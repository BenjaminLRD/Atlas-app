import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/data/app_dependencies.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/models/user_profile.dart';
import 'package:aizawl_gym/services/supabase/supabase_env.dart';
import 'package:aizawl_gym/services/supabase/supabase_client.dart';
import 'package:aizawl_gym/services/supabase/supabase_auth_provider.dart';
import 'package:aizawl_gym/services/supabase/supabase_sync_provider.dart';
import 'package:aizawl_gym/services/supabase/supabase_profile_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SupabaseClientManager.resetInstance();
    AppDependencies.useMock();
  });

  group('SupabaseEnv Unit Tests', () {
    test('development and production factories set correct environment', () {
      final devEnv = SupabaseEnv.dev();
      expect(devEnv.isDevelopment, isTrue);
      expect(devEnv.isProduction, isFalse);

      final prodEnv = SupabaseEnv.prod(
        url: 'https://prod.supabase.co',
        anonKey: 'prod_key',
      );
      expect(prodEnv.isProduction, isTrue);
      expect(prodEnv.supabaseUrl, equals('https://prod.supabase.co'));
    });
  });

  group('SupabaseAuthProvider Unit Tests', () {
    test('signUp and signIn create user and broadcast authStateChanges',
        () async {
      final authProvider = SupabaseAuthProvider();
      final streamEmissions = <String>[];

      final sub = authProvider.authStateChanges.listen((user) {
        if (user != null) {
          streamEmissions.add(user.email);
        }
      });

      final user = await authProvider.signUp(
        email: 'test@aizawlgym.com',
        password: 'password123',
        displayName: 'Tester',
      );

      expect(user.email, equals('test@aizawlgym.com'));
      expect(user.displayName, equals('Tester'));
      expect(await authProvider.isAuthenticated(), isTrue);

      await authProvider.signOut();
      expect(await authProvider.isAuthenticated(), isFalse);

      final signedIn = await authProvider.signIn(
        email: 'test@aizawlgym.com',
        password: 'password123',
      );
      expect(signedIn.email, equals('test@aizawlgym.com'));

      await sub.cancel();
      authProvider.dispose();
      expect(streamEmissions, contains('test@aizawlgym.com'));
    });
  });

  group('SupabaseSyncProvider & ProfileRepository Unit Tests', () {
    test('SupabaseSyncProvider uploads and downloads data payloads', () async {
      final syncProvider = SupabaseSyncProvider();
      await syncProvider.upload(
          {'name': 'Barbell Bench Press'}, 'workout_history');

      final tableQuery = syncProvider.clientManager.from('workout_sessions');
      final rows = await tableQuery.select();
      expect(rows, isNotEmpty);

      final downloaded =
          await syncProvider.download<Map<String, dynamic>>('workout_history');
      expect(downloaded, isNotNull);
    });

    test('SupabaseProfileRepository updates local storage and cloud profiles table',
        () async {
      final repo = SupabaseProfileRepository();
      final profile = UserProfile.defaultProfile();
      profile.name = 'Zorema';
      profile.weight = '78.0';

      await repo.saveProfile(profile);

      final localProfile = repo.getProfile();
      expect(localProfile.name, equals('Zorema'));
      expect(localProfile.weight, equals('78.0'));

      final rows =
          await SupabaseClientManager.instance.from('profiles').select();
      expect(rows.isNotEmpty, isTrue);
      expect(rows.first['full_name'], equals('Zorema'));
    });
  });

  group('AppDependencies Provider Switching Unit Tests', () {
    test('switching between Mock and Supabase modes works seamlessly', () {
      expect(AppDependencies.instance.isUsingSupabase, isFalse);

      AppDependencies.useSupabase(env: SupabaseEnv.dev());
      expect(AppDependencies.instance.isUsingSupabase, isTrue);
      expect(
          AppDependencies.instance.authProvider, isA<SupabaseAuthProvider>());
      expect(
          AppDependencies.instance.syncProvider, isA<SupabaseSyncProvider>());
      expect(AppDependencies.instance.profileRepository,
          isA<SupabaseProfileRepository>());

      AppDependencies.useMock();
      expect(AppDependencies.instance.isUsingSupabase, isFalse);
    });
  });
}
