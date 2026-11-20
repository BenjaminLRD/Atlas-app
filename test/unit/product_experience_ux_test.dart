import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/screens/ai_coach_screen.dart';
import 'package:atlas/screens/dashboard_screen.dart';
import 'package:atlas/screens/onboarding_screen.dart';
import 'package:atlas/screens/unified_food_scanner_screen.dart';
import 'package:atlas/services/ai/memory/fitness_memory.dart';
import 'package:atlas/services/showcase_mode_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    AppDependencies.reset();
    FitnessProvider.resetInstance();
    FitnessMemory.resetInstance();
    ShowcaseModeService.resetInstance();
  });

  group('Phase D.2 — Startup-Level UX & Product Experience Tests', () {
    testWidgets('1. Onboarding Screen renders Step 0 Welcome and progresses through 8 steps', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: OnboardingScreen()),
      );
      await tester.pumpAndSettle();

      // Step 0: Welcome Screen
      expect(find.text('ATLAS AI'), findsOneWidget);
      expect(
        find.text('Your Autonomous Personal Trainer & Nutrition Intelligence'),
        findsOneWidget,
      );
      expect(find.text('Adaptive Workout Engine'), findsOneWidget);
      expect(find.text('Vision Nutrition Scanner'), findsOneWidget);
      expect(find.text('24/7 AI Strength Coach'), findsOneWidget);
      expect(find.text("LET'S GET STARTED"), findsOneWidget);

      // Tap Let's Get Started -> Step 1: Goal
      await tester.tap(find.text("LET'S GET STARTED"));
      await tester.pumpAndSettle();

      expect(find.text("What's your primary goal?"), findsOneWidget);
      expect(find.text('Build Muscle'), findsOneWidget);
      expect(find.text('STEP 1 OF 7'), findsOneWidget);

      // Select Goal & Tap Continue -> Step 2: Experience
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(find.text('Lifting Experience'), findsOneWidget);
      expect(find.text('STEP 2 OF 7'), findsOneWidget);

      // Select Experience & Tap Continue -> Step 3: Equipment Profile
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(find.text('Available Equipment'), findsOneWidget);
      expect(find.text('Full Commercial Gym'), findsOneWidget);
      expect(find.text('Home Dumbbells & Bench'), findsOneWidget);
      expect(find.text('STEP 3 OF 7'), findsOneWidget);

      // Select Equipment & Tap Continue -> Step 4: Workout Schedule
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(find.text('Workout Preference'), findsOneWidget);
      expect(find.text('WEEKLY TRAINING FREQUENCY'), findsOneWidget);
      expect(find.text('PREFERRED SESSION DURATION'), findsOneWidget);
      expect(find.text('STEP 4 OF 7'), findsOneWidget);

      // Tap Continue -> Step 5: Nutrition Strategy
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(find.text('Nutrition Strategy'), findsOneWidget);
      expect(find.text('Daily Calorie Target'), findsOneWidget);
      expect(find.text('STEP 5 OF 7'), findsOneWidget);

      // Tap Continue -> Step 6: optional permissions (nothing is asked yet)
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();

      expect(find.text('Let Atlas use your phone'), findsOneWidget);
      expect(find.text('STEP 6 OF 7'), findsOneWidget);

      // Skipping is allowed -> Step 7: Meet Your AI Coach
      await tester.tap(find.byKey(const Key('permissions_skip')));
      await tester.pumpAndSettle();

      expect(find.text('Meet Your AI Coach'), findsOneWidget);
      expect(find.text('ENTER DASHBOARD'), findsOneWidget);
      expect(find.text('STEP 7 OF 7'), findsOneWidget);
    });

    testWidgets('2. Dashboard renders 4-pillar quick AI Coach action pills', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: DashboardScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('ASK AI COACH'), findsOneWidget);
      expect(find.text("Create today's workout"), findsOneWidget);
      expect(find.text("Analyze my diet"), findsOneWidget);
    });

    testWidgets('3. Atlas AI launches with initial prompt and responds', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AICoachScreen(initialPrompt: "Plan my day"),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 20));

      expect(find.text('Atlas AI'), findsWidgets);
    });

    testWidgets('4. Unified Food Scanner shows clean pre-scan header and prompt', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UnifiedFoodScannerScreen(initialMode: UnifiedScanMode.foodAi),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SCAN FOOD & PRODUCTS'), findsOneWidget);
      expect(find.text('Scan your meal or barcode'), findsOneWidget);
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('From Gallery'), findsOneWidget);
    });

    testWidgets('5. ShowcaseModeService provides rich investor demo presentation data without overwriting real profiles', (
      tester,
    ) async {
      final demo = ShowcaseModeService.instance;
      expect(demo.isDemoMode, isFalse);

      demo.enableDemoMode();
      expect(demo.isDemoMode, isTrue);

      final user = demo.getDemoUserProfile();
      expect(user.name, equals('Alex Lalremruata'));
      expect(user.subscription, equals('Premium Pro'));

      final history = demo.getDemoWorkoutHistory();
      expect(history.length, greaterThanOrEqualTo(5));
      expect(history.first.workoutName, contains('Upper Push'));

      final context = demo.getDemoFitnessContext();
      expect(context.recoveryState?.recoveryScore, equals(88));
      expect(context.userProgress.workoutStreak, equals(12));

      demo.disableDemoMode();
      expect(demo.isDemoMode, isFalse);
    });
  });
}
