import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/models/food_item.dart';
import 'package:aizawl_gym/models/consumed_food.dart';
import 'package:aizawl_gym/models/meal_entry.dart';
import 'package:aizawl_gym/models/nutrition_log.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/widgets/nutrition/nutrition_hero_card.dart';
import 'package:aizawl_gym/widgets/nutrition/macro_progress_card.dart';
import 'package:aizawl_gym/widgets/nutrition/meal_card.dart';
import 'package:aizawl_gym/screens/diet_plan_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(body: child),
    );
  }

  group('Nutrition Dashboard UI Widgets Tests', () {
    testWidgets('NutritionHeroCard renders without error', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const NutritionHeroCard()));
      await tester.pumpAndSettle();

      expect(find.text("TODAY'S NUTRITION"), findsOneWidget);
      expect(find.text('Target Daily Intake'), findsOneWidget);
      expect(find.text('PROTEIN TARGET'), findsOneWidget);
    });

    testWidgets('MacroProgressCard grid renders 4 macro cards', (tester) async {
      final log = NutritionLog(
        id: 'grid_test',
        date: DateTime(2026, 8, 6),
        calorieGoal: 2400.0,
        proteinGoal: 160.0,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          Builder(
            builder: (ctx) => MacroProgressCard.grid(context: ctx, log: log),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CALORIES'), findsOneWidget);
      expect(find.text('PROTEIN'), findsOneWidget);
      expect(find.text('CARBS'), findsOneWidget);
      expect(find.text('FATS'), findsOneWidget);
    });

    testWidgets('MealCard renders meal details and expands on tap', (tester) async {
      final meal = MealEntry(
        id: 'm_test_1',
        mealType: MealCategory.lunch,
        consumedFoods: const [
          ConsumedFood(
            food: FoodItem(
              id: 'chk',
              name: 'Chicken Breast',
              calories: 165.0,
              protein: 31.0,
              carbohydrates: 0.0,
              fats: 3.6,
            ),
            quantity: 200.0,
          ),
        ],
        completed: false,
      );

      await tester.pumpWidget(buildTestableWidget(MealCard(meal: meal)));
      await tester.pumpAndSettle();

      expect(find.text('Lunch'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);

      // Tap to expand
      await tester.tap(find.text('Lunch'));
      await tester.pumpAndSettle();

      expect(find.text('Chicken Breast'), findsOneWidget);
      expect(find.text('ADD FOOD'), findsOneWidget);
    });

    testWidgets('DietPlanScreen renders Nutrition Dashboard sections', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const DietPlanScreen()));
      await tester.pumpAndSettle();

      expect(find.text('NUTRITION DASHBOARD'), findsOneWidget);
      expect(find.text('MACRONUTRIENTS'), findsOneWidget);
      expect(find.text("TODAY'S MEALS"), findsOneWidget);
      expect(find.text('ADD FOOD'), findsOneWidget);
    });
  });
}
