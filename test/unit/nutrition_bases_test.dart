import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/consumed_food.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/models/food_scan_result.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/food/openfoodfacts_service.dart';
import 'package:atlas/services/nutrition/nutrition_calculator.dart';

/// 150 kcal and 6 g protein for ONE serving, a serving being 30 g.
const _perServing = FoodItem(
  id: 'ps',
  name: 'Granola',
  calories: 150,
  protein: 6,
  carbohydrates: 20,
  fats: 5,
  salt: 0.1,
  nutritionBasis: NutritionBasis.perServing,
  servingQuantity: 30,
  servingQuantityUnit: 'g',
);

/// The same, but nobody says how big a serving is.
const _perServingNoSize = FoodItem(
  id: 'ps2',
  name: 'Bar',
  calories: 200,
  protein: 4,
  nutritionBasis: NutritionBasis.perServing,
);

/// 367.5 kcal for the whole 750 ml bottle.
const _perPackage = FoodItem(
  id: 'pp',
  name: 'Bottle',
  calories: 367.5,
  carbohydrates: 92,
  nutritionBasis: NutritionBasis.perPackage,
  packageQuantity: 750,
  packageQuantityUnit: 'ml',
);

const _perPackageNoSize = FoodItem(
  id: 'pp2',
  name: 'Pack',
  calories: 300,
  nutritionBasis: NutritionBasis.perPackage,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('saving and loading', () {
    test('the new bases have names that older data cannot confuse', () {
      expect(NutritionBasis.perServing.jsonValue, 'perServing');
      expect(NutritionBasis.perPackage.jsonValue, 'perPackage');
      expect(
        NutritionBasis.fromJsonValue('perServing'),
        NutritionBasis.perServing,
      );
      expect(
        NutritionBasis.fromJsonValue('perPackage'),
        NutritionBasis.perPackage,
      );
    });

    test('the quantities survive, and absent ones stay absent', () {
      final back = FoodItem.fromJson(_perServing.toJson());
      expect(back.nutritionBasis, NutritionBasis.perServing);
      expect(back.servingQuantity, 30);
      expect(back.servingQuantityUnit, 'g');
      expect(back.packageQuantity, isNull);

      final pack = FoodItem.fromJson(_perPackage.toJson());
      expect(pack.packageQuantity, 750);
      expect(pack.packageQuantityUnit, 'ml');
      expect(pack.servingQuantity, isNull);
    });

    test('a food saved before has no quantities, not zeros', () {
      final old = FoodItem.fromJson({'id': 'a', 'name': 'A', 'calories': 1});
      expect(old.packageQuantity, isNull);
      expect(old.servingQuantity, isNull);
    });

    test('a derived basis is never per serving or per package', () {
      // Older foods with a "piece" or "bowl" unit keep their unknown basis.
      final old = FoodItem.fromJson({
        'id': 'a',
        'name': 'A',
        'servingUnit': 'bowl',
        'calories': 1,
      });
      expect(old.nutritionBasis, NutritionBasis.unknown);
    });

    test('copyWith keeps and changes the quantities', () {
      expect(_perServing.copyWith(name: 'x').servingQuantity, 30);
      expect(_perServing.copyWith(servingQuantity: 40).servingQuantity, 40);
      expect(_perPackage.copyWith(packageQuantity: 500).packageQuantity, 500);
    });
  });

  group('per serving', () {
    test('servings count whole servings', () {
      final two = NutritionCalculator.tryCalculate(_perServing, 2, 'serving')!;
      expect(two.calories, 300);
      expect(two.protein, 12);
      expect(two.salt, closeTo(0.2, 1e-9));
      expect(
        NutritionCalculator.tryCalculate(
          _perServing,
          0.5,
          'servings',
        )!.calories,
        75,
      );
    });

    test('a weight scales by the serving weight when it is known', () {
      // 60 g of a food with 30 g servings is two servings.
      final scaled = NutritionCalculator.tryCalculate(_perServing, 60, 'g')!;
      expect(scaled.calories, 300);
      expect(
        NutritionCalculator.tryCalculate(_perServing, 0.06, 'kg')!.calories,
        closeTo(300, 1e-6),
      );
    });

    test('a weight is refused when the serving has no weight', () {
      expect(
        NutritionCalculator.isUnitCompatible(_perServingNoSize, 'g'),
        isFalse,
      );
      expect(
        NutritionCalculator.tryCalculate(_perServingNoSize, 60, 'g'),
        isNull,
      );
    });

    test('grams and millilitres are not interchangeable', () {
      // The serving is 30 g, so millilitres cannot be scaled to it.
      expect(NutritionCalculator.tryCalculate(_perServing, 60, 'ml'), isNull);
      expect(NutritionCalculator.tryCalculate(_perServing, 1, 'l'), isNull);
    });

    test('a count works with or without a serving weight', () {
      expect(
        NutritionCalculator.tryCalculate(
          _perServingNoSize,
          3,
          'serving',
        )!.calories,
        600,
      );
      expect(
        NutritionCalculator.tryCalculate(
          _perServingNoSize,
          2,
          'piece',
        )!.calories,
        400,
      );
    });

    test('an unknown nutrient stays unknown when scaled', () {
      expect(
        NutritionCalculator.tryCalculate(
          _perServing,
          2,
          'serving',
        )!.saturatedFat,
        isNull,
      );
    });
  });

  group('per package', () {
    test('one package is the whole package', () {
      final one = NutritionCalculator.tryCalculate(_perPackage, 1, 'package')!;
      expect(one.calories, 367.5);
    });

    test('a part of the package scales by the package size', () {
      // 250 ml of a 750 ml bottle is a third of the bottle.
      final part = NutritionCalculator.tryCalculate(_perPackage, 250, 'ml')!;
      expect(part.calories, closeTo(122.5, 1e-9));
      expect(
        NutritionCalculator.tryCalculate(_perPackage, 0.25, 'l')!.calories,
        closeTo(122.5, 1e-9),
      );
    });

    test('grams are refused for a package measured in millilitres', () {
      expect(NutritionCalculator.isUnitCompatible(_perPackage, 'g'), isFalse);
      expect(NutritionCalculator.tryCalculate(_perPackage, 250, 'g'), isNull);
    });

    test('a part is refused when the package size is not known', () {
      expect(
        NutritionCalculator.tryCalculate(_perPackageNoSize, 250, 'ml'),
        isNull,
      );
      expect(
        NutritionCalculator.tryCalculate(
          _perPackageNoSize,
          1,
          'package',
        )!.calories,
        300,
      );
    });
  });

  group('the other bases are unchanged', () {
    test('per 100 ml still scales 750 ml by 7.5', () {
      const drink = FoodItem(
        id: 'd',
        name: 'D',
        calories: 49,
        servingUnit: 'ml',
        nutritionBasis: NutritionBasis.per100ml,
      );
      expect(
        NutritionCalculator.tryCalculate(drink, 750, 'ml')!.calories,
        closeTo(367.5, 1e-9),
      );
      expect(NutritionCalculator.tryCalculate(drink, 750, 'g'), isNull);
    });

    test('an unknown basis keeps its old behaviour', () {
      const legacy = FoodItem(id: 'l', name: 'L', calories: 200);
      const unknown = FoodItem(
        id: 'u',
        name: 'U',
        calories: 200,
        nutritionBasis: NutritionBasis.unknown,
      );
      expect(NutritionCalculator.calculate(unknown, 50, 'g').calories, 100);
      expect(NutritionCalculator.calculate(unknown, 2, 'piece').calories, 400);
      expect(legacy.nutritionBasis, NutritionBasis.per100g);
    });
  });

  group('logged entries and scans use the same factor', () {
    test('a logged entry', () {
      expect(
        ConsumedFood(food: _perServing, quantity: 2, unit: 'serving').calories,
        300,
      );
      expect(
        ConsumedFood(food: _perServing, quantity: 60, unit: 'g').calories,
        300,
      );
      expect(
        ConsumedFood(food: _perPackage, quantity: 250, unit: 'ml').calories,
        closeTo(122.5, 1e-9),
      );
    });

    test('an entry saved before is still read the old way', () {
      final legacy = ConsumedFood.fromJson({
        'food': const FoodItem(id: 'x', name: 'X', calories: 200).toJson(),
        'quantity': 2,
        'unit': 'kg',
      });
      expect(legacy.scalingVersion, 1);
      expect(legacy.calories, 400);
    });

    test('a photo scan result', () {
      FoodScanResult scan(double qty, String unit) => FoodScanResult(
        scanType: FoodScanType.aiVision,
        food: _perServing,
        estimatedQuantity: qty,
        estimatedUnit: unit,
        isAiEstimate: false,
      );
      expect(scan(2, 'serving').estimatedCalories, 300);
      expect(scan(60, 'g').estimatedCalories, 300);
      expect(scan(1, 'serving').estimatedProtein, 6);
    });

    test('a per-package scan', () {
      final scan = FoodScanResult(
        scanType: FoodScanType.aiVision,
        food: _perPackage,
        estimatedQuantity: 1,
        estimatedUnit: 'package',
        isAiEstimate: false,
      );
      expect(scan.estimatedCalories, 367.5);
    });
  });

  group('logging refuses what cannot be scaled', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.init();
      FitnessProvider.resetInstance();
    });

    test('millilitres of a per-serving food measured in grams', () async {
      await expectLater(
        FitnessProvider.instance.addFoodToMeal('Lunch', _perServing, 100, 'ml'),
        throwsArgumentError,
      );
    });

    test('a weight of a per-serving food with no serving weight', () async {
      await expectLater(
        FitnessProvider.instance.addFoodToMeal(
          'Lunch',
          _perServingNoSize,
          50,
          'g',
        ),
        throwsArgumentError,
      );
    });

    test('servings are logged', () async {
      final before = FitnessProvider.instance.todayNutritionLog.dailyCalories;
      await FitnessProvider.instance.addFoodToMeal(
        'Lunch',
        _perServing,
        2,
        'serving',
      );
      expect(
        FitnessProvider.instance.todayNutritionLog.dailyCalories - before,
        closeTo(300, 1e-9),
      );
    });
  });

  group('Open Food Facts parsing', () {
    FoodItem parse(Map<String, dynamic> product) =>
        OpenFoodFactsService().parseOpenFoodFactsProduct({
          'status': 1,
          'product': {'product_name': 'Thing', ...product},
        }, '8901234567890')!;

    test('values per serving with no serving size stay per serving', () {
      final f = parse({
        'nutriments': {'energy-kcal_serving': 50, 'proteins_serving': 5},
      });
      expect(f.nutritionBasis, NutritionBasis.perServing);
      expect(f.calories, 50);
      expect(f.protein, 5);
      // Never converted to a per-100 figure it cannot support.
      expect(f.isNutrientKnown(FoodItem.carbohydrateKey), isFalse);
      expect(f.servingQuantity, isNull);
    });

    test('plain values on a "per serving" product stay per serving', () {
      final f = parse({
        'nutrition_data_per': 'serving',
        'nutriments': {'energy-kcal': 100},
      });
      expect(f.nutritionBasis, NutritionBasis.perServing);
      expect(f.calories, 100);
    });

    test('a serving with a weight is still converted to per 100 g', () {
      final f = parse({
        'serving_size': '25 g',
        'nutriments': {'energy-kcal_serving': 50},
      });
      expect(f.nutritionBasis, NutritionBasis.per100g);
      expect(f.calories, 200);
      expect(f.servingQuantity, 25);
      expect(f.servingQuantityUnit, 'g');
    });

    test('per-100 values win and are never mixed with per-serving ones', () {
      final f = parse({
        'quantity': '500 g',
        'nutriments': {
          'energy-kcal_100g': 400,
          'proteins_serving': 5, // no serving size: cannot be used
        },
      });
      expect(f.nutritionBasis, NutritionBasis.per100g);
      expect(f.calories, 400);
      expect(f.isNutrientKnown(FoodItem.proteinKey), isFalse);
    });

    test('the package size is read from the quantity', () {
      final f = parse({
        'quantity': '750 ml',
        'nutriments': {'energy-kcal_100g': 49},
      });
      expect(f.packageQuantity, 750);
      expect(f.packageQuantityUnit, 'ml');
      expect(f.nutritionBasis, NutritionBasis.per100ml);
    });

    test('a quantity with no unit gives no package size', () {
      final f = parse({
        'quantity': '3',
        'nutriments': {'energy-kcal_100g': 49},
      });
      expect(f.packageQuantity, isNull);
    });

    test('the package size can come from the product quantity fields', () {
      final f = parse({
        'product_quantity': 330,
        'product_quantity_unit': 'ml',
        'nutriments': {'energy-kcal_100g': 42},
      });
      expect(f.packageQuantity, 330);
      expect(f.packageQuantityUnit, 'ml');
    });

    test('where the numbers came from is recorded', () {
      final before = DateTime.now();
      final f = parse({
        'nutriments': {'energy-kcal_100g': 49},
      });
      expect(f.nutritionSource, NutritionSource.openFoodFacts);
      expect(f.sourceMatch, SourceMatch.barcode);
      expect(f.sourceRetrievedAt, isNotNull);
      expect(
        f.sourceRetrievedAt!.isBefore(
          before.subtract(const Duration(seconds: 1)),
        ),
        isFalse,
      );
      expect(
        f.sourceUrl,
        'https://world.openfoodfacts.org/product/8901234567890',
      );
    });

    test('provenance survives saving and loading', () {
      final f = parse({
        'nutriments': {'energy-kcal_100g': 49},
      });
      final back = FoodItem.fromJson(f.toJson());
      expect(back.sourceMatch, SourceMatch.barcode);
      expect(back.sourceRetrievedAt, f.sourceRetrievedAt);
    });

    test('a food saved before has no claimed match or time', () {
      final old = FoodItem.fromJson({'id': 'a', 'name': 'A', 'calories': 1});
      expect(old.sourceMatch, isNull);
      expect(old.sourceRetrievedAt, isNull);
    });
  });
}
