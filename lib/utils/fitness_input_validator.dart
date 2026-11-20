/// Result container for input validation checks
class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult({required this.isValid, this.errorMessage});

  factory ValidationResult.valid() => const ValidationResult(isValid: true);

  factory ValidationResult.invalid(String message) =>
      ValidationResult(isValid: false, errorMessage: message);
}

/// Comprehensive input validation for user profiles, biometrics, weight goals, and barcode categories.
class FitnessInputValidator {
  // --- 1. User Biometric Profile Bounds ---

  /// Validates user height in centimeters (Allowed: 100cm - 250cm)
  static ValidationResult validateHeight(double? heightCm) {
    if (heightCm == null) {
      return ValidationResult.invalid('Height cannot be empty.');
    }
    if (heightCm < 100.0 || heightCm > 250.0) {
      return ValidationResult.invalid(
        'Please enter a realistic height between 100cm and 250cm.',
      );
    }
    return ValidationResult.valid();
  }

  /// Validates user weight in kilograms (Allowed: 20kg - 300kg)
  static ValidationResult validateWeight(double? weightKg) {
    if (weightKg == null) {
      return ValidationResult.invalid('Weight cannot be empty.');
    }
    if (weightKg < 20.0 || weightKg > 300.0) {
      return ValidationResult.invalid(
        'Please enter a realistic weight between 20kg and 300kg.',
      );
    }
    return ValidationResult.valid();
  }

  /// Validates user age in years (Allowed: 13 - 100)
  static ValidationResult validateAge(int? age) {
    if (age == null) {
      return ValidationResult.invalid('Age cannot be empty.');
    }
    if (age < 13 || age > 100) {
      return ValidationResult.invalid(
        'Please enter a realistic age between 13 and 100.',
      );
    }
    return ValidationResult.valid();
  }

  // --- 2. Goal Pace & Feasibility Validation ---

  /// Validates whether a target weight goal timeline is physiologically realistic and safe.
  static ValidationResult validateWeightGoal({
    required double currentWeight,
    required double targetWeight,
    required int durationWeeks,
  }) {
    if (durationWeeks <= 0) {
      return ValidationResult.invalid('Goal timeline must be at least 1 week.');
    }

    final totalDelta = (targetWeight - currentWeight).abs();
    final ratePerWeek = totalDelta / durationWeeks;

    // Maximum safe physiological rate is 1.0kg / week
    if (ratePerWeek > 1.0) {
      return ValidationResult.invalid(
        'Your goal is unrealistic.\n\nRecommended safe pace:\n0.25kg - 1kg per week.',
      );
    }

    return ValidationResult.valid();
  }

  // --- 3. Barcode Product Category Validation ---

  static const List<String> allowedFoodCategories = [
    'food',
    'beverage',
    'drink',
    'supplement',
    'nutrition',
    'snack',
    'dairy',
    'meat',
    'produce',
    'bakery',
    'cereal',
    'grain',
    'fruit',
    'vegetable',
    'poultry',
    'seafood',
    'oil',
    'condiment',
    'sauce',
    'protein powder',
  ];

  static const List<String> nonFoodCategories = [
    'electronics',
    'electronic',
    'clothing',
    'apparel',
    'cosmetics',
    'beauty',
    'skincare',
    'household',
    'cleaning',
    'hardware',
    'books',
    'toys',
    'shoes',
    'furniture',
  ];

  /// Validates whether a barcode product belongs to an edible food/beverage/supplement category.
  static ValidationResult validateBarcodeCategory(String? categoryName) {
    if (categoryName == null || categoryName.trim().isEmpty) {
      return ValidationResult.valid(); // Allow with manual review if category tag is absent
    }

    final lower = categoryName.toLowerCase().trim();

    // Check non-food rejection
    if (nonFoodCategories.any((rejected) => lower.contains(rejected))) {
      return ValidationResult.invalid(
        'This barcode does not belong to a food product.',
      );
    }

    return ValidationResult.valid();
  }
}
