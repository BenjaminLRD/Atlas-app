import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/models/app_user.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/data/profile_provider.dart';
import 'package:atlas/screens/auth/profile_setup_screen.dart';
import 'package:atlas/screens/profile_screen.dart';
import 'package:atlas/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('Default User Profile Initialization Tests', () {
    test(
      'UserProfile.defaultProfile contains no demo personal or biometric data for new users',
      () {
        final profile = UserProfile.defaultProfile();

        expect(profile.name, isEmpty);
        expect(profile.email, isEmpty);
        expect(profile.phone, isEmpty);
        expect(profile.dob, isEmpty);
        expect(profile.gender, isEmpty);
        expect(profile.height, isEmpty);
        expect(profile.weight, isEmpty);
        expect(profile.fitnessGoal, isEmpty);
        expect(profile.workoutExperience, isEmpty);
        expect(profile.dietPreference, isEmpty);
        expect(profile.profilePic, isEmpty);
      },
    );

    test(
      'LocalStorage auto-migrates legacy demo profile data (zothana@aizawlgym.com)',
      () async {
        SharedPreferences.setMockInitialValues({
          'user_profile':
              '{"name": "", "email": "zothana@aizawlgym.com", "phone": "9876543210", "height": "175", "weight": "68.2", "gender": "Male", "dob": "1995-10-15"}',
        });
        await LocalStorage.init();

        final profile = LocalStorage.getUserProfile();
        expect(profile.email, isEmpty);
        expect(profile.phone, isEmpty);
        expect(profile.height, isEmpty);
        expect(profile.weight, isEmpty);
        expect(profile.gender, isEmpty);
        expect(profile.dob, isEmpty);
      },
    );

    test(
      'Legitimate custom profile data is preserved during init and migration checks',
      () async {
        SharedPreferences.setMockInitialValues({
          'user_profile':
              '{"name": "Lalramdina", "email": "custom@gmail.com", "phone": "9876543210", "height": "180", "weight": "72.0", "gender": "Male", "dob": "1995-08-10"}',
        });
        await LocalStorage.init();

        final profile = LocalStorage.getUserProfile();
        expect(profile.name, equals('Lalramdina'));
        expect(profile.email, equals('custom@gmail.com'));
        expect(profile.height, equals('180'));
        expect(profile.weight, equals('72.0'));
      },
    );

    test('Empty DOB does not crash ProfileProvider age calculation', () {
      final provider = ProfileProvider();
      expect(provider.age, equals(0));
    });

    test(
      'ProfileProvider retrieves email from authentication provider when profile email is empty',
      () async {
        final mockAuthUser = AppUser(
          id: 'usr_auth_123',
          email: 'newuser@example.com',
          displayName: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await LocalStorage.saveAppUser(mockAuthUser);

        final provider = ProfileProvider();
        provider.reload();

        expect(provider.email, equals('newuser@example.com'));
        expect(provider.name, isEmpty);
        expect(provider.phone, isEmpty);
        expect(provider.dob, isEmpty);
        expect(provider.profilePic, isEmpty);
      },
    );

    test(
      'Saving user-entered information persists correctly and survives reload',
      () async {
        final provider = ProfileProvider();
        final updatedProfile = UserProfile(
          name: 'Zorinpuia',
          email: 'zorin@example.com',
          phone: '9988776655',
          dob: '2001-03-20',
          gender: 'Male',
          height: '182',
          weight: '78.5',
          fitnessGoal: 'Build Muscle',
          workoutExperience: 'Intermediate',
          preferredDays: const ['Mon', 'Fri'],
          dietPreference: 'High Protein',
          massUnit: 'kg',
          lengthUnit: 'cm',
          subscription: 'Free',
          privacy: 'Friends Only',
          notificationsEnabled: true,
          profilePic: '',
        );

        await provider.updateProfile(updatedProfile);

        expect(provider.name, equals('Zorinpuia'));
        expect(provider.weight, equals('78.5'));

        provider.reload();
        expect(provider.name, equals('Zorinpuia'));
        expect(provider.weight, equals('78.5'));

        final loadedFromDisk = LocalStorage.getUserProfile();
        expect(loadedFromDisk.name, equals('Zorinpuia'));
        expect(loadedFromDisk.email, equals('zorin@example.com'));
      },
    );

    test(
      'UserProfile.sanitizeName removes placeholder identities but preserves legitimate names',
      () {
        expect(UserProfile.sanitizeName('Zothanmawia'), isEmpty);
        expect(UserProfile.sanitizeName('zothanmawia'), isEmpty);
        expect(UserProfile.sanitizeName('User'), isEmpty);
        expect(UserProfile.sanitizeName('Athlete'), isEmpty);
        expect(UserProfile.sanitizeName('Benjamin'), equals('Benjamin'));
        expect(UserProfile.sanitizeName('Zorinpuia'), equals('Zorinpuia'));
      },
    );

    testWidgets(
      'ProfileSetupScreen displays "Complete your profile to personalize your fitness journey"',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ProfileSetupScreen(),
          ),
        );

        expect(
          find.text(
            'Complete your profile to personalize your fitness journey',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ProfileScreen displays Athlete Profile and Edit Profile CTA when profile is incomplete',
      (WidgetTester tester) async {
        final emptyProfile = UserProfile.defaultProfile();
        await LocalStorage.saveUserProfile(emptyProfile);
        ProfileProvider().reload();

        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.lightTheme, home: const ProfileScreen()),
        );

        expect(find.text('Athlete Profile'), findsOneWidget);
        expect(find.text('Edit Profile'), findsOneWidget);
      },
    );
  });
}
