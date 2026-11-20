import 'nutrient_status.dart';

/// What the nutrient numbers of a [FoodItem] are measured per.
///
/// Grams and millilitres are never interchangeable: a drink's values are per
/// 100 ml, and nothing converts between the two (no density is guessed).
enum NutritionBasis {
  /// Values are per 100 g.
  per100g,

  /// Values are per 100 ml.
  per100ml,

  /// Values are for one serving (see [FoodItem.servingQuantity] for how much
  /// that is, when the source says).
  perServing,

  /// Values are for the whole package (see [FoodItem.packageQuantity]).
  perPackage,

  /// Not known, or not a per-100 g/ml basis (for example values for one
  /// piece or one bowl). It is never treated as grams.
  unknown;

  /// The value saved in JSON.
  String get jsonValue => name;

  /// Reads [jsonValue]; null for a missing key, [unknown] for anything else.
  static NutritionBasis? fromJsonValue(Object? raw) {
    if (raw == null) return null;
    for (final b in values) {
      if (b.name == raw) return b;
    }
    return unknown;
  }
}

/// Where a food's nutrition numbers come from.
enum NutritionSource {
  /// Typical values from the app's own food list. Not checked against a
  /// product record.
  builtIn,

  /// A product record from Open Food Facts.
  openFoodFacts,

  /// Estimated by AI from a photo. Not checked against anything.
  aiEstimate,

  /// Typed in or edited by the user.
  userEntry,

  /// Not recorded (foods saved before this was tracked).
  unknown;

  /// The value saved in JSON.
  String get jsonValue => name;

  /// Reads [jsonValue]; anything missing or unrecognised is [unknown], never
  /// a claimed source.
  static NutritionSource fromJsonValue(Object? raw) {
    for (final s in values) {
      if (s.name == raw) return s;
    }
    return unknown;
  }
}

/// How a database record was matched to the food the user has.
enum SourceMatch {
  /// Found by its barcode number.
  barcode,

  /// The one record that fits the brand, name, flavour and size.
  exactProduct,

  /// Picked by the user from a list of possible records.
  userSelected;

  String get jsonValue => name;

  /// Reads [jsonValue]; null for a missing or unrecognised value.
  static SourceMatch? fromJsonValue(Object? raw) {
    for (final m in values) {
      if (m.name == raw) return m;
    }
    return null;
  }
}

/// Model representing a food item with macronutrient details, optional brand, micronutrients, and custom/packaged flags.
class FoodItem {
  /// Names used in [unknownNutrients] and for the other nutrients.
  static const String sugarKey = 'sugar';
  static const String fiberKey = 'fiber';
  static const String sodiumKey = 'sodium';
  static const String saturatedFatKey = 'saturatedFat';
  static const String saltKey = 'salt';
  static const String calorieKey = 'calories';
  static const String proteinKey = 'protein';
  static const String carbohydrateKey = 'carbohydrates';
  static const String fatKey = 'fats';
  static const Set<String> coreNutrients = {
    calorieKey,
    proteinKey,
    carbohydrateKey,
    fatKey,
  };

  final String id;
  final String name;
  final String? brand;
  final String category;
  final String servingSize;
  final String servingUnit;
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fats;
  final double? fiber;
  final double? sugar;
  final double? sodium;

  /// Saturated fat and salt, in g. Null when not known, never a default 0.
  final double? saturatedFat;
  final double? salt;
  final String imageUrl;
  final String description;
  final String? ingredients;
  final bool isCustom;
  final bool isPackaged;
  final List<String> altNames;
  final String? barcode;

  /// What the nutrient numbers are per (see [NutritionBasis]). When not given
  /// it is worked out from older data: a built-in food (not custom, not a
  /// packaged or barcoded product) in grams or ml has that basis. Anything
  /// else is [NutritionBasis.unknown]: older versions labelled every scanned
  /// product "grams", including drinks, and a custom food's numbers are for
  /// the serving the user typed.
  final NutritionBasis nutritionBasis;

  /// Where the numbers come from (see [NutritionSource]).
  final NutritionSource nutritionSource;

  /// A page about the source record, for attribution (for example the Open
  /// Food Facts product page). Null when there is none.
  final String? sourceUrl;

  /// How the record was matched, and when it was retrieved. Null for foods
  /// that were not found in a database, and for ones saved before this was
  /// recorded.
  final SourceMatch? sourceMatch;
  final DateTime? sourceRetrievedAt;

