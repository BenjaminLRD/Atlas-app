/// Structured multi-variable score evaluating the personalized suitability
/// of a candidate exercise for a specific athlete on a specific day.
class ExerciseRecommendationScore {
  final String exerciseName;
  final int preferenceMatch; // 0 to 30
  final int performanceHistory; // 0 to 25
  final int goalAlignment; // 0 to 20
  final int recoveryCompatibility; // 0 to 15
  final int equipmentAvailability; // 0 to 10
  final int totalScore; // 0 to 100
  final List<String> reasons; // Explainable AI bullet points
  final String? alternativeSuggestion; // If score is low or exercise is avoided

  const ExerciseRecommendationScore({
    required this.exerciseName,
    required this.preferenceMatch,
    required this.performanceHistory,
    required this.goalAlignment,
    required this.recoveryCompatibility,
    required this.equipmentAvailability,
    required this.totalScore,
    this.reasons = const [],
    this.alternativeSuggestion,
  });

  bool get isRecommended => totalScore >= 60;
  bool get isHighlyRecommended => totalScore >= 80;

  Map<String, dynamic> toJson() => {
    'exerciseName': exerciseName,
    'preferenceMatch': preferenceMatch,
    'performanceHistory': performanceHistory,
    'goalAlignment': goalAlignment,
    'recoveryCompatibility': recoveryCompatibility,
    'equipmentAvailability': equipmentAvailability,
    'totalScore': totalScore,
    'reasons': reasons,
    if (alternativeSuggestion != null)
      'alternativeSuggestion': alternativeSuggestion,
  };
}
