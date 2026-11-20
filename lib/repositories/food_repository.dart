import '../models/food_item.dart';
import '../data/mock_food_database.dart';
import '../data/local_storage.dart';
import '../services/food_api/open_food_facts_service.dart';

/// Data source interface for built-in food catalog.
abstract class BuiltInFoodSource {
  List<FoodItem> getAllFoods();
  FoodItem? getFoodById(String id);
}

/// Local implementation of BuiltInFoodSource wrapping MockFoodDatabase.
class LocalBuiltInFoodSource implements BuiltInFoodSource {
  @override
  List<FoodItem> getAllFoods() => MockFoodDatabase.getAllFoods();

  @override
  FoodItem? getFoodById(String id) => MockFoodDatabase.getFoodById(id);
}

/// Data source interface for user-defined custom foods.
abstract class CustomFoodSource {
  List<FoodItem> getCustomFoods();
  Future<void> addCustomFood(FoodItem food);
  Future<void> updateCustomFood(FoodItem food);
  Future<void> deleteCustomFood(String foodId);
}

/// Local implementation of CustomFoodSource persisting to LocalStorage.
class LocalCustomFoodSource implements CustomFoodSource {
  @override
  List<FoodItem> getCustomFoods() {
    final rawList = LocalStorage.getCustomFoods();
    return rawList.map((json) => FoodItem.fromJson(json)).toList();
  }

  @override
  Future<void> addCustomFood(FoodItem food) async {
    final customList = getCustomFoods();
    final updated = [
      food.copyWith(isCustom: true),
      ...customList.where((f) => f.id != food.id),
    ];
    await LocalStorage.saveCustomFoods(updated.map((f) => f.toJson()).toList());
  }

  @override
  Future<void> updateCustomFood(FoodItem food) async {
    final customList = getCustomFoods();
    final updated = customList.map((f) => f.id == food.id ? food : f).toList();
    await LocalStorage.saveCustomFoods(updated.map((f) => f.toJson()).toList());
  }

  @override
  Future<void> deleteCustomFood(String foodId) async {
    final customList = getCustomFoods();
    final updated = customList.where((f) => f.id != foodId).toList();
    await LocalStorage.saveCustomFoods(updated.map((f) => f.toJson()).toList());
  }
}

/// Data source interface for user-scanned packaged foods.
abstract class ScannedFoodSource {
  List<FoodItem> getScannedFoods();
  FoodItem? getScannedFoodByBarcode(String barcode);
  Future<void> saveScannedFood(FoodItem food);
}

/// Local implementation of ScannedFoodSource persisting to LocalStorage.
class LocalScannedFoodSource implements ScannedFoodSource {
  @override
  List<FoodItem> getScannedFoods() {
    final rawList = LocalStorage.getScannedFoods();
    return rawList.map((json) => FoodItem.fromJson(json)).toList();
  }

