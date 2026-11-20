/// Domain model representing a comprehensive 7-day retrospective AI Coach Review.
class WeeklyCoachReview {
  final DateTime weekStartDate;
  final DateTime weekEndDate;

  // Training Metrics
  final int workoutsCompleted;
  final double volumeChangePercentage;
  final List<String> personalRecordsAchieved;
  final List<String> weakAreasIdentified;

  // Nutrition Metrics
  final double averageDailyCalories;
  final double proteinConsistencyPercentage; // e.g. 86.0%

  // Recovery Metrics
  final double averageSleepHours;
  final int averageReadinessScore;

  // Body Composition / Weight
  final double weightChangeKg;

  // AI Synthesis
  final String strengthSummary;
  final String nutritionSummary;
  final String primaryRecommendation;
  final List<String> actionItems;

  const WeeklyCoachReview({
    required this.weekStartDate,
    required this.weekEndDate,
    required this.workoutsCompleted,
    required this.volumeChangePercentage,
    required this.personalRecordsAchieved,
    required this.weakAreasIdentified,
    required this.averageDailyCalories,
    required this.proteinConsistencyPercentage,
    required this.averageSleepHours,
    required this.averageReadinessScore,
    required this.weightChangeKg,
    required this.strengthSummary,
    required this.nutritionSummary,
    required this.primaryRecommendation,
    required this.actionItems,
  });

  factory WeeklyCoachReview.empty() {
    final now = DateTime.now();
    return WeeklyCoachReview(
      weekStartDate: now.subtract(const Duration(days: 7)),
      weekEndDate: now,
      workoutsCompleted: 0,
      volumeChangePercentage: 0.0,
      personalRecordsAchieved: const [],
      weakAreasIdentified: const [],
      averageDailyCalories: 0.0,
      proteinConsistencyPercentage: 0.0,
      averageSleepHours: 7.5,
      averageReadinessScore: 80,
      weightChangeKg: 0.0,
      strengthSummary: 'No strength sessions logged this week.',
      nutritionSummary: 'No nutrition logs recorded this week.',
      primaryRecommendation:
          'Log workouts and meals to unlock weekly AI intelligence.',
      actionItems: const ['Complete your first scheduled workout'],
    );
  }

  factory WeeklyCoachReview.fromJson(Map<String, dynamic> json) {
    return WeeklyCoachReview(
      weekStartDate: json['week_start_date'] != null
          ? DateTime.parse(json['week_start_date'] as String)
          : DateTime.now().subtract(const Duration(days: 7)),
      weekEndDate: json['week_end_date'] != null
          ? DateTime.parse(json['week_end_date'] as String)
          : DateTime.now(),
      workoutsCompleted: (json['workouts_completed'] as num?)?.toInt() ?? 0,
      volumeChangePercentage:
          (json['volume_change_percentage'] as num?)?.toDouble() ?? 0.0,
      personalRecordsAchieved:
          (json['personal_records_achieved'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      weakAreasIdentified:
          (json['weak_areas_identified'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      averageDailyCalories:
          (json['average_daily_calories'] as num?)?.toDouble() ?? 0.0,
      proteinConsistencyPercentage:
          (json['protein_consistency_percentage'] as num?)?.toDouble() ?? 0.0,
      averageSleepHours:
          (json['average_sleep_hours'] as num?)?.toDouble() ?? 7.5,
      averageReadinessScore:
          (json['average_readiness_score'] as num?)?.toInt() ?? 80,
      weightChangeKg: (json['weight_change_kg'] as num?)?.toDouble() ?? 0.0,
      strengthSummary: json['strength_summary'] as String? ?? '',
      nutritionSummary: json['nutrition_summary'] as String? ?? '',
      primaryRecommendation: json['primary_recommendation'] as String? ?? '',
      actionItems:
          (json['action_items'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'week_start_date': weekStartDate.toIso8601String(),
      'week_end_date': weekEndDate.toIso8601String(),
      'workouts_completed': workoutsCompleted,
      'volume_change_percentage': volumeChangePercentage,
      'personal_records_achieved': personalRecordsAchieved,
      'weak_areas_identified': weakAreasIdentified,
      'average_daily_calories': averageDailyCalories,
      'protein_consistency_percentage': proteinConsistencyPercentage,
      'average_sleep_hours': averageSleepHours,
      'average_readiness_score': averageReadinessScore,
      'weight_change_kg': weightChangeKg,
      'strength_summary': strengthSummary,
      'nutrition_summary': nutritionSummary,
      'primary_recommendation': primaryRecommendation,
      'action_items': actionItems,
    };
  }
}
