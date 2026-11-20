import 'food_item.dart';

/// Enum representing the origin source of a food analysis or scan
enum FoodSource { cameraAI, galleryAI, barcodeDatabase, manualEntry }

/// Structured model representing the nutritional analysis of a scanned or manually entered food item
class FoodAnalysisResult {
  final String foodName;
  final double confidence; // Range 0.0 to 1.0 (e.g. 0.85 = 85%)
  final double servingSize;
  final String servingUnit;
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fats;
  final List<String> detectedIngredients;
  final bool isAiGenerated;
  final DateTime timestamp;
  final String? brand;
  final String? barcode;
  final String? notes;

  /// A flavour or edition read from the label ("Zero Sugar"), if any.
  final String? variant;

  /// True when the photo shows a branded, packaged product. Its portion is
  /// then the whole pack or an AI guess, never a measured amount.
  final bool isPackagedProduct;

  /// A pack size the model read as printed text on the label (already in g or
  /// ml). Used only to find the product, never shown as a verified size.
  final double? labelPackageSize;
  final String? labelPackageUnit;

  /// A barcode number the model read from the photo, kept only when its check
  /// digit is right. Used to find the product, never trusted on its own.
  final String? readBarcode;

  /// Core nutrients (see [FoodItem.coreNutrients]) the model did not give, or
  /// gave as exactly 0. A zero from a photo is not a measurement, so it is
  /// unknown, never a real 0. Their numbers are 0.0 placeholders only.
  final Set<String> unknownNutrients;

  const FoodAnalysisResult({
    required this.foodName,
    this.confidence = 1.0,
    this.servingSize = 100.0,
    this.servingUnit = 'g',
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fats,
    List<String>? ingredients,
    List<String> detectedIngredients = const [],
    this.isAiGenerated = false,
    required this.timestamp,
    this.brand,
    this.barcode,
    this.notes,
    this.variant,
    this.isPackagedProduct = false,
    this.labelPackageSize,
    this.labelPackageUnit,
    this.readBarcode,
    this.unknownNutrients = const {},
  }) : detectedIngredients = ingredients ?? detectedIngredients;

  /// Convenience getter matching standard API specification
  List<String> get ingredients => detectedIngredients;

  /// Alias for confidence score
  double get confidenceScore => confidence;

  /// Confidence level categorization helper
  String get confidenceLevel {
    if (confidence >= 0.8) return 'High';
    if (confidence >= 0.5) return 'Medium';
    return 'Low';
  }

  bool get requiresVerification => confidence < 0.5;

  /// Labels an AI *photo* estimate may carry.
  static const String photoLevelLow = 'Low';
  static const String photoLevelUnverified = 'Unverified';

  /// What the app may say about an AI photo estimate. The model's confidence
  /// number is its own unchecked opinion (a successful answer or a recognized
  /// food name proves nothing), so it is never turned into "High": below 0.5
  /// the estimate is flagged [photoLevelLow], otherwise it is only
  /// [photoLevelUnverified]. Verified package or database data is a different
  /// thing and does not use these labels.
  String get photoEstimateLevel =>
      confidence < 0.5 ? photoLevelLow : photoLevelUnverified;

  /// Factory for a clean empty/zero state result
  factory FoodAnalysisResult.empty() {
    return FoodAnalysisResult(
      foodName: '',
      confidence: 0.0,
      servingSize: 100.0,
      servingUnit: 'g',
      calories: 0.0,
      protein: 0.0,
      carbohydrates: 0.0,
      fats: 0.0,
      detectedIngredients: const [],
      isAiGenerated: false,
      timestamp: DateTime.now(),
    );
  }

  /// Scales all caloric and macronutrient values to a new portion size
  FoodAnalysisResult scaledToPortion(double newServingSize) {
    if (servingSize <= 0 || newServingSize <= 0) return this;
    final ratio = newServingSize / servingSize;
    return copyWith(
      servingSize: newServingSize,
      calories: double.parse((calories * ratio).toStringAsFixed(1)),
      protein: double.parse((protein * ratio).toStringAsFixed(1)),
      carbohydrates: double.parse((carbohydrates * ratio).toStringAsFixed(1)),
      fats: double.parse((fats * ratio).toStringAsFixed(1)),
    );
  }