  @override
  FoodItem? getScannedFoodByBarcode(String barcode) {
    final list = getScannedFoods();
    final clean = barcode.trim();
    try {
      return list.firstWhere(
        (f) => f.barcode == clean || f.id == 'scanned_$clean',
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveScannedFood(FoodItem food) async {
    final scannedList = getScannedFoods();
    final updated = [
      food,
      ...scannedList.where((f) => f.id != food.id && f.barcode != food.barcode),
    ];
    await LocalStorage.saveScannedFoods(
      updated.map((f) => f.toJson()).toList(),
    );
  }
}

/// Abstract data source interface for remote food database integrations (Open Food Facts).
abstract class RemoteFoodSource {
  Future<List<FoodItem>> searchRemote(String query);
  Future<FoodItem?> fetchRemoteById(String id);
  Future<FoodItem?> fetchRemoteByBarcode(String barcode);
}

/// Implementation of RemoteFoodSource connecting to OpenFoodFactsService.
class ApiRemoteFoodSource implements RemoteFoodSource {
  final OpenFoodFactsService? _offService;

  ApiRemoteFoodSource([OpenFoodFactsService? offService])
    : _offService = offService;

  @override
  Future<List<FoodItem>> searchRemote(String query) async => [];

  @override
  Future<FoodItem?> fetchRemoteById(String id) async => null;

  @override
  Future<FoodItem?> fetchRemoteByBarcode(String barcode) async {
    final service = _offService ?? HttpOpenFoodFactsService();
    return service.getProductByBarcode(barcode);
  }
}

/// Abstract Food Repository interface defining built-in, custom, scanned, favorite, and barcode operations.
abstract class FoodRepository {
  List<FoodItem> getAllFoods();
  List<FoodItem> searchFoods(String query, {String? category});
  List<FoodItem> filterByCategory(String category);
  FoodItem? getFoodById(String id);

  List<FoodItem> getFavorites();
  List<FoodItem> getFavoriteFoods();
  List<String> getFavoriteFoodIds();
  Future<void> toggleFavorite(String foodId);
  bool isFavorite(String foodId);

  List<FoodItem> getRecentFoods();
  List<String> getRecentFoodIds();
  Future<void> addRecentFood(String foodId);
  Future<void> recordRecentFood(String foodId);

  List<FoodItem> getCustomFoods();
  Future<void> addCustomFood(FoodItem food);
  Future<void> createCustomFood(FoodItem food);
  Future<void> updateCustomFood(FoodItem food);
  Future<void> deleteCustomFood(String foodId);

  List<FoodItem> getScannedFoods();
  Future<FoodItem?> searchByBarcode(String barcode);
  Future<FoodItem?> fetchRemoteFood(String barcode);
  Future<void> saveScannedFood(FoodItem food);
}

/// Local implementation of FoodRepository combining BuiltInFoodSource, CustomFoodSource, ScannedFoodSource, and RemoteFoodSource.
class LocalFoodRepository implements FoodRepository {
  final BuiltInFoodSource builtInSource;
  final CustomFoodSource customSource;
  final ScannedFoodSource scannedSource;
  final RemoteFoodSource remoteSource;

  LocalFoodRepository({
    BuiltInFoodSource? builtInSource,
    CustomFoodSource? customSource,
    ScannedFoodSource? scannedSource,
    RemoteFoodSource? remoteSource,
  }) : builtInSource = builtInSource ?? LocalBuiltInFoodSource(),
       customSource = customSource ?? LocalCustomFoodSource(),
       scannedSource = scannedSource ?? LocalScannedFoodSource(),
       remoteSource = remoteSource ?? ApiRemoteFoodSource();

  @override
  List<FoodItem> getAllFoods() {
    final builtIn = builtInSource.getAllFoods();
    final custom = customSource.getCustomFoods();
    final scanned = scannedSource.getScannedFoods();
    return [...scanned, ...custom, ...builtIn];
  }

  @override
  FoodItem? getFoodById(String id) {
    final all = getAllFoods();
    try {
      return all.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  List<FoodItem> getCustomFoods() => customSource.getCustomFoods();

  @override
  List<FoodItem> getScannedFoods() => scannedSource.getScannedFoods();

  @override
  Future<void> saveScannedFood(FoodItem food) async {
    await scannedSource.saveScannedFood(food);
  }

  @override
  Future<FoodItem?> fetchRemoteFood(String barcode) async {
    return remoteSource.fetchRemoteByBarcode(barcode);
  }

  @override
  Future<FoodItem?> searchByBarcode(String barcode) async {
    final clean = barcode.trim();
    if (clean.isEmpty) return null;

    // 1. Check local scanned cache
    // A cached item without any nutrition data (older versions saved missing
    // data as zeros) is not a usable hit: look it up again below.
    final localMatch = scannedSource.getScannedFoodByBarcode(clean);
    if (localMatch != null && !localMatch.nutritionUnavailable) {
      return localMatch;
    }

    // Check if custom or built-in foods match barcode
    final all = getAllFoods();
    try {
      final existingMatch = all.firstWhere(
        (f) => f.barcode == clean && !f.nutritionUnavailable,
      );
      return existingMatch;
    } catch (_) {}

    // 2. Query Remote Open Food Facts API
    final remoteFood = await fetchRemoteFood(clean);
    if (remoteFood != null) {
      // A product with no nutrition data is shown but not stored, so a later
      // scan can find updated data.
      if (!remoteFood.nutritionUnavailable) {
        await saveScannedFood(remoteFood);
      }
      return remoteFood;
    }

    return null;
  }

  @override
  Future<void> createCustomFood(FoodItem food) => addCustomFood(food);

  @override
  Future<void> addCustomFood(FoodItem food) async {
    final foodId = food.id.trim().isEmpty
        ? 'custom_${DateTime.now().millisecondsSinceEpoch}'
        : food.id;

    final prepared = food.copyWith(
      id: foodId,
      isCustom: true,
      isPackaged: food.brand != null && food.brand!.trim().isNotEmpty,
    );

    await customSource.addCustomFood(prepared);
  }

  @override
  Future<void> updateCustomFood(FoodItem food) async {
    // Ensure built-in food cannot be updated
    final isBuiltIn =
        builtInSource.getFoodById(food.id) != null && !food.isCustom;
    if (isBuiltIn) {
      throw UnsupportedError(
        'Built-in catalogue food items are immutable and cannot be modified.',
      );
    }
    await customSource.updateCustomFood(food);
  }

  @override
  Future<void> deleteCustomFood(String foodId) async {
    // Check if foodId belongs to built-in food
    final isBuiltIn = builtInSource.getFoodById(foodId) != null;
    final isCustomExist = customSource.getCustomFoods().any(
      (f) => f.id == foodId,
    );

    if (isBuiltIn && !isCustomExist) {
      throw UnsupportedError(
        'Built-in catalogue food items are immutable and cannot be deleted.',
      );
    }
    await customSource.deleteCustomFood(foodId);
  }

  @override
  List<String> getFavoriteFoodIds() => LocalStorage.getFavoriteFoodIds();

  @override
  Future<void> toggleFavorite(String foodId) async {
    final favorites = getFavoriteFoodIds();
    if (favorites.contains(foodId)) {
      favorites.remove(foodId);
    } else {
      favorites.insert(0, foodId);
    }
    await LocalStorage.saveFavoriteFoodIds(favorites);
  }

  @override
  bool isFavorite(String foodId) => getFavoriteFoodIds().contains(foodId);

  @override
  List<FoodItem> getFavorites() => getFavoriteFoods();

  @override
  List<FoodItem> getFavoriteFoods() {
    final ids = getFavoriteFoodIds();
    final all = getAllFoods();
    return all.where((f) => ids.contains(f.id)).toList();
  }

  @override
  List<String> getRecentFoodIds() => LocalStorage.getRecentFoodIds();

  @override
  Future<void> addRecentFood(String foodId) => recordRecentFood(foodId);

  @override
  Future<void> recordRecentFood(String foodId) async {
    final recents = getRecentFoodIds();
    recents.remove(foodId);
    recents.insert(0, foodId);
    if (recents.length > 20) {
      recents.removeLast();
    }
    await LocalStorage.saveRecentFoodIds(recents);
  }

  @override
  List<FoodItem> getRecentFoods() {
    final ids = getRecentFoodIds();
    final all = getAllFoods();
    final List<FoodItem> results = [];
    for (final id in ids) {
      final match = all.firstWhere(
        (f) => f.id == id,
        orElse: () => const FoodItem(id: '', name: '', calories: 0),
      );
      if (match.id.isNotEmpty) {
        results.add(match);
      }
    }
    return results;
  }

  @override
  List<FoodItem> filterByCategory(String category) {
    return searchFoods('', category: category);
  }

  @override
  List<FoodItem> searchFoods(String query, {String? category}) {
    final all = getAllFoods();
    final q = query.trim().toLowerCase();
    final cat = category?.trim().toLowerCase() ?? 'all';

    return all.where((food) {
      // Category filter check
      if (cat != 'all' && cat.isNotEmpty) {
        if (cat == 'custom' && !food.isCustom) return false;
        if (cat == 'packaged' && !food.isPackaged) return false;
        if (cat == 'favorites' && !isFavorite(food.id)) return false;
        if (cat == 'recent' && !getRecentFoodIds().contains(food.id)) {
          return false;
        }

        if (cat != 'custom' &&
            cat != 'packaged' &&
            cat != 'favorites' &&
            cat != 'recent') {
          final foodCat = food.category.toLowerCase();
          if (!foodCat.contains(cat)) return false;
        }
      }

      // Query search check
      if (q.isEmpty) return true;

      final nameMatch = food.name.toLowerCase().contains(q);
      final brandMatch = food.brand?.toLowerCase().contains(q) ?? false;
      final catMatch = food.category.toLowerCase().contains(q);
      final altMatch = food.altNames.any(
        (alt) => alt.toLowerCase().contains(q),
      );
      final descMatch = food.description.toLowerCase().contains(q);
      final barcodeMatch = food.barcode?.contains(q) ?? false;

      return nameMatch ||
          brandMatch ||
          catMatch ||
          altMatch ||
          descMatch ||
          barcodeMatch;
    }).toList();
  }
}
