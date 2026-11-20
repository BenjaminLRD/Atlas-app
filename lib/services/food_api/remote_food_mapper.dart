import '../../models/food_item.dart';
import '../food_validation_service.dart';

/// Mapper utility parsing raw Open Food Facts API JSON into FoodItem model.
class RemoteFoodMapper {
  /// Converts an Open Food Facts product JSON map into a validated FoodItem instance.
  static FoodItem? mapOpenFoodFactsToFoodItem(
    Map<String, dynamic> json,
    String barcode,
  ) {
    final status = json['status'];
    if (status == 0 || json['product'] == null) {
      return null;
    }

    final rawProduct = json['product'];
    final Map product = rawProduct is Map ? rawProduct : const {};
    final rawNutriments = product['nutriments'];
    final Map nutriments = rawNutriments is Map ? rawNutriments : const {};

    final String name =
        (product['product_name'] as String?)?.trim().isNotEmpty == true
        ? (product['product_name'] as String).trim()
        : (product['product_name_en'] as String?)?.trim().isNotEmpty == true
        ? (product['product_name_en'] as String).trim()
        : 'Scanned Product ($barcode)';

    final String? brand =
        (product['brands'] as String?)?.trim().isNotEmpty == true
        ? (product['brands'] as String).trim().split(',').first
        : null;

    final String servingSizeRaw =
        (product['serving_size'] as String?)?.trim().isNotEmpty == true
        ? (product['serving_size'] as String).trim()
        : '100g';

    final String category =
        (product['categories_tags'] as List?)?.isNotEmpty == true
        ? _mapCategoryTag((product['categories_tags'] as List).first.toString())
        : 'Packaged';

    // Parse Calories (kcal)
    double calories =
        _parseDouble(nutriments['energy-kcal_100g']) ??
        _parseDouble(nutriments['energy-kcal']) ??
        _parseDouble(nutriments['energy-kcal_serving']) ??
        0.0;

    if (calories <= 0.0 && nutriments['energy_100g'] != null) {
      final kJ = _parseDouble(nutriments['energy_100g']) ?? 0.0;
      if (kJ > 0) calories = kJ / 4.184;
    }

    // Parse Macros (g)
    final double protein =
        _parseDouble(nutriments['proteins_100g']) ??
        _parseDouble(nutriments['proteins']) ??
        _parseDouble(nutriments['proteins_serving']) ??
        0.0;

    final double carbs =
        _parseDouble(nutriments['carbohydrates_100g']) ??
        _parseDouble(nutriments['carbohydrates']) ??
        _parseDouble(nutriments['carbohydrates_serving']) ??
        0.0;

    final double fats =
        _parseDouble(nutriments['fat_100g']) ??
        _parseDouble(nutriments['fat']) ??
        _parseDouble(nutriments['fat_serving']) ??
        0.0;

    // Parse Optional Micros
    final double? fiber =
        _parseDouble(nutriments['fiber_100g']) ??
        _parseDouble(nutriments['fiber']);
    final double? sugar =
        _parseDouble(nutriments['sugars_100g']) ??
        _parseDouble(nutriments['sugars']);

    // Sodium in Open Food Facts is usually stored in grams; convert g -> mg if value < 10
    double? sodiumRaw =
        _parseDouble(nutriments['sodium_100g']) ??
        _parseDouble(nutriments['sodium']);
    if (sodiumRaw != null && sodiumRaw < 10.0) {
      sodiumRaw = sodiumRaw * 1000.0; // convert grams to milligrams
    }

    final String imageUrl =
        (product['image_front_url'] as String?) ??
        (product['image_url'] as String?) ??
        (product['image_front_small_url'] as String?) ??
        '';

    final food = FoodItem(
      id: 'scanned_$barcode',
      name: name,
      brand: brand,
      category: category,
      servingSize: servingSizeRaw,
      servingUnit: 'grams',
      calories: calories.clamp(0.0, 10000.0),
      protein: protein.clamp(0.0, 1000.0),
      carbohydrates: carbs.clamp(0.0, 1000.0),
      fats: fats.clamp(0.0, 1000.0),
      fiber: fiber?.clamp(0.0, 500.0),
      sugar: sugar?.clamp(0.0, 500.0),
      sodium: sodiumRaw?.clamp(0.0, 100000.0),
      imageUrl: imageUrl,
      description: 'Scanned packaged product (Barcode: $barcode)',
      isCustom: false,
      isPackaged: true,
      barcode: barcode,
      altNames: [
        name.toLowerCase(),
        if (brand != null) brand.toLowerCase(),
        barcode,
      ],
    );

    final validation = FoodValidationService.validateCustomFood(food);
    if (!validation.isValid) {
      // Clean fallback for invalid macro numbers
      return food.copyWith(
        calories: calories.clamp(0.0, 10000.0),
        protein: protein.clamp(0.0, 1000.0),
        carbohydrates: carbs.clamp(0.0, 1000.0),
        fats: fats.clamp(0.0, 1000.0),
      );
    }

    return food;
  }

  static double? _parseDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

  static String _mapCategoryTag(String tag) {
    final t = tag.toLowerCase();
    if (t.contains('beverage') || t.contains('drink')) return 'Drinks';
    if (t.contains('snack') || t.contains('chip')) return 'Snacks';
    if (t.contains('fruit')) return 'Fruits';
    if (t.contains('vegetable')) return 'Vegetables';
    if (t.contains('cereal') || t.contains('grain')) return 'Grains';
    if (t.contains('dessert') || t.contains('sweet')) return 'Desserts';
    if (t.contains('dairy') || t.contains('meat') || t.contains('protein')) {
      return 'Protein';
    }
    return 'Packaged';
  }
}
