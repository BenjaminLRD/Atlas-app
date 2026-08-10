/// Persistent memory storage capturing user training preferences, previous insights, and coaching style.
class CoachMemory {
  final List<String> trainingPreferences;
  final List<String> previousInsights;
  final String preferredStyle; // 'encouraging', 'direct', 'analytical'

  const CoachMemory({
    this.trainingPreferences = const ['Prefers compound lifts', 'Morning workout schedule'],
    this.previousInsights = const ['Responds well to progressive overload targets'],
    this.preferredStyle = 'encouraging',
  });

  factory CoachMemory.fromJson(Map<String, dynamic> json) {
    return CoachMemory(
      trainingPreferences: (json['trainingPreferences'] as List<dynamic>? ??
              (json['training_preferences'] as List<dynamic>? ?? []))
          .map((e) => e.toString())
          .toList(),
      previousInsights: (json['previousInsights'] as List<dynamic>? ??
              (json['previous_insights'] as List<dynamic>? ?? []))
          .map((e) => e.toString())
          .toList(),
      preferredStyle: json['preferredStyle'] as String? ??
          (json['preferred_style'] as String? ?? 'encouraging'),
    );
  }

  Map<String, dynamic> toJson() => {
        'training_preferences': trainingPreferences,
        'previous_insights': previousInsights,
        'preferred_style': preferredStyle,
      };

  CoachMemory copyWith({
    List<String>? trainingPreferences,
    List<String>? previousInsights,
    String? preferredStyle,
  }) {
    return CoachMemory(
      trainingPreferences: trainingPreferences ?? this.trainingPreferences,
      previousInsights: previousInsights ?? this.previousInsights,
      preferredStyle: preferredStyle ?? this.preferredStyle,
    );
  }
}
