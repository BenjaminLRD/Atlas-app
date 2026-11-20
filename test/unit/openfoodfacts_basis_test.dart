import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/services/food/openfoodfacts_service.dart';

/// Parses an OFF product made of [product] plus ordinary per-100 nutrition.
FoodItem _parse(Map<String, dynamic> product) {
  final food = OpenFoodFactsService().parseOpenFoodFactsProduct({
    'status': 1,
    'product': {
      'product_name': 'Thing',
      'brands': 'Acme',
      'nutrition_data_per': '100g',
      'nutriments': {
        'energy-kcal_100g': 46,
        'proteins_100g': 0,
        'carbohydrates_100g': 11.5,
        'fat_100g': 0,
      },
      ...product,
    },
  }, '8901234567890');
  return food!;
}

NutritionBasis _basis(Map<String, dynamic> product) =>
    _parse(product).nutritionBasis;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('grams', () {
    test('a serving stated in grams is per 100 g', () {
      expect(_basis({'serving_size': '30 g'}), NutritionBasis.per100g);
      expect(_basis({'serving_size': '30g'}), NutritionBasis.per100g);
      expect(_basis({'serving_size': '1.5 G (1 bar)'}), NutritionBasis.per100g);
    });

    test('a package quantity in grams or kilograms is per 100 g', () {
      expect(_basis({'quantity': '500 g'}), NutritionBasis.per100g);
      expect(_basis({'quantity': '1 kg'}), NutritionBasis.per100g);
      expect(_basis({'quantity': '4 x 25 g'}), NutritionBasis.per100g);
    });

    test('an explicit unit field is used', () {
      expect(_basis({'product_quantity_unit': 'g'}), NutritionBasis.per100g);
      expect(_basis({'serving_quantity_unit': 'G'}), NutritionBasis.per100g);
    });
  });

  group('millilitres', () {
    test('a serving stated in ml is per 100 ml', () {
      expect(_basis({'serving_size': '250 ml'}), NutritionBasis.per100ml);
      expect(_basis({'serving_size': '330ml'}), NutritionBasis.per100ml);
    });

    test('litres and centilitres are per 100 ml', () {
      expect(_basis({'quantity': '1 L'}), NutritionBasis.per100ml);
      expect(_basis({'quantity': '1.5l'}), NutritionBasis.per100ml);
      expect(_basis({'quantity': '6 x 33 cl'}), NutritionBasis.per100ml);
    });

    test('an explicit unit field is used', () {
      expect(_basis({'serving_quantity_unit': 'ml'}), NutritionBasis.per100ml);
      expect(_basis({'product_quantity_unit': 'l'}), NutritionBasis.per100ml);
    });

    test('serving and package agreeing on ml is still ml', () {
      expect(
        _basis({'serving_size': '250 ml', 'quantity': '1 L'}),
        NutritionBasis.per100ml,
      );
    });
  });

  group('ambiguous or missing basis stays unknown', () {
    test('no unit stated anywhere', () {
      expect(_basis({}), NutritionBasis.unknown);
    });

    test('a drink category alone is not evidence of ml', () {
      expect(
        _basis({
          'categories_tags': ['en:beverages', 'en:sodas'],
          'product_name': 'Cola',
        }),
        NutritionBasis.unknown,
      );
    });

    test('grams and millilitres both stated is unknown', () {
      expect(
        _basis({'serving_size': '30 g', 'quantity': '500 ml'}),
        NutritionBasis.unknown,
      );
      expect(
        _basis({'serving_quantity_unit': 'ml', 'product_quantity_unit': 'g'}),
        NutritionBasis.unknown,
      );
      expect(
        _basis({'serving_size': '100 g (250 ml)'}),
        NutritionBasis.unknown,
      );
    });

    test('units that are not weight or volume are ignored', () {
      expect(_basis({'serving_size': '1 bottle'}), NutritionBasis.unknown);
      expect(_basis({'quantity': '12 pieces'}), NutritionBasis.unknown);
      expect(_basis({'serving_size': '2 oz'}), NutritionBasis.unknown);
      expect(_basis({'quantity': '3 packs'}), NutritionBasis.unknown);
    });

    test('words that merely contain a unit letter are not units', () {
      expect(_basis({'serving_size': '5 large'}), NutritionBasis.unknown);
      expect(_basis({'serving_size': '1 glass'}), NutritionBasis.unknown);
    });

    test('values of the wrong type are ignored, not errors', () {
      expect(
        _basis({
          'quantity': ['500 g'],
          'serving_quantity_unit': 5,
          'product_quantity_unit': null,
        }),
        NutritionBasis.unknown,
      );
    });
  });

  group('everything else parses as before', () {
    test('values, serving size and unit label are unchanged by the basis', () {
      final f = _parse({'serving_size': '250 ml', 'serving_quantity': 250});
      expect(f.nutritionBasis, NutritionBasis.per100ml);
      expect(f.calories, 46);
      expect(f.carbohydrates, 11.5);
      expect(f.servingSize, '250 ml');
      // Scaling is a later task: the unit label is left as it was.
      expect(f.servingUnit, 'grams');
      expect(f.unknownNutrients, isEmpty);
    });

    test('kJ-only values are still converted', () {
      final f = OpenFoodFactsService().parseOpenFoodFactsProduct({
        'status': 1,
        'product': {
          'product_name': 'Juice',
          'serving_size': '200 ml',
          'nutriments': {'energy-kj_100g': 188.3},
        },
      }, '1')!;
      expect(f.calories, closeTo(45, 0.1));
      expect(f.nutritionBasis, NutritionBasis.per100ml);
      // Missing macros stay unknown, as before.
      expect(f.unknownNutrients, {
        FoodItem.proteinKey,
        FoodItem.carbohydrateKey,
        FoodItem.fatKey,
      });
    });

    test('a product with no nutrition keeps its basis separate', () {
      final f = OpenFoodFactsService().parseOpenFoodFactsProduct({
        'status': 1,
        'product': {'product_name': 'Gum', 'quantity': '18.6g'},
      }, '2')!;
      expect(f.nutritionUnavailable, isTrue);
      expect(f.nutritionBasis, NutritionBasis.per100g);
    });

    test('an unknown basis does not make nutrients unknown', () {
      final f = _parse({});
      expect(f.nutritionBasis, NutritionBasis.unknown);
      expect(f.unknownNutrients, isEmpty);
      expect(f.calories, 46);
    });

    test('the basis survives saving and loading', () {
      final f = _parse({'serving_size': '250 ml'});
      final loaded = FoodItem.fromJson(f.toJson());
      expect(loaded.nutritionBasis, NutritionBasis.per100ml);
    });
  });

  group('legacy product responses', () {
    test('a response with no unit information is unknown, not grams', () {
      final f = _parse({'serving_size': null});
      expect(f.nutritionBasis, NutritionBasis.unknown);
    });

    test('a lookup asks for the unit fields and parses the answer', () async {
      late Uri seen;
      final service = OpenFoodFactsService(
        httpClient: MockClient((request) async {
          seen = request.url;
          return http.Response(
            '{"status":1,"product":{"product_name":"Cola",'
            '"serving_size":"330 ml","nutrition_data_per":"100g",'
            '"nutriments":{"energy-kcal_100g":42,"proteins_100g":0,'
            '"carbohydrates_100g":10.6,"fat_100g":0}}}',
            200,
          );
        }),
      );

      final f = await service.getProductByBarcode('5449000000996');

      final fields = seen.queryParameters['fields']!.split(',');
      expect(
        fields,
        containsAll([
          'quantity',
          'serving_quantity_unit',
          'product_quantity_unit',
        ]),
      );
      expect(f!.nutritionBasis, NutritionBasis.per100ml);
    });
  });
}
