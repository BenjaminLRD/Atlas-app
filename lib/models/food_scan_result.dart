import '../services/nutrition/nutrition_calculator.dart';
import 'food_item.dart';

/// Type of scan performed for food recognition
enum FoodScanType { aiVision, barcodeOrQr }

/// How a database product came to be the result of a photo scan.
enum ProductMatchKind {
  /// The only record that fits the brand, name, variant and size.
  exactProduct,

  /// One the user picked from a list of plausible records.
  userSelected,
}

/// Structured model representing the outcome of a food scan (AI Photo Vision or Barcode/QR)
class FoodScanResult {
  final FoodScanType scanType;
  final FoodItem food;
  final double estimatedQuantity;
  final String estimatedUnit;
  final String
  confidence; // 'High', 'Medium', 'Low', or 'Unverified' (AI photo)

  /// The model's own confidence number (0 to 1) for an AI estimate. Kept as
  /// reported; it is not verified.
  final double? modelConfidence;
  final String? rawResponse;
  final String? barcode;
  final String? notes;
  final bool isAiEstimate;
  final DateTime timestamp;

  /// False while the amount is only a guess or a database record's size that
  /// the user has not checked against what they have. It must be confirmed
  /// before the food is logged.
  final bool portionConfirmed;

  /// Set when the food is a database product found from a photo.
  final ProductMatchKind? matchKind;

  /// A line about how the lookup went, shown with the result.
  final String? lookupNote;

  FoodScanResult({
    required this.scanType,
    required this.food,
    this.estimatedQuantity = 100.0,
    this.estimatedUnit = 'g',
    this.confidence = 'Medium',
    this.modelConfidence,
    this.rawResponse,
    this.barcode,
    this.notes,
    bool? isAiEstimate,
    DateTime? timestamp,
    this.portionConfirmed = true,
    this.matchKind,
    this.lookupNote,
  }) : isAiEstimate = isAiEstimate ?? (scanType == FoodScanType.aiVision),
       timestamp = timestamp ?? DateTime.now();

  /// Whether [nutrient] (see [FoodItem.coreNutrients]) has a real value. An
  /// unknown one must be shown as a dash, never as 0.
  bool isKnown(String nutrient) => food.isNutrientKnown(nutrient);

  /// False when no amount is set, so no totals can be worked out.
  bool get portionKnown => estimatedQuantity > 0;

  /// How many of the food's reference amounts (100 g, 100 ml, one serving or
  /// one package) the estimated portion is. The calculator is the one place
  /// that decides.
  double get _scale => NutritionCalculator.getScaleFactor(
    food,
    estimatedQuantity,
    estimatedUnit,
  );

  /// Computed total calories for the estimated portion
  double get estimatedCalories => food.calories * _scale;

  /// Computed total protein (g) for the estimated portion
  double get estimatedProtein => food.protein * _scale;

  /// Computed total carbohydrates (g) for the estimated portion
  double get estimatedCarbs => food.carbohydrates * _scale;

  /// Computed total fats (g) for the estimated portion
  double get estimatedFats => food.fats * _scale;

  /// Whether the calories roughly agree with the macros (about 4 kcal per
  /// gram of protein and carbohydrate, 9 per gram of fat). A large gap means
  /// the numbers do not add up (or the food has alcohol or fibre) and should
  /// be checked; it is a warning, not a correction.
  bool get caloriesMatchMacros {
    // With a value missing there is nothing to compare.
    if (food.hasUnknownNutrition) return true;
    final calories = estimatedCalories;
    if (calories < 30) return true;
    final fromMacros =
        4 * estimatedProtein + 4 * estimatedCarbs + 9 * estimatedFats;
    final tolerance = calories * 0.35 > 20 ? calories * 0.35 : 20.0;
    return (calories - fromMacros).abs() <= tolerance;
  }

  FoodScanResult copyWith({
    FoodScanType? scanType,
    FoodItem? food,
    double? estimatedQuantity,
    String? estimatedUnit,
    String? confidence,
    double? modelConfidence,
    String? rawResponse,
    String? barcode,
    String? notes,
    bool? isAiEstimate,
    DateTime? timestamp,
    bool? portionConfirmed,
    ProductMatchKind? matchKind,
    String? lookupNote,
  }) {
    return FoodScanResult(
      scanType: scanType ?? this.scanType,
      food: food ?? this.food,
      estimatedQuantity: estimatedQuantity ?? this.estimatedQuantity,
      estimatedUnit: estimatedUnit ?? this.estimatedUnit,
      confidence: confidence ?? this.confidence,
      modelConfidence: modelConfidence ?? this.modelConfidence,
      rawResponse: rawResponse ?? this.rawResponse,
      barcode: barcode ?? this.barcode,
      notes: notes ?? this.notes,
      isAiEstimate: isAiEstimate ?? this.isAiEstimate,
      timestamp: timestamp ?? this.timestamp,
      portionConfirmed: portionConfirmed ?? this.portionConfirmed,
      matchKind: matchKind ?? this.matchKind,
      lookupNote: lookupNote ?? this.lookupNote,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'scanType': scanType.name,
      'food': food.toJson(),
      'estimatedQuantity': estimatedQuantity,
      'estimatedUnit': estimatedUnit,
      'confidence': confidence,
      if (rawResponse != null) 'rawResponse': rawResponse,
      if (barcode != null) 'barcode': barcode,
      if (notes != null) 'notes': notes,
      'isAiEstimate': isAiEstimate,
      'timestamp': timestamp.toIso8601String(),
      if (!portionConfirmed) 'portionConfirmed': false,
      if (matchKind != null) 'matchKind': matchKind!.name,
      if (lookupNote != null) 'lookupNote': lookupNote,
    };
  }

  factory FoodScanResult.fromJson(Map<String, dynamic> json) {
    return FoodScanResult(
      scanType: json['scanType'] == 'barcodeOrQr'
          ? FoodScanType.barcodeOrQr
          : FoodScanType.aiVision,
      food: FoodItem.fromJson(json['food'] as Map<String, dynamic>? ?? {}),
      estimatedQuantity:
          (json['estimatedQuantity'] as num?)?.toDouble() ?? 100.0,
      estimatedUnit: json['estimatedUnit'] as String? ?? 'g',
      confidence: json['confidence'] as String? ?? 'Medium',
      rawResponse: json['rawResponse'] as String?,
      barcode: json['barcode'] as String?,
      notes: json['notes'] as String?,
      isAiEstimate: json['isAiEstimate'] as bool? ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      portionConfirmed: json['portionConfirmed'] as bool? ?? true,
      matchKind: ProductMatchKind.values
          .where((k) => k.name == json['matchKind'])
          .firstOrNull,
      lookupNote: json['lookupNote'] as String?,
    );
  }
}
