import 'dart:async';
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

/// The record Open Food Facts returns for Boomer Bubble Gum (8902433040207),
/// reduced to the fields Atlas asks for: a name and brand, but no nutriments,
/// no serving size and nothing else that carries nutrition.
const _boomer = {
  'code': '8902433040207',
  'status': 1,
  'status_verbose': 'product found',
  'product': {
    'code': '8902433040207',
    'product_name': 'Boomer Bubble Gum',
    'brands': "Wrigley's",
    'categories_tags': ['en:snacks', 'en:candies', 'en:bubble gum'],
    'ingredients_text': '',
    'image_front_url': 'https://images.openfoodfacts.org/x.jpg',
  },
};

Map<String, dynamic> _product(Map<String, dynamic> extra) => {
  'status': 1,
  'product': {'product_name': 'Test product', 'brands': 'Acme', ...extra},
};

http.Client _reply(
  Object body, {
  int status = 200,
  void Function(http.Request)? onRequest,
}) => MockClient((request) async {
  onRequest?.call(request);
  return http.Response(body is String ? body : jsonEncode(body), status);
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    OpenFoodFactsService.resetInstance();
  });

  group('what is asked for', () {
    test('only the fields the parser reads', () async {
      late Uri seen;
      final service = OpenFoodFactsService(
        httpClient: _reply(_boomer, onRequest: (r) => seen = r.url),
      );

      await service.getProductByBarcode('8902433040207');

      expect(seen.path, '/api/v2/product/8902433040207.json');
      final fields = seen.queryParameters['fields']!.split(',');
      expect(
        fields,
        containsAll([
          'product_name',
          'brands',
          'nutriments',
          'serving_size',
          'serving_quantity',
          'nutrition_data_per',
          'categories_tags',
          'image_front_url',
          'ingredients_text',
        ]),
      );
      expect(fields, isNot(contains('')));
    });

    test(
      'a product with nutrition still parses from just those fields',
      () async {
        final service = OpenFoodFactsService(
          httpClient: _reply({
            'status': 1,
            'product': {
              'product_name': 'Hazelnut spread',
              'brands': 'Acme',
              'nutrition_data_per': '100g',
              'nutriments': {
                'energy-kcal_100g': 539,
                'proteins_100g': 6.3,
                'carbohydrates_100g': 57.5,
                'fat_100g': 30.9,
              },
            },
          }),
        );

        final f = await service.getProductByBarcode('3017620422003');

        expect(f!.calories, 539);
        expect(f.protein, 6.3);
        expect(f.unknownNutrients, isEmpty);
      },
    );
  });

  group('a product that has no nutrition facts (Boomer Bubble Gum)', () {
    test('is found by name and brand but its nutrition is unknown', () async {
      final service = OpenFoodFactsService(httpClient: _reply(_boomer));

      final f = await service.getProductByBarcode('8902433040207');

      expect(f!.name, 'Boomer Bubble Gum');
      expect(f.brand, "Wrigley's");
      expect(f.nutritionUnavailable, isTrue);
      expect(f.caloriesUnknown, isTrue);
    });

    test('estimated nutrients are not used as facts', () {
      final food = OpenFoodFactsService().parseOpenFoodFactsProduct(
        _product({
          'nutriments': <String, dynamic>{},
          'nutriments_estimated': {
            'energy-kcal_100g': 480,
            'proteins_100g': 5,
            'carbohydrates_100g': 70,
            'fat_100g': 20,
          },
        }),
        '1',
      )!;
      expect(food.nutritionUnavailable, isTrue);
      expect(food.calories, 0, reason: 'a placeholder, never an estimate');
    });

    test('other nutrition-looking fields do not become values', () {
      final food = OpenFoodFactsService().parseOpenFoodFactsProduct(
        _product({
          'nutrition_grades': 'unknown',
          'nutrition_score_debug': 'missing energy_100g',
          'quantity': '18.6g',
          'product_quantity': 18.6,
          'nutriments': null,
        }),
        '1',
      )!;
      expect(food.nutritionUnavailable, isTrue);
    });

    test(
      'there is no hidden second source: one request, nothing invented',
      () async {
        var requests = 0;
        final repository = LocalFoodRepository(
          remoteSource: ApiRemoteFoodSource(
            api.HttpOpenFoodFactsService(
              _reply(_boomer, onRequest: (_) => requests++),
            ),
          ),
        );

        final f = await repository.searchByBarcode('8902433040207');

        expect(requests, 1);
        expect(f!.nutritionUnavailable, isTrue);
        expect(f.calories, 0);
        expect(LocalStorage.getScannedFoods(), isEmpty);
      },
    );

    test('a user-entered product replaces it on the next scan', () async {
      await LocalStorage.saveCustomFoods([
        const FoodItem(
          id: 'scanned_8902433040207',
          name: 'Boomer Bubble Gum',
          calories: 15,
          protein: 0,
          carbohydrates: 4,
          fats: 0,
          isCustom: true,
          barcode: '8902433040207',
        ).toJson(),
      ]);
      var requests = 0;
      final repository = LocalFoodRepository(
        remoteSource: ApiRemoteFoodSource(
          api.HttpOpenFoodFactsService(
            _reply(_boomer, onRequest: (_) => requests++),
          ),
        ),
      );

      final f = await repository.searchByBarcode('8902433040207');

      expect(requests, 0);
      expect(f!.calories, 15);
      expect(f.hasUnknownNutrition, isFalse);
    });
  });

  group('valid zero values are kept', () {
    test('explicit zeros are known zeros', () async {
      final service = OpenFoodFactsService(
        httpClient: _reply(
          _product({
            'nutriments': {
              'energy-kcal_100g': 0,
              'proteins_100g': 0,
              'carbohydrates_100g': 0,
              'fat_100g': 0,
            },
          }),
        ),
      );

      final f = await service.getProductByBarcode('4000');

      expect(f!.unknownNutrients, isEmpty);
      expect(f.nutritionUnavailable, isFalse);
      expect(f.calories, 0);
      // A real zero is cached like any other known product.
      expect(LocalStorage.getScannedFoods(), hasLength(1));
    });

    test('zero for some nutrients with others missing stays partial', () {
      final f = OpenFoodFactsService().parseOpenFoodFactsProduct(
        _product({
          'nutriments': {'energy-kcal_100g': 0, 'fat_100g': 0},
        }),
        '1',
      )!;
      expect(f.unknownNutrients, {
        FoodItem.proteinKey,
        FoodItem.carbohydrateKey,
      });
    });
  });

  group('timeouts', () {
    test('a slow database is cut off at the timeout', () async {
      final never = Completer<http.Response>();
      final service = OpenFoodFactsService(
        httpClient: MockClient((_) => never.future),
        timeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        service.getProductByBarcode('5000'),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('the default bound is ten seconds', () {
      expect(OpenFoodFactsService.defaultTimeout, const Duration(seconds: 10));
    });

    test('after a timeout nothing is cached and a retry works', () async {
      var slow = true;
      final service = OpenFoodFactsService(
        httpClient: MockClient((_) async {
          if (slow) return Completer<http.Response>().future;
          return http.Response(
            jsonEncode(
              _product({
                'nutriments': {
                  'energy-kcal_100g': 100,
                  'proteins_100g': 1,
                  'carbohydrates_100g': 1,
                  'fat_100g': 1,
                },
              }),
            ),
            200,
          );
        }),
        timeout: const Duration(milliseconds: 50),
      );

      await expectLater(
        service.getProductByBarcode('5001'),
        throwsA(isA<TimeoutException>()),
      );
      expect(LocalStorage.getScannedFoods(), isEmpty);

      slow = false;
      final f = await service.getProductByBarcode('5001');
      expect(f!.calories, 100);
    });
  });

  group('malformed and failing responses', () {
    Future<OpenFoodFactsException> failure(http.Client client) async {
      try {
        await OpenFoodFactsService(
          httpClient: client,
        ).getProductByBarcode('6000');
      } on OpenFoodFactsException catch (e) {
        return e;
      }
      fail('expected an OpenFoodFactsException');
    }

    for (final body in [
      'not json at all',
      '',
      '[1, 2, 3]',
      '"text"',
      '{"status": 1, "product": {"product_name": 5}}',
      '{"status": 1, "product": {"product_name": "X", "nutriments": {"energy-kcal_100g": {}}, "brands": ["a"]}}',
    ]) {
      test('an unreadable body is an error, not "not found": $body', () async {
        final e = await failure(_reply(body));
        expect(e.message, contains('unreadable'));
        expect(LocalStorage.getScannedFoods(), isEmpty);
      });
    }

    test('a server error keeps its status', () async {
      final e = await failure(_reply('oops', status: 503));
      expect(e.statusCode, 503);
    });

    test('a missing product is null, not an error', () async {
      final service = OpenFoodFactsService(
        httpClient: _reply({
          'status': 0,
          'status_verbose': 'product not found',
        }),
      );
      expect(await service.getProductByBarcode('7000'), isNull);

      final notFound = OpenFoodFactsService(
        httpClient: _reply({'status': 0}, status: 404),
      );
      expect(await notFound.getProductByBarcode('7001'), isNull);
    });

    test('no network is flagged as a network error', () async {
      final e = await failure(
        MockClient((_) async => throw http.ClientException('down')),
      );
      expect(e.isNetworkError, isTrue);
    });

    test(
      'a failed lookup does not disturb the cache of other products',
      () async {
        final good = OpenFoodFactsService(
          httpClient: _reply(
            _product({
              'nutriments': {
                'energy-kcal_100g': 90,
                'proteins_100g': 1,
                'carbohydrates_100g': 20,
                'fat_100g': 0,
              },
            }),
          ),
        );
        await good.getProductByBarcode('8000');

        await failure(_reply('garbage'));

        expect(LocalStorage.getScannedFoods(), hasLength(1));
        expect(await good.getProductByBarcode('8000'), isNotNull);
      },
    );
  });
}
