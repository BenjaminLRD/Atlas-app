import 'food_item.dart';

/// Model representing a specific portion/quantity of a FoodItem consumed by the user.
class ConsumedFood {
  final FoodItem food;
  final double quantity;
  final String unit;

  const ConsumedFood({
    required this.food,
    this.quantity = 100.0,
    this.unit = 'grams',
  });

  /// Scale factor based on standard 100g base or 1 serving unit
  double get _scaleFactor {
    final lowerUnit = unit.toLowerCase();
    if (lowerUnit == 'grams' || lowerUnit == 'g' || lowerUnit == 'ml') {
      return (quantity / 100.0).clamp(0.0, 100.0);
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'food': food.toJson(),
      'quantity': quantity,
      'unit': unit,
      'calories': calories,
      'protein': protein,
      'carbohydrates': carbohydrates,
      'fats': fats,
    };
  }

  ConsumedFood copyWith({
    FoodItem? food,
    double? quantity,
    String? unit,
  }) {
    return ConsumedFood(
      food: food ?? this.food,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
    );
  }
}
