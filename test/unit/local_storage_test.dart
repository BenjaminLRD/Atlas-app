import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/models/user_profile.dart';
import 'package:aizawl_gym/models/active_workout_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('LocalStorage Tests', () {
    test('save and load profile round trip using UserProfile model', () async {
      final profile = UserProfile(
        name: 'Lalduhawma',
        email: 'lalduhawma@aizawlgym.com',
        phone: '9876500000',
        dob: '1992-08-25',
        gender: 'Male',
        height: '172',
        weight: '71.0',
        fitnessGoal: 'Fat Loss',
        workoutExperience: 'Beginner',
        preferredDays: ['Tuesday', 'Thursday', 'Saturday'],
        dietPreference: 'Low Carb',
        massUnit: 'kg',
        lengthUnit: 'cm',
        subscription: 'Free',
        password: 'pass',
        privacy: 'Private',
        notificationsEnabled: false,
        profilePic: '',
      );

      await LocalStorage.saveUserProfile(profile);
      final retrieved = LocalStorage.getUserProfile();

      expect(retrieved.name, equals('Lalduhawma'));
      expect(retrieved.email, equals('lalduhawma@aizawlgym.com'));
      expect(retrieved.height, equals('172'));
      expect(retrieved.weight, equals('71.0'));
      expect(retrieved.fitnessGoal, equals('Fat Loss'));
      expect(retrieved.notificationsEnabled, isFalse);
    });

    test('save and load active workout session round trip', () async {
      final session = ActiveWorkoutSession(
        workoutName: 'Pull Day Heavy',
        workoutId: 'pull_01',
        currentIndex: 3,
        seconds: 600,
        isPaused: false,
        completedSets: [
          [true, true, true],
          [true, true, false],
        ],
      );

      await LocalStorage.saveActiveSession(session);
      final retrieved = LocalStorage.getActiveSession();

      expect(retrieved, isNotNull);
      expect(retrieved!.workoutName, equals('Pull Day Heavy'));
      expect(retrieved.workoutId, equals('pull_01'));
      expect(retrieved.currentIndex, equals(3));
      expect(retrieved.seconds, equals(600));
      expect(retrieved.completedSets.length, equals(2));

      await LocalStorage.clearActiveSession();
      expect(LocalStorage.getActiveSession(), isNull);
    });
  });
}
