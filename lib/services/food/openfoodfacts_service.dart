import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../data/local_storage.dart';
import '../../models/food_item.dart';

/// Structured exception thrown on OpenFoodFacts API errors, invalid responses, or network disruptions.
class OpenFoodFactsException implements Exception {
  final String message;
  final int? statusCode;
  final bool isNetworkError;

  const OpenFoodFactsException({
    required this.message,
    this.statusCode,
    this.isNetworkError = false,
  });

  @override
  String toString() =>
      'OpenFoodFactsException: $message ${statusCode != null ? '(HTTP $statusCode)' : ''}';
}

/// Service providing live barcode nutrition lookup via OpenFoodFacts REST API v2
/// with local persistent caching, comprehensive nutrition parsing, and offline resilience.
class OpenFoodFactsService {
  static OpenFoodFactsService? _instance;
  final http.Client _httpClient;
  final Map<String, FoodItem> _inMemoryCache = {};

  /// Keep the version in step with `version:` in pubspec.yaml (a test checks it).
  static const String userAgent = 'Atlas/1.1.0 (lzadeng_be24@thapar.edu)';
  static const String baseUrl = 'https://world.openfoodfacts.org/api/v2/product';

  /// The only product fields the parser reads. Asking for just these keeps
  /// the answer small (a typical product has about 175 fields) without
  /// dropping anything the app uses.
  static const String requestedFields =
      'code,product_name,product_name_en,generic_name,generic_name_en,brands,'
      'brand_owner,serving_size,serving_quantity,nutrition_data_per,nutriments,'
      'image_front_url,image_url,image_front_small_url,ingredients_text,'
      'ingredients_text_en,categories_tags,'
      'quantity,product_quantity_unit,serving_quantity_unit';

  /// Longest the lookup waits for the database.
  static const Duration defaultTimeout = Duration(seconds: 10);

  final Duration _timeout;

  OpenFoodFactsService({http.Client? httpClient, Duration? timeout})
    : _httpClient = httpClient ?? http.Client(),
      _timeout = timeout ?? defaultTimeout;

  /// Global singleton accessor.
  static OpenFoodFactsService get instance =>
      _instance ??= OpenFoodFactsService();

  /// Inject custom instance (useful for unit tests).
  static void setInstance(OpenFoodFactsService service) {
    _instance = service;
  }

  /// Reset singleton instance.
  static void resetInstance() {
    _instance = null;
  }

  /// Look up a product by its barcode.
  ///
  /// Priority & Flow:
  /// 1. In-memory cache & LocalStorage cache
  /// 2. OpenFoodFacts REST API v2 query
  /// 3. Parse product name, brand, calories, protein, carbs, fat, serving size, ingredients
  /// 4. Cache newly discovered products locally
  /// 5. Never returns hardcoded fake food items
  Future<FoodItem?> getProductByBarcode(String barcode) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return null;

    // 1. Check in-memory and local persistent cache first
    final memory = _inMemoryCache[cleanBarcode];
    if (memory != null && !memory.nutritionUnavailable) return memory;

    try {
      final rawList = LocalStorage.getScannedFoods();
      for (final json in rawList) {
        final f = FoodItem.fromJson(json);
        if (f.barcode == cleanBarcode || f.id == 'scanned_$cleanBarcode') {
          // An item without nutrition data (older versions saved those as
          // zeros) is not a usable cache hit: ask the database again.
          if (f.nutritionUnavailable) break;
          _inMemoryCache[cleanBarcode] = f;
          return f;
        }
      }
    } catch (_) {
      // LocalStorage uninitialized or empty in pure unit tests
    }

    // 2. Query OpenFoodFacts API v2
    final url = Uri.parse(
      '$baseUrl/$cleanBarcode.json',
    ).replace(queryParameters: {'fields': requestedFields});