  /// Converts this analysis result into a reusable [FoodItem] normalized to 100g/1-unit base
  FoodItem toFoodItem({String? customId}) {
    final lowerUnit = servingUnit.toLowerCase();
    final isGrams =
        lowerUnit == 'g' || lowerUnit == 'grams' || lowerUnit == 'ml';
    // The values below are normalised to per 100 g / ml, so that is the basis.
    // A portion in cups, pieces and so on has values for one such unit.
    final basis = lowerUnit == 'ml'
        ? NutritionBasis.per100ml
        : (isGrams ? NutritionBasis.per100g : NutritionBasis.perServing);
    final baseFactor = isGrams
        ? (servingSize > 0 ? 100.0 / servingSize : 1.0)
        : (servingSize > 0 ? 1.0 / servingSize : 1.0);

    return FoodItem(
      id:
          customId ??
          (barcode != null && barcode!.isNotEmpty
              ? 'barcode_$barcode'
              : 'food_${DateTime.now().millisecondsSinceEpoch}'),
      name: foodName,
      brand: brand,
      category: isAiGenerated ? 'AI Scanned' : 'Scanned Product',
      servingSize: '${servingSize.toStringAsFixed(0)}$servingUnit',
      servingUnit: servingUnit,
      calories: calories * baseFactor,
      protein: protein * baseFactor,
      carbohydrates: carbohydrates * baseFactor,
      fats: fats * baseFactor,
      barcode: barcode,
      isPackaged: barcode != null && barcode!.isNotEmpty,
      isCustom: true,
      description: detectedIngredients.isNotEmpty
          ? 'Ingredients: ${detectedIngredients.join(', ')}'
          : (notes ?? ''),
      ingredients: detectedIngredients.isNotEmpty
          ? detectedIngredients.join(', ')
          : null,
      unknownNutrients: unknownNutrients,
      nutritionBasis: basis,
      nutritionSource: isAiGenerated
          ? NutritionSource.aiEstimate
          : NutritionSource.unknown,
    );
  }

  /// Creates a [FoodAnalysisResult] from a verified [FoodItem]
  factory FoodAnalysisResult.fromFoodItem(
    FoodItem food, {
    double portionQuantity = 100.0,
    String? portionUnit,
    FoodSource source = FoodSource.barcodeDatabase,
  }) {
    final unit = portionUnit ?? food.servingUnit;
    final ratio =
        (unit.toLowerCase() == 'g' ||
            unit.toLowerCase() == 'grams' ||
            unit.toLowerCase() == 'ml')
        ? (portionQuantity / 100.0)
        : portionQuantity;

    return FoodAnalysisResult(
      foodName: food.name,
      brand: food.brand,
      confidence: 1.0,
      servingSize: portionQuantity,
      servingUnit: unit,
      calories: double.parse((food.calories * ratio).toStringAsFixed(1)),
      protein: double.parse((food.protein * ratio).toStringAsFixed(1)),
      carbohydrates: double.parse(
        (food.carbohydrates * ratio).toStringAsFixed(1),
      ),
      fats: double.parse((food.fats * ratio).toStringAsFixed(1)),
      detectedIngredients: food.description.isNotEmpty
          ? [food.description]
          : const [],
      isAiGenerated:
          source == FoodSource.cameraAI || source == FoodSource.galleryAI,
      barcode: food.barcode,
      timestamp: DateTime.now(),
      // What the food does not know stays unknown in the scan.
      unknownNutrients: food.unknownNutrients,
    );
  }

