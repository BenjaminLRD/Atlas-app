import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/consumed_food.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/models/meal_entry.dart';
import 'package:atlas/models/nutrition_log.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/providers/showcase_data_provider.dart';
import 'package:atlas/services/ai/weekly_athlete_review_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _food = FoodItem(
  id: 'f1',
  name: 'Meal',
  calories: 600,
  protein: 50,
  carbohydrates: 60,
  fats: 20,
);

String _day(DateTime d) => d.toIso8601String().split('T')[0];

NutritionLog _logFor(DateTime day, {double grams = 100}) => NutritionLog(
  id: 'log_${_day(day)}',
  date: DateTime(day.year, day.month, day.day, 12),
  meals: [
    MealEntry(
      id: 'meal_lunch',
      mealType: MealCategory.lunch,
      consumedFoods: [
        ConsumedFood(food: _food, quantity: grams, unit: 'grams'),
      ],
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  tearDown(() async {
    await LocalStorage.setShowcaseModeEnabled(false);
    await FitnessProvider.instance.onShowcaseModeToggled(false);
  });

  group('nutrition history is built from logged meals', () {
    test('no logged food means no history, not zero-intake days', () {
      expect(LocalStorage.getNutritionHistory(), isEmpty);
    });

    test('only days with logged food appear, with their own totals', () async {
      final today = DateTime.now();
      final twoDaysAgo = today.subtract(const Duration(days: 2));
      await LocalStorage.saveNutritionLog(_logFor(today));
      await LocalStorage.saveNutritionLog(_logFor(twoDaysAgo, grams: 200));

      final history = LocalStorage.getNutritionHistory();
      expect(history.map((d) => d.date), [_day(today), _day(twoDaysAgo)]);
      expect(history[0].totalCaloriesConsumed, closeTo(600, 0.001));
      expect(history[0].totalProteinConsumed, closeTo(50, 0.001));
      expect(history[1].totalCaloriesConsumed, closeTo(1200, 0.001));
      // Targets are whatever is configured, untouched by the totals.
      expect(
        history[0].targets.calories,
        LocalStorage.getMacroTarget().calories,
      );
    });

    test('a log older than the 7-day window is not included', () async {
      await LocalStorage.saveNutritionLog(
        _logFor(DateTime.now().subtract(const Duration(days: 9))),
      );
      expect(LocalStorage.getNutritionHistory(), isEmpty);
    });
  });

  group('weekly reviews read those logged totals', () {
    test('the athlete review averages only the logged days', () async {
      final today = DateTime.now();
      await LocalStorage.saveNutritionLog(_logFor(today));
      await LocalStorage.saveNutritionLog(
        _logFor(today.subtract(const Duration(days: 1)), grams: 200),
      );
      final history = LocalStorage.getNutritionHistory();
      expect(history, hasLength(2));

      final report = WeeklyAthleteReviewService.instance.generateReport(
        userId: 'u',
        nutritionHistory: history,
      );
      // (600 + 1200) / 2, from the two logged days.
      expect(report.averageDailyCalories, 900);
    });

    test('with nothing logged the athlete review reports no intake', () {
      final report = WeeklyAthleteReviewService.instance.generateReport(
        userId: 'u',
        nutritionHistory: LocalStorage.getNutritionHistory(),
      );
      expect(report.averageDailyCalories, 0);
      expect(report.proteinAdherencePercentage, 0);
    });
  });

  group('showcase mode still shows its demo day', () {
    test(
      'provider totals come from the showcase day, not the empty log',
      () async {
        await LocalStorage.setShowcaseModeEnabled(true);
        final provider = FitnessProvider.instance;
        await provider.onShowcaseModeToggled(true);

        final demo = ShowcaseDataProvider.instance.getShowcaseDailyNutrition();
        expect(demo.totalProteinConsumed, greaterThan(0));
        expect(
          provider.proteinConsumed,
          closeTo(demo.totalProteinConsumed, 0.001),
        );
        expect(
          provider.totalCaloriesConsumed,
          closeTo(demo.totalCaloriesConsumed, 0.001),
        );
        // The athlete's own log is untouched and still empty.
        expect(provider.todayNutritionLog.totals.calories, 0);
      },
    );

    test(
      'the demo day is not mixed with the real log in the AI context',
      () async {
        await LocalStorage.saveNutritionLog(_logFor(DateTime.now()));
        await LocalStorage.setShowcaseModeEnabled(true);
        final provider = FitnessProvider.instance;
        await provider.onShowcaseModeToggled(true);

        final demo = ShowcaseDataProvider.instance.getShowcaseDailyNutrition();
        final context = provider.buildFitnessContext();
        expect(
          context.todayNutrition!.totalCaloriesConsumed,
          closeTo(demo.totalCaloriesConsumed, 0.001),
        );
      },
    );

    test('outside showcase mode the same getters read the real log', () async {
      await LocalStorage.saveNutritionLog(_logFor(DateTime.now()));
      final provider = FitnessProvider.instance;
      await provider.onShowcaseModeToggled(false);
      expect(provider.totalCaloriesConsumed, closeTo(600, 0.001));
      expect(provider.proteinConsumed, closeTo(50, 0.001));
    });
  });
}
