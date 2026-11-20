/// Detailed intelligence scoring and rationale report for an AI-generated workout.
class WorkoutIntelligenceReport {
  final int overallScore; // 0 - 100
  final int goalAlignmentScore; // 0 - 100
  final int equipmentMatchScore; // 0 - 100
  final int muscleBalanceScore; // 0 - 100
  /// 0 - 100, or null when no recovery data exists to check the plan against.
  final int? recoveryCompatibilityScore;
  final int progressionScore; // 0 - 100
  final int personalizationScore; // 0 - 100
  final List<String> strengths;
  final List<String> recommendations;
  final List<String> aiExplanation;

  const WorkoutIntelligenceReport({
    required this.overallScore,
    required this.goalAlignmentScore,
    required this.equipmentMatchScore,
    required this.muscleBalanceScore,
    this.recoveryCompatibilityScore,
    required this.progressionScore,
    required this.personalizationScore,
    this.strengths = const [],
    this.recommendations = const [],
    this.aiExplanation = const [],
  });

  /// Factory creating an empty or default report.
  factory WorkoutIntelligenceReport.initial() {
    return const WorkoutIntelligenceReport(
      overallScore: 90,
      goalAlignmentScore: 90,
      equipmentMatchScore: 100,
      muscleBalanceScore: 90,
      recoveryCompatibilityScore: 90,
      progressionScore: 90,
      personalizationScore: 90,
      strengths: ['Balanced multi-joint routine'],
      recommendations: [],
      aiExplanation: ['Workout customized for your daily readiness and goals.'],
    );
  }

  Map<String, dynamic> toJson() => {
    'overallScore': overallScore,
    'goalAlignmentScore': goalAlignmentScore,
    'equipmentMatchScore': equipmentMatchScore,
    'muscleBalanceScore': muscleBalanceScore,
    if (recoveryCompatibilityScore != null)
      'recoveryCompatibilityScore': recoveryCompatibilityScore,
    'progressionScore': progressionScore,
    'personalizationScore': personalizationScore,
    'strengths': strengths,
    'recommendations': recommendations,
    'aiExplanation': aiExplanation,
  };

  factory WorkoutIntelligenceReport.fromJson(Map<String, dynamic> json) {
    final rawStrengths = json['strengths'] as List? ?? const [];
    final rawRecs = json['recommendations'] as List? ?? const [];
    final rawExplanations =
        json['aiExplanation'] as List? ??
        (json['ai_explanation'] as List?) ??
        const [];

    return WorkoutIntelligenceReport(
      overallScore:
          (json['overallScore'] as num?)?.toInt() ??
          (json['overall_score'] as num?)?.toInt() ??
          0,
      goalAlignmentScore:
          (json['goalAlignmentScore'] as num?)?.toInt() ??
          (json['goal_alignment_score'] as num?)?.toInt() ??
          0,
      equipmentMatchScore:
          (json['equipmentMatchScore'] as num?)?.toInt() ??
          (json['equipment_match_score'] as num?)?.toInt() ??
          0,
      muscleBalanceScore:
          (json['muscleBalanceScore'] as num?)?.toInt() ??
          (json['muscle_balance_score'] as num?)?.toInt() ??
          0,
      recoveryCompatibilityScore:
          (json['recoveryCompatibilityScore'] as num?)?.toInt() ??
          (json['recovery_compatibility_score'] as num?)?.toInt(),
      progressionScore:
          (json['progressionScore'] as num?)?.toInt() ??
          (json['progression_score'] as num?)?.toInt() ??
          0,
      personalizationScore:
          (json['personalizationScore'] as num?)?.toInt() ??
          (json['personalization_score'] as num?)?.toInt() ??
          0,
      strengths: rawStrengths.map((e) => e.toString()).toList(),
      recommendations: rawRecs.map((e) => e.toString()).toList(),
      aiExplanation: rawExplanations.map((e) => e.toString()).toList(),
    );
  }

  WorkoutIntelligenceReport copyWith({
    int? overallScore,
    int? goalAlignmentScore,
    int? equipmentMatchScore,
    int? muscleBalanceScore,
    int? recoveryCompatibilityScore,
    int? progressionScore,
    int? personalizationScore,
    List<String>? strengths,
    List<String>? recommendations,
    List<String>? aiExplanation,
  }) {
    return WorkoutIntelligenceReport(
      overallScore: overallScore ?? this.overallScore,
      goalAlignmentScore: goalAlignmentScore ?? this.goalAlignmentScore,
      equipmentMatchScore: equipmentMatchScore ?? this.equipmentMatchScore,
      muscleBalanceScore: muscleBalanceScore ?? this.muscleBalanceScore,
      recoveryCompatibilityScore:
          recoveryCompatibilityScore ?? this.recoveryCompatibilityScore,
      progressionScore: progressionScore ?? this.progressionScore,
      personalizationScore: personalizationScore ?? this.personalizationScore,
      strengths: strengths ?? this.strengths,
      recommendations: recommendations ?? this.recommendations,
      aiExplanation: aiExplanation ?? this.aiExplanation,
    );
  }
}
