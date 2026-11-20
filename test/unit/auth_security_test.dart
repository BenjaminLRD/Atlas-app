import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/services/auth/secure_auth_storage.dart';
import 'package:atlas/services/storage/secure_storage_service.dart';
import '../mocks/mock_auth_provider.dart';
import 'package:atlas/services/supabase/supabase_auth_provider.dart';
import 'package:atlas/services/supabase/supabase_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureAuthStorage secureStorage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    secureStorage = SecureAuthStorage.inMemory();
    SecureAuthStorage.setInstance(secureStorage);
  });

  group(
    'Phase 1 & 2 — UserProfile Password Stripping & Serialization Security',
    () {
      test('UserProfile.toJson() never includes password field', () {
        final profile = UserProfile(
          name: 'Lalremruata',
          email: 'remruata@example.com',
          phone: '9876543211',
          dob: '1996-04-12',
          gender: 'Male',
          height: '178',
          weight: '75',
          fitnessGoal: 'Muscle Gain',
          workoutExperience: 'Intermediate',
          preferredDays: const ['Monday', 'Wednesday', 'Friday'],
          dietPreference: 'High Protein',
          massUnit: 'kg',
          lengthUnit: 'cm',
          subscription: 'Free',
          privacy: 'Public',
          notificationsEnabled: true,
          profilePic: '',
        );

        final json = profile.toJson();

        expect(json.containsKey('password'), isFalse);
        expect(json['name'], equals('Lalremruata'));
        expect(json['email'], equals('remruata@example.com'));
      });

      test(
        'UserProfile.defaultProfile() does not have password in serialization',
        () {
          final defaultProf = UserProfile.defaultProfile(
            email: 'user@example.com',
          );
          final json = defaultProf.toJson();

          expect(json.containsKey('password'), isFalse);
          expect(json['email'], equals('user@example.com'));
        },
      );

      test(
        'UserProfile.fromJson() ignores legacy password field from old JSON',
        () {
          final legacyJson = {
            'name': 'Benjamin',
            'email': 'benjamin@example.com',
            'password': 'super_secret_password_123',
            'phone': '9876543212',
            'gender': 'Male',
            'height': '170',
            'weight': '65',
            'fitnessGoal': 'Strength',
            'workoutExperience': 'Advanced',
          };

          final profile = UserProfile.fromJson(legacyJson);

          expect(profile.name, equals('Benjamin'));
          expect(profile.email, equals('benjamin@example.com'));
          // Extra fields must not contain password either
          expect(profile.extraFields.containsKey('password'), isFalse);

          final serialized = profile.toJson();
          expect(serialized.containsKey('password'), isFalse);
        },
      );

      test(
        'LocalStorage strips password when saving Map or migrating legacy profiles',
        () async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(
            'user_profile',
            jsonEncode({
              'name': 'LegacyUser',
              'email': 'legacy@test.com',
              'password': 'old_plain_password',
              'height': '175',
              'weight': '70',
            }),
          );
          await prefs.setString('user_password', 'secret123');

          // Run migration
          await LocalStorage.migrateLegacyCredentials();

          // Check user_password key was deleted
          expect(prefs.containsKey('user_password'), isFalse);

          // Check plaintext user_profile is purged from SharedPreferences and encrypted in SecureStorage
          expect(prefs.containsKey('user_profile'), isFalse);
          final secureService = SecureStorageService.instance;
          expect(await secureService.containsKey('user_profile'), isTrue);
          final rawStored = (await secureService.readSecureData(
            'user_profile',
          ))!;
          expect(rawStored.contains('old_plain_password'), isFalse);
          expect(rawStored.contains('"password"'), isFalse);

          final loadedProfile = LocalStorage.getUserProfile();
          expect(loadedProfile.name, equals('LegacyUser'));
          expect(loadedProfile.email, equals('legacy@test.com'));
        },
      );
    },
  );

  group('Phase 3 — SecureAuthStorage Token Lifecycle', () {
    test('saves, retrieves, and clears access tokens securely', () async {
      expect(await secureStorage.getAccessToken(), isNull);
      expect(await secureStorage.hasValidSession(), isFalse);

      await secureStorage.saveAccessToken('jwt_access_token_xyz_123');

      expect(
        await secureStorage.getAccessToken(),
        equals('jwt_access_token_xyz_123'),
      );
      expect(await secureStorage.hasValidSession(), isTrue);

      await secureStorage.clearTokens();

      expect(await secureStorage.getAccessToken(), isNull);
      expect(await secureStorage.hasValidSession(), isFalse);
    });

    test('saves and retrieves refresh token and user ID', () async {
      await secureStorage.saveRefreshToken('jwt_refresh_token_abc');
      expect(
        await secureStorage.getRefreshToken(),
        equals('jwt_refresh_token_abc'),
      );

      await secureStorage.saveAuthSession(
        accessToken: 'access_123',
        refreshToken: 'refresh_456',
        userId: 'usr_999',
      );

      expect(await secureStorage.getAccessToken(), equals('access_123'));
      expect(await secureStorage.getRefreshToken(), equals('refresh_456'));
      expect(await secureStorage.getUserId(), equals('usr_999'));

      await secureStorage.clearTokens();
      expect(await secureStorage.getAccessToken(), isNull);
      expect(await secureStorage.getRefreshToken(), isNull);
      expect(await secureStorage.getUserId(), isNull);
    });
  });

  group('Phase 4, 5 & 6 — Authentication Provider Token Management', () {
    test(
      'MockAuthProvider creates secure token session on signIn and purges on signOut',
      () async {
        final authProvider = MockAuthProvider(secureStorage: secureStorage);

        expect(await secureStorage.hasValidSession(), isFalse);

        final user = await authProvider.signIn(
          email: 'member@example.com',
          password: 'validPassword123',
        );

        expect(user.email, equals('member@example.com'));
        expect(await secureStorage.hasValidSession(), isTrue);
        expect(await secureStorage.getUserId(), equals(user.id));
        expect(
          await secureStorage.getAccessToken(),
          contains('mock_token_${user.id}'),
        );

        // Logout
        await authProvider.signOut();

        expect(await authProvider.isAuthenticated(), isFalse);
        expect(await secureStorage.hasValidSession(), isFalse);
        expect(await secureStorage.getAccessToken(), isNull);
        expect(await secureStorage.getUserId(), isNull);

        authProvider.dispose();
      },
    );

    test(
      'SupabaseAuthProvider saves secure tokens on signUp/signIn and clears on signOut',
      () async {
        final clientManager = SupabaseClientManager.instance;
        final authProvider = SupabaseAuthProvider(
          clientManager: clientManager,
          secureStorage: secureStorage,
        );

        final user = await authProvider.signUp(
          email: 'sp_user@example.com',
          password: 'spPassword123',
          displayName: 'Sp User',
        );

        expect(user.email, equals('sp_user@example.com'));
        expect(await secureStorage.hasValidSession(), isTrue);
        expect(await secureStorage.getUserId(), equals(user.id));
        expect(
          await secureStorage.getAccessToken(),
          contains('sp_access_${user.id}'),
        );

        await authProvider.signOut();
        expect(await secureStorage.hasValidSession(), isFalse);
        expect(await secureStorage.getAccessToken(), isNull);
      },
    );

    test('New User Profile contains zero credentials or tokens', () {
      final newProfile = UserProfile.defaultProfile(
        email: 'newbie@example.com',
      );
      final json = newProfile.toJson();

      expect(json.containsKey('password'), isFalse);
      expect(json.containsKey('token'), isFalse);
      expect(json.containsKey('secret'), isFalse);
      expect(json.containsKey('apiKey'), isFalse);
      expect(json['email'], equals('newbie@example.com'));
      expect(json['massUnit'], equals('kg'));
      expect(json['lengthUnit'], equals('cm'));
    });
  });
}