    try {
      final response = await _httpClient
          .get(
            url,
            headers: {
              'User-Agent': userAgent,
              'Accept': 'application/json',
            },
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final FoodItem? food;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is! Map<String, dynamic>) throw const FormatException();
          food = parseOpenFoodFactsProduct(decoded, cleanBarcode);
        } catch (_) {
          // Not JSON, not an object, or fields of the wrong type: an error,
          // not "product not found" and not a guess.
          throw const OpenFoodFactsException(
            message: 'The product database returned an unreadable response.',
            statusCode: 200,
          );
        }
        if (food != null && food.nutritionUnavailable) {
          // Name and brand only. Not cached, so a later scan can pick up
          // nutrition data once the database has it.
          return food;
        }
        if (food != null) {
          _inMemoryCache[cleanBarcode] = food;
          try {
            final rawList = LocalStorage.getScannedFoods();
            final updated = [
              food.toJson(),
              ...rawList.where(
                (json) =>
                    json['barcode'] != cleanBarcode &&
                    json['id'] != 'scanned_$cleanBarcode',
              ),
            ];
            await LocalStorage.saveScannedFoods(updated);
          } catch (_) {}
          return food;
        }
        return null;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw OpenFoodFactsException(
          message: 'Failed to retrieve product information.',
          statusCode: response.statusCode,
        );
      }
    } on SocketException catch (e) {
      debugPrint('[OpenFoodFactsService] Network error: $e');
      throw const OpenFoodFactsException(
        message: 'Network connection unavailable. Please check your internet.',
        isNetworkError: true,
      );
    } on http.ClientException catch (e) {
      debugPrint('[OpenFoodFactsService] Client exception: $e');
      throw OpenFoodFactsException(
        message: 'Unable to communicate with OpenFoodFacts server: $e',
        isNetworkError: true,
      );
    }
  }

  /// Alias matching repository naming.
  Future<FoodItem?> lookupBarcode(String barcode) =>
      getProductByBarcode(barcode);

  /// Parses OpenFoodFacts JSON response into a validated [FoodItem] domain model.
  FoodItem? parseOpenFoodFactsProduct(
    Map<String, dynamic> json,
    String barcode,
  ) {
    final status = json['status'];
    final productRaw = json['product'];
    if (status == 0 || productRaw == null || productRaw is! Map) {
      return null;
    }

    final product = Map<String, dynamic>.from(productRaw);
    final rawNutriments = product['nutriments'];
    final nutriments = rawNutriments is Map
        ? Map<String, dynamic>.from(rawNutriments)
        : <String, dynamic>{};

    // 1. Product Name
    final rawName =
        (product['product_name'] as String?)?.trim() ??
        (product['product_name_en'] as String?)?.trim() ??
        (product['generic_name'] as String?)?.trim() ??
        (product['generic_name_en'] as String?)?.trim();

    final name = (rawName != null && rawName.isNotEmpty)
        ? rawName
        : 'Product ($barcode)';

    // 2. Brand
    final rawBrand =
        (product['brands'] as String?)?.trim() ??
        (product['brand_owner'] as String?)?.trim();
    final brand = (rawBrand != null && rawBrand.isNotEmpty)
        ? rawBrand.split(',').first.trim()
        : null;

    // 3. Serving Size & Unit
    final rawServingSize = (product['serving_size'] as String?)?.trim();
    final servingSize = (rawServingSize != null && rawServingSize.isNotEmpty)
        ? rawServingSize
        : '100g';

    // 4. Ingredients
    final rawIngredients =
        (product['ingredients_text'] as String?)?.trim() ??
        (product['ingredients_text_en'] as String?)?.trim();
    final ingredients = (rawIngredients != null && rawIngredients.isNotEmpty)
        ? rawIngredients
        : null;

    // 5. Nutriments (Calories, Protein, Carbs, Fat). A value the database does
    // not have stays unknown; it is never turned into a real zero.
    final servingGrams = _servingGrams(product);
    final per = (product['nutrition_data_per'] as String?)?.trim();
    final valuesPer100g = per == null || per.isEmpty || per == '100g';

    final double? caloriesValue = _energyKcal(
      nutriments,
      servingGrams: servingGrams,
      valuesPer100g: valuesPer100g,
    );
    final double? proteinValue = _per100g(
      nutriments,
      'proteins',
      servingGrams: servingGrams,
      valuesPer100g: valuesPer100g,
    );
    final double? carbsValue = _per100g(
      nutriments,
      'carbohydrates',
      servingGrams: servingGrams,
      valuesPer100g: valuesPer100g,
    );
    final double? fatValue = _per100g(
      nutriments,
      'fat',
      servingGrams: servingGrams,
      valuesPer100g: valuesPer100g,
    );
    // When nothing is available per 100 g (and so nothing could be worked out
    // from a serving weight), values given only per serving are kept per
    // serving. They are never turned into per-100 figures, and never mixed
    // with per-100 ones in the same record.
    var perServing = false;
    var calValue = caloriesValue;
    var proValue = proteinValue;
    var carValue = carbsValue;
    var fatVal = fatValue;
    if (calValue == null &&
        proValue == null &&
        carValue == null &&
        fatVal == null) {
      final calS = _energyKcalPerServing(
        nutriments,
        valuesPer100g: valuesPer100g,
      );
      final proS = _perServing(
        nutriments,
        'proteins',
        valuesPer100g: valuesPer100g,
      );
      final carS = _perServing(
        nutriments,
        'carbohydrates',
        valuesPer100g: valuesPer100g,
      );
      final fatS = _perServing(nutriments, 'fat', valuesPer100g: valuesPer100g);
      if (calS != null || proS != null || carS != null || fatS != null) {
        perServing = true;
        calValue = calS;
        proValue = proS;
        carValue = carS;
        fatVal = fatS;
      }
    }
    final unknown = <String>{
      if (calValue == null) FoodItem.calorieKey,
      if (proValue == null) FoodItem.proteinKey,
      if (carValue == null) FoodItem.carbohydrateKey,
      if (fatVal == null) FoodItem.fatKey,
    };
    final double calories = calValue ?? 0.0;
    final double protein = proValue ?? 0.0;
    final double carbs = carValue ?? 0.0;
    final double fat = fatVal ?? 0.0;

    // The package and one serving, when the product states them with a unit.
    final package = _packageSize(product);
    final serving = _servingSize(product);

    // Optional Micronutrients
    final double? fiber =
        _parseDouble(nutriments['fiber_100g']) ??
        _parseDouble(nutriments['fiber']);
    final double? sugar =
        _parseDouble(nutriments['sugars_100g']) ??
        _parseDouble(nutriments['sugars']);

    final double? saturatedFat = _per100g(
      nutriments,
      'saturated-fat',
      servingGrams: servingGrams,
      valuesPer100g: valuesPer100g,
    );
    final double? salt = _per100g(
      nutriments,
      'salt',
      servingGrams: servingGrams,
      valuesPer100g: valuesPer100g,
    );

    double? sodiumRaw =
        _parseDouble(nutriments['sodium_100g']) ??
        _parseDouble(nutriments['sodium']);
    if (sodiumRaw != null && sodiumRaw < 10.0) {
      sodiumRaw = sodiumRaw * 1000.0; // g -> mg
    }

    // Image URLs
    final imageUrl =
        (product['image_front_url'] as String?) ??
        (product['image_url'] as String?) ??
        (product['image_front_small_url'] as String?) ??
        '';

    final category = _mapCategoryTag(
      (product['categories_tags'] as List?)?.firstOrNull?.toString() ?? '',
    );

    return FoodItem(
      id: 'scanned_$barcode',
      name: name,
      brand: brand,
      category: category,
      servingSize: servingSize,
      servingUnit: 'grams',
      calories: calories.clamp(0.0, 10000.0),
      protein: protein.clamp(0.0, 1000.0),
      carbohydrates: carbs.clamp(0.0, 1000.0),
      fats: fat.clamp(0.0, 1000.0),
      fiber: fiber?.clamp(0.0, 500.0),
      sugar: sugar?.clamp(0.0, 500.0),
      sodium: sodiumRaw?.clamp(0.0, 100000.0),
      saturatedFat: saturatedFat?.clamp(0.0, 1000.0),
      salt: salt?.clamp(0.0, 1000.0),
      imageUrl: imageUrl,
      description: ingredients != null ? 'Ingredients: $ingredients' : 'Scanned product ($barcode)',
      ingredients: ingredients,
      isCustom: false,
      isPackaged: true,
      barcode: barcode,
      altNames: [
        name.toLowerCase(),
        if (brand != null) brand.toLowerCase(),
        barcode,
      ],
      unknownNutrients: unknown,
      nutritionBasis: perServing
          ? NutritionBasis.perServing
          : _nutritionBasis(product),
      nutritionSource: NutritionSource.openFoodFacts,
      sourceUrl: 'https://world.openfoodfacts.org/product/$barcode',
      sourceMatch: SourceMatch.barcode,
      sourceRetrievedAt: DateTime.now(),
      packageQuantity: package?.value,
      packageQuantityUnit: package?.unit,
      servingQuantity: serving?.value,
      servingQuantityUnit: serving?.unit,
    );
  }

  /// What the nutrient numbers are per, taken only from the units the product
  /// itself states: the explicit unit fields, else the unit written in the
  /// serving size or the package quantity. A product that states grams is
  /// per 100 g, one that states millilitres is per 100 ml. Nothing stated,
  /// or grams and millilitres both stated, is unknown. A drink is never
  /// assumed to be in ml because of its category, and no density is used.
  static NutritionBasis _nutritionBasis(Map<String, dynamic> product) {
    final stated = <NutritionBasis>{};
    void add(NutritionBasis? basis) {
      if (basis != null) stated.add(basis);
    }

    add(_basisFromUnit(product['serving_quantity_unit']));
    add(_basisFromUnit(product['product_quantity_unit']));
    add(_basisFromText(product['serving_size']));
    add(_basisFromText(product['quantity']));
    return stated.length == 1 ? stated.first : NutritionBasis.unknown;
  }

  static NutritionBasis? _basisFromUnit(Object? unit) {
    if (unit is! String) return null;
    switch (unit.trim().toLowerCase()) {
      case 'g':
      case 'kg':
      case 'mg':
        return NutritionBasis.per100g;
      case 'ml':
      case 'cl':
      case 'dl':
      case 'l':
        return NutritionBasis.per100ml;
    }
    return null;
  }

  /// The unit in text such as "30 g", "330 ml", "1.5 L" or "6 x 33 cl".
  /// Units that are neither weight nor volume (pieces, ounces) give null.
  static NutritionBasis? _basisFromText(Object? text) {
    if (text is! String) return null;
    final match = RegExp(
      r'\d(?:[.,]\d+)?\s*(kg|mg|g|ml|cl|dl|l)(?![a-z])',
      caseSensitive: false,
    ).allMatches(text).map((m) => _basisFromUnit(m.group(1))).toSet();
    return match.length == 1 ? match.first : null;
  }

  /// The size of the whole package, with its unit (g or ml), when the product
  /// states one: the quantity if it has a unit, else the product quantity.
  static ({double value, String unit})? _packageSize(
    Map<String, dynamic> product,
  ) {
    final quantity = product['quantity'];
    if (quantity is String) {
      final parsed = parseSize(quantity);
      if (parsed != null) return parsed;
    }
    final pq = product['product_quantity'];
    final unit = product['product_quantity_unit'];
    if (pq != null && unit is String) return parseSize('$pq $unit');
    return null;
  }

  /// The size of one serving, with its unit (g or ml), when stated.
  static ({double value, String unit})? _servingSize(
    Map<String, dynamic> product,
  ) {
    final text = product['serving_size'];
    if (text is String) {
      final parsed = parseSize(text);
      if (parsed != null) return parsed;
    }
    final q = product['serving_quantity'];
    final unit = product['serving_quantity_unit'];
    if (q != null && unit is String) return parseSize('$q $unit');
    return null;
  }

  /// The first weight or volume in [text] ("750 ml", "1.25 l", "2ltr",
  /// "6 x 33 cl"), in g or ml. Null when there is none; a bare number is not
  /// a size.
  static ({double value, String unit})? parseSize(String text) {
    final m = _sizePattern.firstMatch(text);
    if (m == null) return null;
    final number = double.tryParse(m.group(1)!.replaceAll(',', '.'));
    if (number == null || number <= 0) return null;
    switch (m.group(2)!.toLowerCase()) {
      case 'ml':
        return (value: number, unit: 'ml');
      case 'cl':
        return (value: number * 10, unit: 'ml');
      case 'dl':
        return (value: number * 100, unit: 'ml');
      case 'l':
      case 'lt':
      case 'ltr':
      case 'ltrs':
      case 'litre':
      case 'litres':
      case 'liter':
      case 'liters':
        return (value: number * 1000, unit: 'ml');
      case 'g':
      case 'gm':
      case 'gms':
      case 'gr':
      case 'gram':
      case 'grams':
        return (value: number, unit: 'g');
      case 'kg':
        return (value: number * 1000, unit: 'g');
    }
    return null;
  }

  static final RegExp _sizePattern = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(ml|cl|dl|ltrs?|litres?|liters?|lt|l|kg|gms?|grams?|gr|g)(?![a-z])',
    caseSensitive: false,
  );

  /// [text] without any size written in it.
  static String withoutSize(String text) => text.replaceAll(_sizePattern, ' ');

  /// A nutrient per serving, or null: the per-serving value, else the plain
  /// value when the product's data is per serving.
  static double? _perServing(
    Map<String, dynamic> n,
    String key, {
    required bool valuesPer100g,
  }) =>
      _parseDouble(n['${key}_serving']) ??
      (valuesPer100g ? null : _parseDouble(n[key]));

  /// Calories per serving, from kcal or, if only kilojoules exist, converted.
  static double? _energyKcalPerServing(
    Map<String, dynamic> n, {
    required bool valuesPer100g,
  }) {
    final kcal = _perServing(n, 'energy-kcal', valuesPer100g: valuesPer100g);
    if (kcal != null && kcal > 0) return kcal;
    final kj =
        _parseDouble(n['energy-kj_serving']) ??
        _parseDouble(n['energy_serving']) ??
        (valuesPer100g
            ? null
            : (_parseDouble(n['energy-kj']) ?? _parseDouble(n['energy'])));
    if (kj != null && kj > 0) return kj / 4.184;
    return kcal;
  }

  /// Serving size in grams or millilitres, when the product states it.
  static double? _servingGrams(Map<String, dynamic> product) {
    final quantity = _parseDouble(product['serving_quantity']);
    if (quantity != null && quantity > 0) return quantity;
    final text = (product['serving_size'] as String?) ?? '';
    final match = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(?:g|gr|grams?|ml)(?![a-z])',
      caseSensitive: false,
    ).firstMatch(text);
    final parsed = double.tryParse(match?.group(1)?.replaceAll(',', '.') ?? '');
    return (parsed != null && parsed > 0) ? parsed : null;
  }

  /// A nutrient per 100 g/ml, or null when it cannot be known: the per-100g
  /// value if present, else the plain value when the product's data is per
  /// 100 g, else the per-serving value converted using the serving size.
  static double? _per100g(
    Map<String, dynamic> n,
    String key, {
    required double? servingGrams,
    required bool valuesPer100g,
  }) {
    final per100 = _parseDouble(n['${key}_100g']);
    if (per100 != null) return per100;
    if (valuesPer100g) {
      final plain = _parseDouble(n[key]);
      if (plain != null) return plain;
    }
    final perServing =
        _parseDouble(n['${key}_serving']) ??
        (valuesPer100g ? null : _parseDouble(n[key]));
    if (perServing != null && servingGrams != null) {
      return perServing * 100.0 / servingGrams;
    }
    return null;
  }

  /// Calories per 100 g, from kcal values or, if only kilojoules exist,
  /// converted from kJ. Null when neither is available.
  static double? _energyKcal(
    Map<String, dynamic> n, {
    required double? servingGrams,
    required bool valuesPer100g,
  }) {
    final kcal = _per100g(
      n,
      'energy-kcal',
      servingGrams: servingGrams,
      valuesPer100g: valuesPer100g,
    );
    if (kcal != null && kcal > 0) return kcal;

    double? kj = _parseDouble(n['energy-kj_100g']) ?? _parseDouble(n['energy_100g']);
    if (kj == null && valuesPer100g) {
      kj = _parseDouble(n['energy-kj']) ?? _parseDouble(n['energy']);
    }
    if (kj == null && servingGrams != null) {
      final perServing =
          _parseDouble(n['energy-kj_serving']) ??
          _parseDouble(n['energy_serving']);
      if (perServing != null) kj = perServing * 100.0 / servingGrams;
    }
    if (kj != null && kj > 0) return kj / 4.184;
    // A stated 0 kcal (and no kilojoules) is a real zero; no value is unknown.
    return kcal;
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
    if (t.contains('cereal') || t.contains('grain') || t.contains('bread')) {
      return 'Grains';
    }
    if (t.contains('dessert') || t.contains('sweet') || t.contains('chocolate')) {
      return 'Desserts';
    }
    if (t.contains('dairy') ||
        t.contains('milk') ||
        t.contains('meat') ||
        t.contains('protein') ||
        t.contains('fish')) {
      return 'Protein';
    }
    return 'Packaged';
  }
}