  /// The size of the whole package and of one serving, in [packageQuantityUnit]
  /// / [servingQuantityUnit] ("g" or "ml"), when the source states them. Null
  /// when not stated: they are never guessed.
  final double? packageQuantity;
  final String? packageQuantityUnit;
  final double? servingQuantity;
  final String? servingQuantityUnit;

  /// Core nutrients (see [coreNutrients]) whose value is **not known**, for
  /// example because the product database has no data for them. The matching
  /// number (calories, protein, carbohydrates or fats) is a 0.0 placeholder
  /// and must not be shown or logged as a real zero. Empty for foods whose
  /// nutrition is known, including foods whose real value is 0.
  final Set<String> unknownNutrients;

  const FoodItem({
    required this.id,
    required this.name,
    this.brand,
    this.category = 'General',
    this.servingSize = '100g',
    this.servingUnit = 'grams',
    required this.calories,
    double? protein,
    double? proteinGrams,
    double? carbohydrates,
    double? carbsGrams,
    double? fats,
    double? fatGrams,
    this.fiber,
    this.sugar,
    this.sodium,
    this.saturatedFat,
    this.salt,
    this.imageUrl = '',
    this.description = '',
    this.ingredients,
    this.isCustom = false,
    this.isPackaged = false,
    this.altNames = const [],
    this.barcode,
    this.unknownNutrients = const {},
    NutritionBasis? nutritionBasis,
    this.nutritionSource = NutritionSource.unknown,
    this.sourceUrl,
    this.sourceMatch,
    this.sourceRetrievedAt,
    this.packageQuantity,
    this.packageQuantityUnit,
    this.servingQuantity,
    this.servingQuantityUnit,
  }) : nutritionBasis =
           nutritionBasis ??
           (isCustom || isPackaged || barcode != null
               ? NutritionBasis.unknown
               : servingUnit == 'ml'
               ? NutritionBasis.per100ml
               : (servingUnit == 'grams' || servingUnit == 'g')
               ? NutritionBasis.per100g
               : NutritionBasis.unknown),
       protein = protein ?? proteinGrams ?? 0.0,
       carbohydrates = carbohydrates ?? carbsGrams ?? 0.0,
       fats = fats ?? fatGrams ?? 0.0;

  // Backwards compatibility getters
  double get proteinGrams => protein;
  double get carbsGrams => carbohydrates;
  double get fatGrams => fats;
  String get ingredientsText => ingredients ?? description;

  bool isNutrientKnown(String nutrient) => !unknownNutrients.contains(nutrient);

  /// The per-basis amount of [nutrient], or null when it is not known. This is
  /// the one place that decides: a stored 0.0 placeholder is not a value.
  double? valueOf(String nutrient) {
    if (coreNutrients.contains(nutrient) &&
        unknownNutrients.contains(nutrient)) {
      return null;
    }
    return switch (nutrient) {
      calorieKey => calories,
      proteinKey => protein,
      carbohydrateKey => carbohydrates,
      fatKey => fats,
      sugarKey => sugar,
      fiberKey => fiber,
      sodiumKey => sodium,
      saturatedFatKey => saturatedFat,
      saltKey => salt,
      _ => null,
    };
  }

  /// What is known about [nutrient]: unknown, a known zero, a known value, or
  /// an unchecked AI estimate.
  NutrientStatus statusOf(String nutrient) {
    final value = valueOf(nutrient);
    if (value == null) return NutrientStatus.unknown;
    if (nutritionSource == NutritionSource.aiEstimate) {
      return NutrientStatus.estimate;
    }
    return value == 0 ? NutrientStatus.knownZero : NutrientStatus.known;
  }

  /// True when at least one core nutrient is unknown.
  bool get hasUnknownNutrition => unknownNutrients.isNotEmpty;

  /// True when the calories are unknown, so the food cannot be logged
  /// honestly as it is.
  bool get caloriesUnknown => unknownNutrients.contains(calorieKey);

