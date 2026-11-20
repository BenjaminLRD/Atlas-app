import 'dart:convert';

import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/consumed_food.dart';
import 'package:atlas/models/daily_nutrition.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/models/health_metric.dart';
import 'package:atlas/models/meal_entry.dart';
import 'package:atlas/models/nutrition_log.dart';
import 'package:atlas/models/recovery_summary.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/ai/weekly_athlete_review_service.dart';
import 'package:atlas/services/ai/weekly_coach_review_service.dart';
import 'package:atlas/services/nutrition/nutrition_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _day(DateTime d) => d.toIso8601String().split('T')[0];
DateTime _daysAgo(int n) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - n);
}

FoodItem _food(double kcal, double protein) => FoodItem(
  id: 'f_${kcal}_$protein',
  name: 'Food',
  calories: kcal,
  protein: protein,
  carbohydrates: 0,
  fats: 0,
);

MealEntry _meal(String id, MealCategory type, FoodItem food) => MealEntry(
  id: id,
  mealType: type,
  consumedFoods: [ConsumedFood(food: food, quantity: 100, unit: 'grams')],
);

NutritionLog _log(DateTime at, List<MealEntry> meals) =>
    NutritionLog(id: 'log_${_day(at)}', date: at, meals: meals);

/// A day as stored before the marker existed.
Map<String, dynamic> _legacyJson({
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('the marker is written by every save path', () {
    test('LocalStorage saves, default and per-user', () async {
      final prefs = await SharedPreferences.getInstance();
      final day = DailyNutrition.defaultForDate('2026-10-15');
      await LocalStorage.saveDailyNutrition(day);
      await LocalStorage.saveDailyNutrition(day, userId: 'u1');

      for (final key in [
        'nutrition_daily_2026-10-15',
        'nutrition_daily_u1_2026-10-15',
      ]) {
        final json = jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
        expect(json[DailyNutrition.baseAmountsVersionKey], 2, reason: key);
      }
    });

    test('the repository paths (log a food, toggle a meal) keep it', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = NutritionService();
      final today = _day(DateTime.now());
      await service.logFoodItem(
        category: MealCategory.breakfast,
        foodItem: _food(100, 5),
      );
      var json =
          jsonDecode(prefs.getString('nutrition_daily_$today')!)
              as Map<String, dynamic>;
      expect(json[DailyNutrition.baseAmountsVersionKey], 2);

      final mealId = service.getDailyNutrition().meals.first.id;
      await service.toggleMealCompletion(mealId: mealId);
      json =
          jsonDecode(prefs.getString('nutrition_daily_$today')!)
              as Map<String, dynamic>;
      expect(json[DailyNutrition.baseAmountsVersionKey], 2);
    });

    test(
      'a legacy record gets the marker the first time it is saved',
      () async {
        final prefs = await SharedPreferences.getInstance();
        const key = 'nutrition_daily_2026-10-15';
        await prefs.setString(key, jsonEncode(_legacyJson()));

        await LocalStorage.saveDailyNutrition(
          LocalStorage.getDailyNutrition('2026-10-15'),
        );
        final json = jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
        expect(json[DailyNutrition.baseAmountsVersionKey], 2);
        expect(json['baseCalories'], 0);
      },
    );
  });

  group('legacy records are normalised without being rewritten', () {
    test('reading never changes what is stored, and is repeatable', () async {
      final prefs = await SharedPreferences.getInstance();
      const key = 'nutrition_daily_2026-10-15';
      final raw = jsonEncode(_legacyJson());
      await prefs.setString(key, raw);

      final first = LocalStorage.getDailyNutrition('2026-10-15');
      final second = LocalStorage.getDailyNutrition('2026-10-15');
      expect(prefs.getString(key), raw);
      expect(first.totalCaloriesConsumed, 0);
      expect(second.totalCaloriesConsumed, 0);
    });

    test('a record that already has the marker is not zeroed again', () async {
      final prefs = await SharedPreferences.getInstance();
      const key = 'nutrition_daily_2026-10-15';
      final json = _legacyJson()..[DailyNutrition.baseAmountsVersionKey] = 2;
      await prefs.setString(key, jsonEncode(json));
      expect(
        LocalStorage.getDailyNutrition('2026-10-15').totalCaloriesConsumed,
        300,
      );
    });
  });

  group('weekly history covers the last seven local days', () {
    test('day 6 back is included, day 7 back is not', () async {
      await LocalStorage.saveNutritionLog(
        _log(_daysAgo(6).add(const Duration(hours: 12)), [
          _meal('m1', MealCategory.lunch, _food(500, 30)),
        ]),
      );
      await LocalStorage.saveNutritionLog(
        _log(_daysAgo(7).add(const Duration(hours: 12)), [
          _meal('m2', MealCategory.lunch, _food(900, 90)),
        ]),
      );
      final history = LocalStorage.getNutritionHistory();
      expect(history.map((d) => d.date), [_day(_daysAgo(6))]);
    });

    test(
      'logs just before and just after midnight land on their own day',
      () async {
        final yesterdayLate = _daysAgo(
          1,
        ).add(const Duration(hours: 23, minutes: 59, seconds: 59));
        final todayEarly = _daysAgo(0);
        await LocalStorage.saveNutritionLog(
          _log(yesterdayLate, [
            _meal('a', MealCategory.dinner, _food(700, 40)),
          ]),
        );
        await LocalStorage.saveNutritionLog(
          _log(todayEarly, [
            _meal('b', MealCategory.breakfast, _food(300, 20)),
          ]),
        );

        final history = LocalStorage.getNutritionHistory();
        expect(history.map((d) => d.date), [
          _day(_daysAgo(0)),
          _day(_daysAgo(1)),
        ]);
        expect(history[0].totalCaloriesConsumed, 300);
        expect(history[1].totalCaloriesConsumed, 700);
      },
    );

    test('several meals on one day add up, with no invented amounts', () async {
      await LocalStorage.saveNutritionLog(
        _log(_daysAgo(2).add(const Duration(hours: 9)), [
          _meal('b', MealCategory.breakfast, _food(300, 20)),
          _meal('l', MealCategory.lunch, _food(600, 45)),
          _meal('d', MealCategory.dinner, _food(800, 55)),
        ]),
      );
      final history = LocalStorage.getNutritionHistory();
      expect(history, hasLength(1));
      expect(history.single.totalCaloriesConsumed, 1700);
      expect(history.single.totalProteinConsumed, 120);
      expect(history.single.totalCarbsConsumed, 0);
      expect(history.single.totalFatConsumed, 0);
    });

    test('a day with empty meals is left out', () async {
      await LocalStorage.saveNutritionLog(
        _log(_daysAgo(1), [MealEntry(id: 'e', mealType: MealCategory.lunch)]),
      );
      expect(LocalStorage.getNutritionHistory(), isEmpty);
    });
  });

  group('effect of leaving unlogged days out of the weekly reviews', () {
    // 200 g protein on a day clears the default 160 g target.
    List<MealEntry> hit() => [_meal('h', MealCategory.lunch, _food(2400, 200))];
    List<MealEntry> miss() => [_meal('m', MealCategory.lunch, _food(1000, 50))];

    Future<void> logDays(Map<int, List<MealEntry>> byAge) async {
      for (final e in byAge.entries) {
        await LocalStorage.saveNutritionLog(
          _log(_daysAgo(e.key).add(const Duration(hours: 12)), e.value),
        );
      }
    }

    test('one logged day: figures describe that day only', () async {
      await logDays({0: hit()});
      final report = WeeklyAthleteReviewService.instance.generateReport(
        userId: 'u',
        nutritionHistory: LocalStorage.getNutritionHistory(),
      );
      expect(report.averageDailyCalories, 2400);
      // 1 of 1 logged day hit: 100%, from a single day of data.
      expect(report.proteinAdherencePercentage, 100);
    });

    test('two logged days average only those days', () async {
      await logDays({0: hit(), 1: miss()});
      final report = WeeklyAthleteReviewService.instance.generateReport(
        userId: 'u',
        nutritionHistory: LocalStorage.getNutritionHistory(),
      );
      expect(report.averageDailyCalories, 1700);
      expect(report.proteinAdherencePercentage, 50);
    });

    test(
      'with nothing logged the athlete review reports zero, not defaults',
      () {
        final report = WeeklyAthleteReviewService.instance.generateReport(
          userId: 'u',
          nutritionHistory: LocalStorage.getNutritionHistory(),
        );
        expect(report.averageDailyCalories, 0);
        expect(report.proteinAdherencePercentage, 0);
      },
    );

    test(
      'the coach review uses the same history and invents nothing',
      () async {
        final empty = WeeklyCoachReviewService.instance.generateReview(
          workoutHistory: const [],
          nutritionHistory: LocalStorage.getNutritionHistory(),
          healthMetrics: const <HealthMetric>[],
          currentRecovery: const RecoverySummary(),
        );
        expect(empty.averageDailyCalories, 0);
        expect(empty.proteinConsistencyPercentage, 0);

        await logDays({0: hit(), 1: miss()});
        final two = WeeklyCoachReviewService.instance.generateReview(
          workoutHistory: const [],
          nutritionHistory: LocalStorage.getNutritionHistory(),
          healthMetrics: const <HealthMetric>[],
          currentRecovery: const RecoverySummary(),
        );
        expect(two.averageDailyCalories, 1700);
        expect(two.proteinConsistencyPercentage, 50);
      },
    );
  });

  group('showcase mode does not mix in the real log', () {
    tearDown(() async {
      await LocalStorage.setShowcaseModeEnabled(false);
      await FitnessProvider.instance.onShowcaseModeToggled(false);
    });

    test('the AI context log is the demo day', () async {
      await LocalStorage.saveNutritionLog(
        _log(DateTime.now(), [_meal('r', MealCategory.lunch, _food(123, 7))]),
      );
      await LocalStorage.setShowcaseModeEnabled(true);
      final provider = FitnessProvider.instance;
      await provider.onShowcaseModeToggled(true);

      final context = provider.buildFitnessContext();
      final demo = context.todayNutrition!;
      expect(context.todayNutritionLog!.id, 'showcase_day');
      expect(
        context.todayNutritionLog!.dailyCalories,
        closeTo(demo.totalCaloriesConsumed, 0.001),
      );
      expect(context.todayNutritionLog!.dailyCalories, isNot(123));
    });

    test('the weekly coach review uses the demo day only', () async {
      await LocalStorage.saveNutritionLog(
        _log(DateTime.now(), [_meal('r', MealCategory.lunch, _food(123, 7))]),
      );
      await LocalStorage.setShowcaseModeEnabled(true);
      final provider = FitnessProvider.instance;
      await provider.onShowcaseModeToggled(true);

      final review = provider.generateWeeklyCoachReview();
      expect(
        review.averageDailyCalories,
        closeTo(provider.todayNutrition.totalCaloriesConsumed, 1),
      );
    });

    test('leaving showcase mode returns to the real log', () async {
      await LocalStorage.saveNutritionLog(
        _log(DateTime.now(), [_meal('r', MealCategory.lunch, _food(123, 7))]),
      );
      await FitnessProvider.instance.onShowcaseModeToggled(false);
      final context = FitnessProvider.instance.buildFitnessContext();
      expect(context.todayNutritionLog!.dailyCalories, closeTo(123, 0.001));
    });
  });
}
