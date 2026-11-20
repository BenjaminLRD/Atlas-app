/// Classification of visual multimodal analysis requests
enum VisionAnalysisType { equipment, food, exerciseForm, general }

/// Structured response container for AI visual recognition (equipment, nutrition, exercise)
class ImageAnalysisResult {
  final VisionAnalysisType analysisType;
  final String title;
  final String description;
  final String rawText;
  final String confidence; // 'High', 'Medium', 'Low'

  // Food / Nutrition Specific
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final String? portionAdvice;

  // Equipment / Workout Specific
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> instructions;
  final String? caloriesPerMinEstimate;
  final List<String> alternatives;

  final bool isOffline;

  const ImageAnalysisResult({
    required this.analysisType,
    required this.title,
    required this.description,
    required this.rawText,
    this.confidence = 'Medium',
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.portionAdvice,
    this.primaryMuscles = const [],
    this.secondaryMuscles = const [],
    this.instructions = const [],
    this.caloriesPerMinEstimate,
    this.alternatives = const [],
    this.isOffline = false,
  });

  /// Offline fallback factory when internet or vision model is unreachable
  factory ImageAnalysisResult.offlineFallback({String? customMessage}) {
    const defaultMsg =
        'Image analysis is currently unavailable. I can still help you with a text description.';
    final text = customMessage ?? defaultMsg;
    return ImageAnalysisResult(
      analysisType: VisionAnalysisType.general,
      title: 'Offline / Unavailable',
      description: text,
      rawText: text,
      confidence: 'Low',
      isOffline: true,
    );
  }

  /// Parses AI text output into structured ImageAnalysisResult
  factory ImageAnalysisResult.fromResponse(
    String responseText, {
    VisionAnalysisType type = VisionAnalysisType.general,
  }) {
    final lower = responseText.toLowerCase();

    // Auto-detect type if general
    VisionAnalysisType detectedType = type;
    if (type == VisionAnalysisType.general) {
      if (lower.contains('machine') ||
          lower.contains('equipment') ||
          lower.contains('pulldown') ||
          lower.contains('exercise') ||
          lower.contains('workout') ||
          lower.contains('muscles') ||
          lower.contains('dumbbell') ||
          lower.contains('barbell')) {
        detectedType = VisionAnalysisType.equipment;
      } else if (lower.contains('meal') ||
          lower.contains('food') ||
          lower.contains('ingredient') ||
          lower.contains('recipe') ||
          lower.contains('calories') ||
          lower.contains('protein') ||
          lower.contains('carbs')) {
        detectedType = VisionAnalysisType.food;
      }
    }

    // Extract title (first line or first heading)
    String title = 'Visual Analysis';
    final lines = responseText.split('\n').map((l) => l.trim()).toList();
    for (final l in lines) {
      if (l.isNotEmpty) {
        title = l.replaceAll(RegExp(r'^[#*\s-]+'), '').trim();
        break;
      }
    }

    // Extract macros for food
    double? calories;
    double? protein;
    double? carbs;
    double? fat;
    String confidence = 'Medium';

    if (detectedType == VisionAnalysisType.food) {
      final calMatch = RegExp(
        r'(?:calories|kcal)[\s:]*~?(\d+(?:\.\d+)?)',
        caseSensitive: false,
      ).firstMatch(responseText);
      if (calMatch != null) calories = double.tryParse(calMatch.group(1)!);

      final proMatch = RegExp(
        r'protein[\s:]*~?(\d+(?:\.\d+)?)',
        caseSensitive: false,
      ).firstMatch(responseText);
      if (proMatch != null) protein = double.tryParse(proMatch.group(1)!);

      final carbMatch = RegExp(
        r'carbs?[\s:]*~?(\d+(?:\.\d+)?)',
        caseSensitive: false,
      ).firstMatch(responseText);
      if (carbMatch != null) carbs = double.tryParse(carbMatch.group(1)!);

      final fatMatch = RegExp(
        r'fat[\s:]*~?(\d+(?:\.\d+)?)',
        caseSensitive: false,
      ).firstMatch(responseText);
      if (fatMatch != null) fat = double.tryParse(fatMatch.group(1)!);

      if (lower.contains('high confidence') ||
          lower.contains('confidence: high')) {
        confidence = 'High';
      } else if (lower.contains('low confidence') ||
          lower.contains('confidence: low')) {
        confidence = 'Low';
      }
    }

    return ImageAnalysisResult(
      analysisType: detectedType,
      title: title,
      description: responseText,
      rawText: responseText,
      confidence: confidence,
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      portionAdvice: detectedType == VisionAnalysisType.food
          ? 'For accurate tracking, confirm portion size.'
          : null,
    );
  }

  /// Converts the analysis into rich formatted markdown for chat presentation
  String toMarkdownFormatted() {
    return rawText;
  }
}
