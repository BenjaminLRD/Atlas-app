import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/repositories/food_repository.dart';
import 'package:atlas/services/barcode/barcode_result.dart';
import 'package:atlas/services/food_api/remote_food_mapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalFoodRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    repository = LocalFoodRepository();
  });

  group('Phase 5 — Barcode Food & Open Food Facts Integration Unit Tests', () {
    test('1. Barcode result parsing and serialization', () {
      final success = BarcodeResult.success('737628064502', format: 'EAN_13');
      expect(success.isValid, isTrue);
      expect(success.barcode, equals('737628064502'));
      expect(success.format, equals('EAN_13'));

      final json = success.toJson();
      final parsed = BarcodeResult.fromJson(json);
      expect(parsed.barcode, equals('737628064502'));
      expect(parsed.isValid, isTrue);

      final denied = BarcodeResult.permissionDenied();
      expect(denied.permissionDenied, isTrue);
      expect(denied.isValid, isFalse);

      final unavail = BarcodeResult.cameraUnavailable();
      expect(unavail.cameraUnavailable, isTrue);
      expect(unavail.isValid, isFalse);
    });

    test('2. API response mapping to FoodItem model', () {
      final apiJson = {
        'status': 1,
        'product': {
          'product_name': 'Peanut Butter Smooth',
          'brands': 'Pintola',
          'serving_size': '32g',
          'nutriments': {
            'energy-kcal_100g': 625.0,
            'proteins_100g': 26.0,
            'carbohydrates_100g': 20.0,
            'fat_100g': 50.0,
            'fiber_100g': 6.0,
            'sugars_100g': 4.0,
            'sodium_100g': 0.15, // in grams -> should map to mg
          },
          'image_front_url': 'https://images.openfoodfacts.org/pb.jpg',
          'categories_tags': ['en:spreads', 'en:peanut-butters'],
        },
      };

      final food = RemoteFoodMapper.mapOpenFoodFactsToFoodItem(
        apiJson,
        '8906000000001',
      );
      expect(food, isNotNull);
      expect(food!.name, equals('Peanut Butter Smooth'));
      expect(food.brand, equals('Pintola'));
      expect(food.calories, equals(625.0));
      expect(food.protein, equals(26.0));
      expect(food.carbohydrates, equals(20.0));
      expect(food.fats, equals(50.0));
      expect(food.fiber, equals(6.0));
      expect(food.sugar, equals(4.0));
      expect(food.sodium, equals(150.0)); // 0.15g * 1000 = 150mg
      expect(food.imageUrl, equals('https://images.openfoodfacts.org/pb.jpg'));
      expect(food.isPackaged, isTrue);
    });

    test('3. Invalid API response handling (status 0 or missing product)', () {
      final invalidJson = {'status': 0, 'status_verbose': 'product not found'};
      final food = RemoteFoodMapper.mapOpenFoodFactsToFoodItem(
        invalidJson,
        '00000000',
      );
      expect(food, isNull);
    });

    test('4. Missing nutrition values handled safely', () {
      final partialJson = {
        'status': 1,
        'product': {'product_name': 'Mystery Snack', 'nutriments': {}},
      };

      final food = RemoteFoodMapper.mapOpenFoodFactsToFoodItem(
        partialJson,
        '11112222',
      );
      expect(food, isNotNull);
      expect(food!.name, equals('Mystery Snack'));
      expect(food.calories, equals(0.0));
      expect(food.protein, equals(0.0));
      expect(food.carbohydrates, equals(0.0));
      expect(food.fats, equals(0.0));
    });

    test('5. Local scanned caching works via LocalStorage', () async {
      const scannedItem = FoodItem(
        id: 'scanned_999888777',
        name: 'Oat Milk Barista',
        brand: 'Oatly',
        calories: 60.0,
        protein: 1.0,
        carbohydrates: 7.0,
        fats: 3.0,
        isPackaged: true,
        barcode: '999888777',
      );

      await repository.saveScannedFood(scannedItem);

      final cached = repository.getScannedFoods();
      expect(cached.length, equals(1));
      expect(cached.first.name, equals('Oat Milk Barista'));
      expect(cached.first.barcode, equals('999888777'));
    });

    test(
      '6 & 7. Offline fallback & Barcode lookup returns cached FoodItem',
      () async {
        const offlineFood = FoodItem(
          id: 'scanned_123456789',
          name: 'Dark Chocolate 85%',
          brand: 'Amul',
          calories: 550.0,
          protein: 8.0,
          carbohydrates: 30.0,
          fats: 42.0,
          barcode: '123456789',
        );

        await repository.saveScannedFood(offlineFood);

        // Search by barcode without calling remote network
        final match = await repository.searchByBarcode('123456789');
        expect(match, isNotNull);
        expect(match!.name, equals('Dark Chocolate 85%'));
        expect(match.brand, equals('Amul'));
      },
    );

    test(
      '8. Existing custom food system remains completely unaffected',
      () async {
        const customFood = FoodItem(
          id: 'custom_mizo_soup',
          name: 'Mizo Bamboo Soup',
          category: 'Mizo',
          calories: 120.0,
          protein: 6.0,
          isCustom: true,
        );

        await repository.addCustomFood(customFood);

        final customList = repository.getCustomFoods();
        expect(customList.any((f) => f.id == 'custom_mizo_soup'), isTrue);

        final allFoods = repository.getAllFoods();
        expect(allFoods.any((f) => f.id == 'custom_mizo_soup'), isTrue);
      },
    );
  });
}
