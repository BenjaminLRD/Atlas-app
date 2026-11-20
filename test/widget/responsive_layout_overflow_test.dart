import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/data/profile_provider.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/screens/profile_screen.dart';
import 'package:atlas/screens/dashboard_screen.dart';
import 'package:atlas/widgets/common/achievement_gallery.dart';
import 'package:atlas/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    await LocalStorage.saveUserProfile(
      UserProfile(
        name: 'Test User',
        email: 'test@example.com',
        phone: '1234567890',
        dob: '1995-01-01',
        gender: 'Male',
        height: '175',
        weight: '70',
        fitnessGoal: 'Fitness',
        workoutExperience: 'Intermediate',
        preferredDays: const [],
        dietPreference: 'None',
        massUnit: 'kg',
        lengthUnit: 'cm',
        subscription: 'Free',
        privacy: 'Public',
        notificationsEnabled: true,
        profilePic: '',
      ),
    );
    ProfileProvider().reload();
  });

  Future<void> testScreenAtWidth(
    WidgetTester tester, {
    required double width,
    required Widget child,
  }) async {
    tester.view.physicalSize = Size(width * 3.0, 800 * 3.0);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: child),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group(
    'Responsive Layout & Overflow Tests at 320px, 360px, 390px, 412px Viewports',
    () {
      final viewports = [320.0, 360.0, 390.0, 412.0];

      for (final width in viewports) {
        testWidgets(
          'ProfileScreen renders without overflow on ${width}px device width',
          (WidgetTester tester) async {
            await testScreenAtWidth(
              tester,
              width: width,
              child: const ProfileScreen(),
            );

            expect(find.text('Weight Trends'), findsOneWidget);
            expect(find.text('WEEKLY PERFORMANCE'), findsOneWidget);
            expect(find.text('Edit Profile'), findsOneWidget);
          },
        );

        testWidgets(
          'AchievementGallery filter chips render without overflow on ${width}px device width',
          (WidgetTester tester) async {
            await testScreenAtWidth(
              tester,
              width: width,
              child: const SingleChildScrollView(
                child: AchievementGallery(unlockedBadgeIds: ['b_streak_7']),
              ),
            );

            expect(find.text('Milestone'), findsOneWidget);
            expect(find.text('Consistency'), findsOneWidget);
            expect(find.text('Strength'), findsOneWidget);
            expect(find.text('Nutrition'), findsOneWidget);
          },
        );

        testWidgets(
          'DashboardScreen renders without overflow on ${width}px device width',
          (WidgetTester tester) async {
            await testScreenAtWidth(
              tester,
              width: width,
              child: const DashboardScreen(),
            );

            expect(find.byType(DashboardScreen), findsOneWidget);
          },
        );
      }
    },
  );
}
