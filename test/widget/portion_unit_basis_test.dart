import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/widgets/nutrition/food_search_sheet.dart';
import 'package:atlas/widgets/nutrition/scanned_food_result_card.dart';

FoodItem _food(
  NutritionBasis basis, {
  String unit = 'grams',
  Set<String> unknown = const {},
  bool packaged = false,
}) => FoodItem(
  id: 'f_${basis.name}_$unit',
  name: 'Thing',
  servingUnit: unit,
  servingSize: '100',
  calories: 46,
  protein: 0.5,
  carbohydrates: 11.5,
  fats: 0.2,
  isPackaged: packaged,
  barcode: packaged ? '1' : null,
  unknownNutrients: unknown,
  nutritionBasis: basis,
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

Future<void> _portion(WidgetTester tester, FoodItem food) => _open(
  tester,
  (_) => PortionSelectorSheet(
    food: food,
    currentMealId: 'Lunch',
    currentMealTitle: 'Lunch',
  ),
);

/// Opens the unit menu and reports the units it offers.
Future<Set<String>> _units(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButton<String>));
  await tester.pumpAndSettle();
  final items = tester.widgetList<DropdownMenuItem<String>>(
    find.byType(DropdownMenuItem<String>),
  );
  return items.map((i) => i.value!).toSet();
}

