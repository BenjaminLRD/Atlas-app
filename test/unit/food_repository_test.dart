import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/repositories/food_repository.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/services/nutrition/nutrition_calculator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalFoodRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    repository = LocalFoodRepository();
  });

  group('Phase 1 - FoodRepository & Database Expansion Tests', () {
    test('1. Built-in database contains 200+ food items', () {
      final foods = repository.getAllFoods();
      expect(foods.length, greaterThanOrEqualTo(200));
    });

    test('2. All food IDs in database are unique (no duplicates)', () {
      final foods = repository.getAllFoods();
      final ids = foods.map((f) => f.id).toList();
      final uniqueIds = ids.toSet();

      expect(ids.length, equals(uniqueIds.length));
    });

    test('3. Search works by food name (case-insensitive)', () {
      final results = repository.searchFoods('chicken');
      expect(results.isNotEmpty, isTrue);
      expect(
        results.any((f) => f.name.toLowerCase().contains('chicken')),
        isTrue,
      );
    });

    test('4. Search works by brand name', () {
      final laysResults = repository.searchFoods('Lays');
      expect(laysResults.isNotEmpty, isTrue);
      expect(laysResults.any((f) => f.brand?.toLowerCase() == 'lays'), isTrue);

      final quakerResults = repository.searchFoods('Quaker');
      expect(quakerResults.isNotEmpty, isTrue);
      expect(
        quakerResults.any(
          (f) => f.brand?.toLowerCase().contains('quaker') ?? false,
        ),
        isTrue,
      );
    });

    test('5. Search works by category', () {
      final mizoFoods = repository.filterByCategory('Mizo');
      expect(mizoFoods.isNotEmpty, isTrue);
      expect(mizoFoods.every((f) => f.category == 'Mizo'), isTrue);

      final dessertFoods = repository.filterByCategory('Desserts');
      expect(dessertFoods.isNotEmpty, isTrue);
      expect(dessertFoods.every((f) => f.category == 'Desserts'), isTrue);
    });

    test('6. Search works by alternate search names (altNames)', () {
      final vawkResults = repository.searchFoods('vawksa');
      expect(vawkResults.isNotEmpty, isTrue);
      expect(vawkResults.any((f) => f.id == 'mizo_004'), isTrue);

      final doodhResults = repository.searchFoods('doodh');
      expect(doodhResults.isNotEmpty, isTrue);
      expect(
        doodhResults.any(
          (f) => f.name.contains('Milk') || f.name.contains('Chai'),
        ),
        isTrue,
      );
    });

    test('7. Food retrieval by ID works correctly', () {
      final chicken = repository.getFoodById('protein_001');
      expect(chicken, isNotNull);
      expect(chicken!.name, equals('Chicken Breast'));
      expect(chicken.category, equals('Protein'));

      final missing = repository.getFoodById('non_existent_id');
      expect(missing, isNull);
    });

    test('8. Nutrition scaling calculation math works accurately', () {
      final chicken = repository.getFoodById('protein_001')!;
      final scaled250g = NutritionCalculator.calculateNutrition(
        chicken,
        250.0,
        'grams',
      );

      expect(scaled250g.calories, equals(412.5));
      expect(scaled250g.protein, equals(77.5));
      expect(scaled250g.carbohydrates, equals(0.0));
      expect(scaled250g.fats, equals(9.0));
    });

    test(
      '9. Repository architecture structure (BuiltInFoodSource, CustomFoodSource, RemoteFoodSource)',
      () async {
        expect(repository.builtInSource, isA<BuiltInFoodSource>());
        expect(repository.customSource, isA<CustomFoodSource>());
        expect(repository.remoteSource, isA<RemoteFoodSource>());

        // Test adding custom food via customSource/repository
        const customItem = FoodItem(
          id: 'custom_test_001',
          name: 'Custom Whey Shake',
          calories: 200.0,
          protein: 30.0,
          isCustom: true,
        );

        await repository.addCustomFood(customItem);
        expect(repository.getCustomFoods().length, equals(1));
        expect(repository.getFoodById('custom_test_001'), isNotNull);

        await repository.deleteCustomFood('custom_test_001');
        expect(repository.getCustomFoods().isEmpty, isTrue);
      },
    );
  });
}
