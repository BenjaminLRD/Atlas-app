import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/app_user.dart';
import 'package:atlas/models/health_metric.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/models/activity_record.dart';
import 'package:atlas/services/storage/secure_storage_service.dart';
import 'package:atlas/services/storage/secure_storage_migration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SecureStorageService secureStorage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    secureStorage = SecureStorageService.inMemory();
    SecureStorageService.setInstance(secureStorage);
    LocalStorage.setSecureStorage(secureStorage);
  });

  group('Phase 3 — Secure Storage Migration System', () {
    test(
      'migrates legacy plaintext data from SharedPreferences to SecureStorage and purges plaintext',
      () async {
        final prefs = await SharedPreferences.getInstance();

        // Setup legacy plaintext data in SharedPreferences
        await prefs.setString(
          'user_today_health_metric',
          jsonEncode({
            'timestamp': DateTime.now().toIso8601String(),
            'steps': 8450,
            'distanceKm': 6.2,
            'activeCalories': 540.0,
            'heartRate': 72,
            'sleepMinutes': 420,
            'deepSleepMinutes': 110,
            'restingHeartRate': 58,
          }),
        );

        await prefs.setString(
          'app_user_session',
          jsonEncode({
            'id': 'usr_legacy_101',
            'email': 'legacy_user@aizawlgym.com',
            'displayName': 'Lalrinawma',
            'createdAt': DateTime.now().toIso8601String(),
            'updatedAt': DateTime.now().toIso8601String(),
          }),
        );

        await prefs.setString(
          'user_profile',
          jsonEncode({
            'name': 'Lalrinawma',
            'email': 'legacy_user@aizawlgym.com',
            'phone': '9876543210',
            'dob': '1995-06-15',
            'gender': 'Male',
            'height': '176',
            'weight': '72',
            'fitnessGoal': 'Strength',
            'workoutExperience': 'Intermediate',
            'preferredDays': ['Monday', 'Wednesday'],
            'dietPreference': 'High Protein',
            'massUnit': 'kg',
            'lengthUnit': 'cm',
            'subscription': 'Free',
            'privacy': 'Public',
            'notificationsEnabled': true,
            'profilePic': '',
          }),
        );

        await prefs.setStringList('user_activity_records', [
          jsonEncode({
            'id': 'act_001',
            'title': 'Outdoor Run',
            'date': DateTime.now().toIso8601String(),
            'type': 'cardio',
            'caloriesBurned': 320.0,
            'activeMinutes': 30,
            'distanceKm': 4.5,
            'steps': 4200,
          }),
        ]);

        await prefs.setString('user_password', 'oldPlainPassword123');

        // Run migration
        final migrationResult = await SecureStorageMigration.run(
          prefs: prefs,
          secureStorage: secureStorage,
        );

        expect(migrationResult, isTrue);
        expect(prefs.getBool(SecureStorageMigration.migrationFlagKey), isTrue);

        // Verify plaintext keys are deleted from SharedPreferences
        expect(prefs.containsKey('user_today_health_metric'), isFalse);
        expect(prefs.containsKey('app_user_session'), isFalse);
        expect(prefs.containsKey('user_profile'), isFalse);
        expect(prefs.containsKey('user_activity_records'), isFalse);
        expect(prefs.containsKey('user_password'), isFalse);

        // Verify data is now safely in SecureStorage
        expect(
          await secureStorage.containsKey('user_today_health_metric'),
          isTrue,
        );
        expect(await secureStorage.containsKey('app_user_session'), isTrue);
        expect(await secureStorage.containsKey('user_profile'), isTrue);
        expect(
          await secureStorage.containsKey('user_activity_records'),
          isTrue,
        );

        // Verify health telemetry integrity
        final healthRaw = await secureStorage.readSecureData(
          'user_today_health_metric',
        );
        final healthJson = jsonDecode(healthRaw!) as Map<String, dynamic>;
        expect(healthJson['heartRate'], equals(72));
        expect(healthJson['sleepMinutes'], equals(420));
        expect(healthJson['steps'], equals(8450));
      },
    );
  });

  group('Phase 4, 5, 6 & 7 — LocalStorage Encryption & Persistence Simulation', () {
    test(
      'persists health telemetry and personal PII through simulated app restart',
      () async {
        await LocalStorage.init(secureStorage: secureStorage);

        final user = AppUser(
          id: 'usr_secure_99',
          email: 'secure_athlete@example.com',
          displayName: 'Zothanpuia',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final metric = HealthMetric(
          timestamp: DateTime.now(),
          steps: 11200,
          distanceKm: 8.4,
          activeCalories: 680.0,
          heartRate: 68,
          sleepMinutes: 465,
          deepSleepMinutes: 130,
          restingHeartRate: 54,
        );

        final profile = UserProfile(
          name: 'Zothanpuia',
          email: 'secure_athlete@example.com',
          phone: '9862300000',
          dob: '1998-11-20',
          gender: 'Male',
          height: '180',
          weight: '76.5',
          fitnessGoal: 'Hypertrophy',
          workoutExperience: 'Advanced',
          preferredDays: const ['Mon', 'Tue', 'Thu', 'Fri'],
          dietPreference: 'High Protein',
          massUnit: 'kg',
          lengthUnit: 'cm',
          subscription: 'Pro',
          privacy: 'Public',
          notificationsEnabled: true,
          profilePic: 'https://example.com/avatar.jpg',
        );

        final activity = ActivityRecord(
          id: 'act_hiit_01',
          title: 'HIIT Circuit',
          date: DateTime.now(),
          type: ActivityType.cardio,
          caloriesBurned: 410.0,
          activeMinutes: 35,
          distanceKm: 3.5,
        );

        // Save through LocalStorage API
        await LocalStorage.saveAppUser(user);
        await LocalStorage.saveHealthMetric(metric);
        await LocalStorage.saveUserProfile(profile);
        await LocalStorage.saveActivityRecord(activity);

        // Verify SharedPreferences contains zero sensitive values
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey('user_today_health_metric'), isFalse);
        expect(prefs.containsKey('app_user_session'), isFalse);
        expect(prefs.containsKey('user_profile'), isFalse);
        expect(prefs.containsKey('user_activity_records'), isFalse);

        // Simulate App Restart: create new LocalStorage lifecycle with persisted secure storage
        await LocalStorage.init(secureStorage: secureStorage);

        // Verify clean retrieval from secure storage
        final loadedUser = LocalStorage.getAppUser();
        final loadedMetric = LocalStorage.getHealthMetric();
        final loadedProfile = LocalStorage.getUserProfile();
        final loadedActivities = LocalStorage.getActivityRecords();

        expect(loadedUser?.email, equals('secure_athlete@example.com'));
        expect(loadedUser?.displayName, equals('Zothanpuia'));

        expect(loadedMetric?.heartRate, equals(68));
        expect(loadedMetric?.steps, equals(11200));
        expect(loadedMetric?.sleepMinutes, equals(465));

        expect(loadedProfile.name, equals('Zothanpuia'));
        expect(loadedProfile.email, equals('secure_athlete@example.com'));
        expect(loadedProfile.phone, equals('9862300000'));
        expect(loadedProfile.height, equals('180'));
        expect(loadedProfile.weight, equals('76.5'));

        expect(loadedActivities.length, equals(1));
        expect(loadedActivities.first.id, equals('act_hiit_01'));
        expect(loadedActivities.first.caloriesBurned, equals(410.0));
      },
    );

    test(
      'gracefully recovers when secure storage contains corrupted JSON data',
      () async {
        await secureStorage.saveSecureData(
          'user_today_health_metric',
          '{"corrupted_data_without_closing_bracket',
        );
        await secureStorage.saveSecureData('user_profile', 'not_a_json_string');

        // Initialize should not throw and should fallback gracefully
        await LocalStorage.init(secureStorage: secureStorage);

        expect(LocalStorage.getHealthMetric(), isNull);
        expect(LocalStorage.getUserProfile(), isNotNull);
        expect(LocalStorage.getUserProfile().name, isEmpty);
      },
    );

    test(
      'clearAll purges both SecureStorage and SharedPreferences completely',
      () async {
        await LocalStorage.init(secureStorage: secureStorage);

        await LocalStorage.saveAppUser(
          AppUser(
            id: 'usr_to_clear',
            email: 'clear@test.com',
            displayName: 'ClearMe',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        await LocalStorage.clearAll();

        expect(LocalStorage.getAppUser(), isNull);
        expect(await secureStorage.containsKey('app_user_session'), isFalse);
        expect(await secureStorage.containsKey('user_profile'), isFalse);
      },
    );
  });
}
