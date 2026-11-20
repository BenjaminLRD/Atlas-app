/// Dynamic personalized athlete preferences synthesized from long-term feedback.
class PreferenceProfile {
  final List<String> preferredExercises;
  final List<String> dislikedExercises;
  final List<String> preferredFoods;
  final List<String> dislikedFoods;
  final int preferredWorkoutDurationMinutes;
  final String
  trainingStyle; // 'hypertrophy', 'strength', 'endurance', 'calisthenics'
  final String
  coachPersonalityPreference; // 'encouraging', 'direct', 'analytical'
  final Map<String, int> exerciseScores;
  final Map<String, int> foodScores;
  final int helpfulRecommendationsCount;
  final int unhelpfulRecommendationsCount;

  const PreferenceProfile({
    this.preferredExercises = const [],
    this.dislikedExercises = const [],
    this.preferredFoods = const [],
    this.dislikedFoods = const [],
    this.preferredWorkoutDurationMinutes = 45,
    this.trainingStyle = 'hypertrophy',
    this.coachPersonalityPreference = 'encouraging',
    this.exerciseScores = const {},
    this.foodScores = const {},
    this.helpfulRecommendationsCount = 0,
    this.unhelpfulRecommendationsCount = 0,
  });

  /// Factory creating default initial athlete preference profile.
  factory PreferenceProfile.initial() {
    return const PreferenceProfile(
      preferredExercises: [],
      dislikedExercises: [],
      preferredFoods: [],
      dislikedFoods: [],
      preferredWorkoutDurationMinutes: 45,
      trainingStyle: 'hypertrophy',
      coachPersonalityPreference: 'encouraging',
      exerciseScores: {},
      foodScores: {},
      helpfulRecommendationsCount: 0,
      unhelpfulRecommendationsCount: 0,
    );
  }

  /// Calculates feedback satisfaction ratio (e.g. 0.95 = 95% satisfaction).
  double get satisfactionRate {
    final total = helpfulRecommendationsCount + unhelpfulRecommendationsCount;
    if (total == 0) return 1.0;
    return helpfulRecommendationsCount / total;
  }

  PreferenceProfile copyWith({
    List<String>? preferredExercises,
    List<String>? dislikedExercises,
    List<String>? preferredFoods,
    List<String>? dislikedFoods,
    int? preferredWorkoutDurationMinutes,
    String? trainingStyle,
    String? coachPersonalityPreference,
    Map<String, int>? exerciseScores,
    Map<String, int>? foodScores,
    int? helpfulRecommendationsCount,
    int? unhelpfulRecommendationsCount,
  }) {
    return PreferenceProfile(
      preferredExercises: preferredExercises ?? this.preferredExercises,
      dislikedExercises: dislikedExercises ?? this.dislikedExercises,
      preferredFoods: preferredFoods ?? this.preferredFoods,
      dislikedFoods: dislikedFoods ?? this.dislikedFoods,
      preferredWorkoutDurationMinutes:
          preferredWorkoutDurationMinutes ??
          this.preferredWorkoutDurationMinutes,
      trainingStyle: trainingStyle ?? this.trainingStyle,
      coachPersonalityPreference:
          coachPersonalityPreference ?? this.coachPersonalityPreference,
      exerciseScores: exerciseScores ?? this.exerciseScores,
      foodScores: foodScores ?? this.foodScores,
      helpfulRecommendationsCount:
          helpfulRecommendationsCount ?? this.helpfulRecommendationsCount,
      unhelpfulRecommendationsCount:
          unhelpfulRecommendationsCount ?? this.unhelpfulRecommendationsCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'preferredExercises': preferredExercises,
    'dislikedExercises': dislikedExercises,
    'preferredFoods': preferredFoods,
    'dislikedFoods': dislikedFoods,
    'preferredWorkoutDurationMinutes': preferredWorkoutDurationMinutes,
    'trainingStyle': trainingStyle,
    'coachPersonalityPreference': coachPersonalityPreference,
    'exerciseScores': exerciseScores,
    'foodScores': foodScores,
    'helpfulRecommendationsCount': helpfulRecommendationsCount,
    'unhelpfulRecommendationsCount': unhelpfulRecommendationsCount,
  };

  factory PreferenceProfile.fromJson(Map<String, dynamic> json) {
    final rawExScores = json['exerciseScores'] as Map<String, dynamic>? ?? {};
    final exScores = rawExScores.map((k, v) => MapEntry(k, (v as num).toInt()));

    final rawFoodScores = json['foodScores'] as Map<String, dynamic>? ?? {};
    final fScores = rawFoodScores.map(
      (k, v) => MapEntry(k, (v as num).toInt()),
    );

    return PreferenceProfile(
      preferredExercises: (json['preferredExercises'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      dislikedExercises: (json['dislikedExercises'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      preferredFoods: (json['preferredFoods'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      dislikedFoods: (json['dislikedFoods'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      preferredWorkoutDurationMinutes:
          (json['preferredWorkoutDurationMinutes'] as num?)?.toInt() ?? 45,
      trainingStyle: json['trainingStyle'] as String? ?? 'hypertrophy',
      coachPersonalityPreference:
          json['coachPersonalityPreference'] as String? ?? 'encouraging',
      exerciseScores: exScores,
      foodScores: fScores,
      helpfulRecommendationsCount:
          (json['helpfulRecommendationsCount'] as num?)?.toInt() ?? 0,
      unhelpfulRecommendationsCount:
          (json['unhelpfulRecommendationsCount'] as num?)?.toInt() ?? 0,
    );
  }
}
