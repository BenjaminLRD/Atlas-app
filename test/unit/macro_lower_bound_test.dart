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

/// Protein known (10 g), carbs and fat unknown, calories known.
const _noMacros = FoodItem(
  id: 'a',
  name: 'Bare Bar',
  calories: 100,
  protein: 10,
  isPackaged: true,
  barcode: '1',
  unknownNutrients: {FoodItem.carbohydrateKey, FoodItem.fatKey},
);

/// Protein unknown, everything else known.
const _noProtein = FoodItem(
  id: 'b',
  name: 'Plain Rice',
  calories: 130,
  carbohydrates: 28,
  fats: 2,
  isPackaged: true,
  barcode: '2',
  unknownNutrients: {FoodItem.proteinKey},
);

/// Every macro known (protein 4 g).
const _full = FoodItem(
  id: 'c',
  name: 'Granola Bar',
  calories: 190,
  protein: 4,
  carbohydrates: 29,
  fats: 7,
  isPackaged: true,
  barcode: '3',
);

MealEntry _meal(List<FoodItem> foods, {bool completed = false}) => MealEntry(
  id: 'm',
  mealType: MealCategory.lunch,
  completed: completed,
  consumedFoods: [for (final f in foods) ConsumedFood(food: f)],
);

NutritionLog _log(List<FoodItem> foods) => NutritionLog(
  id: 'l',
  date: DateTime(2026, 10, 24),
  meals: [_meal(foods)],
  calorieGoal: 2800,
  proteinGoal: 160,
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
        createdAt: DateTime(2026, 10, 24),
        updatedAt: DateTime(2026, 10, 24),
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

  group('totals know which macros are incomplete', () {
    test('each macro counts its own unknown items', () {
      final t = NutritionTotals.fromMeals([
        _meal([_full, _noMacros, _noProtein]),
      ]);
      expect(t.unknownProteinItems, 1);
      expect(t.unknownCarbItems, 1);
      expect(t.unknownFatItems, 1);
      expect(t.unknownCalorieItems, 0);
      expect(t.itemCount, 3);
      // Known contributions only: 4 + 10 + 0.
      expect(t.protein, 14);
      expect(t.carbs, 57);
    });

    test('a lower bound is shown with a plus', () {
      final t = NutritionTotals.fromMeals([
        _meal([_full, _noMacros]),
      ]);
      expect(t.proteinLabel, '14');
      expect(t.carbsLabel, '29+');
      expect(t.fatLabel, '7+');
      expect(t.carbsText, '29+g');
      expect(t.proteinText, '14g');
    });

    test('a protein total with an unknown item reads 14+', () {
      final t = NutritionTotals.fromMeals([
        _meal([_full, _noProtein, _noMacros]),
      ]);
      expect(t.proteinLabel, '14+');
      expect(t.proteinText, '14+g');
    });

    test('nothing known at all is a dash, not 0+', () {
      final t = NutritionTotals.fromMeals([
        _meal([_noProtein]),
      ]);
      expect(t.proteinLabel, '—');
      expect(t.proteinText, '—');
    });

    test('a day with no food is 0, not unknown', () {
      expect(NutritionTotals.empty.proteinLabel, '0');
      expect(NutritionTotals.fromMeals(const []).carbsText, '0g');
    });

    test('a day where everything is known reads exactly', () {
      final t = NutritionTotals.fromMeals([
        _meal([_full]),
      ]);
      expect(t.proteinLabel, '4');
      expect(t.carbsLabel, '29');
      expect(t.fatLabel, '7');
    });

    test('calories use the same rule', () {
      const noCal = FoodItem(
        id: 'n',
        name: 'N',
        calories: 0,
        unknownNutrients: {FoodItem.calorieKey},
      );
      expect(
        NutritionTotals.fromMeals([
          _meal([noCal]),
        ]).caloriesLabel,
        '—',
      );
      expect(
        NutritionTotals.fromMeals([
          _meal([noCal, _full]),
        ]).caloriesLabel,
        '190+',
      );
    });

    test('adding totals adds the counts', () {
      final a = NutritionTotals.fromMeals([
        _meal([_noMacros]),
      ]);
      final b = NutritionTotals.fromMeals([
        _meal([_noMacros, _full]),
      ]);
      final sum = a + b;
      expect(sum.unknownCarbItems, 2);
      expect(sum.itemCount, 3);
      expect(sum.carbsLabel, '29+');
    });
  });

  group('the log and the daily record agree', () {
    test('the nutrition log', () {
      final log = _log([_full, _noMacros]);
      expect(log.dailyProteinLabel, '14');
      expect(log.dailyCarbohydratesLabel, '29+');
      expect(log.dailyFatsLabel, '7+');
      expect(log.unknownCarbItems, 1);
    });

    test('the daily record counts logged and completed items', () {
      final daily = DailyNutrition(
        date: '2026-10-24',
        targets: MacroTarget.defaultTarget(),
        meals: [
          _meal([_noMacros], completed: true),
        ],
      );
      final merged = daily.withLogged(
        NutritionTotals.fromMeals([
          _meal([_full, _noProtein]),
        ]),
      );
      expect(merged.totalsConsumed.unknownCarbItems, 1);
      expect(merged.totalsConsumed.unknownProteinItems, 1);
      expect(merged.totalsConsumed.itemCount, 3);
      expect(merged.totalProteinLabel, '14+');
    });
  });

  group('screens', () {
    testWidgets('the macro cards show lower bounds and dashes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => MacroProgressCard.grid(
                context: context,
                log: _log([_full, _noMacros]),
              ),
            ),
          ),
        ),
      );
      expect(find.text('14g'), findsOneWidget);
      expect(find.text('29+g'), findsOneWidget);
      expect(find.text('7+g'), findsOneWidget);
    });

    testWidgets('a macro with nothing known is a dash on the card', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => MacroProgressCard.grid(
                context: context,
                log: _log([_noProtein]),
              ),
            ),
          ),
        ),
      );
      expect(find.text('—'), findsOneWidget);
      expect(find.text('0g'), findsNothing);
    });

    testWidgets('the hero card marks protein as a lower bound', (tester) async {
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await FitnessProvider.instance.addFoodToMeal('Lunch', _full, 100, 'g');
      await FitnessProvider.instance.addFoodToMeal(
        'Lunch',
        _noProtein,
        100,
        'g',
      );

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: NutritionHeroCard())),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('4+g / '), findsOneWidget);
    });
  });

  group('AI coach context', () {
    const builder = CoachPromptBuilder();

    test('an item with unknown protein is not "0g P"', () {
      final prompt = builder.buildPrompt(
        message: 'How is my nutrition?',
        context: _context([_full, _noProtein]),
      );
      expect(prompt, contains('Plain Rice (130 kcal, protein unknown)'));
      expect(prompt, contains('Granola Bar (190 kcal, 4g P)'));
      expect(prompt, isNot(contains('Plain Rice (130 kcal, 0g P)')));
    });

    test('the protein total is a minimum and the prompt says so', () {
      final prompt = builder.buildPrompt(
        message: 'How is my nutrition?',
        context: _context([_full, _noProtein]),
      );
      expect(prompt, contains('Protein Target: 4+ / 160g'));
      expect(prompt, contains('at most 156g protein needed'));
      expect(prompt, contains('unknown protein'));
      expect(prompt, contains('minimum'));
    });

    test('unknown carbs and fat are named too', () {
      final prompt = builder.buildPrompt(
        message: 'How is my nutrition?',
        context: _context([_full, _noMacros]),
      );
      expect(prompt, contains('unknown carbohydrates'));
      expect(prompt, contains('unknown fat'));
    });

    test('complete macros read exactly as before', () {
      final prompt = builder.buildPrompt(
        message: 'How is my nutrition?',
        context: _context([_full]),
      );
      expect(
        prompt,
        contains('Protein Target: 4 / 160g (156g protein needed)'),
      );
      expect(prompt, isNot(contains('unknown protein')));
    });
  });

  group('direct answer and tools', () {
    const router = AIRequestRouter();

    String answer(List<FoodItem> foods) =>
        router
            .route(
              message: 'How much protein have I eaten today?',
              context: _context(foods),
            )
            .directResponse ??
        '';

    test('the protein answer is marked as a minimum', () {
      final text = answer([_full, _noProtein]);
      expect(text, contains('4+ / 160g protein'));
      expect(text, contains('unknown protein'));
    });

    test('and unchanged when protein is complete', () {
      final text = answer([_full]);
      expect(text, contains('**4 / 160g protein**'));
      expect(text, isNot(contains('unknown protein')));
    });

    test('get_protein_intake flags a lower bound', () async {
      final service = NutritionService();
      await service.addFoodToMeal('Breakfast', _full, 100, 'g');
      await service.addFoodToMeal('Lunch', _noProtein, 100, 'g');

      final result = await NutritionTool(
        nutritionService: service,
      ).execute({'action': 'get_protein_intake'});

      expect(result['consumed_protein_g'], 4);
      expect(result['protein_is_lower_bound'], isTrue);
      expect(result['unknown_protein_items'], 1);
      expect(result['protein_note'], contains('unknown'));
    });

    test('getNutritionStatus flags every incomplete macro', () async {
      final service = NutritionService();
      await service.addFoodToMeal('Breakfast', _full, 100, 'g');
      await service.addFoodToMeal('Lunch', _noMacros, 100, 'g');

      final result = await CoachTools(
        nutritionService: service,
      ).getNutritionStatus();

      final protein = result['protein'] as Map<String, dynamic>;
      expect(protein['is_lower_bound'], isFalse);
      expect(result['carbs_is_lower_bound'], isTrue);
      expect(result['fats_is_lower_bound'], isTrue);
      expect(result['macro_note'], contains('unknown'));
    });
  });
}
