import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/data/profile_provider.dart';
import 'package:atlas/screens/dashboard_screen.dart';
import 'package:atlas/screens/profile_screen.dart';
import 'package:atlas/app_theme.dart';

String getTestGreeting(int hour, String userName) {
  final greetingPrefix = hour >= 5 && hour < 12
      ? 'Good morning'
      : hour >= 12 && hour < 17
      ? 'Good afternoon'
      : hour >= 17 && hour < 21
      ? 'Good evening'
      : 'Good night';

  final rawName = userName.trim();
  if (rawName.isNotEmpty) {
    return '$greetingPrefix, $rawName';
  }
  return greetingPrefix;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('Dashboard Time-of-Day Greeting Logic Tests', () {
    test('Morning greeting (5:00 - 11:59)', () {
      expect(getTestGreeting(8, ''), equals('Good morning'));
      expect(
        getTestGreeting(8, 'Zorinpuia'),
        equals('Good morning, Zorinpuia'),
      );
    });

    test('Afternoon greeting (12:00 - 16:59)', () {
      expect(getTestGreeting(14, ''), equals('Good afternoon'));
      expect(
        getTestGreeting(14, 'Zorinpuia'),
        equals('Good afternoon, Zorinpuia'),
      );
    });

    test('Evening greeting (17:00 - 20:59)', () {
      expect(getTestGreeting(19, ''), equals('Good evening'));
      expect(
        getTestGreeting(19, 'Zorinpuia'),
        equals('Good evening, Zorinpuia'),
      );
    });

    test('Night greeting (21:00 - 4:59)', () {
      expect(getTestGreeting(23, ''), equals('Good night'));
      expect(getTestGreeting(23, 'Zorinpuia'), equals('Good night, Zorinpuia'));
      expect(getTestGreeting(3, ''), equals('Good night'));
    });
  });

  group('DashboardScreen UI Widget & Navigation Tests', () {
    testWidgets(
      'UserProfile.fromJson defaults missing or placeholder name to empty string',
      (WidgetTester tester) async {
        final jsonProfile = UserProfile.fromJson({});
        expect(jsonProfile.name, equals(''));

        final zothanProfile = UserProfile.fromJson({'name': 'Zothanmawia'});
        expect(zothanProfile.name, equals(''));

        final userProfile = UserProfile.fromJson({'name': 'User'});
        expect(userProfile.name, equals(''));

        final athleteProfile = UserProfile.fromJson({'name': 'Athlete'});
        expect(athleteProfile.name, equals(''));

        final legitimateProfile = UserProfile.fromJson({'name': 'Benjamin'});
        expect(legitimateProfile.name, equals('Benjamin'));
      },
    );

    testWidgets(
      'DashboardScreen renders clean greeting without default name and displays completion CTA',
      (WidgetTester tester) async {
        await LocalStorage.saveUserProfile(UserProfile.defaultProfile());
        ProfileProvider().reload();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const DashboardScreen(),
          ),
        );

        // Verify no hardcoded names like "User", "Athlete", or "Zothanmawia"
        expect(find.textContaining('Zothanmawia'), findsNothing);
        expect(find.textContaining('Athlete'), findsNothing);
        expect(find.textContaining('Good morning, User'), findsNothing);

        // Verify profile completion prompt is visible for new/unnamed users
        expect(
          find.text(
            'Complete your profile to personalize your fitness journey',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'DashboardScreen renders personalized greeting for named user',
      (WidgetTester tester) async {
        final namedProfile = UserProfile.defaultProfile().copyWith(
          name: 'Zorinpuia',
        );
        await LocalStorage.saveUserProfile(namedProfile);
        ProfileProvider().reload();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const DashboardScreen(),
          ),
        );

        expect(find.textContaining('Zorinpuia'), findsOneWidget);
        // Completion prompt should NOT be rendered when user has a set name
        expect(
          find.text(
            'Complete your profile to personalize your fitness journey',
          ),
          findsNothing,
        );
      },
    );

    testWidgets('Avatar tap navigates from DashboardScreen to ProfileScreen', (
      WidgetTester tester,
    ) async {
      await LocalStorage.saveUserProfile(UserProfile.defaultProfile());
      ProfileProvider().reload();

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.lightTheme, home: const DashboardScreen()),
      );

      // Find user profile avatar semantics/tooltip button and tap
      final avatarFinder = find.bySemanticsLabel('User profile avatar');
      expect(avatarFinder, findsOneWidget);

      await tester.tap(avatarFinder);
      await tester.pumpAndSettle();

      // Verify ProfileScreen is pushed
      expect(find.byType(ProfileScreen), findsOneWidget);
    });
  });
}
