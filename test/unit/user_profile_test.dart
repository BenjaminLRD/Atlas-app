import 'package:flutter_test/flutter_test.dart';
import 'package:aizawl_gym/models/user_profile.dart';

void main() {
  group('UserProfile Model Tests', () {
    test('fromJson and toJson round trip with canonical fields', () {
      final jsonMap = {
        'name': 'Renthlei',
        'email': 'renthlei@aizawlgym.com',
        'phone': '9876543210',
        'dob': '1996-04-12',
        'gender': 'Male',
        'height': '180',
        'weight': '75.5',
        'fitnessGoal': 'Build Muscle',
        'workoutExperience': 'Advanced',
        'preferredDays': ['Monday', 'Tuesday', 'Thursday'],
        'dietPreference': 'High Protein',
        'massUnit': 'kg',
        'lengthUnit': 'cm',
        'subscription': 'Pro',
        'password': 'secure123',
        'privacy': 'Public',
        'notificationsEnabled': true,
        'profilePic': 'assets/profile.png',
      };

      final profile = UserProfile.fromJson(jsonMap);

      expect(profile.name, equals('Renthlei'));
      expect(profile.email, equals('renthlei@aizawlgym.com'));
      expect(profile.height, equals('180'));
      expect(profile.weight, equals('75.5'));
      expect(profile.fitnessGoal, equals('Build Muscle'));
      expect(profile.workoutExperience, equals('Advanced'));
      expect(profile.preferredDays, containsAll(['Monday', 'Tuesday', 'Thursday']));
      expect(profile.subscription, equals('Pro'));

      final reserialized = profile.toJson();
      expect(reserialized['name'], equals('Renthlei'));
      expect(reserialized['fitnessGoal'], equals('Build Muscle'));
      expect(reserialized['subscription'], equals('Pro'));
    });

    test('copyWith updates specified fields and retains unmodified fields', () {
      final initial = UserProfile.defaultProfile();
      final updated = initial.copyWith(
        name: 'Updated Name',
        weight: '82.0',
        subscription: 'Premium',
      );

      expect(updated.name, equals('Updated Name'));
      expect(updated.weight, equals('82.0'));
      expect(updated.subscription, equals('Premium'));

      // Unmodified fields retained
      expect(updated.email, equals(initial.email));
      expect(updated.fitnessGoal, equals(initial.fitnessGoal));
      expect(updated.gender, equals(initial.gender));
    });

    test('legacy key compatibility for goal, level, and diet', () {
      final legacyJson = {
        'name': 'Legacy User',
        'goal': 'Lose Weight',
        'level': 'Beginner',
        'diet': 'Keto',
      };

      final profile = UserProfile.fromJson(legacyJson);

      // Maps legacy keys to canonical fields
      expect(profile.fitnessGoal, equals('Lose Weight'));
      expect(profile.workoutExperience, equals('Beginner'));
      expect(profile.dietPreference, equals('Keto'));

      // Maps operator [] compatibility
      expect(profile['goal'], equals('Lose Weight'));
      expect(profile['level'], equals('Beginner'));
      expect(profile['diet'], equals('Keto'));

      // Operator []= compatibility updates canonical properties
      profile['goal'] = 'Strength Training';
      expect(profile.fitnessGoal, equals('Strength Training'));
      expect(profile['goal'], equals('Strength Training'));
    });
  });
}
