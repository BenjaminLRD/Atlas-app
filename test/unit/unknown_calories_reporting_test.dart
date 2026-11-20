import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/consumed_food.dart';
import 'package:atlas/models/daily_nutrition.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/models/macro_target.dart';
import 'package:atlas/models/meal_entry.dart';
import 'package:atlas/models/nutrition_log.dart';
import 'package:atlas/models/nutrition_totals.dart';
import 'package:atlas/models/weight_goal.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/ai/ai_request_router.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';
import 'package:atlas/services/ai/tools/coach_tools.dart';
import 'package:atlas/services/ai/tools/nutrition_tool.dart';
import 'package:atlas/services/nutrition/nutrition_service.dart';
import 'package:atlas/widgets/nutrition/macro_progress_card.dart';
import 'package:atlas/widgets/nutrition/nutrition_hero_card.dart';

const _pudding = FoodItem(
  id: 'scanned_1',
  name: 'Protein Pudding',
  calories: 0,
  protein: 10,
  carbohydrates: 5,
  fats: 2,
  isPackaged: true,
  barcode: '1',
  unknownNutrients: {FoodItem.calorieKey},
);

const _bar = FoodItem(
  id: 'scanned_2',
  name: 'Granola Bar',
  calories: 190,
  protein: 4,
  carbohydrates: 29,
  fats: 7,
  isPackaged: true,
  barcode: '2',
);

MealEntry _meal(List<FoodItem> foods, {bool completed = false}) => MealEntry(
  id: 'm',
  mealType: MealCategory.lunch,
  completed: completed,
  consumedFoods: [for (final f in foods) ConsumedFood(food: f)],
);

NutritionLog _log(List<FoodItem> foods) => NutritionLog(
  id: 'l',
  date: DateTime(2026, 10, 23),
  meals: [_meal(foods)],
  calorieGoal: 2800,
);

