import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/repositories/food_repository.dart';
import 'package:atlas/services/food/openfoodfacts_service.dart';
import 'package:atlas/services/food_api/open_food_facts_service.dart' as api;

OpenFoodFactsService _service([http.Client? client]) =>
    OpenFoodFactsService(httpClient: client);

FoodItem _parse(Map<String, dynamic> product, {String code = '111'}) =>
    _service().parseOpenFoodFactsProduct({
      'status': 1,
      'product': {'product_name': 'Test product', 'brands': 'Acme', ...product},
    }, code)!;

String _body(Map<String, dynamic> product) => jsonEncode({
  'status': 1,
  'product': {'product_name': 'Test product', 'brands': 'Acme', ...product},
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    OpenFoodFactsService.resetInstance();
  });

  group('missing versus explicitly zero nutrition', () {
    test('a product with a name and brand but no nutrition is unavailable', () {
      final f = _parse({'nutriments': <String, dynamic>{}});

      expect(f.name, 'Test product');
      expect(f.brand, 'Acme');
      expect(f.nutritionUnavailable, isTrue);
      expect(f.unknownNutrients, FoodItem.coreNutrients);
      expect(f.caloriesUnknown, isTrue);
      expect(f.hasUnknownNutrition, isTrue);
    });

    test('a product with no nutriments field at all is unavailable', () {
      expect(_parse({}).nutritionUnavailable, isTrue);
      expect(_parse({'nutriments': 'broken'}).nutritionUnavailable, isTrue);
    });

    test('explicit zeros are known zeros, not missing data', () {
      final f = _parse({
        'nutriments': {
          'energy-kcal_100g': 0,
          'proteins_100g': 0,
          'carbohydrates_100g': 0,
          'fat_100g': 0,
        },
      });

      expect(f.calories, 0);
      expect(f.unknownNutrients, isEmpty);
      expect(f.nutritionUnavailable, isFalse);
      expect(f.caloriesUnknown, isFalse);
      expect(f.isNutrientKnown(FoodItem.proteinKey), isTrue);
    });

    test('numbers given as text are read', () {
      final f = _parse({
        'nutriments': {
          'energy-kcal_100g': '250',
          'proteins_100g': '10.5',
          'carbohydrates_100g': '30',
          'fat_100g': '8',
        },
      });
      expect(f.calories, 250);
      expect(f.protein, 10.5);
      expect(f.unknownNutrients, isEmpty);
    });

    test('text that is not a number stays unknown', () {
      final f = _parse({
        'nutriments': {'energy-kcal_100g': 'n/a', 'proteins_100g': ''},
      });
      expect(f.nutritionUnavailable, isTrue);
    });
  });

  group('partial data', () {
    test('only the missing nutrients are unknown', () {
      final f = _parse({
        'nutriments': {'energy-kcal_100g': 120, 'proteins_100g': 3},
      });

      expect(f.calories, 120);
      expect(f.protein, 3);
      expect(f.unknownNutrients, {FoodItem.carbohydrateKey, FoodItem.fatKey});
      expect(f.nutritionUnavailable, isFalse);
      expect(f.caloriesUnknown, isFalse);
      expect(f.hasUnknownNutrition, isTrue);
    });

    test('macros without calories: calories stay unknown, not computed', () {
      final f = _parse({
        'nutriments': {
          'proteins_100g': 10,
          'carbohydrates_100g': 20,
          'fat_100g': 5,
        },
      });
      expect(f.caloriesUnknown, isTrue);
      expect(f.calories, 0, reason: 'a placeholder, not an estimate');
      expect(f.nutritionUnavailable, isFalse);
      expect(f.isNutrientKnown(FoodItem.proteinKey), isTrue);
    });
  });

  group('per-100g, per-serving and kJ-only data', () {
    test('per-100g values are used as they are', () {
      final f = _parse({
        'nutriments': {
          'energy-kcal_100g': 400,
          'energy-kcal_serving': 100,
          'proteins_100g': 20,
          'carbohydrates_100g': 50,
          'fat_100g': 10,
        },
        'serving_quantity': 25,
      });
      expect(f.calories, 400);
      expect(f.protein, 20);
    });

    test('kJ-only energy is converted to kcal', () {
      final f = _parse({
        'nutriments': {'energy_100g': 1000},
      });
      expect(f.calories, closeTo(239.0, 0.1));
      expect(f.isNutrientKnown(FoodItem.calorieKey), isTrue);
      expect(f.isNutrientKnown(FoodItem.proteinKey), isFalse);

      final g = _parse({
        'nutriments': {'energy-kj_100g': 418.4},
      });
      expect(g.calories, closeTo(100.0, 0.01));
    });

    test('per-serving values are converted using the serving size', () {
      final f = _parse({
        'serving_quantity': 25,
        'nutriments': {
          'energy-kcal_serving': 50,
          'proteins_serving': 5,
          'carbohydrates_serving': 10,
          'fat_serving': 2.5,
        },
      });
      expect(f.calories, 200);
      expect(f.protein, 20);
      expect(f.carbohydrates, 40);
      expect(f.fats, 10);
      expect(f.unknownNutrients, isEmpty);
    });

    test('per-serving kJ is converted too', () {
      final f = _parse({
        'serving_quantity': 50,
        'nutriments': {'energy_serving': 418.4},
      });
      expect(f.calories, closeTo(200.0, 0.01));
    });

    test('the serving size can come from the text, e.g. "30 g"', () {
      final f = _parse({
        'serving_size': '30 g',
        'nutriments': {'proteins_serving': 6},
      });
      expect(f.protein, 20);
    });

    test('per-serving data with no usable serving size stays per serving', () {
      // Never turned into a per-100 figure it cannot support, never zeros.
      for (final size in [null, 'one piece', '3 gummies']) {
        final f = _parse({
          'serving_size': ?size,
          'nutriments': {'energy-kcal_serving': 50, 'proteins_serving': 5},
        });
        expect(f.nutritionBasis, NutritionBasis.perServing, reason: '$size');
        expect(f.nutritionUnavailable, isFalse, reason: '$size');
        expect(f.calories, 50);
        expect(f.protein, 5);
        expect(f.isNutrientKnown(FoodItem.carbohydrateKey), isFalse);
        expect(f.servingQuantity, isNull);
      }
    });

    test('plain values are per 100 g unless the product says per serving', () {
      expect(
        _parse({
          'nutriments': {'energy-kcal': 300},
        }).calories,
        300,
      );

      final perServing = _parse({
        'nutrition_data_per': 'serving',
        'serving_quantity': 50,
        'nutriments': {'energy-kcal': 100},
      });
      expect(perServing.calories, 200);

      // No serving weight: kept per serving, not converted and not dropped.
      final noServingSize = _parse({
        'nutrition_data_per': 'serving',
        'nutriments': {'energy-kcal': 100},
      });
      expect(noServingSize.caloriesUnknown, isFalse);
      expect(noServingSize.nutritionBasis, NutritionBasis.perServing);
      expect(noServingSize.calories, 100);
    });

    test('a stated 0 kcal with kilojoules uses the kilojoules', () {
      final f = _parse({
        'nutriments': {'energy-kcal_100g': 0, 'energy-kj_100g': 418.4},
      });
      expect(f.calories, closeTo(100.0, 0.01));
    });
  });

  group('FoodItem serialization compatibility', () {
    test('unknown nutrients survive a JSON round trip', () {
      final original = _parse({
        'nutriments': {'energy-kcal_100g': 90},
      }, code: '555');
      final restored = FoodItem.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(restored.unknownNutrients, original.unknownNutrients);
      expect(restored.calories, 90);
    });

    test('known food writes an empty list so it is never read as legacy', () {
      const water = FoodItem(
        id: 'scanned_1',
        name: 'Water',
        calories: 0,
        protein: 0,
        carbohydrates: 0,
        fats: 0,
        isPackaged: true,
        barcode: '1',
      );
      final json = water.toJson();
      expect(json['unknownNutrients'], isEmpty);
      expect(FoodItem.fromJson(json).unknownNutrients, isEmpty);
      expect(FoodItem.fromJson(json).nutritionUnavailable, isFalse);
    });

    test('JSON from older versions (no field) still loads', () {
      final f = FoodItem.fromJson({
        'id': 'custom_1',
        'name': 'Oats',
        'calories': 380,
        'protein': 13,
        'carbohydrates': 60,
        'fats': 7,
      });
      expect(f.calories, 380);
      expect(f.unknownNutrients, isEmpty);
    });

    test('unknown names in the list are ignored', () {
      final f = FoodItem.fromJson({
        'id': 'x',
        'name': 'x',
        'unknownNutrients': ['protein', 'nonsense', 3],
      });
      expect(f.unknownNutrients, {FoodItem.proteinKey});
    });

    test('copyWith keeps unknown nutrients unless a value is replaced', () {
      final f = _parse({'nutriments': <String, dynamic>{}});
      expect(f.copyWith(name: 'Renamed').nutritionUnavailable, isTrue);

      final typed = f.copyWith(calories: 50, protein: 2);
      expect(typed.caloriesUnknown, isFalse);
      expect(typed.isNutrientKnown(FoodItem.proteinKey), isTrue);
      expect(typed.isNutrientKnown(FoodItem.carbohydrateKey), isFalse);
    });
  });

  group('legacy cached items', () {
    Map<String, dynamic> legacy({
      bool isCustom = false,
      bool isPackaged = true,
      String? barcode = '8902433040207',
      num calories = 0,
      num protein = 0,
    }) => {
      'id': 'scanned_8902433040207',
      'name': 'Boomer Bubble Gum',
      'brand': "Wrigley's",
      'calories': calories,
      'protein': protein,
      'carbohydrates': 0,
      'fats': 0,
      'isCustom': isCustom,
      'isPackaged': isPackaged,
      'barcode': ?barcode,
    };

    test('an all-zero scanned barcode product is read as unknown', () {
      final f = FoodItem.fromJson(legacy());
      expect(f.nutritionUnavailable, isTrue);
    });

    test('items that are not plain scanned products are left alone', () {
      expect(
        FoodItem.fromJson(legacy(isCustom: true)).hasUnknownNutrition,
        isFalse,
      );
      expect(
        FoodItem.fromJson(legacy(isPackaged: false)).hasUnknownNutrition,
        isFalse,
      );
      expect(
        FoodItem.fromJson(legacy(barcode: null)).hasUnknownNutrition,
        isFalse,
      );
      expect(
        FoodItem.fromJson(legacy(calories: 5)).hasUnknownNutrition,
        isFalse,
      );
      expect(
        FoodItem.fromJson(legacy(protein: 1)).hasUnknownNutrition,
        isFalse,
      );
    });

    test(
      'the service ignores a legacy zero cache entry and asks again',
      () async {
        await LocalStorage.saveScannedFoods([legacy()]);
        var requests = 0;
        final service = _service(
          MockClient((_) async {
            requests++;
            return http.Response(
              _body({
                'nutriments': {
                  'energy-kcal_100g': 350,
                  'proteins_100g': 0,
                  'carbohydrates_100g': 90,
                  'fat_100g': 0,
                },
              }),
              200,
            );
          }),
        );

        final f = await service.getProductByBarcode('8902433040207');

        expect(requests, 1);
        expect(f!.calories, 350);
        expect(f.unknownNutrients, isEmpty);
        // The corrected item replaces the legacy one.
        final saved = LocalStorage.getScannedFoods();
        expect(saved, hasLength(1));
        expect(FoodItem.fromJson(saved.single).calories, 350);
      },
    );

    test(
      'a saved known-zero item (new format) is a normal cache hit',
      () async {
        await LocalStorage.saveScannedFoods([
          {...legacy(), 'unknownNutrients': <String>[]},
        ]);
        var requests = 0;
        final service = _service(
          MockClient((_) async {
            requests++;
            return http.Response('{}', 500);
          }),
        );
        final f = await service.getProductByBarcode('8902433040207');
        expect(requests, 0);
        expect(f!.nutritionUnavailable, isFalse);
      },
    );
  });

  group('caching of products without nutrition', () {
    test('is not stored, so a later scan can find updated data', () async {
      var requests = 0;
      var hasData = false;
      final service = _service(
        MockClient((_) async {
          requests++;
          return http.Response(
            _body({
              'nutriments': hasData
                  ? {
                      'energy-kcal_100g': 300,
                      'proteins_100g': 1,
                      'carbohydrates_100g': 70,
                      'fat_100g': 2,
                    }
                  : <String, dynamic>{},
            }),
            200,
          );
        }),
      );

      final first = await service.getProductByBarcode('222');
      expect(first!.nutritionUnavailable, isTrue);
      expect(first.name, 'Test product');
      expect(LocalStorage.getScannedFoods(), isEmpty);

      hasData = true;
      final second = await service.getProductByBarcode('222');
      expect(requests, 2, reason: 'not served from a cache');
      expect(second!.calories, 300);
      expect(LocalStorage.getScannedFoods(), hasLength(1));
    });

    test('a product with nutrition is still cached', () async {
      var requests = 0;
      final service = _service(
        MockClient((_) async {
          requests++;
          return http.Response(
            _body({
              'nutriments': {
                'energy-kcal_100g': 100,
                'proteins_100g': 1,
                'carbohydrates_100g': 1,
                'fat_100g': 1,
              },
            }),
            200,
          );
        }),
      );
      await service.getProductByBarcode('333');
      await service.getProductByBarcode('333');
      expect(requests, 1);
    });
  });

  group('repository barcode lookup', () {
    LocalFoodRepository repo(http.Client client) => LocalFoodRepository(
      remoteSource: ApiRemoteFoodSource(api.HttpOpenFoodFactsService(client)),
    );

    test(
      'returns the product but does not save it when nutrition is missing',
      () async {
        final repository = repo(
          MockClient(
            (_) async =>
                http.Response(_body({'nutriments': <String, dynamic>{}}), 200),
          ),
        );

        final f = await repository.searchByBarcode('444');

        expect(f!.nutritionUnavailable, isTrue);
        expect(LocalStorage.getScannedFoods(), isEmpty);
      },
    );

    test(
      'a legacy zero entry is not returned; the database is asked again',
      () async {
        await LocalStorage.saveScannedFoods([
          {
            'id': 'scanned_444',
            'name': 'Old',
            'calories': 0,
            'protein': 0,
            'carbohydrates': 0,
            'fats': 0,
            'isPackaged': true,
            'barcode': '444',
          },
        ]);
        var requests = 0;
        final repository = repo(
          MockClient((_) async {
            requests++;
            return http.Response(
              _body({
                'nutriments': {
                  'energy-kcal_100g': 120,
                  'proteins_100g': 2,
                  'carbohydrates_100g': 20,
                  'fat_100g': 3,
                },
              }),
              200,
            );
          }),
        );

        final f = await repository.searchByBarcode('444');

        expect(requests, 1);
        expect(f!.calories, 120);
      },
    );

    test(
      'a product the user completed by hand is found by its barcode',
      () async {
        await LocalStorage.saveCustomFoods([
          const FoodItem(
            id: 'scanned_555',
            name: 'My gum',
            calories: 15,
            protein: 0,
            carbohydrates: 4,
            fats: 0,
            isCustom: true,
            barcode: '555',
          ).toJson(),
        ]);
        var requests = 0;
        final repository = repo(
          MockClient((_) async {
            requests++;
            return http.Response('{}', 500);
          }),
        );

        final f = await repository.searchByBarcode('555');

        expect(requests, 0);
        expect(f!.name, 'My gum');
        expect(f.calories, 15);
      },
    );

    test(
      'known products keep working: found, saved, then served from cache',
      () async {
        var requests = 0;
        final repository = repo(
          MockClient((_) async {
            requests++;
            return http.Response(
              _body({
                'nutriments': {
                  'energy-kcal_100g': 250,
                  'proteins_100g': 5,
                  'carbohydrates_100g': 40,
                  'fat_100g': 8,
                },
              }),
              200,
            );
          }),
        );

        final first = await repository.searchByBarcode('666');
        final second = await repository.searchByBarcode('666');

        expect(first!.calories, 250);
        expect(second!.calories, 250);
        expect(requests, 1);
      },
    );
  });
}
