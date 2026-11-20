import 'package:http/http.dart' as http;
import '../data/local_storage.dart';
import '../data/mock_food_database.dart';
import '../models/food_analysis_result.dart';
import '../models/food_item.dart';
import 'food_api/open_food_facts_service.dart';

/// Central database service providing unified access to built-in foods, local cache, custom items, and OpenFoodFacts API
class FoodDatabaseService {
  static FoodDatabaseService? _instance;
  final OpenFoodFactsService _openFoodFactsService;

  FoodDatabaseService({
    OpenFoodFactsService? openFoodFactsService,
    http.Client? httpClient,
  }) : _openFoodFactsService =
           openFoodFactsService ?? HttpOpenFoodFactsService(httpClient);

  static FoodDatabaseService get instance {
    _instance ??= FoodDatabaseService();
    return _instance!;
  }

  // ==========================================
  // 1. BARCODE & REMOTE LOOKUP (OpenFoodFacts)
  // ==========================================

  /// Looks up a product by barcode. Follows strict priority:
  /// 1. Local scanned cache (user confirmed data)
  /// 2. OpenFoodFacts API (live external database)
  Future<FoodItem?> lookupBarcode(String barcode) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return null;

    // 1. Check local scanned products first
    final localScanned = getScannedFoods();
    try {
      final cached = localScanned.firstWhere(
        (f) => f.barcode == cleanBarcode || f.id == 'scanned_$cleanBarcode',
      );
      return cached;
    } catch (_) {
      // Not in local cache, proceed to remote API
    }

    // 2. Fetch from live OpenFoodFacts API
    try {
      final remoteProduct = await _openFoodFactsService.getProductByBarcode(
        cleanBarcode,
      );
      if (remoteProduct != null) {
        // Cache to local scanned foods for offline retrieval
        await saveScannedProduct(remoteProduct);
        return remoteProduct;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  /// Converts a verified barcode product lookup into a [FoodAnalysisResult]
  Future<FoodAnalysisResult?> analyzeBarcode(
    String barcode, {
    double portionQuantity = 100.0,
  }) async {
    final product = await lookupBarcode(barcode);
    if (product == null) return null;

    return FoodAnalysisResult.fromFoodItem(
      product,
      portionQuantity: portionQuantity,
      source: FoodSource.barcodeDatabase,
    );
  }

  // ==========================================
  // 2. LOCAL CATALOG & CACHE MANAGEMENT
  // ==========================================

  /// Returns all available foods combining built-in catalog, scanned items, and custom foods
  List<FoodItem> getAllFoods() {
    final custom = getCustomFoods();
    final scanned = getScannedFoods();
    final builtIn = MockFoodDatabase.defaultFoods;

    final Map<String, FoodItem> uniqueMap = {};
    for (final f in custom) {
      uniqueMap[f.id] = f;
    }
    for (final f in scanned) {
      uniqueMap[f.id] = f;
    }
    for (final f in builtIn) {
      if (!uniqueMap.containsKey(f.id)) {
        uniqueMap[f.id] = f;
      }
    }

    return uniqueMap.values.toList();
  }

  /// Searches foods by name/query and optional category
  List<FoodItem> searchFoods(String query, {String? category}) {
    final cleanQuery = query.trim().toLowerCase();
    final all = getAllFoods();

    return all.where((food) {
      final matchesCategory =
          category == null ||
          category.isEmpty ||
          category.toLowerCase() == 'all' ||
          food.category.toLowerCase() == category.toLowerCase();

      if (!matchesCategory) return false;
      if (cleanQuery.isEmpty) return true;

      final nameMatch = food.name.toLowerCase().contains(cleanQuery);
      final brandMatch =
          food.brand?.toLowerCase().contains(cleanQuery) ?? false;
      final altMatch = food.altNames.any(
        (alt) => alt.toLowerCase().contains(cleanQuery),
      );

      return nameMatch || brandMatch || altMatch;
    }).toList();
  }

  /// Returns list of recently consumed food items
  List<FoodItem> getRecentFoods() {
    final ids = LocalStorage.getRecentFoodIds();
    final all = getAllFoods();
    final Map<String, FoodItem> map = {for (final f in all) f.id: f};
    return ids.map((id) => map[id]).whereType<FoodItem>().toList();
  }

  /// Adds a food item to recent foods cache
  Future<void> addRecentFood(FoodItem food) async {
    final ids = LocalStorage.getRecentFoodIds();
    final updated = [
      food.id,
      ...ids.where((id) => id != food.id),
    ].take(30).toList();
    await LocalStorage.saveRecentFoodIds(updated);
  }

  /// Returns list of user's favorite foods
  List<FoodItem> getFavoriteFoods() {
    final ids = LocalStorage.getFavoriteFoodIds();
    final all = getAllFoods();
    final Map<String, FoodItem> map = {for (final f in all) f.id: f};
    return ids.map((id) => map[id]).whereType<FoodItem>().toList();
  }

  /// Toggles favorite status for a food item
  Future<void> toggleFavorite(FoodItem food) async {
    final ids = LocalStorage.getFavoriteFoodIds();
    final isFav = ids.contains(food.id);
    List<String> updated;

    if (isFav) {
      updated = ids.where((id) => id != food.id).toList();
    } else {
      updated = [food.id, ...ids];
    }

    await LocalStorage.saveFavoriteFoodIds(updated);
  }

  /// Returns list of scanned products persisted locally
  List<FoodItem> getScannedFoods() {
    final raw = LocalStorage.getScannedFoods();
    return raw.map((json) => FoodItem.fromJson(json)).toList();
  }

  /// Persists a scanned product to local cache
  Future<void> saveScannedProduct(FoodItem food) async {
    final scanned = getScannedFoods();
    final updated = [
      food,
      ...scanned.where(
        (f) =>
            f.id != food.id && (f.barcode == null || f.barcode != food.barcode),
      ),
    ];
    await LocalStorage.saveScannedFoods(
      updated.map((f) => f.toJson()).toList(),
    );
  }

  /// Returns list of user-created custom foods
  List<FoodItem> getCustomFoods() {
    final raw = LocalStorage.getCustomFoods();
    return raw.map((json) => FoodItem.fromJson(json)).toList();
  }

  /// Saves a custom food item
  Future<void> addCustomFood(FoodItem food) async {
    final custom = getCustomFoods();
    final updated = [
      food.copyWith(isCustom: true),
      ...custom.where((f) => f.id != food.id),
    ];
    await LocalStorage.saveCustomFoods(updated.map((f) => f.toJson()).toList());
  }

  /// Updates an existing custom food item
  Future<void> updateCustomFood(FoodItem food) async {
    final custom = getCustomFoods();
    final updated = custom.map((f) => f.id == food.id ? food : f).toList();
    await LocalStorage.saveCustomFoods(updated.map((f) => f.toJson()).toList());
  }

  /// Deletes a custom food item
  Future<void> deleteCustomFood(String foodId) async {
    final custom = getCustomFoods();
    final updated = custom.where((f) => f.id != foodId).toList();
    await LocalStorage.saveCustomFoods(updated.map((f) => f.toJson()).toList());
  }
}
