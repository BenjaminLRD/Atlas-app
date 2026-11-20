import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/models/weight_goal.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/services/weight_goal_service.dart';
import 'package:atlas/repositories/weight_goal_repository.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';
import '../mocks/mock_ai_provider.dart';
import 'package:atlas/screens/weight_goal_setup_screen.dart';
import 'package:atlas/screens/weight_gain_plan_screen.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('Phase 1: WeightGoal Domain Model & Helpers', () {
    test('sampleGain factory produces consistent initial metrics', () {
      final goal = WeightGoal.sampleGain();
      expect(goal.currentWeight, 55.0);
      expect(goal.targetWeight, 70.0);
      expect(goal.targetWeeks, 24);
      expect(goal.type, WeightGoalType.gain);
      expect(goal.diet, DietPreference.nonVegetarian);
      expect(goal.mealsPerDay, MealFrequency.fourMeals);
      expect(goal.isWeightGain, isTrue);
      expect(goal.weightDifferenceKg, 15.0);
      expect(goal.totalTargetDeltaKg, 15.0);
      expect(goal.progressFraction(55.0), 0.0);
      expect(goal.progressFraction(62.5), closeTo(0.5, 0.01));
      expect(goal.progressFraction(70.0), 1.0);
    });

    test('toJson and fromJson roundtrip preserves all fields', () {
      final original = WeightGoal.sampleGain();
      final json = original.toJson();
      final reconstructed = WeightGoal.fromJson(json);

      expect(reconstructed.id, original.id);
      expect(reconstructed.userId, original.userId);
      expect(reconstructed.currentWeight, original.currentWeight);
      expect(reconstructed.targetWeight, original.targetWeight);
      expect(reconstructed.targetWeeks, original.targetWeeks);
      expect(reconstructed.type, original.type);
      expect(reconstructed.diet, original.diet);
      expect(reconstructed.mealsPerDay, original.mealsPerDay);
      expect(reconstructed.dailyCalorieTarget, original.dailyCalorieTarget);
      expect(reconstructed.proteinGrams, original.proteinGrams);
      expect(reconstructed.carbsGrams, original.carbsGrams);
      expect(reconstructed.fatGrams, original.fatGrams);
    });

    test('copyWith creates modified clone with unchanged defaults', () {
      final original = WeightGoal.sampleGain();
      final updated = original.copyWith(
        dailyCalorieTarget: 3100.0,
        diet: DietPreference.vegetarian,
      );

      expect(updated.dailyCalorieTarget, 3100.0);
      expect(updated.diet, DietPreference.vegetarian);
      expect(updated.currentWeight, original.currentWeight);
      expect(updated.targetWeight, original.targetWeight);
    });
  });

  group('Phase 2: WeightGoalService Calculation Engine', () {
    const service = WeightGoalService();

    test('calculates accurate Mifflin-St Jeor BMR and TDEE', () {
      final bmr = service.calculateBMR(
        weightKg: 55.0,
        heightCm: 175.0,
        age: 25,
      );
      // (10 * 55) + (6.25 * 175) - (5 * 25) + 5 = 550 + 1093.75 - 125 + 5 = 1523.75
      expect(bmr, 1523.75);

      final tdee = service.calculateTDEE(bmr: bmr, activityLevel: 'moderate');
      expect(tdee, closeTo(1523.75 * 1.55, 0.1));
    });

    test('55kg to 70kg in 24 weeks calculates lean bulk surplus & macros', () {
      final goal = service.createWeightGoal(
        userId: 'athlete_01',
        currentWeight: 55.0,
        targetWeight: 70.0,
        targetWeeks: 24,
        type: WeightGoalType.gain,
        diet: DietPreference.nonVegetarian,
        mealsPerDay: MealFrequency.fourMeals,
      );

      expect(goal.isWeightGain, isTrue);
      expect(goal.dailyCalorieTarget, greaterThan(2500));
      expect(goal.proteinGrams, closeTo(140.0, 5.0)); // 2.0g/kg * 70kg = 140g
      expect(goal.fatGrams, greaterThan(50.0));
      expect(goal.carbsGrams, greaterThan(250.0));
      expect(goal.expectedWeeklyRateKg, closeTo(15.0 / 24, 0.05));
    });

    test('generateMealPlan builds correct meal count and diet options', () {
      final goal4 = WeightGoal.sampleGain();
      final meals4 = service.generateMealPlan(goal4);
      expect(meals4.length, 4);
      expect(meals4[0].mealType, 'Breakfast');
      expect(meals4[1].mealType, 'Lunch');
      expect(meals4[2].mealType, 'Snack / Pre-Workout');
      expect(meals4[3].mealType, 'Dinner');

      final vegGoal = goal4.copyWith(diet: DietPreference.vegetarian);
      final vegMeals = service.generateMealPlan(vegGoal);
      expect(vegMeals[0].title.toLowerCase(), contains('oat'));
      expect(vegMeals[1].title.toLowerCase(), contains('paneer'));

      final goal3 = goal4.copyWith(mealsPerDay: MealFrequency.threeMeals);
      final meals3 = service.generateMealPlan(goal3);
      expect(meals3.length, 3);

      final goal5 = goal4.copyWith(mealsPerDay: MealFrequency.fiveMeals);
      final meals5 = service.generateMealPlan(goal5);
      expect(meals5.length, 5);
    });
  });

  group('Phase 6: Progress Adaptation Engine', () {
    const service = WeightGoalService();

    test(
      'detects slower gain rate and recommends +200 kcal surplus increase',
      () {
        final goal = WeightGoal.sampleGain(); // Target: +0.625 kg/wk
        // After 2 weeks, only gained +0.1kg (55.1kg)
        final adaptation = service.analyzeProgressAndAdapt(
          goal: goal,
          currentLoggedWeight: 55.1,
          weeksLogged: 2,
        );

        expect(adaptation.needsAdjustment, isTrue);
        expect(adaptation.suggestedCalorieDelta, 200.0);
        expect(
          adaptation.adjustedGoal.dailyCalorieTarget,
          goal.dailyCalorieTarget + 200.0,
        );
        expect(adaptation.title, contains('Below Target'));
      },
    );

    test(
      'detects excessively fast gain and recommends -150 kcal modulation',
      () {
        final goal = WeightGoal.sampleGain();
        // After 2 weeks, gained +3.0kg (1.5 kg/wk vs 0.625 kg/wk target)
        final adaptation = service.analyzeProgressAndAdapt(
          goal: goal,
          currentLoggedWeight: 58.0,
          weeksLogged: 2,
        );

        expect(adaptation.needsAdjustment, isTrue);
        expect(adaptation.suggestedCalorieDelta, -150.0);
        expect(
          adaptation.adjustedGoal.dailyCalorieTarget,
          goal.dailyCalorieTarget - 150.0,
        );
        expect(adaptation.title, contains('Ahead of Target'));
      },
    );

    test('confirms optimal progress when gain matches target rate', () {
      final goal = WeightGoal.sampleGain();
      // After 2 weeks, gained 1.2kg (0.6 kg/wk matches target)
      final adaptation = service.analyzeProgressAndAdapt(
        goal: goal,
        currentLoggedWeight: 56.2,
        weeksLogged: 2,
      );

      expect(adaptation.needsAdjustment, isFalse);
      expect(adaptation.suggestedCalorieDelta, 0.0);
      expect(adaptation.title, contains('Optimal'));
    });
  });

  group('Phase 6: LocalStorage & Repository Layer', () {
    test('LocalStorage stores and retrieves WeightGoal cleanly', () async {
      const repo = LocalWeightGoalRepository();
      expect(repo.getWeightGoal(), isNull);

      final goal = WeightGoal.sampleGain();
      await repo.saveWeightGoal(goal);

      final retrieved = repo.getWeightGoal();
      expect(retrieved, isNotNull);
      expect(retrieved!.id, goal.id);
      expect(retrieved.currentWeight, 55.0);
      expect(retrieved.targetWeight, 70.0);

      await repo.clearWeightGoal();
      expect(repo.getWeightGoal(), isNull);
    });
  });

  group('Phase 4: AI Coach Context & Prompt Builder Integration', () {
    test('CoachPromptBuilder includes WeightGoal in athlete context', () {
      final goal = WeightGoal.sampleGain();
      final context = FitnessContext.initial().copyWith(weightGoal: goal);

      const builder = CoachPromptBuilder();
      final prompt = builder.buildPrompt(
        message: 'How do I reach my target weight?',
        context: context,
      );

      expect(prompt, contains('55.0kg -> 70.0kg'));
      expect(prompt, contains('2900 kcal/day'));
      expect(prompt, contains('Non-Vegetarian'));
      expect(prompt, contains('Weight Transformation Program'));
    });

    test(
      'MockAIProvider answers weight gain and meal plan questions with goal data',
      () async {
        final goal = WeightGoal.sampleGain();
        final context = FitnessContext.initial().copyWith(weightGoal: goal);

        const provider = MockAIProvider();
        final response = await provider.generateResponse(
          message: 'What should I eat to gain weight on my plan?',
          context: context,
          history: [],
        );

        expect(response, contains('55.0 kg → 70.0 kg'));
        expect(response, contains('2900 kcal/day'));
        expect(response, contains('140g Protein'));
        expect(response, contains('Non-Vegetarian'));
      },
    );
  });

  group('Phase 9: Multi-Device Responsive UI Rendering', () {
    final viewports = [
      const Size(320, 640),
      const Size(360, 740),
      const Size(390, 844),
      const Size(412, 915),
    ];

    for (final size in viewports) {
      testWidgets(
        'WeightGoalSetupScreen renders without overflow on ${size.width}x${size.height}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          await tester.pumpWidget(
            const MaterialApp(home: WeightGoalSetupScreen()),
          );
          await tester.pumpAndSettle();

          expect(find.text('Weight Goal Setup'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets(
        'WeightGainPlanScreen renders without overflow on ${size.width}x${size.height}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);

          final sampleGoal = WeightGoal.sampleGain();

          await tester.pumpWidget(
            MaterialApp(home: WeightGainPlanScreen(goal: sampleGoal)),
          );
          await tester.pumpAndSettle();

          expect(find.text('WEIGHT GOAL PROGRAM'), findsOneWidget);
          expect(find.text('DAILY TARGET INTAKE'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