  /// True when no core nutrient is known at all (a product with a name but no
  /// nutrition data).
  bool get nutritionUnavailable => unknownNutrients.containsAll(coreNutrients);

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    final rawAlt = json['altNames'] as List?;
    return FoodItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Food Item',
      brand: json['brand'] as String?,
      category: json['category'] as String? ?? 'General',
      servingSize: json['servingSize'] as String? ?? '100g',
      servingUnit: json['servingUnit'] as String? ?? 'grams',
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      protein:
          (json['protein'] as num?)?.toDouble() ??
          (json['proteinGrams'] as num?)?.toDouble() ??
          0.0,
      carbohydrates:
          (json['carbohydrates'] as num?)?.toDouble() ??
          (json['carbsGrams'] as num?)?.toDouble() ??
          0.0,
      fats:
          (json['fats'] as num?)?.toDouble() ??
          (json['fatGrams'] as num?)?.toDouble() ??
          0.0,
      fiber: (json['fiber'] as num?)?.toDouble(),
      sugar: (json['sugar'] as num?)?.toDouble(),
      sodium: (json['sodium'] as num?)?.toDouble(),
      saturatedFat: (json['saturatedFat'] as num?)?.toDouble(),
      salt: (json['salt'] as num?)?.toDouble(),
      imageUrl: json['imageUrl'] as String? ?? '',
      description: json['description'] as String? ?? '',
      ingredients: json['ingredients'] as String?,
      isCustom: json['isCustom'] as bool? ?? false,
      isPackaged: json['isPackaged'] as bool? ?? false,
      altNames: rawAlt != null
          ? rawAlt.map((e) => e.toString()).toList()
          : const [],
      barcode: json['barcode'] as String?,
      unknownNutrients: _unknownFromJson(json),
      // A missing key (an older save) is worked out by the constructor from
      // the saved unit; with no saved unit at all it is unknown. A value that
      // is present but not recognised stays unknown.
      nutritionBasis:
          NutritionBasis.fromJsonValue(json['nutritionBasis']) ??
          (json['servingUnit'] is String ? null : NutritionBasis.unknown),
      nutritionSource: NutritionSource.fromJsonValue(json['nutritionSource']),
      sourceUrl: json['sourceUrl'] as String?,
      sourceMatch: SourceMatch.fromJsonValue(json['sourceMatch']),
      sourceRetrievedAt: json['sourceRetrievedAt'] is String
          ? DateTime.tryParse(json['sourceRetrievedAt'] as String)
          : null,
      packageQuantity: (json['packageQuantity'] as num?)?.toDouble(),
      packageQuantityUnit: json['packageQuantityUnit'] as String?,
      servingQuantity: (json['servingQuantity'] as num?)?.toDouble(),
      servingQuantityUnit: json['servingQuantityUnit'] as String?,
    );
  }

  /// Reads which nutrients are unknown. Items saved before this field existed
  /// have no key: for them, a packaged barcode product (not edited by the
  /// user) whose four numbers are all exactly zero is treated as unknown,
  /// because older versions stored missing data as zeros.
  static Set<String> _unknownFromJson(Map<String, dynamic> json) {
    final raw = json['unknownNutrients'];
    if (raw is List) {
      return raw.map((e) => e.toString()).where(coreNutrients.contains).toSet();
    }
    final barcode = (json['barcode'] as String?)?.trim() ?? '';
    final scannedProduct =
        (json['isPackaged'] as bool? ?? false) &&
        barcode.isNotEmpty &&
        !(json['isCustom'] as bool? ?? false);
    if (!scannedProduct) return const {};
    double n(String a, [String? b]) =>
        (json[a] as num?)?.toDouble() ??
        (b == null ? null : (json[b] as num?)?.toDouble()) ??
        0.0;
    final allZero =
        n('calories') == 0 &&
        n('protein', 'proteinGrams') == 0 &&
        n('carbohydrates', 'carbsGrams') == 0 &&
        n('fats', 'fatGrams') == 0;
    return allZero ? coreNutrients : const {};
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (brand != null) 'brand': brand,
      'category': category,
      'servingSize': servingSize,
      'servingUnit': servingUnit,
      'calories': calories,
      'protein': protein,
      'carbohydrates': carbohydrates,
      'fats': fats,
      'proteinGrams': proteinGrams,
      'carbsGrams': carbsGrams,
      'fatGrams': fatGrams,
      if (fiber != null) 'fiber': fiber,
      if (sugar != null) 'sugar': sugar,
      if (sodium != null) 'sodium': sodium,
      if (saturatedFat != null) 'saturatedFat': saturatedFat,
      if (salt != null) 'salt': salt,
      'imageUrl': imageUrl,
      'description': description,
      if (ingredients != null) 'ingredients': ingredients,
      'isCustom': isCustom,
      'isPackaged': isPackaged,
      'altNames': altNames,
      if (barcode != null) 'barcode': barcode,
      // Always written (empty when everything is known) so a saved item is
      // never mistaken for an older one that stored missing data as zeros.
      'unknownNutrients': (unknownNutrients.toList()..sort()),
      'nutritionBasis': nutritionBasis.jsonValue,
      if (nutritionSource != NutritionSource.unknown)
        'nutritionSource': nutritionSource.jsonValue,
      if (sourceUrl != null) 'sourceUrl': sourceUrl,
      if (sourceMatch != null) 'sourceMatch': sourceMatch!.jsonValue,
      if (sourceRetrievedAt != null)
        'sourceRetrievedAt': sourceRetrievedAt!.toIso8601String(),
      if (packageQuantity != null) 'packageQuantity': packageQuantity,
      if (packageQuantityUnit != null)
        'packageQuantityUnit': packageQuantityUnit,
      if (servingQuantity != null) 'servingQuantity': servingQuantity,
      if (servingQuantityUnit != null)
        'servingQuantityUnit': servingQuantityUnit,
    };
  }

  FoodItem copyWith({
    String? id,
    String? name,
    String? brand,
    String? category,
    String? servingSize,
    String? servingUnit,
    double? calories,
    double? protein,
    double? carbohydrates,
    double? fats,
    double? proteinGrams,
    double? carbsGrams,
    double? fatGrams,
    double? fiber,
    double? sugar,
    double? sodium,
    double? saturatedFat,
    double? salt,
    String? imageUrl,
    String? description,
    String? ingredients,
    bool? isCustom,
    bool? isPackaged,
    List<String>? altNames,
    String? barcode,
    Set<String>? unknownNutrients,
    NutritionBasis? nutritionBasis,
    NutritionSource? nutritionSource,
    String? sourceUrl,
    SourceMatch? sourceMatch,
    DateTime? sourceRetrievedAt,
    double? packageQuantity,
    String? packageQuantityUnit,
    double? servingQuantity,
    String? servingQuantityUnit,
  }) {
    // A nutrient given a new value is no longer unknown, unless the caller
    // says otherwise.
    final stillUnknown = unknownNutrients ?? {...this.unknownNutrients};
    if (unknownNutrients == null) {
      if (calories != null) stillUnknown.remove(calorieKey);
      if (protein != null || proteinGrams != null) {
        stillUnknown.remove(proteinKey);
      }
      if (carbohydrates != null || carbsGrams != null) {
        stillUnknown.remove(carbohydrateKey);
      }
      if (fats != null || fatGrams != null) stillUnknown.remove(fatKey);
    }
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      category: category ?? this.category,
      servingSize: servingSize ?? this.servingSize,
      servingUnit: servingUnit ?? this.servingUnit,
      calories: calories ?? this.calories,
      protein: protein ?? proteinGrams ?? this.protein,
      carbohydrates: carbohydrates ?? carbsGrams ?? this.carbohydrates,
      fats: fats ?? fatGrams ?? this.fats,
      fiber: fiber ?? this.fiber,
      sugar: sugar ?? this.sugar,
      sodium: sodium ?? this.sodium,
      saturatedFat: saturatedFat ?? this.saturatedFat,
      salt: salt ?? this.salt,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      ingredients: ingredients ?? this.ingredients,
      isCustom: isCustom ?? this.isCustom,
      isPackaged: isPackaged ?? this.isPackaged,
      altNames: altNames ?? this.altNames,
      barcode: barcode ?? this.barcode,
      unknownNutrients: stillUnknown,
      nutritionBasis: nutritionBasis ?? this.nutritionBasis,
      nutritionSource: nutritionSource ?? this.nutritionSource,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sourceMatch: sourceMatch ?? this.sourceMatch,
      sourceRetrievedAt: sourceRetrievedAt ?? this.sourceRetrievedAt,
      packageQuantity: packageQuantity ?? this.packageQuantity,
      packageQuantityUnit: packageQuantityUnit ?? this.packageQuantityUnit,
      servingQuantity: servingQuantity ?? this.servingQuantity,
      servingQuantityUnit: servingQuantityUnit ?? this.servingQuantityUnit,
    );
  }
}
