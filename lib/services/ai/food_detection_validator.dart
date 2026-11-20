/// Confidence level classification for AI nutrition predictions
enum FoodConfidenceRating { high, medium, low }

/// Validation result container from visual food scanner analysis
class FoodValidationResult {
  final bool isValidFood;
  final bool isConfident;
  final FoodConfidenceRating confidenceRating;
  final String? rejectionReason;
  final String? userGuidanceMessage;

  const FoodValidationResult({
    required this.isValidFood,
    required this.isConfident,
    required this.confidenceRating,
    this.rejectionReason,
    this.userGuidanceMessage,
  });

  bool get isAccepted => isValidFood && isConfident;

  factory FoodValidationResult.accepted({
    required FoodConfidenceRating rating,
  }) {
    return FoodValidationResult(
      isValidFood: true,
      isConfident: true,
      confidenceRating: rating,
    );
  }

  factory FoodValidationResult.lowConfidence() {
    return const FoodValidationResult(
      isValidFood: true,
      isConfident: false,
      confidenceRating: FoodConfidenceRating.low,
      rejectionReason: 'Low visual confidence',
      userGuidanceMessage:
          'Unable to confidently identify this food.\n\nTry:\n- Better lighting\n- Closer image\n- Clearer angle',
    );
  }

  factory FoodValidationResult.nonFood({String? detectedObject}) {
    return FoodValidationResult(
      isValidFood: false,
      isConfident: false,
      confidenceRating: FoodConfidenceRating.low,
      rejectionReason:
          'Non-food object detected: ${detectedObject ?? "Unknown"}',
      userGuidanceMessage:
          'No food detected.\n\nTry scanning a meal or food item.',
    );
  }
}

/// Validator evaluating visual food recognition outputs to prevent hallucinations and reject non-food items.
class FoodDetectionValidator {
  static const double confidenceThreshold = 0.50; // 50% minimum confidence

  static const List<String> nonFoodKeywords = [
    'phone',
    'smartphone',
    'shoe',
    'sneaker',
    'dumbbell',
    'barbell',
    'weight',
    'kettlebell',
    'gym equipment',
    'treadmill',
    'bottle',
    'shaker',
    'laptop',
    'keyboard',
    'mouse',
    'computer',
    'car',
    'clothing',
    'shirt',
    'pants',
    'watch',
    'person',
    'face',
    'hand',
    'room',
    'wall',
    'floor',
    'chair',
    'table',
  ];

  /// Validates a detected item name, confidence score, and optional vision label tags.
  static FoodValidationResult validateScan({
    required String itemName,
    required double confidence,
    List<String> detectedLabels = const [],
  }) {
    final lowerName = itemName.toLowerCase().trim();

    // 1. Non-food keyword detection
    for (final nonFood in nonFoodKeywords) {
      if (lowerName.contains(nonFood) ||
          detectedLabels.any((l) => l.toLowerCase().contains(nonFood))) {
        return FoodValidationResult.nonFood(detectedObject: itemName);
      }
    }

    // 2. Confidence Threshold Check
    if (confidence < confidenceThreshold) {
      return FoodValidationResult.lowConfidence();
    }

    // 3. Determine confidence rating
    final FoodConfidenceRating rating;
    if (confidence >= 0.80) {
      rating = FoodConfidenceRating.high;
    } else if (confidence >= 0.50) {
      rating = FoodConfidenceRating.medium;
    } else {
      rating = FoodConfidenceRating.low;
    }

    return FoodValidationResult.accepted(rating: rating);
  }
}
