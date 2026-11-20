import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/consumed_food.dart';
import 'package:atlas/models/food_analysis_result.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/models/nutrient_format.dart';
import 'package:atlas/models/nutrient_status.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/food/openfoodfacts_service.dart';
import 'package:atlas/services/nutrition/nutrition_calculator.dart';

/// Every nutrient the app reads, with the Open Food Facts key that feeds it.
const _offKeys = <String, String>{
  FoodItem.calorieKey: 'energy-kcal_100g',
  FoodItem.proteinKey: 'proteins_100g',
  FoodItem.carbohydrateKey: 'carbohydrates_100g',
  FoodItem.fatKey: 'fat_100g',
  FoodItem.sugarKey: 'sugars_100g',
  FoodItem.fiberKey: 'fiber_100g',
  FoodItem.sodiumKey: 'sodium_100g',
  FoodItem.saturatedFatKey: 'saturated-fat_100g',
  FoodItem.saltKey: 'salt_100g',
};

FoodItem _parse(Map<String, dynamic> nutriments) =>
    OpenFoodFactsService().parseOpenFoodFactsProduct({
      'status': 1,
      'product': {
        'product_name': 'Thing',
        'quantity': '250 ml',
        'nutriments': nutriments,
      },
    }, '8901234567890')!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the same rule for every nutrient from Open Food Facts', () {
    for (final entry in _offKeys.entries) {
      final nutrient = entry.key;
      final key = entry.value;

      test('$nutrient: omitted is unknown', () {
        final food = _parse({'unrelated_100g': 1});
        expect(food.statusOf(nutrient), NutrientStatus.unknown);
        expect(food.valueOf(nutrient), isNull);
      });

      test('$nutrient: null is unknown', () {
        final food = _parse({key: null});
        expect(food.statusOf(nutrient), NutrientStatus.unknown);
      });

      test('$nutrient: an empty string is unknown', () {
        final food = _parse({key: ''});
        expect(food.statusOf(nutrient), NutrientStatus.unknown);
      });

      test('$nutrient: text that is not a number is unknown', () {
        final food = _parse({key: 'n/a'});
        expect(food.statusOf(nutrient), NutrientStatus.unknown);
      });

      test('$nutrient: an explicit 0 is a known zero', () {
        final food = _parse({key: 0});
        expect(food.statusOf(nutrient), NutrientStatus.knownZero);
        expect(food.valueOf(nutrient), 0);
      });

      test('$nutrient: a number given as text is known', () {
        final food = _parse({key: '12.5'});
        expect(food.statusOf(nutrient), NutrientStatus.known);
        expect(food.valueOf(nutrient), 12.5);
      });

      test('$nutrient: a number is known and comes from the database', () {
        final food = _parse({key: 7});
        expect(food.statusOf(nutrient), NutrientStatus.known);
        expect(food.nutritionSource, NutritionSource.openFoodFacts);
      });
    }

    test('one missing nutrient does not make the others zero or unknown', () {
      final food = _parse({
        'energy-kcal_100g': 49,
        'carbohydrates_100g': 12.3,
        'proteins_100g': 0,
      });
      expect(food.statusOf(FoodItem.calorieKey), NutrientStatus.known);
      expect(food.statusOf(FoodItem.carbohydrateKey), NutrientStatus.known);
      expect(food.statusOf(FoodItem.proteinKey), NutrientStatus.knownZero);
      // Not given: unknown, not inferred from the ones that are.
      expect(food.statusOf(FoodItem.fatKey), NutrientStatus.unknown);
      expect(food.statusOf(FoodItem.saltKey), NutrientStatus.unknown);
    });

    test('a food is not rejected because a nutrient is genuinely zero', () {
      final food = _parse({
        'energy-kcal_100g': 0,
        'proteins_100g': 0,
        'carbohydrates_100g': 0,
        'fat_100g': 0,
      });
      expect(food.nutritionUnavailable, isFalse);
      expect(food.statusOf(FoodItem.calorieKey), NutrientStatus.knownZero);
    });

    test(
      'a missing protein is not zero while a missing fat is also not zero',
      () {
        final food = _parse({'energy-kcal_100g': 40});
        expect(food.statusOf(FoodItem.proteinKey), NutrientStatus.unknown);
        expect(food.statusOf(FoodItem.fatKey), NutrientStatus.unknown);
        expect(food.statusOf(FoodItem.carbohydrateKey), NutrientStatus.unknown);
      },
    );
  });

  group('status by source', () {
    test('an AI estimate is an estimate, even at zero', () {
      const food = FoodItem(
        id: 'a',
        name: 'A',
        calories: 0,
        nutritionSource: NutritionSource.aiEstimate,
      );
      expect(food.statusOf(FoodItem.calorieKey), NutrientStatus.estimate);
    });

    test('an AI estimate with an unknown nutrient is still unknown', () {
      const food = FoodItem(
        id: 'a',
        name: 'A',
        calories: 10,
        nutritionSource: NutritionSource.aiEstimate,
        unknownNutrients: {FoodItem.proteinKey},
      );
      expect(food.statusOf(FoodItem.proteinKey), NutrientStatus.unknown);
      expect(food.statusOf(FoodItem.calorieKey), NutrientStatus.estimate);
    });

    test('a user-typed value is known', () {
      const food = FoodItem(
        id: 'a',
        name: 'A',
        calories: 5,
        protein: 0,
        nutritionSource: NutritionSource.userEntry,
      );
      expect(food.statusOf(FoodItem.proteinKey), NutrientStatus.knownZero);
      expect(food.statusOf(FoodItem.calorieKey), NutrientStatus.known);
    });
  });

  group('the new nutrients', () {
    test('saturated fat and salt default to unknown, never 0', () {
      const food = FoodItem(id: 'a', name: 'A', calories: 10);
      expect(food.saturatedFat, isNull);
      expect(food.salt, isNull);
      expect(food.statusOf(FoodItem.saltKey), NutrientStatus.unknown);
    });

    test('they survive saving and loading, including a real zero', () {
      const food = FoodItem(
        id: 'a',
        name: 'A',
        calories: 10,
        saturatedFat: 0,
        salt: 0.02,
      );
      final back = FoodItem.fromJson(food.toJson());
      expect(back.saturatedFat, 0);
      expect(back.salt, 0.02);
      expect(back.statusOf(FoodItem.saturatedFatKey), NutrientStatus.knownZero);
    });

    test('a food saved before them loads with both unknown', () {
      final old = FoodItem.fromJson({'id': 'a', 'name': 'A', 'calories': 10});
      expect(old.saturatedFat, isNull);
      expect(old.salt, isNull);
    });

    test('copyWith keeps and changes them', () {
      const food = FoodItem(id: 'a', name: 'A', calories: 1, salt: 0.5);
      expect(food.copyWith(name: 'B').salt, 0.5);
      expect(food.copyWith(salt: 1.5).salt, 1.5);
    });

    test('they are scaled, and an unknown one stays unknown', () {
      const food = FoodItem(
        id: 'a',
        name: 'A',
        calories: 49,
        servingUnit: 'ml',
        saturatedFat: 0,
        nutritionBasis: NutritionBasis.per100ml,
      );
      final scaled = NutritionCalculator.calculate(food, 750, 'ml');
      expect(scaled.saturatedFat, 0);
      expect(scaled.salt, isNull);
      expect(scaled.calories, closeTo(367.5, 0.001));
    });

    test('Open Food Facts values are read and scaled once', () {
      final food = _parse({
        'energy-kcal_100g': 49,
        'saturated-fat_100g': 0.4,
        'salt_100g': 0.02,
      });
      expect(food.saturatedFat, 0.4);
      expect(food.salt, 0.02);
      final scaled = NutritionCalculator.calculate(food, 750, 'ml');
      expect(scaled.salt, closeTo(0.15, 0.0001));
    });
  });

  group('showing a nutrient', () {
    test('unknown is a dash, whatever number is stored', () {
      expect(NutrientFormat.grams(0, NutrientStatus.unknown), '—');
      expect(NutrientFormat.grams(null, NutrientStatus.known), '—');
      expect(NutrientFormat.kcal(0, NutrientStatus.unknown), '— kcal');
    });

    test('a known zero is shown as 0', () {
      expect(NutrientFormat.grams(0, NutrientStatus.knownZero), '0.0g');
      expect(NutrientFormat.kcal(0, NutrientStatus.knownZero), '0 kcal');
    });

    test('a known value is shown with its unit', () {
      expect(NutrientFormat.grams(12.34, NutrientStatus.known), '12.3g');
      expect(
        NutrientFormat.grams(1.234, NutrientStatus.known, digits: 2),
        '1.23g',
      );
      expect(NutrientFormat.kcal(196, NutrientStatus.known), '196 kcal');
    });

    test('an estimate is marked with a tilde and never as exact', () {
      expect(NutrientFormat.grams(78, NutrientStatus.estimate), '~78.0g');
      expect(NutrientFormat.kcal(287, NutrientStatus.estimate), '~287 kcal');
      expect(NutrientFormat.grams(0, NutrientStatus.estimate), '~0.0g');
    });
  });

  group('saving and loading keeps what is unknown', () {
    const partial = FoodItem(
      id: 'p',
      name: 'Partial',
      calories: 120,
      protein: 3,
      isPackaged: true,
      barcode: '1',
      unknownNutrients: {FoodItem.carbohydrateKey, FoodItem.fatKey},
    );

    test('a food', () {
      final back = FoodItem.fromJson(partial.toJson());
      expect(back.statusOf(FoodItem.carbohydrateKey), NutrientStatus.unknown);
      expect(back.statusOf(FoodItem.proteinKey), NutrientStatus.known);
    });

    test('a logged entry', () {
      final entry = ConsumedFood(food: partial, quantity: 200, unit: 'g');
      final back = ConsumedFood.fromJson(entry.toJson());
      expect(back.isKnown(FoodItem.carbohydrateKey), isFalse);
      expect(back.isKnown(FoodItem.proteinKey), isTrue);
      expect(back.protein, 6);
    });

    test('a scan in the history', () {
      final result = FoodAnalysisResult(
        foodName: 'x',
        calories: 100,
        protein: 0,
        carbohydrates: 20,
        fats: 0,
        isAiGenerated: true,
        timestamp: _t,
        unknownNutrients: {FoodItem.proteinKey, FoodItem.fatKey},
      );
      final back = FoodAnalysisResult.fromJson(result.toJson());
      expect(back.unknownNutrients, {FoodItem.proteinKey, FoodItem.fatKey});
    });

    test('a scan made from a food keeps the food\'s unknown nutrients', () {
      final analysis = FoodAnalysisResult.fromFoodItem(partial);
      expect(analysis.unknownNutrients, {
        FoodItem.carbohydrateKey,
        FoodItem.fatKey,
      });
      expect(analysis.toFoodItem().isNutrientKnown(FoodItem.fatKey), isFalse);
    });

    test(
      'a saved session without the field is read, not rewritten as zero',
      () {
        final old = FoodAnalysisResult.fromJson({
          'foodName': 'Old',
          'calories': 100,
          'protein': 5,
          'carbohydrates': 10,
          'fats': 2,
        });
        // Nothing is claimed either way for history that never recorded it.
        expect(old.unknownNutrients, isEmpty);
        expect(old.protein, 5);
      },
    );
  });

  group('logging', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.init();
      FitnessProvider.resetInstance();
    });

    test('a logged partial food keeps the unknown nutrients', () async {
      const partial = FoodItem(
        id: 'p',
        name: 'Partial',
        calories: 120,
        protein: 3,
        unknownNutrients: {FoodItem.carbohydrateKey},
      );
      await FitnessProvider.instance.addFoodToMeal('Lunch', partial, 100, 'g');

      final logged = FitnessProvider.instance.todayNutritionLog.meals
          .expand((m) => m.consumedFoods)
          .single;
      expect(logged.isKnown(FoodItem.carbohydrateKey), isFalse);
      expect(logged.isKnown(FoodItem.proteinKey), isTrue);
    });
  });
}

final _t = DateTime(2026, 10, 24);
