import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/services/food/openfoodfacts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    OpenFoodFactsService.resetInstance();
  });

  group('1. OpenFoodFacts Barcode Lookup & User-Agent Tests', () {
    test(
      'Sends custom User-Agent header and queries OpenFoodFacts v2 endpoint',
      () async {
        String? capturedUrl;
        Map<String, String>? capturedHeaders;

        final mockClient = MockClient((request) async {
          capturedUrl = request.url.toString();
          capturedHeaders = request.headers;

          final sampleJson = {
            'status': 1,
            'code': '8901030865412',
            'product': {
              'product_name': 'Whey Protein Isolate',
              'brands': 'Optimum Nutrition, Glanbia',
              'serving_size': '30g',
              'ingredients_text':
                  'Whey protein isolate, cocoa, natural flavors, stevia',
              'image_front_url':
                  'https://images.openfoodfacts.org/images/products/whey.jpg',
              'nutriments': {
                'energy-kcal_100g': 380.0,
                'proteins_100g': 80.0,
                'carbohydrates_100g': 5.0,
                'fat_100g': 2.0,
                'fiber_100g': 1.0,
                'sugars_100g': 2.0,
                'sodium_100g': 0.15,
              },
            },
          };

          return http.Response(jsonEncode(sampleJson), 200);
        });

        final service = OpenFoodFactsService(httpClient: mockClient);
        final food = await service.getProductByBarcode('8901030865412');

        expect(food, isNotNull);
        expect(food!.name, equals('Whey Protein Isolate'));
        expect(food.brand, equals('Optimum Nutrition'));
        expect(food.calories, equals(380.0));
        expect(food.protein, equals(80.0));
        expect(food.carbohydrates, equals(5.0));
        expect(food.fats, equals(2.0));
        expect(food.servingSize, equals('30g'));
        expect(food.ingredients, contains('Whey protein isolate'));
        expect(
          food.imageUrl,
          equals('https://images.openfoodfacts.org/images/products/whey.jpg'),
        );
        expect(food.barcode, equals('8901030865412'));

        // Verify User-Agent header and URL
        expect(
          capturedUrl,
          contains('world.openfoodfacts.org/api/v2/product/8901030865412.json'),
        );
        expect(
          capturedHeaders?['User-Agent'],
          equals(OpenFoodFactsService.userAgent),
        );
      },
    );
  });

  group('2. OpenFoodFacts JSON Parsing & Unit Conversion Tests', () {
    test('Converts energy in kJ to kcal when energy-kcal is missing', () {
      final service = OpenFoodFactsService();
      final json = {
        'status': 1,
        'product': {
          'product_name': 'Energy Bar',
          'brands': 'PowerBar',
          'serving_size': '50g',
          'nutriments': {
            'energy_100g': 1673.6, // 1673.6 kJ = ~400 kcal
            'proteins_100g': 20.0,
            'carbohydrates_100g': 45.0,
            'fat_100g': 10.0,
          },
        },
      };

      final food = service.parseOpenFoodFactsProduct(json, '5000159461122');
      expect(food, isNotNull);
      expect(food!.name, equals('Energy Bar'));
      expect(food.calories, closeTo(400.0, 1.0));
      expect(food.protein, equals(20.0));
      expect(food.carbohydrates, equals(45.0));
      expect(food.fats, equals(10.0));
    });

    test('Handles sodium conversion from grams to milligrams', () {
      final service = OpenFoodFactsService();
      final json = {
        'status': 1,
        'product': {
          'product_name': 'Salted Almonds',
          'nutriments': {
            'energy-kcal_100g': 580.0,
            'proteins_100g': 21.0,
            'carbohydrates_100g': 20.0,
            'fat_100g': 50.0,
            'sodium_100g': 0.4, // 0.4g sodium = 400mg
          },
        },
      };

      final food = service.parseOpenFoodFactsProduct(json, '123456789012');
      expect(food, isNotNull);
      expect(food!.sodium, equals(400.0));
    });
  });

  group('3. Missing Nutrition Fields & Graceful Defaults Tests', () {
    test(
      'Gracefully defaults missing macronutrients and brand to zero/null without crashing',
      () {
        final service = OpenFoodFactsService();
        final json = {
          'status': 1,
          'product': {
            'product_name': 'Minimalist Water',
            // No nutriments or brand provided
          },
        };

        final food = service.parseOpenFoodFactsProduct(json, '9999999999');
        expect(food, isNotNull);
        expect(food!.name, equals('Minimalist Water'));
        expect(food.brand, isNull);
        expect(food.calories, equals(0.0));
        expect(food.protein, equals(0.0));
        expect(food.carbohydrates, equals(0.0));
        expect(food.fats, equals(0.0));
        expect(food.servingSize, equals('100g'));
      },
    );
  });

  group('4. Unknown Products & Invalid Barcodes Tests', () {
    test(
      'Returns null when OpenFoodFacts returns status 0 (product not found)',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'status': 0, 'status_verbose': 'product not found'}),
            200,
          );
        });

        final service = OpenFoodFactsService(httpClient: mockClient);
        final food = await service.getProductByBarcode('0000000000000');

        expect(food, isNull);
      },
    );

    test(
      'Returns null on HTTP 404 response without throwing exceptions',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response('Not Found', 404);
        });

        final service = OpenFoodFactsService(httpClient: mockClient);
        final food = await service.getProductByBarcode('999888777666');

        expect(food, isNull);
      },
    );

    test('Never returns fake hardcoded product for unknown barcode', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'status': 0}), 200);
      });

      final service = OpenFoodFactsService(httpClient: mockClient);
      final result = await service.getProductByBarcode('unknown_test_barcode');

      expect(result, isNull);
    });
  });

  group('5. Offline Fallback & Local Caching Tests', () {
    test(
      'Caches scanned products locally and returns cached item when offline',
      () async {
        int apiCallCount = 0;
        final mockClient = MockClient((request) async {
          apiCallCount++;
          final sampleJson = {
            'status': 1,
            'product': {
              'product_name': 'Greek Yogurt',
              'brands': 'Chobani',
              'nutriments': {
                'energy-kcal_100g': 100.0,
                'proteins_100g': 15.0,
                'carbohydrates_100g': 6.0,
                'fat_100g': 0.5,
              },
            },
          };
          return http.Response(jsonEncode(sampleJson), 200);
        });

        final service = OpenFoodFactsService(httpClient: mockClient);

        // First query hits API
        final onlineFood = await service.getProductByBarcode('7000000001');
        expect(onlineFood, isNotNull);
        expect(onlineFood!.name, equals('Greek Yogurt'));
        expect(apiCallCount, equals(1));

        // Second query with offline client retrieves from local cache without hitting network
        final offlineClient = MockClient((request) async {
          throw const SocketException('No Internet Connection');
        });

        final offlineService = OpenFoodFactsService(httpClient: offlineClient);
        final cachedFood = await offlineService.getProductByBarcode(
          '7000000001',
        );

        expect(cachedFood, isNotNull);
        expect(cachedFood!.name, equals('Greek Yogurt'));
        expect(cachedFood.protein, equals(15.0));
      },
    );
  });
}