FitnessContext _context(List<FoodItem> foods) =>
    FitnessContext.initial().copyWith(
      todayNutritionLog: _log(foods),
      weightGoal: WeightGoal(
        id: 'wg',
        userId: 'u',
        type: WeightGoalType.gain,
        currentWeight: 70,
        targetWeight: 75,
        targetWeeks: 12,
        dailyCalorieTarget: 2800,
        proteinGrams: 160,
        carbsGrams: 350,
        fatGrams: 75,
        expectedWeeklyRateKg: 0.4,
        diet: DietPreference.nonVegetarian,
        mealsPerDay: MealFrequency.fourMeals,
        createdAt: DateTime(2026, 10, 23),
        updatedAt: DateTime(2026, 10, 23),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    FitnessProvider.resetInstance();
    AppDependencies.useMock();
  });

  group('totals', () {
    test('count the items without calories and keep known macros', () {
      final totals = NutritionTotals.fromMeals([
        _meal([_bar, _pudding]),
      ]);
      expect(totals.calories, 190);
      expect(totals.unknownCalorieItems, 1);
      expect(totals.caloriesAreLowerBound, isTrue);
      expect(totals.protein, 14);
      expect(totals.carbs, 34);
      expect(totals.caloriesLabel, '190+');
    });

    test('a day where every item has calories is exact', () {
      final totals = NutritionTotals.fromMeals([
        _meal([_bar]),
      ]);
      expect(totals.unknownCalorieItems, 0);
      expect(totals.caloriesLabel, '190');
    });

    test('nothing logged is 0 with no plus', () {
      expect(NutritionTotals.empty.caloriesLabel, '0');
      expect(NutritionTotals.fromMeals(const []).caloriesLabel, '0');
    });

    test('adding totals adds the unknown counts', () {
      final a = NutritionTotals.fromMeals([
        _meal([_pudding]),
      ]);
      final b = NutritionTotals.fromMeals([
        _meal([_pudding, _bar]),
      ]);
      expect((a + b).unknownCalorieItems, 2);
      expect((a + b).caloriesLabel, '190+');
    });

    test('the nutrition log exposes the same facts', () {
      final log = _log([_bar, _pudding]);
      expect(log.unknownCalorieItems, 1);
      expect(log.dailyCaloriesLabel, '190+');
      expect(_log([_bar]).dailyCaloriesLabel, '190');
    });

    test('the daily record counts logged and completed items', () {
      final daily = DailyNutrition(
        date: '2026-10-23',
        targets: MacroTarget.defaultTarget(),
        meals: [
          _meal([_pudding], completed: true),
        ],
      );
      final withLogged = daily.withLogged(
        NutritionTotals.fromMeals([
          _meal([_pudding, _bar]),
        ]),
      );
      expect(withLogged.totalsConsumed.unknownCalorieItems, 2);
      expect(withLogged.totalCaloriesLabel, '190+');
      expect(withLogged.totalProteinConsumed, 24);
    });

    test('old saved entries still load: scaling version and flag kept', () {
      final oldEntry = ConsumedFood.fromJson({
        'food': _pudding.toJson(),
        'quantity': 1,
        'unit': 'kg',
      });
      expect(oldEntry.scalingVersion, 1);
      expect(oldEntry.caloriesKnown, isFalse);
      expect(oldEntry.protein, 10);

      final known = ConsumedFood.fromJson({
        'food': _bar.toJson(),
        'quantity': 1,
        'unit': 'kg',
      });
      expect(known.calories, 190);
      expect(
        NutritionTotals.fromMeals([
          MealEntry(id: 'o', consumedFoods: [oldEntry, known]),
        ]).caloriesLabel,
        '190+',
      );
    });
  });

  group('AI coach prompt', () {
    const builder = CoachPromptBuilder();

    test('says the item\'s calories are unknown, never 0 kcal', () {
      final prompt = builder.buildPrompt(
        message: 'How is my nutrition?',
        context: _context([_bar, _pudding]),
      );

      expect(prompt, contains('Protein Pudding (calories unknown, 10g P)'));
      expect(prompt, contains('Granola Bar (190 kcal, 4g P)'));
      expect(prompt, isNot(contains('Protein Pudding (0 kcal')));
    });

    test('the daily total is a minimum and the prompt says so', () {
      final prompt = builder.buildPrompt(
        message: 'How is my nutrition?',
        context: _context([_bar, _pudding]),
      );

      expect(prompt, contains("Today's Calories: 190+ / 2800 kcal"));
      expect(prompt, contains('at most 2610 kcal remaining'));
      expect(prompt, contains('unknown calories'));
      expect(prompt, contains('minimum'));
      expect(prompt, contains('not 0 kcal'));
    });

    test('a day with known calories reads exactly as before', () {
      final prompt = builder.buildPrompt(
        message: 'How is my nutrition?',
        context: _context([_bar]),
      );

      expect(
        prompt,
        contains("Today's Calories: 190 / 2800 kcal (2610 kcal remaining)"),
      );
      expect(prompt, isNot(contains('unknown calories')));
      expect(prompt, isNot(contains('190+')));
    });
  });

  group('direct nutrition answer', () {
    const router = AIRequestRouter();

    String answer(List<FoodItem> foods) =>
        router
            .route(
              message: 'How much protein have I eaten today?',
              context: _context(foods),
            )
            .directResponse ??
        '';

    test('marks the calories as a minimum', () {
      final text = answer([_bar, _pudding]);
      expect(text, contains('190+ / 2800 kcal'));
      expect(text, contains('unknown calories'));
    });

    test('is unchanged when all calories are known', () {
      final text = answer([_bar]);
      expect(text, contains('**190 / 2800 kcal**'));
      expect(text, isNot(contains('unknown calories')));
    });
  });

  group('AI tools', () {
    late NutritionService service;

    setUp(() async {
      service = NutritionService();
      await service.addFoodToMeal('Breakfast', _bar, 100, 'g');
    });

    test('get_today_calories flags a lower bound', () async {
      await service.addFoodToMeal('Lunch', _pudding, 100, 'g');
      final result = await NutritionTool(
        nutritionService: service,
      ).execute({'action': 'get_today_calories'});

      expect(result['consumed_calories'], 190);
      expect(result['calories_are_lower_bound'], isTrue);
      expect(result['unknown_calorie_items'], 1);
      expect(result['calorie_note'], contains('unknown'));
      expect(result['calorie_note'], contains('not 0'));
    });

    test('get_today_calories is exact when everything is known', () async {
      final result = await NutritionTool(
        nutritionService: service,
      ).execute({'action': 'get_today_calories'});

      expect(result['calories_are_lower_bound'], isFalse);
      expect(result['unknown_calorie_items'], 0);
      expect(result.containsKey('calorie_note'), isFalse);
    });

    test('getNutritionStatus flags a lower bound', () async {
      await service.addFoodToMeal('Lunch', _pudding, 100, 'g');
      final result = await CoachTools(
        nutritionService: service,
      ).getNutritionStatus();

      final calories = result['calories'] as Map<String, dynamic>;
      expect(calories['consumed'], 190);
      expect(calories['is_lower_bound'], isTrue);
      expect(calories['unknown_calorie_items'], 1);
      expect(calories['note'], contains('unknown'));
      expect(result['protein']['consumed_g'], 14);
    });
  });

  group('screens', () {
    testWidgets('the calorie card shows a lower bound with a plus', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => MacroProgressCard.grid(
                context: context,
                log: _log([_bar, _pudding]),
              ),
            ),
          ),
        ),
      );

      expect(find.text('190+ kcal'), findsOneWidget);
    });

    testWidgets('the calorie card is unchanged when all calories are known', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) =>
                  MacroProgressCard.grid(context: context, log: _log([_bar])),
            ),
          ),
        ),
      );

      expect(find.text('190 kcal'), findsOneWidget);
    });

    testWidgets('the hero card marks the total and the remainder', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await FitnessProvider.instance.addFoodToMeal('Breakfast', _bar, 100, 'g');
      await FitnessProvider.instance.addFoodToMeal('Lunch', _pudding, 100, 'g');

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: NutritionHeroCard())),
      );
      await tester.pumpAndSettle();

      expect(find.text('190+'), findsOneWidget);
      expect(find.textContaining('at most'), findsOneWidget);
      expect(find.textContaining('kcal left'), findsOneWidget);
    });
  });
}
