import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/data/profile_provider.dart';
import 'package:atlas/models/user_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    ProfileProvider().reload();
  });

  group('ProfileProvider Tests', () {
    test('update profile notifies listeners and persists data', () async {
      final provider = ProfileProvider();
      bool listenerNotified = false;

      void listener() {
        listenerNotified = true;
      }

      provider.addListener(listener);

      final updatedProfile = UserProfile(
        name: 'Zorinpuia',
        email: 'zorina@example.com',
        phone: '9876543210',
        dob: '1998-05-20',
        gender: 'Male',
        height: '176',
        weight: '72.0',
        fitnessGoal: 'Hypertrophy',
        workoutExperience: 'Advanced',
        preferredDays: ['Monday', 'Wednesday', 'Friday'],
        dietPreference: 'High Protein',
        massUnit: 'kg',
        lengthUnit: 'cm',
        subscription: 'Pro',
        privacy: 'Public',
        notificationsEnabled: true,
        profilePic: '',
      );

      await provider.update(updatedProfile);

      expect(listenerNotified, isTrue);
      expect(provider.name, equals('Zorinpuia'));
      expect(provider.email, equals('zorina@example.com'));
      expect(provider.fitnessGoal, equals('Hypertrophy'));

      // Check persistence
      final fromStorage = LocalStorage.getUserProfile();
      expect(fromStorage.name, equals('Zorinpuia'));

      provider.removeListener(listener);
    });

    test('age calculation consistency from date of birth', () async {
      final provider = ProfileProvider();

      // DOB exactly 20 years ago
      final today = DateTime.now();
      final dob20YearsAgo = DateTime(today.year - 20, today.month, today.day);
      final dobString = dob20YearsAgo.toIso8601String().split('T')[0];

      await provider.updateField('dob', dobString);

      expect(provider.age, equals(20));
    });
  });
}
