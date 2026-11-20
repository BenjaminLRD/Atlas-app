import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/data/profile_provider.dart';
import 'package:atlas/screens/profile_screen.dart';
import 'package:atlas/screens/edit_profile_screen.dart';
import 'package:atlas/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    ProfileProvider().reload();
  });

  group('ProfileScreen Edit Profile Navigation Tests', () {
    testWidgets(
      'ProfileScreen renders dedicated Edit Profile button near header',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.lightTheme, home: const ProfileScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Edit Profile'), findsOneWidget);
        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping Edit Profile opens EditProfileScreen and back button returns to ProfileScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.lightTheme, home: const ProfileScreen()),
        );
        await tester.pumpAndSettle();

        final editButton = find.text('Edit Profile');
        expect(editButton, findsOneWidget);

        await tester.tap(editButton);
        await tester.pumpAndSettle();

        // Verify EditProfileScreen is pushed onto navigator stack
        expect(find.byType(EditProfileScreen), findsOneWidget);
        expect(find.text('Identity & Profile'), findsOneWidget);
        expect(find.text('Personal Information'), findsOneWidget);

        // Verify back button tap pops EditProfileScreen back to ProfileScreen
        final backButton = find.byIcon(Icons.chevron_left_rounded);
        expect(backButton, findsOneWidget);

        await tester.tap(backButton);
        await tester.pumpAndSettle();

        expect(find.byType(ProfileScreen), findsOneWidget);
        expect(find.byType(EditProfileScreen), findsNothing);
      },
    );
  });
}
