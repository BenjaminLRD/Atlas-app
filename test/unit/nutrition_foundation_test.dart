import 'package:flutter_test/flutter_test.dart';
import 'package:aizawl_gym/models/food_item.dart';
import 'package:aizawl_gym/models/consumed_food.dart';
import 'package:aizawl_gym/models/meal_entry.dart';
import 'package:aizawl_gym/data/mock_food_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FoodItem Model Tests', () {
    test('FoodItem initializes canonical and backwards compatible fields', () {
      const item = FoodItem(
        id: 'food_1',
        name: 'Chicken Breast',
        category: 'Protein',
        servingSize: '100g',
        calories: 165.0,
        protein: 31.0,
        carbohydrates: 0.0,
        fats: 3.6,
        imageUrl: 'https://example.com/chicken.jpg',
        description: 'Lean chicken breast',
      );

      expect(item.id, equals('food_1'));
      expect(item.name, equals('Chicken Breast'));
      expect(item.category, equals('Protein'));
      expect(item.protein, equals(31.0));
      expect(item.proteinGrams, equals(31.0));
      expect(item.carbohydrates, equals(0.0));
      expect(item.carbsGrams, equals(0.0));
      expect(item.fats, equals(3.6));
      expect(item.fatGrams, equals(3.6));
    });

    test('FoodItem.fromJson and toJson round trip', () {
      const item = FoodItem(
        id: 'food_2',
        name: 'Whole Eggs',
        category: 'Protein',
        servingSize: '100g',
        calories: 155.0,
        protein: 13.0,
        carbohydrates: 1.1,
        fats: 11.0,
      );

      final json = item.toJson();
      final roundTrip = FoodItem.fromJson(json);

      expect(roundTrip.id, equals('food_2'));
      expect(roundTrip.name, equals('Whole Eggs'));
      expect(roundTrip.calories, equals(155.0));
      expect(roundTrip.protein, equals(13.0));
    });
  });

  group('ConsumedFood Portion Scaling Tests', () {
    const baseChicken = FoodItem(
      id: 'food_chicken',
      name: 'Chicken Breast',
      category: 'Protein',
      servingSize: '100g',
      calories: 165.0,
      protein: 31.0,
      carbohydrates: 0.0,
      fats: 3.6,
    );

    test('100g portion yields base nutrition values', () {
      const consumed = ConsumedFood(
        food: baseChicken,
        quantity: 100.0,
        unit: 'grams',
      );

      expect(consumed.calories, equals(165.0));
      expect(consumed.protein, equals(31.0));
      expect(consumed.carbohydrates, equals(0.0));
      expect(consumed.fats, equals(3.6));
    });

    test('250g portion scales nutrition values by 2.5x', () {
      const consumed = ConsumedFood(
        food: baseChicken,
        quantity: 250.0,
        unit: 'grams',
      );

      expect(consumed.calories, closeTo(412.5, 0.01));
      expect(consumed.protein, closeTo(77.5, 0.01));
      expect(consumed.carbohydrates, equals(0.0));
      expect(consumed.fats, closeTo(9.0, 0.01));
    });

    test('ConsumedFood.fromJson and toJson round trip', () {
      const consumed = ConsumedFood(
        food: baseChicken,
        quantity: 200.0,
        unit: 'grams',
      );

      final json = consumed.toJson();
      final roundTrip = ConsumedFood.fromJson(json);

      expect(roundTrip.quantity, equals(200.0));
      expect(roundTrip.food.name, equals('Chicken Breast'));
      expect(roundTrip.protein, closeTo(62.0, 0.01));
    });
  });

  group('MealEntry Model Tests', () {
    test('MealEntry calculates total macros from ConsumedFoods', () {
      const chicken = FoodItem(
        id: '1',
        name: 'Chicken Breast',
        calories: 165.0,
        protein: 31.0,
        carbohydrates: 0.0,
        fats: 3.6,
      );

      const rice = FoodItem(
        id: '2',
        name: 'Steamed Rice',
        calories: 130.0,
        protein: 2.7,
        carbohydrates: 28.0,
        fats: 0.3,
      );

      final meal = MealEntry(
        id: 'meal_lunch',
        mealType: MealCategory.lunch,
        consumedFoods: const [
          ConsumedFood(food: chicken, quantity: 200.0, unit: 'grams'),
          ConsumedFood(food: rice, quantity: 150.0, unit: 'grams'),
        ],
      );

      expect(meal.totalCalories, closeTo(330.0 + 195.0, 0.01));
      expect(meal.totalProtein, closeTo(62.0 + 4.05, 0.01));
      expect(meal.totalCarbohydrates, closeTo(0.0 + 42.0, 0.01));
      expect(meal.totalFats, closeTo(7.2 + 0.45, 0.01));
      expect(meal.foods.length, equals(2));
      expect(meal.items.length, equals(2));
    });

    test('MealEntry fromJson and toJson round trip', () {
      final meal = MealEntry(
        id: 'meal_1',
        mealType: MealCategory.breakfast,
        consumedFoods: const [
          ConsumedFood(
            food: FoodItem(
              id: 'egg',
              name: 'Eggs',
              calories: 155.0,
              protein: 13.0,
              carbohydrates: 1.1,
              fats: 11.0,
            ),
            quantity: 100.0,
          ),
        ],
      );

      final json = meal.toJson();
      final roundTrip = MealEntry.fromJson(json);

      expect(roundTrip.id, equals('meal_1'));
      expect(roundTrip.mealType, equals(MealCategory.breakfast));
      expect(roundTrip.consumedFoods.length, equals(1));
      expect(roundTrip.totalCalories, equals(155.0));
    });
  });

  group('MockFoodDatabase Tests', () {
    test('getAllFoods returns non-empty list of structured foods', () {
      final foods = MockFoodDatabase.getAllFoods();
      expect(foods, isNotEmpty);
      expect(foods.length, greaterThanOrEqualTo(9));
    });

    test('getFoodsByCategory filters foods by macro category', () {
      final proteinFoods = MockFoodDatabase.getFoodsByCategory('Protein');
      final carbFoods = MockFoodDatabase.getFoodsByCategory('Carbohydrates');
      final fatFoods = MockFoodDatabase.getFoodsByCategory('Fats');

      expect(proteinFoods.any((f) => f.name == 'Chicken Breast'), isTrue);
      expect(carbFoods.any((f) => f.name == 'Steamed Rice'), isTrue);
      expect(fatFoods.any((f) => f.name == 'Peanut Butter'), isTrue);
    });

    test('searchFoods finds matching foods by query', () {
      final matches = MockFoodDatabase.searchFoods('chicken');
      expect(matches.length, equals(1));
      expect(matches.first.name, equals('Chicken Breast'));
    });
  });
}
