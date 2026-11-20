import '../models/food_item.dart';

/// Class containing validation status and descriptive error messages for custom foods.
class FoodValidationResult {
  final bool isValid;
  final List<String> errors;

  const FoodValidationResult({required this.isValid, required this.errors});

  factory FoodValidationResult.valid() =>
      const FoodValidationResult(isValid: true, errors: []);
  factory FoodValidationResult.invalid(List<String> errors) =>
      FoodValidationResult(isValid: false, errors: errors);
}

/// Service providing data validation for custom food entries.
class FoodValidationService {
  /// Validates a custom FoodItem instance according to nutrition data constraints.
  static FoodValidationResult validateCustomFood(FoodItem food) {
    final List<String> errors = [];

    // Name validation
    if (food.name.trim().isEmpty) {
      errors.add('Food name is required and cannot be empty.');
    }

    // Calories validation
    if (food.calories < 0) {
      errors.add('Calories cannot be negative.');
    }

    // Macros validation
    if (food.protein < 0) {
      errors.add('Protein cannot be negative.');
    }
    if (food.carbohydrates < 0) {
      errors.add('Carbohydrates cannot be negative.');
    }
    if (food.fats < 0) {
      errors.add('Fats cannot be negative.');
    }
    if (food.fiber != null && food.fiber! < 0) {
      errors.add('Fiber cannot be negative.');
    }
    if (food.sugar != null && food.sugar! < 0) {
      errors.add('Sugar cannot be negative.');
    }
    if (food.sodium != null && food.sodium! < 0) {
      errors.add('Sodium cannot be negative.');
    }

    // Serving size validation
    if (food.servingSize.trim().isEmpty) {
      errors.add('Serving size is required.');
    } else {
      final numericMatch = RegExp(
        r'(\d+(?:\.\d+)?)',
      ).firstMatch(food.servingSize);
      if (numericMatch != null) {
        final val = double.tryParse(numericMatch.group(1)!);
        if (val != null && val <= 0) {
          errors.add(
            'Serving size numeric quantity must be greater than zero.',
          );
        }
      }
    }

    if (errors.isEmpty) {
      return FoodValidationResult.valid();
    }
    return FoodValidationResult.invalid(errors);
  }
}
