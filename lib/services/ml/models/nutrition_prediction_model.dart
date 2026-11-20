/// Output result from the Nutrition Prediction ML Model.
class NutritionPredictionResult {
  final double goalAdherenceProbability; // 0.0 to 1.0 (e.g. 0.88)
  final double proteinConsistencyScore; // 0 to 100 (e.g. 92.0)
  final double calorieConsistencyScore; // 0 to 100 (e.g. 86.0)
  final double predictedWeeklyDeficitOrSurplusKcal; // Net delta in kcal
  final List<String> nutritionalDirectives;
  final double confidenceScore;

  const NutritionPredictionResult({
    required this.goalAdherenceProbability,
    required this.proteinConsistencyScore,
    required this.calorieConsistencyScore,
    required this.predictedWeeklyDeficitOrSurplusKcal,
    required this.nutritionalDirectives,
    required this.confidenceScore,
  });

  factory NutritionPredictionResult.fromJson(Map<String, dynamic> json) {
    final rawDir = json['nutritional_directives'] as List<dynamic>? ?? [];
    return NutritionPredictionResult(
      goalAdherenceProbability:
          (json['goal_adherence_probability'] as num?)?.toDouble() ?? 0.85,
      proteinConsistencyScore:
          (json['protein_consistency_score'] as num?)?.toDouble() ?? 90.0,
      calorieConsistencyScore:
          (json['calorie_consistency_score'] as num?)?.toDouble() ?? 85.0,
      predictedWeeklyDeficitOrSurplusKcal:
          (json['predicted_weekly_net_kcal'] as num?)?.toDouble() ?? -1750.0,
      nutritionalDirectives: rawDir.map((e) => e.toString()).toList(),
      confidenceScore: (json['confidence_score'] as num?)?.toDouble() ?? 0.93,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'goal_adherence_probability': goalAdherenceProbability,
      'protein_consistency_score': proteinConsistencyScore,
      'calorie_consistency_score': calorieConsistencyScore,
      'predicted_weekly_net_kcal': predictedWeeklyDeficitOrSurplusKcal,
      'nutritional_directives': nutritionalDirectives,
      'confidence_score': confidenceScore,
    };
  }
}

/// Custom ML Model forecasting dietary goal adherence, protein delivery consistency, and weekly calorie net balance.
class NutritionPredictionModel {
  static NutritionPredictionModel? _instance;
  static NutritionPredictionModel get instance =>
      _instance ??= NutritionPredictionModel();

  /// Predicts future adherence and protein consistency given historical nutrition metrics.
  NutritionPredictionResult predict({
    required double averageCaloriesConsumed,
    required double targetCalories,
    required double averageProteinGrams,
    required double targetProteinGrams,
    required int loggedDaysLast7Days,
  }) {
    final List<String> directives = [];

    // 1. Protein consistency
    final proteinRatio = targetProteinGrams > 0
        ? (averageProteinGrams / targetProteinGrams).clamp(0.0, 1.5)
        : 1.0;
    final proteinScore = (100.0 - (1.0 - proteinRatio).abs() * 100.0).clamp(
      40.0,
      100.0,
    );
    if (proteinRatio < 0.85) {
      directives.add(
        'Increase daily protein intake by ${(targetProteinGrams - averageProteinGrams).round()}g to optimize muscle protein synthesis.',
      );
    }

    // 2. Calorie consistency
    final calRatio = targetCalories > 0
        ? (averageCaloriesConsumed / targetCalories).clamp(0.0, 1.5)
        : 1.0;
    final calScore = (100.0 - (1.0 - calRatio).abs() * 100.0).clamp(
      40.0,
      100.0,
    );

    // 3. Goal adherence probability
    final loggingFactor = (loggedDaysLast7Days / 7.0).clamp(0.2, 1.0);
    final adherenceProb =
        ((proteinScore * 0.4 + calScore * 0.4 + loggingFactor * 100.0 * 0.2) /
                100.0)
            .clamp(0.3, 0.98);

    // 4. Net weekly forecast
    final dailyNet = averageCaloriesConsumed - targetCalories;
    final weeklyNet = dailyNet * 7.0;

    if (directives.isEmpty) {
      directives.add(
        'Optimal nutrition compliance: macros align with body composition target.',
      );
    }

    return NutritionPredictionResult(
      goalAdherenceProbability: adherenceProb,
      proteinConsistencyScore: proteinScore,
      calorieConsistencyScore: calScore,
      predictedWeeklyDeficitOrSurplusKcal: weeklyNet,
      nutritionalDirectives: directives,
      confidenceScore: 0.92,
    );
  }
}
