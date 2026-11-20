import '../../models/food_item.dart';

/// Class containing scaled nutritional values based on portion quantity and unit.
class ScaledNutrition {
  final double quantity;
  final String unit;
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fats;
  final double? fiber;
  final double? sugar;
  final double? sodium;
  final double? saturatedFat;
  final double? salt;

  const ScaledNutrition({
    required this.quantity,
    required this.unit,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fats,
    this.fiber,
    this.sugar,
    this.sodium,
    this.saturatedFat,
    this.salt,
  });

  double get proteinGrams => protein;
  double get carbsGrams => carbohydrates;
  double get fatGrams => fats;
}

/// Food Portion Scaling Service
class NutritionCalculator {
  /// Calculates scaled nutrition values proportionally based on food item and portion quantity.
  static ScaledNutrition calculate(
    FoodItem food,
    double quantity, [
    String unit = 'grams',
  ]) {
    final double scaleFactor = getScaleFactor(food, quantity, unit);

    return ScaledNutrition(
      quantity: quantity,
      unit: unit,
      calories: food.calories * scaleFactor,
      protein: food.protein * scaleFactor,
      carbohydrates: food.carbohydrates * scaleFactor,
      fats: food.fats * scaleFactor,
      fiber: food.fiber != null ? food.fiber! * scaleFactor : null,
      sugar: food.sugar != null ? food.sugar! * scaleFactor : null,
      sodium: food.sodium != null ? food.sodium! * scaleFactor : null,
      saturatedFat: food.saturatedFat != null
          ? food.saturatedFat! * scaleFactor
          : null,
      salt: food.salt != null ? food.salt! * scaleFactor : null,
    );
  }

  static const Set<String> _massUnits = {'g', 'gr', 'gram', 'grams', 'kg'};
  static const Set<String> _volumeUnits = {'ml', 'l'};

  /// Whether [food] can be scaled by a quantity in [unit].
  ///
  /// Grams and millilitres are never interchangeable and no density is
  /// guessed: a per-100 g food refuses a volume unit (ml, l) and a per-100 ml
  /// food refuses a weight unit (g, kg). A food whose basis is unknown accepts
  /// any unit, as before. Units that are neither weight nor volume (piece,
  /// cup, serving...) keep their existing meaning, "the food's values for one
  /// such unit", for every food, so logging done that way still works.
  static bool isUnitCompatible(FoodItem food, String unit) {
    final u = unit.trim().toLowerCase();
    return switch (food.nutritionBasis) {
      NutritionBasis.per100g => !_volumeUnits.contains(u),
      NutritionBasis.per100ml => !_massUnits.contains(u),
      NutritionBasis.perServing ||
      NutritionBasis.perPackage => _referenceFactor(food, 1, u) != null,
      NutritionBasis.unknown => true,
    };
  }

  /// 'g' for a weight unit, 'ml' for a volume unit, null for anything else.
  static String? _dimension(String unit) {
    final u = unit.trim().toLowerCase();
    if (_massUnits.contains(u)) return 'g';
    if (_volumeUnits.contains(u)) return 'ml';
    return null;
  }

  /// For a per-serving or per-package food: how many servings (or packages)
  /// [quantity] [unit] is. A count (serving, package, piece...) is itself.
  /// A weight or volume needs the serving's (package's) own size in the same
  /// kind of unit; without it, or in the other kind, there is no answer, and
  /// grams are never read as millilitres. Null means it cannot be scaled.
  static double? _referenceFactor(FoodItem food, double quantity, String unit) {
    final dimension = _dimension(unit);
    if (dimension == null) return quantity;
    final perPackage = food.nutritionBasis == NutritionBasis.perPackage;
    final size = perPackage ? food.packageQuantity : food.servingQuantity;
    final sizeUnit = perPackage
        ? food.packageQuantityUnit
        : food.servingQuantityUnit;
    if (size == null || size <= 0 || sizeUnit != dimension) return null;
    final base = baseAmountPerUnit(unit) ?? 1.0;
    return quantity * base / size;
  }

  /// Like [calculate], but null when [unit] does not fit the food's basis
  /// (see [isUnitCompatible]).
  static ScaledNutrition? tryCalculate(
    FoodItem food,
    double quantity,
    String unit,
  ) => isUnitCompatible(food, unit) ? calculate(food, quantity, unit) : null;

  /// Reusable alias for calculate
  static ScaledNutrition calculateNutrition(
    FoodItem food,
    double quantity, [
    String unit = 'grams',
  ]) => calculate(food, quantity, unit);

  /// How many grams (for a weight unit) or millilitres (for a volume unit)
  /// one [unit] stands for: 1 for g and ml, 1000 for kg and l. Null for units
  /// that are neither weight nor volume (piece, cup, serving...). This is the
  /// only place kilograms and litres are converted.
  static double? baseAmountPerUnit(String unit) {
    switch (unit.trim().toLowerCase()) {
      case 'g':
      case 'gr':
      case 'gram':
      case 'grams':
      case 'ml':
        return 1.0;
      case 'kg':
      case 'l':
        return 1000.0;
    }
    return null;
  }

  /// Calculates the proportional scale factor relative to the base serving size.
  static double getScaleFactor(FoodItem food, double quantity, String unit) {
    if (food.nutritionBasis == NutritionBasis.perServing ||
        food.nutritionBasis == NutritionBasis.perPackage) {
      final factor = _referenceFactor(food, quantity, unit);
      if (factor != null) return factor.clamp(0.0, 1000.0);
      // Cannot be scaled: callers check isUnitCompatible first.
      return quantity.clamp(0.0, 1000.0);
    }
    // Weight and volume units: values are per 100 g / 100 ml, so 1 kg is 10.
    final base = baseAmountPerUnit(unit);
    if (base != null) {
      return ((quantity * base) / 100.0).clamp(0.0, 1000.0);
    }

    // Servings, pieces, cups, slices, bowls, packets, bottles, cans:
    // Base food values represent 1 serving unit
    return quantity.clamp(0.0, 1000.0);
  }
}