String _selectedUnit(WidgetTester tester) => tester
    .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
    .value!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    FitnessProvider.resetInstance();
  });

  group('portion sheet units follow the nutrition basis', () {
    testWidgets('per 100 ml offers only volume and per-piece units', (
      tester,
    ) async {
      await _portion(tester, _food(NutritionBasis.per100ml, unit: 'ml'));

      expect(_selectedUnit(tester), 'ml');
      final units = await _units(tester);
      expect(units, containsAll(['ml', 'L']));
      expect(units, isNot(contains('g')));
      expect(units, isNot(contains('kg')));
    });

    testWidgets('a drink labelled "grams" starts in ml, not g', (tester) async {
      // What the OFF parser produces: basis ml, unit label still "grams".
      await _portion(tester, _food(NutritionBasis.per100ml, packaged: true));

      expect(_selectedUnit(tester), 'ml');
    });

    testWidgets('per 100 g offers weight units and no volume units', (
      tester,
    ) async {
      await _portion(tester, _food(NutritionBasis.per100g));

      expect(_selectedUnit(tester), 'g');
      final units = await _units(tester);
      expect(units, containsAll(['g', 'kg']));
      expect(units, isNot(contains('ml')));
      expect(units, isNot(contains('L')));
    });

    testWidgets('unknown basis still offers every unit', (tester) async {
      await _portion(
        tester,
        _food(NutritionBasis.unknown, unit: 'piece').copyWith(isCustom: true),
      );

      final units = await _units(tester);
      expect(units, containsAll(['g', 'kg', 'ml', 'L', 'piece', 'cup']));
    });
  });

  group('portion sheet never shows unknown nutrition as zero', () {
    testWidgets('unknown nutrients are dashes', (tester) async {
      await _portion(
        tester,
        _food(
          NutritionBasis.unknown,
          packaged: true,
          unknown: {FoodItem.carbohydrateKey, FoodItem.fatKey},
        ),
      );

      expect(find.text('0.5g'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2));
      expect(find.text('0.0g'), findsNothing);
    });

    testWidgets('unknown calories are a dash, not 0 kcal', (tester) async {
      await _portion(
        tester,
        _food(
          NutritionBasis.unknown,
          packaged: true,
          unknown: {FoodItem.calorieKey},
        ),
      );

      expect(find.text('— kcal'), findsOneWidget);
      expect(find.text('0 kcal'), findsNothing);
    });

    testWidgets('known values are shown as before', (tester) async {
      await _portion(tester, _food(NutritionBasis.per100g));

      expect(find.text('46 kcal'), findsOneWidget);
      expect(find.text('11.5g'), findsOneWidget);
    });
  });

  group('scanned product sheet', () {
    Future<void> sheet(WidgetTester tester, FoodItem food) =>
        _open(tester, (_) => ScannedFoodResultCard(food: food));

    testWidgets('a per-100 ml product is shown and logged in ml', (
      tester,
    ) async {
      await sheet(tester, _food(NutritionBasis.per100ml, packaged: true));

      expect(find.text('per 100 ml'), findsOneWidget);
      expect(find.text('46 kcal'), findsOneWidget);

      final before = FitnessProvider.instance.todayNutritionLog.dailyCalories;
      await tester.tap(find.textContaining('ADD TO'));
      await tester.pumpAndSettle();

      final log = FitnessProvider.instance.todayNutritionLog;
      expect(log.dailyCalories - before, closeTo(46, 0.01));
      final entry = log.meals
          .expand((m) => m.consumedFoods)
          .firstWhere((c) => c.food.id.startsWith('f_per100ml'));
      expect(entry.unit, 'ml');
    });

    testWidgets('a per-100 g product keeps its gram unit', (tester) async {
      await sheet(tester, _food(NutritionBasis.per100g, packaged: true));

      expect(find.text('per 100 grams'), findsOneWidget);
    });

    testWidgets('an unknown-basis product behaves as before', (tester) async {
      await sheet(tester, _food(NutritionBasis.unknown, packaged: true));

      expect(find.text('per 100 grams'), findsOneWidget);
      expect(find.text('46 kcal'), findsOneWidget);
    });
  });

  group('values for one serving or one package', () {
    const perServing = FoodItem(
      id: 'ps',
      name: 'Granola',
      calories: 150,
      protein: 6,
      carbohydrates: 20,
      fats: 5,
      isPackaged: true,
      barcode: '1',
      nutritionBasis: NutritionBasis.perServing,
      servingQuantity: 30,
      servingQuantityUnit: 'g',
    );
    const perServingNoSize = FoodItem(
      id: 'ps2',
      name: 'Bar',
      calories: 200,
      isPackaged: true,
      barcode: '2',
      nutritionBasis: NutritionBasis.perServing,
    );

    testWidgets('the portion sheet starts at one serving', (tester) async {
      await _portion(tester, perServing);
      expect(_selectedUnit(tester), 'serving');
      expect(find.text('150 kcal'), findsOneWidget);
    });

    testWidgets('and offers weights only when the serving has a weight', (
      tester,
    ) async {
      await _portion(tester, perServing);
      final withSize = await _units(tester);
      expect(withSize, containsAll(['serving', 'g', 'kg']));
      // The serving is measured in grams, so millilitres have no meaning.
      expect(withSize, isNot(contains('ml')));
      expect(withSize, isNot(contains('L')));
    });

    testWidgets('a serving with no weight offers no weights at all', (
      tester,
    ) async {
      await _portion(tester, perServingNoSize);
      final units = await _units(tester);
      expect(units, contains('serving'));
      expect(units, isNot(contains('g')));
      expect(units, isNot(contains('ml')));
    });

    testWidgets('the barcode sheet says per serving and logs a serving', (
      tester,
    ) async {
      await _open(tester, (_) => ScannedFoodResultCard(food: perServing));

      expect(find.text('per serving (30 g)'), findsOneWidget);
      expect(find.text('150 kcal'), findsOneWidget);

      await tester.tap(find.textContaining('ADD TO'));
      await tester.pumpAndSettle();
      final entry = FitnessProvider.instance.todayNutritionLog.meals
          .expand((m) => m.consumedFoods)
          .single;
      expect(entry.unit, 'serving');
      expect(entry.quantity, 1);
      expect(entry.calories, closeTo(150, 1e-9));
    });

    testWidgets('values per package say per package', (tester) async {
      await _open(
        tester,
        (_) => ScannedFoodResultCard(
          food: const FoodItem(
            id: 'pp',
            name: 'Bottle',
            calories: 367.5,
            isPackaged: true,
            barcode: '3',
            nutritionBasis: NutritionBasis.perPackage,
            packageQuantity: 750,
            packageQuantityUnit: 'ml',
            unknownNutrients: {
              FoodItem.proteinKey,
              FoodItem.carbohydrateKey,
              FoodItem.fatKey,
            },
          ),
        ),
      );
      expect(find.text('per package (750 ml)'), findsOneWidget);
      expect(find.text('368 kcal'), findsOneWidget);
    });
  });
}
