import 'dart:convert';

import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/consumed_food.dart';
import 'package:atlas/models/daily_nutrition.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/models/macro_target.dart';
import 'package:atlas/models/meal_entry.dart';
import 'package:atlas/models/nutrition_log.dart';
import 'package:atlas/models/nutrition_totals.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/ai/tools/coach_tools.dart';
import 'package:atlas/services/ai/tools/nutrition_tool.dart';
import 'package:atlas/services/nutrition/nutrition_service.dart';
import 'package:atlas/widgets/nutrition/nutrition_hero_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _chicken = FoodItem(
  id: 'chk',
  name: 'Chicken',
  calories: 200,
  protein: 40,
  carbohydrates: 0,
  fats: 4,
);
const _rice = FoodItem(
  id: 'rice',
  name: 'Rice',
  calories: 130,
  protein: 3,
  carbohydrates: 28,
  fats: 0.5,
);

String _dayString(DateTime d) => d.toIso8601String().split('T')[0];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late NutritionService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    service = NutritionService();
  });

  group('NutritionTotals', () {
    test('no meals means zero, not an assumed amount', () {
      final totals = NutritionTotals.fromMeals(const []);
      expect(totals.calories, 0);
      expect(totals.protein, 0);
      expect(totals.carbs, 0);
      expect(totals.fat, 0);
    });

    test('empty meals contribute nothing', () {
      final totals = NutritionTotals.fromMeals([
        MealEntry(id: 'a', mealType: MealCategory.breakfast),
        MealEntry(id: 'b', mealType: MealCategory.lunch),
      ]);
      expect(totals.calories, 0);
      expect(totals.protein, 0);
    });

    test('meals of several categories add up to one daily total', () {
      final totals = NutritionTotals.fromMeals([
        MealEntry(
          id: 'a',
          mealType: MealCategory.breakfast,
          consumedFoods: [
            ConsumedFood(food: _chicken, quantity: 100, unit: 'grams'),
          ],
        ),
        MealEntry(
          id: 'b',
          mealType: MealCategory.dinner,
          consumedFoods: [
            ConsumedFood(food: _rice, quantity: 100, unit: 'grams'),
            ConsumedFood(food: _chicken, quantity: 100, unit: 'grams'),
          ],
        ),
      ]);
      expect(totals.calories, closeTo(530, 0.001));
      expect(totals.protein, closeTo(83, 0.001));
      expect(totals.carbs, closeTo(28, 0.001));
      expect(totals.fat, closeTo(8.5, 0.001));
    });
  });

  group('DailyNutrition has no built-in starting amount', () {
    test('a new day consumed nothing, with the target untouched', () {
      final daily = DailyNutrition.defaultForDate('2026-10-15');
      expect(daily.totalCaloriesConsumed, 0);
      expect(daily.totalProteinConsumed, 0);
      expect(daily.totalCarbsConsumed, 0);
      expect(daily.totalFatConsumed, 0);
      expect(daily.targets.calories, MacroTarget.defaultTarget().calories);
      expect(daily.caloriesRemaining, daily.targets.calories);
    });

    // A day as saved before the marker existed: automatic 300/25/40/15.
    Map<String, dynamic> legacyDay({
      double calories = 300,
      double protein = 25,
      double carbs = 40,
      double fat = 15,
    }) => DailyNutrition.defaultForDate('2026-10-15').toJson()
      ..remove(DailyNutrition.baseAmountsVersionKey)
      ..['baseCalories'] = calories
      ..['baseProtein'] = protein
      ..['baseCarbs'] = carbs
      ..['baseFat'] = fat;

    test('the old automatic starting amount reads as zero', () {
      final restored = DailyNutrition.fromJson(legacyDay());
      expect(restored.totalCaloriesConsumed, 0);
      expect(restored.totalProteinConsumed, 0);
      expect(restored.totalCarbsConsumed, 0);
      expect(restored.totalFatConsumed, 0);
    });

    test('a legacy record with any other amount keeps it', () {
      final restored = DailyNutrition.fromJson(
        legacyDay(calories: 1200, protein: 80),
      );
      expect(restored.totalCaloriesConsumed, 1200);
      expect(restored.totalProteinConsumed, 80);
      // Changing only some of the four numbers is not the old default.
      final partial = DailyNutrition.fromJson(legacyDay(calories: 301));
      expect(partial.totalCaloriesConsumed, 301);
      expect(partial.totalProteinConsumed, 25);
    });

    test(
      'amounts equal to the old default are kept once saved by this version',
      () {
        const entered = DailyNutrition(
          date: '2026-10-15',
          targets: MacroTarget(
            calories: 2000,
            proteinGrams: 150,
            carbsGrams: 200,
            fatGrams: 60,
          ),
          meals: [],
          baseCalories: 300,
          baseProtein: 25,
          baseCarbs: 40,
          baseFat: 15,
        );
        final json = entered.toJson();
        expect(json[DailyNutrition.baseAmountsVersionKey], isNotNull);
        final restored = DailyNutrition.fromJson(json);
        expect(restored.totalCaloriesConsumed, 300);
        expect(restored.totalProteinConsumed, 25);
        expect(restored.totalCarbsConsumed, 40);
        expect(restored.totalFatConsumed, 15);
      },
    );

    test('a stored day without base fields reads as zero', () {
      final json = legacyDay()
        ..remove('baseCalories')
        ..remove('baseProtein')
        ..remove('baseCarbs')
        ..remove('baseFat');
      expect(DailyNutrition.fromJson(json).totalCaloriesConsumed, 0);
    });

    test('a legacy day in storage is cleaned once and stays clean', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'nutrition_daily_2026-10-15',
        jsonEncode(legacyDay()),
      );

      final loaded = LocalStorage.getDailyNutrition('2026-10-15');
      expect(loaded.totalCaloriesConsumed, 0);
      // Saving and reading again does not bring the amount back.
      await LocalStorage.saveDailyNutrition(loaded);
      final again = LocalStorage.getDailyNutrition('2026-10-15');
      expect(again.totalCaloriesConsumed, 0);
      expect(again.meals.length, loaded.meals.length);
    });

    test('a cloud row round-trips through the same json', () {
      // Cloud sync stores DailyNutrition.toJson() and reads it back with
      // fromJson (CloudSyncCoordinator), so the same rules apply to it.
      final legacyRow = DailyNutrition.fromJson(legacyDay());
      expect(legacyRow.totalCaloriesConsumed, 0);
      final modern = DailyNutrition.fromJson(
        DailyNutrition.fromJson(legacyDay(calories: 900)).toJson(),
      );
      expect(modern.totalCaloriesConsumed, 900);
    });
  });

  group('one total across providers, services and tools', () {
    test('an empty day reads zero everywhere', () async {
      final provider = FitnessProvider.instance;
      expect(provider.todayNutritionLog.totals.calories, 0);
      expect(provider.totalCaloriesConsumed, 0);
      expect(provider.proteinConsumed, 0);
      expect(provider.carbsConsumed, 0);
      expect(provider.fatConsumed, 0);
      expect(service.getConsumedTotals().calories, 0);
      expect(service.getDailyNutritionWithLogged().totalProteinConsumed, 0);

      final status = await CoachTools(
        nutritionService: service,
      ).getNutritionStatus();
      expect((status['calories'] as Map)['consumed'], 0);
      expect((status['protein'] as Map)['consumed_g'], 0);
    });

    test('logged food reaches every reader with the same numbers', () async {
      final provider = FitnessProvider.instance;
      await provider.addFoodToMeal('Breakfast', _chicken, 100, 'grams');
      await provider.addFoodToMeal('Dinner', _rice, 100, 'grams');
      await provider.addFoodToMeal('Snack', _chicken, 100, 'grams');

      final log = provider.todayNutritionLog;
      // The authoritative numbers: 200 + 130 + 200 kcal, 83 g protein.
      expect(log.totals.calories, closeTo(530, 0.001));
      expect(log.totals.protein, closeTo(83, 0.001));

      expect(provider.totalCaloriesConsumed, log.dailyCalories);
      expect(provider.proteinConsumed, log.dailyProtein);
      expect(provider.carbsConsumed, log.dailyCarbohydrates);
      expect(provider.fatConsumed, log.dailyFats);
      expect(provider.todayConsumed.calories, log.totals.calories);

      expect(service.getConsumedTotals().calories, log.totals.calories);
      final view = service.getDailyNutritionWithLogged();
      expect(view.totalCaloriesConsumed, closeTo(530, 0.001));
      expect(view.totalProteinConsumed, closeTo(83, 0.001));
      expect(view.totalCarbsConsumed, closeTo(28, 0.001));
      expect(view.totalFatConsumed, closeTo(8.5, 0.001));

      final status = await CoachTools(
        nutritionService: service,
      ).getNutritionStatus();
      expect((status['calories'] as Map)['consumed'], 530);
      expect((status['protein'] as Map)['consumed_g'], 83);
      expect(status['carbs_g'], 28);

      final tool = NutritionTool(nutritionService: service);
      final cals = await tool.execute({'action': 'get_today_calories'});
      final protein = await tool.execute({'action': 'get_protein_intake'});
      expect(cals['consumed_calories'], 530);
      expect(protein['consumed_protein_g'], 83);
    });

    test('the engines see the same numbers through the provider', () async {
      final provider = FitnessProvider.instance;
      await provider.addFoodToMeal('Lunch', _chicken, 100, 'grams');
      final context = provider.buildFitnessContext();
      expect(context.todayNutrition!.totalCaloriesConsumed, 200);
      expect(context.todayNutritionLog!.dailyCalories, 200);
    });

    test('targets are not changed by logging food', () async {
      const target = MacroTarget(
        calories: 2100,
        proteinGrams: 140,
        carbsGrams: 220,
        fatGrams: 60,
      );
      await service.saveMacroTarget(target);
      final goalsBefore = service.getTodayNutrition();

      await FitnessProvider.instance.addFoodToMeal(
        'Lunch',
        _chicken,
        100,
        'grams',
      );

      final daily = service.getDailyNutritionWithLogged();
      expect(daily.targets.calories, 2100);
      expect(daily.targets.proteinGrams, 140);
      expect(daily.targets.carbsGrams, 220);
      expect(daily.targets.fatGrams, 60);
      final goalsAfter = service.getTodayNutrition();
      expect(goalsAfter.calorieGoal, goalsBefore.calorieGoal);
      expect(goalsAfter.proteinGoal, goalsBefore.proteinGoal);
    });
  });

  group('local calendar days', () {
    test('each day keeps its own total', () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final yesterdayLog = NutritionLog(
        id: 'log_${_dayString(yesterday)}',
        date: DateTime(yesterday.year, yesterday.month, yesterday.day, 12),
        meals: [
          MealEntry(
            id: 'meal_lunch',
            mealType: MealCategory.lunch,
            consumedFoods: [
              ConsumedFood(food: _rice, quantity: 200, unit: 'grams'),
            ],
          ),
        ],
      );
      await LocalStorage.saveNutritionLog(yesterdayLog);
      await FitnessProvider.instance.addFoodToMeal(
        'Lunch',
        _chicken,
        100,
        'grams',
      );

      expect(
        service.getConsumedTotals(_dayString(yesterday)).calories,
        closeTo(260, 0.001),
      );
      expect(service.getConsumedTotals().calories, closeTo(200, 0.001));
      expect(
        service.getConsumedTotals(_dayString(today)).calories,
        closeTo(200, 0.001),
      );
      // A day with nothing logged is empty, not filled in.
      final empty = _dayString(today.subtract(const Duration(days: 5)));
      expect(service.getConsumedTotals(empty).calories, 0);
      expect(service.getNutritionLog(empty).meals, isEmpty);
    });
  });

  group('nutrition dashboard card', () {
    testWidgets('shows the same protein the provider reports', (tester) async {
      final provider = FitnessProvider.instance;
      await tester.runAsync(
        () => provider.addFoodToMeal('Lunch', _chicken, 100, 'grams'),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: NutritionHeroCard()),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));

      final shown = provider.proteinConsumed.toStringAsFixed(0);
      expect(shown, '40');
      expect(find.textContaining('${shown}g /'), findsOneWidget);
    });
  });
}