  FoodAnalysisResult copyWith({
    String? foodName,
    double? confidence,
    double? servingSize,
    String? servingUnit,
    double? calories,
    double? protein,
    double? carbohydrates,
    double? fats,
    List<String>? ingredients,
    List<String>? detectedIngredients,
    bool? isAiGenerated,
    DateTime? timestamp,
    String? brand,
    String? barcode,
    String? notes,
    String? variant,
    bool? isPackagedProduct,
    double? labelPackageSize,
    String? labelPackageUnit,
    String? readBarcode,
    Set<String>? unknownNutrients,
  }) {
    return FoodAnalysisResult(
      foodName: foodName ?? this.foodName,
      confidence: confidence ?? this.confidence,
      servingSize: servingSize ?? this.servingSize,
      servingUnit: servingUnit ?? this.servingUnit,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbohydrates: carbohydrates ?? this.carbohydrates,
      fats: fats ?? this.fats,
      detectedIngredients:
          ingredients ?? detectedIngredients ?? this.detectedIngredients,
      isAiGenerated: isAiGenerated ?? this.isAiGenerated,
      timestamp: timestamp ?? this.timestamp,
      brand: brand ?? this.brand,
      barcode: barcode ?? this.barcode,
      notes: notes ?? this.notes,
      variant: variant ?? this.variant,
      isPackagedProduct: isPackagedProduct ?? this.isPackagedProduct,
      labelPackageSize: labelPackageSize ?? this.labelPackageSize,
      labelPackageUnit: labelPackageUnit ?? this.labelPackageUnit,
      readBarcode: readBarcode ?? this.readBarcode,
      unknownNutrients: unknownNutrients ?? this.unknownNutrients,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'foodName': foodName,
      'confidence': confidence,
      'servingSize': servingSize,
      'servingUnit': servingUnit,
      'calories': calories,
      'protein': protein,
      'carbohydrates': carbohydrates,
      'fats': fats,
      'ingredients': detectedIngredients,
      'detectedIngredients': detectedIngredients,
      'isAiGenerated': isAiGenerated,
      'timestamp': timestamp.toIso8601String(),
      if (brand != null) 'brand': brand,
      if (barcode != null) 'barcode': barcode,
      if (notes != null) 'notes': notes,
      if (variant != null) 'variant': variant,
      if (isPackagedProduct) 'isPackagedProduct': true,
      if (labelPackageSize != null) 'labelPackageSize': labelPackageSize,
      if (labelPackageUnit != null) 'labelPackageUnit': labelPackageUnit,
      if (readBarcode != null) 'readBarcode': readBarcode,
      if (unknownNutrients.isNotEmpty)
        'unknownNutrients': (unknownNutrients.toList()..sort()),
    };
  }

  factory FoodAnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawIngredients =
        (json['ingredients'] as List?) ??
        (json['detectedIngredients'] as List?);

    return FoodAnalysisResult(
      foodName: json['foodName'] as String? ?? 'Food Item',
      confidence: ((json['confidence'] ?? json['confidenceScore']) as num?)?.toDouble() ?? 1.0,
      servingSize: (json['servingSize'] as num?)?.toDouble() ?? 100.0,
      servingUnit: json['servingUnit'] as String? ?? 'g',
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      carbohydrates: (json['carbohydrates'] as num?)?.toDouble() ?? 0.0,
      fats: (json['fats'] as num?)?.toDouble() ?? 0.0,
      detectedIngredients:
          rawIngredients?.map((e) => e.toString()).toList() ?? const [],
      isAiGenerated: json['isAiGenerated'] as bool? ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      brand: json['brand'] as String?,
      barcode: json['barcode'] as String?,
      notes: json['notes'] as String?,
      variant: json['variant'] as String?,
      isPackagedProduct: json['isPackagedProduct'] as bool? ?? false,
      labelPackageSize: (json['labelPackageSize'] as num?)?.toDouble(),
      labelPackageUnit: json['labelPackageUnit'] as String?,
      readBarcode: json['readBarcode'] as String?,
      // Saved unknowns, plus any number the record lacks: a missing number is
      // unknown, not the 0 the constructor above falls back to.
      unknownNutrients: {
        ...((json['unknownNutrients'] as List?) ?? const [])
            .map((e) => e.toString())
            .where(FoodItem.coreNutrients.contains),
        if (json['calories'] is! num) FoodItem.calorieKey,
        if (json['protein'] is! num) FoodItem.proteinKey,
        if (json['carbohydrates'] is! num) FoodItem.carbohydrateKey,
        if (json['fats'] is! num) FoodItem.fatKey,
      },
    );
  }
}

/// Tracks a food scanning session instance with telemetry and results
class FoodScanSession {
  final String id;
  final FoodSource source;
  final String? imagePath;
  final String? barcode;
  final FoodAnalysisResult? result;
  final DateTime createdAt;

  const FoodScanSession({
    required this.id,
    required this.source,
    this.imagePath,
    this.barcode,
    this.result,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source': source.name,
      'imagePath': imagePath,
      'barcode': barcode,
      'result': result?.toJson(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FoodScanSession.fromJson(Map<String, dynamic> json) {
    return FoodScanSession(
      id:
          json['id'] as String? ??
          'session_${DateTime.now().millisecondsSinceEpoch}',
      source: FoodSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => FoodSource.manualEntry,
      ),
      imagePath: json['imagePath'] as String?,
      barcode: json['barcode'] as String?,
      result: json['result'] != null
          ? FoodAnalysisResult.fromJson(
              Map<String, dynamic>.from(json['result'] as Map),
            )
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
