/// Classification of proactive AI insights.
enum InsightType {
  recoveryWarning('RECOVERY_WARNING'),
  sleepRecommendation('SLEEP_RECOMMENDATION'),
  proteinReminder('PROTEIN_REMINDER'),
  calorieAdjustment('CALORIE_ADJUSTMENT'),
  missedWorkout('MISSED_WORKOUT'),
  excessiveVolume('EXCESSIVE_VOLUME'),
  stalledProgress('STALLED_PROGRESS'),
  personalRecordOpportunity('PR_OPPORTUNITY'),
  dailyBrief('DAILY_BRIEF');

  final String code;
  const InsightType(this.code);

  static InsightType fromCode(String code) {
    return InsightType.values.firstWhere(
      (e) => e.code.toUpperCase() == code.toUpperCase(),
      orElse: () => InsightType.dailyBrief,
    );
  }
}

/// Urgency level of an insight for visual badges and notification prioritization.
enum InsightPriority {
  critical(4, 'Critical'),
  high(3, 'High'),
  medium(2, 'Medium'),
  low(1, 'Low');

  final int level;
  final String displayName;
  const InsightPriority(this.level, this.displayName);

  static InsightPriority fromString(String str) {
    return InsightPriority.values.firstWhere(
      (p) => p.name.toLowerCase() == str.toLowerCase(),
      orElse: () => InsightPriority.medium,
    );
  }
}

/// Direct user action trigger mapped to an insight.
enum InsightActionType {
  startWorkout('Start Workout'),
  logProtein('Log Protein'),
  reviewRecovery('Review Recovery'),
  adjustCalories('Adjust Calories'),
  openAICoach('Ask AI Coach'),
  viewProgress('View Progress');

  final String defaultLabel;
  const InsightActionType(this.defaultLabel);

  static InsightActionType fromString(String str) {
    return InsightActionType.values.firstWhere(
      (a) => a.name.toLowerCase() == str.toLowerCase(),
      orElse: () => InsightActionType.openAICoach,
    );
  }
}

/// Structured AI insight entity containing actionable coaching advice and context.
class CoachInsight {
  final String id;
  final InsightType type;
  final InsightPriority priority;
  final String title;
  final String message;
  final String? rationale;
  final InsightActionType actionType;
  final String? actionLabel;
  final Map<String, dynamic>? actionPayload;
  final DateTime timestamp;
  final bool isDismissed;

  const CoachInsight({
    required this.id,
    required this.type,
    required this.priority,
    required this.title,
    required this.message,
    this.rationale,
    required this.actionType,
    this.actionLabel,
    this.actionPayload,
    required this.timestamp,
    this.isDismissed = false,
  });

  String get effectiveActionLabel => actionLabel ?? actionType.defaultLabel;

  CoachInsight copyWith({
    String? id,
    InsightType? type,
    InsightPriority? priority,
    String? title,
    String? message,
    String? rationale,
    InsightActionType? actionType,
    String? actionLabel,
    Map<String, dynamic>? actionPayload,
    DateTime? timestamp,
    bool? isDismissed,
  }) {
    return CoachInsight(
      id: id ?? this.id,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      title: title ?? this.title,
      message: message ?? this.message,
      rationale: rationale ?? this.rationale,
      actionType: actionType ?? this.actionType,
      actionLabel: actionLabel ?? this.actionLabel,
      actionPayload: actionPayload ?? this.actionPayload,
      timestamp: timestamp ?? this.timestamp,
      isDismissed: isDismissed ?? this.isDismissed,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.code,
    'priority': priority.name,
    'title': title,
    'message': message,
    'rationale': rationale,
    'actionType': actionType.name,
    'actionLabel': actionLabel,
    'actionPayload': actionPayload,
    'timestamp': timestamp.toIso8601String(),
    'isDismissed': isDismissed,
  };

  factory CoachInsight.fromJson(Map<String, dynamic> json) {
    return CoachInsight(
      id:
          json['id'] as String? ??
          'ins_${DateTime.now().millisecondsSinceEpoch}',
      type: InsightType.fromCode(json['type'] as String? ?? 'DAILY_BRIEF'),
      priority: InsightPriority.fromString(
        json['priority'] as String? ?? 'medium',
      ),
      title: json['title'] as String? ?? 'Coach Insight',
      message: json['message'] as String? ?? '',
      rationale: json['rationale'] as String?,
      actionType: InsightActionType.fromString(
        json['actionType'] as String? ?? 'openAICoach',
      ),
      actionLabel: json['actionLabel'] as String?,
      actionPayload: json['actionPayload'] as Map<String, dynamic>?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      isDismissed: json['isDismissed'] as bool? ?? false,
    );
  }
}

/// Comprehensive daily holistic overview prepared by the proactive AI coach.
class DailyCoachBrief {
  final String greeting;

  /// Null when readiness is not measured (no sleep, HRV or heart-rate data).
  final int? recoveryScore;
  final String readinessTier;
  final String plannedWorkout;

  /// What is left to reach today's targets, or null when some food logged
  /// today has no value for it (the amount left is then unknown).
  final double? remainingProteinGrams;
  final double? remainingCalories;
  final String keySuggestion;
  final List<CoachInsight> topInsights;
  final DateTime generatedAt;

  const DailyCoachBrief({
    required this.greeting,
    this.recoveryScore,
    required this.readinessTier,
    required this.plannedWorkout,
    required this.remainingProteinGrams,
    required this.remainingCalories,
    required this.keySuggestion,
    this.topInsights = const [],
    required this.generatedAt,
  });

  Map<String, dynamic> toJson() => {
    'greeting': greeting,
    'recoveryScore': ?recoveryScore,
    'readinessTier': readinessTier,
    'plannedWorkout': plannedWorkout,
    'remainingProteinGrams': ?remainingProteinGrams,
    'remainingCalories': ?remainingCalories,
    'keySuggestion': keySuggestion,
    'topInsights': topInsights.map((i) => i.toJson()).toList(),
    'generatedAt': generatedAt.toIso8601String(),
  };

  factory DailyCoachBrief.fromJson(Map<String, dynamic> json) {
    final rawInsights = json['topInsights'] as List?;
    final List<CoachInsight> insights = rawInsights != null
        ? rawInsights
              .map((i) => CoachInsight.fromJson(i as Map<String, dynamic>))
              .toList()
        : [];

    return DailyCoachBrief(
      greeting: json['greeting'] as String? ?? 'Good morning Athlete',
      recoveryScore: (json['recoveryScore'] as num?)?.toInt(),
      readinessTier:
          json['readinessTier'] as String? ?? 'Readiness unavailable',
      plannedWorkout: json['plannedWorkout'] as String? ?? 'Push Day',
      remainingProteinGrams: (json['remainingProteinGrams'] as num?)
          ?.toDouble(),
      remainingCalories: (json['remainingCalories'] as num?)?.toDouble(),
      keySuggestion:
          json['keySuggestion'] as String? ??
          'Stay hydrated and hit your macros.',
      topInsights: insights,
      generatedAt: json['generatedAt'] != null
          ? DateTime.tryParse(json['generatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
