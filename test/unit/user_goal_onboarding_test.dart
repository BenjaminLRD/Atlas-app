import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/models/user_goal.dart';
import 'package:aizawl_gym/providers/fitness_provider.dart';
import 'package:aizawl_gym/screens/onboarding/goal_selection_screen.dart';
import 'package:aizawl_gym/screens/onboarding/fitness_level_screen.dart';
import 'package:aizawl_gym/screens/onboarding/body_metrics_screen.dart';
import 'package:aizawl_gym/screens/onboarding/activity_level_screen.dart';
import 'package:aizawl_gym/screens/onboarding/goal_summary_screen.dart';
import 'package:aizawl_gym/screens/onboarding/user_goal_setup_flow.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    FitnessProvider.resetInstance();
  });

  group('User Goal Onboarding Step Widgets Tests', () {
    testWidgets('GoalSelectionScreen renders options and handles tap selection', (tester) async {
      FitnessGoalType selected = FitnessGoalType.muscleGain;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoalSelectionScreen(
              selectedGoal: selected,
              onGoalSelected: (val) => selected = val,
            ),
          ),
        ),
      );

      expect(find.text('What is your primary goal?'), findsOneWidget);
      expect(find.text('Muscle Gain'), findsOneWidget);
      expect(find.text('Fat Loss'), findsOneWidget);
      expect(find.text('Maintenance'), findsOneWidget);
      expect(find.text('Strength'), findsOneWidget);
      expect(find.text('Endurance'), findsOneWidget);

      await tester.tap(find.text('Fat Loss'));
      expect(selected, equals(FitnessGoalType.fatLoss));
    });

    testWidgets('FitnessLevelScreen renders options with descriptions and handles selection', (tester) async {
      FitnessLevel selected = FitnessLevel.intermediate;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FitnessLevelScreen(
              selectedLevel: selected,
              onLevelSelected: (val) => selected = val,
            ),
          ),
        ),
      );

      expect(find.text('What is your fitness level?'), findsOneWidget);
      expect(find.text('Beginner'), findsOneWidget);
      expect(find.text('Intermediate'), findsOneWidget);
      expect(find.text('Advanced'), findsOneWidget);

      await tester.tap(find.text('Advanced'));
      expect(selected, equals(FitnessLevel.advanced));
    });

    testWidgets('BodyMetricsScreen accepts inputs and triggers onChanged callback when valid', (tester) async {
      int ageOut = 0;
      double heightOut = 0;
      double weightOut = 0;
      double targetWeightOut = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BodyMetricsScreen(
              age: 25,
              height: 175.0,
              currentWeight: 70.0,
              targetWeight: 75.0,
              onChanged: ({required age, required height, required currentWeight, required targetWeight}) {
                ageOut = age;
                heightOut = height;
                weightOut = currentWeight;
                targetWeightOut = targetWeight;
              },
            ),
          ),
        ),
      );

      expect(find.text('Your Body Measurements'), findsOneWidget);
      expect(find.text('Age'), findsOneWidget);
      expect(find.text('Height'), findsOneWidget);
      expect(find.text('Current Weight'), findsOneWidget);
      expect(find.text('Target Weight'), findsOneWidget);

      // Clear age input to test validation warning
      final ageFinder = find.byType(TextField).at(0);
      await tester.enterText(ageFinder, '');
      await tester.pump();
      expect(find.text('Age is required'), findsOneWidget);

      // Enter valid age
      await tester.enterText(ageFinder, '28');
      await tester.pump();
      expect(find.text('Age is required'), findsNothing);
      expect(ageOut, equals(28));
      expect(heightOut, equals(175.0));
      expect(weightOut, equals(70.0));
      expect(targetWeightOut, equals(75.0));
    });

    testWidgets('ActivityLevelScreen renders activity options and handles selection', (tester) async {
      ActivityLevel selected = ActivityLevel.moderate;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ActivityLevelScreen(
              selectedActivity: selected,
              onActivitySelected: (val) => selected = val,
            ),
          ),
        ),
      );

      expect(find.text('What is your daily activity level?'), findsOneWidget);
      expect(find.text('Sedentary'), findsOneWidget);
      expect(find.text('Light Activity'), findsOneWidget);
      expect(find.text('Moderate Activity'), findsOneWidget);
      expect(find.text('Very Active'), findsOneWidget);

      await tester.tap(find.text('Very Active'));
      expect(selected, equals(ActivityLevel.active));
    });

    testWidgets('GoalSummaryScreen calculates targets and CREATE PLAN saves goal', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GoalSummaryScreen(
              goalType: FitnessGoalType.muscleGain,
              fitnessLevel: FitnessLevel.intermediate,
              activityLevel: ActivityLevel.moderate,
              age: 25,
              height: 175.0,
              currentWeight: 70.0,
              targetWeight: 75.0,
            ),
          ),
        ),
      );

      expect(find.text('Your Personalized Fitness Plan'), findsOneWidget);
      expect(find.text('DAILY CALORIE TARGET'), findsOneWidget);

      final buttonFinder = find.text('CREATE PLAN');
      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pump();

      expect(find.text('Generating Your Custom Protocol...'), findsOneWidget);

      // Advance simulated timer
      await tester.pump(const Duration(milliseconds: 1500));

      expect(FitnessProvider.instance.currentGoal, isNotNull);
      expect(FitnessProvider.instance.currentGoal!.goalType, equals(FitnessGoalType.muscleGain));
      expect(LocalStorage.isGoalOnboardingCompleted(), isTrue);
    });
  });

  group('UserGoalSetupFlow Container Tests', () {
    testWidgets('UserGoalSetupFlow manages 5-step navigation and progress indicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: UserGoalSetupFlow(),
        ),
      );

      // Step 1
      expect(find.text('Step 1 of 5'), findsOneWidget);
      expect(find.text('What is your primary goal?'), findsOneWidget);

      // Tap Continue to Step 2
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Step 2
      expect(find.text('Step 2 of 5'), findsOneWidget);
      expect(find.text('What is your fitness level?'), findsOneWidget);

      // Tap Continue to Step 3
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Step 3
      expect(find.text('Step 3 of 5'), findsOneWidget);
      expect(find.text('Your Body Measurements'), findsOneWidget);

      // Tap Continue to Step 4
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Step 4
      expect(find.text('Step 4 of 5'), findsOneWidget);
      expect(find.text('What is your daily activity level?'), findsOneWidget);

      // Tap Continue to Step 5
      await tester.tap(find.text('Continue'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Step 5
      expect(find.text('Step 5 of 5'), findsOneWidget);
      expect(find.text('Your Personalized Fitness Plan'), findsOneWidget);
      expect(find.text('CREATE PLAN'), findsOneWidget);
    });
  });
}
