import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/repositories/food_repository.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/services/food_validation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalFoodRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    repository = LocalFoodRepository();
  });

  group('Phase 2 — Custom Food System, Favorites & Recent Foods Tests', () {
    test('1. Creating custom food works', () async {
      const newFood = FoodItem(
        id: 'custom_bowl_01',
        name: 'Homemade Protein Bowl',
        category: 'Protein',
        servingSize: '1 bowl (300g)',
        servingUnit: 'bowl',
        calories: 450.0,
        protein: 35.0,
        carbohydrates: 40.0,
        fats: 12.0,
      );

      final valResult = FoodValidationService.validateCustomFood(newFood);
      expect(valResult.isValid, isTrue);

      await repository.addCustomFood(newFood);

      final customFoods = repository.getCustomFoods();
      expect(customFoods.length, equals(1));
      expect(customFoods.first.name, equals('Homemade Protein Bowl'));
      expect(customFoods.first.isCustom, isTrue);
    });

    test('2. Custom food receives unique ID if missing', () async {
      const foodWithoutId = FoodItem(
        id: '',
        name: 'Homemade Shake',
        calories: 250.0,
        protein: 25.0,
      );

      await repository.createCustomFood(foodWithoutId);

      final customList = repository.getCustomFoods();
      expect(customList.isNotEmpty, isTrue);
      expect(customList.first.id.startsWith('custom_'), isTrue);
      expect(customList.first.id.length, greaterThan('custom_'.length));
    });

    test('3. Custom food appears in search and category filter', () async {
      const customFood = FoodItem(
        id: 'custom_wrap_99',
        name: 'Special Chicken Wrap',
        brand: 'Aizawl Kitchen',
        category: 'Protein',
        servingSize: '1 wrap',
        calories: 380.0,
        protein: 28.0,
        isCustom: true,
      );

      await repository.addCustomFood(customFood);

      final searchResults = repository.searchFoods('Special');
      expect(searchResults.any((f) => f.id == 'custom_wrap_99'), isTrue);

      final categoryResults = repository.filterByCategory('custom');
      expect(categoryResults.any((f) => f.id == 'custom_wrap_99'), isTrue);
    });

    test(
      '4. Custom food persists after reload / new repository instance',
      () async {
        const persistentFood = FoodItem(
          id: 'custom_oats_001',
          name: 'Overnight Peanut Oats',
          calories: 350.0,
          protein: 15.0,
          isCustom: true,
        );

        await repository.addCustomFood(persistentFood);

        // Simulate app restart with new repository instance reading from same LocalStorage
        final newRepository = LocalFoodRepository();
        final loadedCustoms = newRepository.getCustomFoods();

        expect(loadedCustoms.length, equals(1));
        expect(loadedCustoms.first.id, equals('custom_oats_001'));
        expect(loadedCustoms.first.name, equals('Overnight Peanut Oats'));
      },
    );

    test('5. Updating custom food works', () async {
      const original = FoodItem(
        id: 'custom_smoothie_1',
        name: 'Green Smoothie',
        calories: 200.0,
        protein: 10.0,
        isCustom: true,
      );

      await repository.addCustomFood(original);

      final updated = original.copyWith(calories: 230.0, protein: 14.0);
      await repository.updateCustomFood(updated);

      final customList = repository.getCustomFoods();
      expect(customList.first.calories, equals(230.0));
      expect(customList.first.protein, equals(14.0));
    });

    test('6. Deleting custom food works', () async {
      const itemToDelete = FoodItem(
        id: 'custom_to_delete',
        name: 'Temporary Snack',
        calories: 100.0,
        isCustom: true,
      );

      await repository.addCustomFood(itemToDelete);
      expect(repository.getCustomFoods().length, equals(1));

      await repository.deleteCustomFood('custom_to_delete');
      expect(repository.getCustomFoods().isEmpty, isTrue);
    });

    test(
      '7. Built-in foods cannot be deleted (throws UnsupportedError)',
      () async {
        // protein_001 is built-in Chicken Breast
        expect(
          () async => await repository.deleteCustomFood('protein_001'),
          throwsA(isA<UnsupportedError>()),
        );
      },
    );

    test('8. Favorite toggle works (favoriting & unfavoriting)', () async {
      const foodId = 'protein_001';
      expect(repository.isFavorite(foodId), isFalse);

      await repository.toggleFavorite(foodId);
      expect(repository.isFavorite(foodId), isTrue);

      await repository.toggleFavorite(foodId);
      expect(repository.isFavorite(foodId), isFalse);
    });

    test('9. Favorite foods persist across app reload', () async {
      const foodId = 'protein_006'; // Whole Eggs
      await repository.toggleFavorite(foodId);

      final reloadedRepo = LocalFoodRepository();
      expect(reloadedRepo.isFavorite(foodId), isTrue);

      final favFoods = reloadedRepo.getFavoriteFoods();
      expect(favFoods.any((f) => f.id == foodId), isTrue);
    });

    test('10. Recent foods record correctly', () async {
      await repository.recordRecentFood('protein_001');
      await repository.recordRecentFood('fruit_001');

      final recents = repository.getRecentFoods();
      expect(recents.length, equals(2));
      expect(recents.first.id, equals('fruit_001'));
      expect(recents.last.id, equals('protein_001'));
    });

    test(
      '11. Recent foods avoid duplicates and move re-logged item to top',
      () async {
        await repository.recordRecentFood('protein_001');
        await repository.recordRecentFood('fruit_001');
        await repository.recordRecentFood(
          'protein_001',
        ); // Re-logging protein_001

        final recentIds = repository.getRecentFoodIds();
        expect(recentIds.length, equals(2));
        expect(recentIds.first, equals('protein_001'));
        expect(recentIds.last, equals('fruit_001'));
      },
    );

    test('12. Recent foods limit queue size to 20 items', () async {
      for (int i = 1; i <= 25; i++) {
        final id = 'food_id_$i';
        await repository.recordRecentFood(id);
      }

      final recentIds = repository.getRecentFoodIds();
      expect(recentIds.length, equals(20));
      expect(recentIds.first, equals('food_id_25'));
      expect(recentIds.contains('food_id_1'), isFalse);
    });
  });
}
