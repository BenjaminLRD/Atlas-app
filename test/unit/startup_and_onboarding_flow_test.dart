import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/user_goal.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/screens/login_screen.dart';
import 'package:atlas/screens/onboarding_screen.dart';
import 'package:atlas/screens/splash_screen.dart';
import 'package:atlas/services/onboarding_state_service.dart';
import 'package:atlas/services/showcase_mode_service.dart';
import 'package:atlas/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    AppDependencies.reset();
    FitnessProvider.resetInstance();
    ShowcaseModeService.resetInstance();
  });

  group('Atlas Startup & Onboarding Flow Tests', () {
    test('1. Fresh install defaults: hasCompletedOnboarding is false and isLoggedIn is false', () {
      final onboardingState = OnboardingStateService.instance;
      expect(onboardingState.hasCompletedOnboarding(), isFalse);
      expect(onboardingState.isCompleted, isFalse);
      expect(LocalStorage.isLoggedIn(), isFalse);
    });

    testWidgets('2. Fresh install launch: SplashScreen navigates to OnboardingScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SplashScreen()),
      );

      // Verify splash emblem is rendered
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('ATLAS AI'), findsOneWidget);

      // Advance clock past splash transition
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pumpAndSettle();

      // Should be on OnboardingScreen
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.text("LET'S GET STARTED"), findsOneWidget);
      expect(find.text('⚡ TRY SHOWCASE MODE (NO SIGNUP)'), findsOneWidget);
      expect(find.text('Already have an account? Log In'), findsOneWidget);
    });

    testWidgets('3. Returning user (completed onboarding, logged out): SplashScreen navigates to LoginScreen', (tester) async {
      // Mark onboarding as completed
      await OnboardingStateService.instance.setCompletedOnboarding(true);
      await LocalStorage.setLoggedIn(false);

      await tester.pumpWidget(
        const MaterialApp(home: SplashScreen()),
      );

      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pumpAndSettle();

      // Should be on LoginScreen
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);
    });

    testWidgets('4. Returning authenticated user with goal: SplashScreen navigates to MainShell', (tester) async {
      // Mark onboarding & login & goal complete
      await OnboardingStateService.instance.setCompletedOnboarding(true);
      await LocalStorage.setLoggedIn(true);
      await LocalStorage.setGoalOnboardingCompleted(true);
      await LocalStorage.saveGoal(UserGoal.initial());

      await tester.pumpWidget(
        const MaterialApp(home: SplashScreen()),
      );

      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pump(const Duration(milliseconds: 500));

      // Should be on MainShell (Dashboard)
      expect(find.byType(MainShell), findsOneWidget);
    });

    testWidgets('5. Showcase Mode from Onboarding: seeds athlete and navigates to MainShell', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: OnboardingScreen()),
      );
      await tester.pumpAndSettle();

      // Ensure button is visible in scroll view and tap Showcase Mode button
      final showcaseFinder = find.text('⚡ TRY SHOWCASE MODE (NO SIGNUP)');
      expect(showcaseFinder, findsOneWidget);
      await tester.ensureVisible(showcaseFinder);
      await tester.pumpAndSettle();
      await tester.tap(showcaseFinder);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(OnboardingStateService.instance.hasCompletedOnboarding(), isTrue);
      expect(LocalStorage.isLoggedIn(), isTrue);
      expect(ShowcaseModeService.instance.isDemoMode, isTrue);
      expect(find.byType(MainShell), findsOneWidget);
    });

    test('6. OnboardingStateService reset clears onboarding completion', () async {
      final onboardingState = OnboardingStateService.instance;
      await onboardingState.setCompletedOnboarding(true);
      expect(onboardingState.hasCompletedOnboarding(), isTrue);

      await onboardingState.reset();
      expect(onboardingState.hasCompletedOnboarding(), isFalse);
    });
  });
}
