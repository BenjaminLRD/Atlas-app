import '../services/nutrition/nutrition_calculator.dart';
import 'food_item.dart';

/// Model representing a specific portion/quantity of a FoodItem consumed by the user.
class ConsumedFood {
  final FoodItem food;
  final double quantity;
  final String unit;

  /// 1 for entries saved before kilograms and litres were converted (they
  /// counted "1 kg" as one 100 g portion); 2 for the current rule. Saved
  /// entries keep their version so past totals are not rewritten.
  final int scalingVersion;

  /// The scaling rule new entries use.
  static const int currentScalingVersion = 2;

  const ConsumedFood({
    required this.food,
    this.quantity = 100.0,
    this.unit = 'grams',
    this.scalingVersion = currentScalingVersion,
  });

  /// Whether the food has a value for [nutrient] (see
  /// [FoodItem.coreNutrients]). When not, its number here is a 0 placeholder.
  bool isKnown(String nutrient) => food.isNutrientKnown(nutrient);

  /// False when the food's calories are unknown: [calories] is then a 0
  /// placeholder and must not be shown or counted as a real 0 kcal.
  bool get caloriesKnown => food.isNutrientKnown(FoodItem.calorieKey);

  /// Scale factor based on standard 100g base or 1 serving unit
  double get _scaleFactor {
    // Per-serving and per-package foods exist only in entries made with the
    // current rule, and have their own scaling.
    if (food.nutritionBasis == NutritionBasis.perServing ||
        food.nutritionBasis == NutritionBasis.perPackage) {
      return NutritionCalculator.getScaleFactor(
        food,
        quantity,
        unit,
      ).clamp(0.0, 100.0);
    }
    final lowerUnit = unit.toLowerCase();
    if (lowerUnit == 'grams' || lowerUnit == 'g' || lowerUnit == 'ml') {
      return (quantity / 100.0).clamp(0.0, 100.0);
    }
    if (scalingVersion >= 2) {
      final base = NutritionCalculator.baseAmountPerUnit(unit);
      if (base != null) return (quantity * base / 100.0).clamp(0.0, 100.0);
    }
    return quantity.clamp(0.0, 100.0);
  }

  /// Computed calories scaled by consumed portion
  double get calories => food.calories * _scaleFactor;

  /// Computed protein in grams scaled by consumed portion
  double get protein => food.protein * _scaleFactor;

  /// Computed carbohydrates in grams scaled by consumed portion
  double get carbohydrates => food.carbohydrates * _scaleFactor;

  /// Computed fats in grams scaled by consumed portion
  double get fats => food.fats * _scaleFactor;

  // Backwards compatibility getters
  double get proteinGrams => protein;
  double get carbsGrams => carbohydrates;
  double get fatGrams => fats;

  factory ConsumedFood.fromJson(Map<String, dynamic> json) {
    final foodJson = json['food'] as Map<String, dynamic>? ?? {};
    return ConsumedFood(
      food: FoodItem.fromJson(foodJson),
      quantity: (json['quantity'] as num?)?.toDouble() ?? 100.0,
      unit: json['unit'] as String? ?? 'grams',
      scalingVersion: (json['scalingVersion'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'food': food.toJson(),
      'quantity': quantity,
      'unit': unit,
      'scalingVersion': scalingVersion,
      'calories': calories,
      'protein': protein,
      'carbohydrates': carbohydrates,
      'fats': fats,
    };
  }

  ConsumedFood copyWith({FoodItem? food, double? quantity, String? unit}) {
    return ConsumedFood(
      food: food ?? this.food,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      // A new quantity or unit is entered under the current rule.
      scalingVersion: quantity != null || unit != null
          ? currentScalingVersion
          : scalingVersion,
    );
  }
}
