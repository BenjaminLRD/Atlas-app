import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/consumed_food.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/models/meal_entry.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/widgets/nutrition/food_search_sheet.dart';
import 'package:atlas/widgets/nutrition/meal_card.dart';
import 'package:atlas/widgets/nutrition/scanned_food_result_card.dart';

/// A product whose calories are unknown but whose protein is known.
const _noCalories = FoodItem(
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

const _known = FoodItem(
  id: 'scanned_2',
  name: 'Granola Bar',
  calories: 190,
  protein: 4,
  carbohydrates: 29,
  fats: 7,
  isPackaged: true,
  barcode: '2',
);

Future<void> _open(
  WidgetTester tester,
  Widget Function(BuildContext) sheet,
) async {
  tester.view.physicalSize = const Size(900, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: sheet,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Iterable<ConsumedFood> _logged() => FitnessProvider
    .instance
    .todayNutritionLog
    .meals
    .expand((m) => m.consumedFoods);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    FitnessProvider.resetInstance();
  });

  group('the model remembers that calories are unknown', () {
    test('an entry keeps the flag and its known macros', () {
      final entry = ConsumedFood(food: _noCalories, quantity: 200, unit: 'g');
      expect(entry.caloriesKnown, isFalse);
      expect(entry.protein, 20);
      expect(entry.carbohydrates, 10);
    });

    test('the flag survives saving and loading', () {
      final entry = ConsumedFood(food: _noCalories, quantity: 100, unit: 'g');
      final back = ConsumedFood.fromJson(entry.toJson());
      expect(back.caloriesKnown, isFalse);
      expect(back.protein, 10);
    });

    test('a meal counts its items without calories', () {
      final meal = MealEntry(
        id: 'm',
        mealType: MealCategory.lunch,
        consumedFoods: [
          ConsumedFood(food: _noCalories),
          ConsumedFood(food: _known),
          ConsumedFood(food: _noCalories, quantity: 50),
        ],
      );
      expect(meal.unknownCalorieCount, 2);
      expect(
        MealEntry(
          id: 'n',
          consumedFoods: [ConsumedFood(food: _known)],
        ).unknownCalorieCount,
        0,
      );
    });
  });

  group('portion sheet', () {
    Future<void> sheet(WidgetTester tester, FoodItem food) => _open(
      tester,
      (_) => PortionSelectorSheet(
        food: food,
        currentMealId: 'Lunch',
        currentMealTitle: 'Lunch',
      ),
    );

    testWidgets('a food with calories logs at once, with no question', (
      tester,
    ) async {
      await sheet(tester, _known);
      await tester.tap(find.textContaining('ADD TO'));
      await tester.pumpAndSettle();

      expect(find.text('Calories unknown'), findsNothing);
      expect(_logged().single.food.id, 'scanned_2');
    });

    testWidgets('unknown calories ask first, and Cancel logs nothing', (
      tester,
    ) async {
      await sheet(tester, _noCalories);
      await tester.tap(find.textContaining('ADD TO'));
      await tester.pumpAndSettle();

      expect(find.text('Calories unknown'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(_logged(), isEmpty);
    });

    testWidgets('"Log anyway" logs it, flagged, with its known macros', (
      tester,
    ) async {
      await sheet(tester, _noCalories);
      await tester.tap(find.textContaining('ADD TO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log anyway'));
      await tester.pumpAndSettle();

      final entry = _logged().single;
      expect(entry.caloriesKnown, isFalse);
      expect(entry.protein, 10);
      expect(FitnessProvider.instance.todayNutritionLog.dailyProtein, 10);
    });
  });

  group('barcode sheet', () {
    Future<void> sheet(WidgetTester tester, FoodItem food) =>
        _open(tester, (_) => ScannedFoodResultCard(food: food));

    testWidgets('manual entry stays the main action', (tester) async {
      await sheet(tester, _noCalories);
      expect(find.byKey(const Key('scanned_enter_nutrition')), findsOneWidget);
      expect(find.textContaining('ADD TO'), findsNothing);
      expect(
        find.byKey(const Key('scanned_log_without_calories')),
        findsOneWidget,
      );
    });

    testWidgets('logging without calories needs confirmation', (tester) async {
      await sheet(tester, _noCalories);
      await tester.tap(find.byKey(const Key('scanned_log_without_calories')));
      await tester.pumpAndSettle();

      expect(find.text('Calories unknown'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(_logged(), isEmpty);

      await tester.tap(find.byKey(const Key('scanned_log_without_calories')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log anyway'));
      await tester.pumpAndSettle();

      final entry = _logged().single;
      expect(entry.caloriesKnown, isFalse);
      expect(entry.protein, 10);
    });

    testWidgets('a food with calories has no such option', (tester) async {
      await sheet(tester, _known);
      expect(
        find.byKey(const Key('scanned_log_without_calories')),
        findsNothing,
      );
    });
  });

  group('meal card', () {
    Future<void> card(WidgetTester tester, List<ConsumedFood> foods) async {
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final meal = MealEntry(
        id: 'm1',
        mealType: MealCategory.lunch,
        consumedFoods: foods,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MealCard(meal: meal)),
        ),
      );
      await tester.tap(find.text('Lunch'));
      await tester.pumpAndSettle();
    }

    testWidgets('an item without calories shows a dash, not 0 kcal', (
      tester,
    ) async {
      await card(tester, [ConsumedFood(food: _noCalories)]);

      expect(find.textContaining('10g protein • — kcal'), findsOneWidget);
      expect(find.textContaining('0 kcal'), findsNothing);
    });

    testWidgets('the meal total is marked as a minimum', (tester) async {
      await card(tester, [
        ConsumedFood(food: _known),
        ConsumedFood(food: _noCalories),
      ]);

      expect(find.textContaining('190+ kcal'), findsOneWidget);
    });

    testWidgets('a meal where every item has calories is unchanged', (
      tester,
    ) async {
      await card(tester, [ConsumedFood(food: _known)]);

      expect(find.textContaining('190 kcal •'), findsWidgets);
      expect(find.textContaining('190+'), findsNothing);
    });
  });
}
