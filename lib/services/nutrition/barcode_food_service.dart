import '../../data/app_dependencies.dart';
import '../../models/food_item.dart';
import 'nutrition_service.dart';

/// Centralized service interface for food barcode & QR lookup.
abstract class BarcodeFoodService {
  /// Looks up product details and nutrition info by [barcode].
  /// Returns null if barcode is empty, invalid, or not found in local/remote databases.
  Future<FoodItem?> lookupBarcode(String barcode);
}

/// Default implementation querying local database, cached items, and Open Food Facts.
class DefaultBarcodeFoodService implements BarcodeFoodService {
  final NutritionService _nutritionService;

  /// Uses the app's shared [NutritionService] unless one is given, the same
  /// one the app state works through.
  DefaultBarcodeFoodService({NutritionService? nutritionService})
    : _nutritionService =
          nutritionService ?? AppDependencies.instance.nutritionService;

  @override
  Future<FoodItem?> lookupBarcode(String barcode) async {
    final clean = barcode.trim();
    if (clean.isEmpty) return null;

    // Queries local cache, custom foods, and remote Open Food Facts API via repository
    return await _nutritionService.searchByBarcode(clean);
  }
}
