import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/widgets/nutrition/food_search_sheet.dart';
import 'package:atlas/widgets/nutrition/custom_food_modal.dart';
import 'package:atlas/services/nutrition/nutrition_calculator.dart';
import 'package:atlas/services/food_validation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  Widget buildTestWidget({
    String mealId = 'Breakfast',
    String mealTitle = 'Breakfast',
    Size screenSize = const Size(390, 844),
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: screenSize),
        child: Scaffold(
          body: FoodSearchSheet(mealId: mealId, mealTitle: mealTitle),
        ),
      ),
    );
  }

  group('Phase 3 — FoodSearchSheet & Custom Food Widget Tests', () {
    testWidgets(
      '1 & 2. Search field works and finds foods by name, brand, altNames',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.byType(TextField), findsWidgets);

        // Search for 'Chicken'
        await tester.enterText(find.byType(TextField).first, 'Chicken');
        await tester.pumpAndSettle();

        expect(find.textContaining('Chicken'), findsWidgets);

        // Clear search
        await tester.tap(find.byIcon(Icons.clear_rounded));
        await tester.pumpAndSettle();

        // Search for alt name / brand
        await tester.enterText(find.byType(TextField).first, 'Oats');
        await tester.pumpAndSettle();

        expect(find.textContaining('Oats'), findsWidgets);
      },
    );

    testWidgets('3. Category chips scroll horizontally and filter foods', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);

      // Tap 'Protein' category chip
      await tester.tap(find.text('Protein'));
      await tester.pumpAndSettle();

      // Scroll horizontal category list to find 'Custom'
      final scrollable = find
          .byWidgetPredicate(
            (w) =>
                w is SingleChildScrollView &&
                w.scrollDirection == Axis.horizontal,
          )
          .last;
      await tester.drag(scrollable, const Offset(-300, 0));
      await tester.pumpAndSettle();

      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('Mizo'), findsOneWidget);
    });

    testWidgets('4. Food cards render with title, macros, and badges', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify food card elements exist
      expect(find.byIcon(Icons.favorite_outline_rounded), findsWidgets);
      expect(find.byIcon(Icons.add_circle_rounded), findsWidgets);
      expect(find.textContaining('kcal'), findsWidgets);
    });

    testWidgets('5. Favorite toggle works', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final favIconFinder = find.byIcon(Icons.favorite_outline_rounded).first;
      expect(favIconFinder, findsOneWidget);

      // Tap favorite icon
      await tester.tap(favIconFinder);
      await tester.pumpAndSettle();

      // Icon changes to filled favorite icon
      expect(find.byIcon(Icons.favorite_rounded), findsWidgets);
    });

    testWidgets('6. Add food button opens PortionSelectorSheet', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final addBtnFinder = find.byIcon(Icons.add_circle_rounded).first;
      await tester.tap(addBtnFinder);
      await tester.pumpAndSettle();

      // Portion selector modal pops up
      expect(find.byType(PortionSelectorSheet), findsOneWidget);
      expect(find.text('SERVING SIZE & PORTION'), findsOneWidget);
    });

    testWidgets('7. Portion selector updates nutrition dynamically', (
      tester,
    ) async {
      const food = FoodItem(
        id: 'chicken_breast_1',
        name: 'Chicken Breast',
        calories: 165.0,
        protein: 31.0,
        carbohydrates: 0.0,
        fats: 4.0,
        servingSize: '100g',
        servingUnit: 'g',
      );

      final scaled100 = NutritionCalculator.calculateNutrition(food, 100, 'g');
      expect(scaled100.calories, equals(165.0));

      final scaled250 = NutritionCalculator.calculateNutrition(food, 250, 'g');
      expect(scaled250.calories, equals(412.5));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PortionSelectorSheet(
              food: food,
              currentMealId: 'Breakfast',
              currentMealTitle: 'Breakfast',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('165 kcal'), findsOneWidget);

      // Increase portion with + button
      final plusBtn = find.byIcon(Icons.add_rounded);
      await tester.tap(plusBtn);
      await tester.pumpAndSettle();

      // Calories should increase
      expect(find.text('182 kcal'), findsOneWidget);
    });

    testWidgets('8 & 9. Custom food modal opens and validation works', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => CustomFoodModal.show(ctx),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.byType(CustomFoodModal), findsOneWidget);
      expect(find.text('CREATE CUSTOM FOOD'), findsOneWidget);

      // Tap SAVE FOOD without required fields -> validation fails
      await tester.ensureVisible(find.text('SAVE FOOD'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SAVE FOOD'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter food name'), findsOneWidget);
    });

    testWidgets('10. Custom food appears in search list after creation', (
      tester,
    ) async {
      const customFood = FoodItem(
        id: 'custom_mizo_stew',
        name: 'Mizo Pork Stew',
        category: 'Mizo',
        calories: 320.0,
        protein: 24.0,
        carbohydrates: 5.0,
        fats: 22.0,
        isCustom: true,
      );

      final val = FoodValidationService.validateCustomFood(customFood);
      expect(val.isValid, isTrue);

      await FitnessProvider.instance.addCustomFood(customFood);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Search for newly created food
      await tester.enterText(find.byType(TextField).first, 'Mizo Pork');
      await tester.pumpAndSettle();

      expect(find.text('Mizo Pork Stew'), findsOneWidget);
      expect(find.text('CUSTOM'), findsWidgets);
    });

    testWidgets(
      '11. Responsive design test — ZERO RenderFlex overflow at 320px, 360px, 390px, 412px',
      (tester) async {
        final widths = [320.0, 360.0, 390.0, 412.0];

        for (final w in widths) {
          await tester.pumpWidget(buildTestWidget(screenSize: Size(w, 800)));
          await tester.pumpAndSettle();

          // Verify zero overflow errors
          expect(tester.takeException(), isNull);
          expect(find.byType(FoodSearchSheet), findsOneWidget);
        }
      },
    );
  });
}
