/// Physical anthropometric characteristics of the athlete.
class PhysicalProfile {
  final int age;
  final double weightKg;
  final double heightCm;
  final String gender;
  final double bodyFatPercentage;

  const PhysicalProfile({
    this.age = 26,
    this.weightKg = 75.0,
    this.heightCm = 175.0,
    this.gender = 'male',
    this.bodyFatPercentage = 15.0,
  });

  factory PhysicalProfile.fromJson(Map<String, dynamic> json) {
    return PhysicalProfile(
      age: (json['age'] as num?)?.toInt() ?? 26,
      weightKg: (json['weight_kg'] as num?)?.toDouble() ?? 75.0,
      heightCm: (json['height_cm'] as num?)?.toDouble() ?? 175.0,
      gender: json['gender']?.toString() ?? 'male',
      bodyFatPercentage:
          (json['body_fat_percentage'] as num?)?.toDouble() ?? 15.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'age': age,
    'weight_kg': weightKg,
    'height_cm': heightCm,
    'gender': gender,
    'body_fat_percentage': bodyFatPercentage,
  };

  PhysicalProfile copyWith({
    int? age,
    double? weightKg,
    double? heightCm,
    String? gender,
    double? bodyFatPercentage,
  }) {
    return PhysicalProfile(
      age: age ?? this.age,
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      gender: gender ?? this.gender,
      bodyFatPercentage: bodyFatPercentage ?? this.bodyFatPercentage,
    );
  }
}

/// Comprehensive strength capacity, 1RM estimates, and progression velocity.
class StrengthProfile {
  final Map<String, double>
  estimated1RM; // e.g. {'Squat': 140.0, 'Bench Press': 105.0, 'Deadlift': 180.0}
  final String strengthLevel; // 'beginner', 'intermediate', 'advanced', 'elite'
  final double progressionVelocityPercentage; // e.g. +4.5% month-over-month
  final double totalStrengthVolumeKg;

  const StrengthProfile({
    this.estimated1RM = const {
      'Squat': 130.0,
      'Bench Press': 100.0,
      'Deadlift': 160.0,
      'Overhead Press': 65.0,
    },
    this.strengthLevel = 'intermediate',
    this.progressionVelocityPercentage = 4.0,
    this.totalStrengthVolumeKg = 45000.0,
  });

  factory StrengthProfile.fromJson(Map<String, dynamic> json) {
    final raw1rm = json['estimated_1rm'] as Map<String, dynamic>? ?? {};
    final map1rm = raw1rm.map((k, v) => MapEntry(k, (v as num).toDouble()));

    return StrengthProfile(
      estimated1RM: map1rm.isNotEmpty
          ? map1rm
          : const {
              'Squat': 130.0,
              'Bench Press': 100.0,
              'Deadlift': 160.0,
              'Overhead Press': 65.0,
            },
      strengthLevel: json['strength_level']?.toString() ?? 'intermediate',
      progressionVelocityPercentage:
          (json['progression_velocity_percentage'] as num?)?.toDouble() ?? 4.0,
      totalStrengthVolumeKg:
          (json['total_strength_volume_kg'] as num?)?.toDouble() ?? 45000.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'estimated_1rm': estimated1RM,
    'strength_level': strengthLevel,
    'progression_velocity_percentage': progressionVelocityPercentage,
    'total_strength_volume_kg': totalStrengthVolumeKg,
  };

  StrengthProfile copyWith({
    Map<String, double>? estimated1RM,
    String? strengthLevel,
    double? progressionVelocityPercentage,
    double? totalStrengthVolumeKg,
  }) {
    return StrengthProfile(
      estimated1RM: estimated1RM ?? this.estimated1RM,
      strengthLevel: strengthLevel ?? this.strengthLevel,
      progressionVelocityPercentage:
          progressionVelocityPercentage ?? this.progressionVelocityPercentage,
      totalStrengthVolumeKg:
          totalStrengthVolumeKg ?? this.totalStrengthVolumeKg,
    );
  }
}

/// Periodization preferences, session volume, and athlete training personality.
class TrainingProfile {
  final String preferredSplit; // 'Upper/Lower', 'PPL', 'Full Body'
  final int weeklyFrequency; // e.g. 4 days/week
  final int averageSessionMinutes;
  final String
  trainingPersonality; // e.g. 'Methodical Powerbuilder', 'High-Volume Hypertrophy Enthusiast'
  final String
  primaryFocus; // 'Hypertrophy', 'Strength Overload', 'Athleticism'
  final List<String> favoriteExercises;

  const TrainingProfile({
    this.preferredSplit = 'Upper/Lower',
    this.weeklyFrequency = 4,
    this.averageSessionMinutes = 55,
    this.trainingPersonality = 'Methodical Powerbuilder',
    this.primaryFocus = 'Hypertrophy & Strength',
    this.favoriteExercises = const [
      'Incline Barbell Bench Press',
      'Barbell Back Squat',
      'Romanian Deadlift',
    ],
  });

  factory TrainingProfile.fromJson(Map<String, dynamic> json) {
    final rawFav = json['favorite_exercises'] as List<dynamic>? ?? [];
    return TrainingProfile(
      preferredSplit: json['preferred_split']?.toString() ?? 'Upper/Lower',
      weeklyFrequency: (json['weekly_frequency'] as num?)?.toInt() ?? 4,
      averageSessionMinutes:
          (json['average_session_minutes'] as num?)?.toInt() ?? 55,
      trainingPersonality:
          json['training_personality']?.toString() ?? 'Methodical Powerbuilder',
      primaryFocus:
          json['primary_focus']?.toString() ?? 'Hypertrophy & Strength',
      favoriteExercises: rawFav.isNotEmpty
          ? rawFav.map((e) => e.toString()).toList()
          : const [
              'Incline Barbell Bench Press',
              'Barbell Back Squat',
              'Romanian Deadlift',
            ],
    );
  }

  Map<String, dynamic> toJson() => {
    'preferred_split': preferredSplit,
    'weekly_frequency': weeklyFrequency,
    'average_session_minutes': averageSessionMinutes,
    'training_personality': trainingPersonality,
    'primary_focus': primaryFocus,
    'favorite_exercises': favoriteExercises,
  };

  TrainingProfile copyWith({
    String? preferredSplit,
    int? weeklyFrequency,
    int? averageSessionMinutes,
    String? trainingPersonality,
    String? primaryFocus,
    List<String>? favoriteExercises,
  }) {
    return TrainingProfile(
      preferredSplit: preferredSplit ?? this.preferredSplit,
      weeklyFrequency: weeklyFrequency ?? this.weeklyFrequency,
      averageSessionMinutes:
          averageSessionMinutes ?? this.averageSessionMinutes,
      trainingPersonality: trainingPersonality ?? this.trainingPersonality,
      primaryFocus: primaryFocus ?? this.primaryFocus,
      favoriteExercises: favoriteExercises ?? this.favoriteExercises,
    );
  }
}

/// Recovery capacity, sleep metrics, HRV, and fatigue tolerance profile.
class RecoveryProfile {
  final double averageRecoveryScore; // 0 to 100
  final double sleepDurationHours;
  final double hrvAverage;
  final int restingHeartRate;
  final String fatigueSensitivity; // 'low', 'moderate', 'high'
  final int optimalRestDaysPerWeek;

  const RecoveryProfile({
    this.averageRecoveryScore = 84.0,
    this.sleepDurationHours = 7.6,
    this.hrvAverage = 68.0,
    this.restingHeartRate = 58,
    this.fatigueSensitivity = 'moderate',
    this.optimalRestDaysPerWeek = 3,
  });

  factory RecoveryProfile.fromJson(Map<String, dynamic> json) {
    return RecoveryProfile(
      averageRecoveryScore:
          (json['average_recovery_score'] as num?)?.toDouble() ?? 84.0,
      sleepDurationHours:
          (json['sleep_duration_hours'] as num?)?.toDouble() ?? 7.6,
      hrvAverage: (json['hrv_average'] as num?)?.toDouble() ?? 68.0,
      restingHeartRate: (json['resting_heart_rate'] as num?)?.toInt() ?? 58,
      fatigueSensitivity: json['fatigue_sensitivity']?.toString() ?? 'moderate',
      optimalRestDaysPerWeek:
          (json['optimal_rest_days_per_week'] as num?)?.toInt() ?? 3,
    );
  }

  Map<String, dynamic> toJson() => {
    'average_recovery_score': averageRecoveryScore,
    'sleep_duration_hours': sleepDurationHours,
    'hrv_average': hrvAverage,
    'resting_heart_rate': restingHeartRate,
    'fatigue_sensitivity': fatigueSensitivity,
    'optimal_rest_days_per_week': optimalRestDaysPerWeek,
  };

  RecoveryProfile copyWith({
    double? averageRecoveryScore,
    double? sleepDurationHours,
    double? hrvAverage,
    int? restingHeartRate,
    String? fatigueSensitivity,
    int? optimalRestDaysPerWeek,
  }) {
    return RecoveryProfile(
      averageRecoveryScore: averageRecoveryScore ?? this.averageRecoveryScore,
      sleepDurationHours: sleepDurationHours ?? this.sleepDurationHours,
      hrvAverage: hrvAverage ?? this.hrvAverage,
      restingHeartRate: restingHeartRate ?? this.restingHeartRate,
      fatigueSensitivity: fatigueSensitivity ?? this.fatigueSensitivity,
      optimalRestDaysPerWeek:
          optimalRestDaysPerWeek ?? this.optimalRestDaysPerWeek,
    );
  }
}

/// Nutrition targets, macronutrient adherence, and dietary preferences.
class NutritionProfile {
  final int dailyCalories;
  final double dailyProteinGrams;
  final double dailyCarbsGrams;
  final double dailyFatGrams;
  final double adherenceRate; // 0.0 to 1.0
  final String dietaryPreference; // 'high_protein', 'balanced', 'keto', 'vegan'

  const NutritionProfile({
    this.dailyCalories = 2600,
    this.dailyProteinGrams = 175.0,
    this.dailyCarbsGrams = 300.0,
    this.dailyFatGrams = 75.0,
    this.adherenceRate = 0.92,
    this.dietaryPreference = 'high_protein',
  });

  factory NutritionProfile.fromJson(Map<String, dynamic> json) {
    return NutritionProfile(
      dailyCalories: (json['daily_calories'] as num?)?.toInt() ?? 2600,
      dailyProteinGrams:
          (json['daily_protein_grams'] as num?)?.toDouble() ?? 175.0,
      dailyCarbsGrams: (json['daily_carbs_grams'] as num?)?.toDouble() ?? 300.0,
      dailyFatGrams: (json['daily_fat_grams'] as num?)?.toDouble() ?? 75.0,
      adherenceRate: (json['adherence_rate'] as num?)?.toDouble() ?? 0.92,
      dietaryPreference:
          json['dietary_preference']?.toString() ?? 'high_protein',
    );
  }

  Map<String, dynamic> toJson() => {
    'daily_calories': dailyCalories,
    'daily_protein_grams': dailyProteinGrams,
    'daily_carbs_grams': dailyCarbsGrams,
    'daily_fat_grams': dailyFatGrams,
    'adherence_rate': adherenceRate,
    'dietary_preference': dietaryPreference,
  };

  NutritionProfile copyWith({
    int? dailyCalories,
    double? dailyProteinGrams,
    double? dailyCarbsGrams,
    double? dailyFatGrams,
    double? adherenceRate,
    String? dietaryPreference,
  }) {
    return NutritionProfile(
      dailyCalories: dailyCalories ?? this.dailyCalories,
      dailyProteinGrams: dailyProteinGrams ?? this.dailyProteinGrams,
      dailyCarbsGrams: dailyCarbsGrams ?? this.dailyCarbsGrams,
      dailyFatGrams: dailyFatGrams ?? this.dailyFatGrams,
      adherenceRate: adherenceRate ?? this.adherenceRate,
      dietaryPreference: dietaryPreference ?? this.dietaryPreference,
    );
  }
}

/// Behavioral discipline, training cadence, and habit continuity telemetry.
class BehaviorProfile {
  final double consistencyScore; // 0 to 100
  final String preferredWorkoutTime; // 'morning', 'afternoon', 'evening'
  final String
  missedSessionTrigger; // e.g. 'work_travel', 'accumulated_fatigue'
  final double habitContinuityRate; // 0.0 to 1.0

  const BehaviorProfile({
    this.consistencyScore = 92.0,
    this.preferredWorkoutTime = 'evening',
    this.missedSessionTrigger = 'accumulated_fatigue',
    this.habitContinuityRate = 0.94,
  });

  factory BehaviorProfile.fromJson(Map<String, dynamic> json) {
    return BehaviorProfile(
      consistencyScore: (json['consistency_score'] as num?)?.toDouble() ?? 92.0,
      preferredWorkoutTime:
          json['preferred_workout_time']?.toString() ?? 'evening',
      missedSessionTrigger:
          json['missed_session_trigger']?.toString() ?? 'accumulated_fatigue',
      habitContinuityRate:
          (json['habit_continuity_rate'] as num?)?.toDouble() ?? 0.94,
    );
  }

  Map<String, dynamic> toJson() => {
    'consistency_score': consistencyScore,
    'preferred_workout_time': preferredWorkoutTime,
    'missed_session_trigger': missedSessionTrigger,
    'habit_continuity_rate': habitContinuityRate,
  };

  BehaviorProfile copyWith({
    double? consistencyScore,
    String? preferredWorkoutTime,
    String? missedSessionTrigger,
    double? habitContinuityRate,
  }) {
    return BehaviorProfile(
      consistencyScore: consistencyScore ?? this.consistencyScore,
      preferredWorkoutTime: preferredWorkoutTime ?? this.preferredWorkoutTime,
      missedSessionTrigger: missedSessionTrigger ?? this.missedSessionTrigger,
      habitContinuityRate: habitContinuityRate ?? this.habitContinuityRate,
    );
  }
}

/// Goal timeline, target metrics, and milestones.
class GoalProfile {
  final String
  primaryGoal; // 'hypertrophy', 'strength', 'fat_loss', 'endurance'
  final double targetWeightKg;
  final DateTime? targetDate;
  final Map<String, double>
  targetStrengthMilestones; // e.g. {'Squat': 150.0, 'Bench Press': 120.0}

  const GoalProfile({
    this.primaryGoal = 'hypertrophy',
    this.targetWeightKg = 78.0,
    this.targetDate,
    this.targetStrengthMilestones = const {
      'Squat': 150.0,
      'Bench Press': 115.0,
      'Deadlift': 190.0,
    },
  });

  factory GoalProfile.fromJson(Map<String, dynamic> json) {
    final rawM =
        json['target_strength_milestones'] as Map<String, dynamic>? ?? {};
    final milestones = rawM.map((k, v) => MapEntry(k, (v as num).toDouble()));

    return GoalProfile(
      primaryGoal: json['primary_goal']?.toString() ?? 'hypertrophy',
      targetWeightKg: (json['target_weight_kg'] as num?)?.toDouble() ?? 78.0,
      targetDate: json['target_date'] != null
          ? DateTime.tryParse(json['target_date'].toString())
          : DateTime.now().add(const Duration(days: 90)),
      targetStrengthMilestones: milestones.isNotEmpty
          ? milestones
          : const {'Squat': 150.0, 'Bench Press': 115.0, 'Deadlift': 190.0},
    );
  }

  Map<String, dynamic> toJson() => {
    'primary_goal': primaryGoal,
    'target_weight_kg': targetWeightKg,
    'target_date': targetDate?.toIso8601String(),
    'target_strength_milestones': targetStrengthMilestones,
  };

  GoalProfile copyWith({
    String? primaryGoal,
    double? targetWeightKg,
    DateTime? targetDate,
    Map<String, double>? targetStrengthMilestones,
  }) {
    return GoalProfile(
      primaryGoal: primaryGoal ?? this.primaryGoal,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      targetDate: targetDate ?? this.targetDate,
      targetStrengthMilestones:
          targetStrengthMilestones ?? this.targetStrengthMilestones,
    );
  }
}

/// Unified Digital Twin of the Athlete.
/// Represents an adaptive, multi-dimensional intelligence representation of the user
/// continuously updated from workouts, diet, recovery, biomechanics, and AI coaching dialogues.
class DigitalAthlete {
  final String userId;
  final PhysicalProfile physicalProfile;
  final StrengthProfile strengthProfile;
  final TrainingProfile trainingProfile;
  final RecoveryProfile recoveryProfile;
  final NutritionProfile nutritionProfile;
  final BehaviorProfile behaviorProfile;
  final GoalProfile goalProfile;
  final List<String> biomechanicsWeaknesses;
  final Map<String, double> formScoreAverages;
  final DateTime updatedAt;

  const DigitalAthlete({
    required this.userId,
    this.physicalProfile = const PhysicalProfile(),
    this.strengthProfile = const StrengthProfile(),
    this.trainingProfile = const TrainingProfile(),
    this.recoveryProfile = const RecoveryProfile(),
    this.nutritionProfile = const NutritionProfile(),
    this.behaviorProfile = const BehaviorProfile(),
    this.goalProfile = const GoalProfile(),
    this.biomechanicsWeaknesses = const [
      'Knee valgus under heavy loads (>85% 1RM)',
    ],
    this.formScoreAverages = const {
      'Squat': 88.0,
      'Bench Press': 92.0,
      'Deadlift': 85.0,
    },
    required this.updatedAt,
  });

  /// Factory baseline default digital twin for new athletes
  factory DigitalAthlete.initial(String userId) {
    return DigitalAthlete(userId: userId, updatedAt: DateTime.now());
  }

  factory DigitalAthlete.fromJson(Map<String, dynamic> json) {
    final rawWeak = json['biomechanics_weaknesses'] as List<dynamic>? ?? [];
    final rawForm = json['form_score_averages'] as Map<String, dynamic>? ?? {};
    final formMap = rawForm.map((k, v) => MapEntry(k, (v as num).toDouble()));

    return DigitalAthlete(
      userId: json['user_id']?.toString() ?? 'usr_local',
      physicalProfile: json['physical_profile'] != null
          ? PhysicalProfile.fromJson(
              Map<String, dynamic>.from(json['physical_profile'] as Map),
            )
          : const PhysicalProfile(),
      strengthProfile: json['strength_profile'] != null
          ? StrengthProfile.fromJson(
              Map<String, dynamic>.from(json['strength_profile'] as Map),
            )
          : const StrengthProfile(),
      trainingProfile: json['training_profile'] != null
          ? TrainingProfile.fromJson(
              Map<String, dynamic>.from(json['training_profile'] as Map),
            )
          : const TrainingProfile(),
      recoveryProfile: json['recovery_profile'] != null
          ? RecoveryProfile.fromJson(
              Map<String, dynamic>.from(json['recovery_profile'] as Map),
            )
          : const RecoveryProfile(),
      nutritionProfile: json['nutrition_profile'] != null
          ? NutritionProfile.fromJson(
              Map<String, dynamic>.from(json['nutrition_profile'] as Map),
            )
          : const NutritionProfile(),
      behaviorProfile: json['behavior_profile'] != null
          ? BehaviorProfile.fromJson(
              Map<String, dynamic>.from(json['behavior_profile'] as Map),
            )
          : const BehaviorProfile(),
      goalProfile: json['goal_profile'] != null
          ? GoalProfile.fromJson(
              Map<String, dynamic>.from(json['goal_profile'] as Map),
            )
          : const GoalProfile(),
      biomechanicsWeaknesses: rawWeak.isNotEmpty
          ? rawWeak.map((e) => e.toString()).toList()
          : const ['Knee valgus under heavy loads (>85% 1RM)'],
      formScoreAverages: formMap.isNotEmpty
          ? formMap
          : const {'Squat': 88.0, 'Bench Press': 92.0, 'Deadlift': 85.0},
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'physical_profile': physicalProfile.toJson(),
    'strength_profile': strengthProfile.toJson(),
    'training_profile': trainingProfile.toJson(),
    'recovery_profile': recoveryProfile.toJson(),
    'nutrition_profile': nutritionProfile.toJson(),
    'behavior_profile': behaviorProfile.toJson(),
    'goal_profile': goalProfile.toJson(),
    'biomechanics_weaknesses': biomechanicsWeaknesses,
    'form_score_averages': formScoreAverages,
    'updated_at': updatedAt.toIso8601String(),
  };

  DigitalAthlete copyWith({
    String? userId,
    PhysicalProfile? physicalProfile,
    StrengthProfile? strengthProfile,
    TrainingProfile? trainingProfile,
    RecoveryProfile? recoveryProfile,
    NutritionProfile? nutritionProfile,
    BehaviorProfile? behaviorProfile,
    GoalProfile? goalProfile,
    List<String>? biomechanicsWeaknesses,
    Map<String, double>? formScoreAverages,
    DateTime? updatedAt,
  }) {
    return DigitalAthlete(
      userId: userId ?? this.userId,
      physicalProfile: physicalProfile ?? this.physicalProfile,
      strengthProfile: strengthProfile ?? this.strengthProfile,
      trainingProfile: trainingProfile ?? this.trainingProfile,
      recoveryProfile: recoveryProfile ?? this.recoveryProfile,
      nutritionProfile: nutritionProfile ?? this.nutritionProfile,
      behaviorProfile: behaviorProfile ?? this.behaviorProfile,
      goalProfile: goalProfile ?? this.goalProfile,
      biomechanicsWeaknesses:
          biomechanicsWeaknesses ?? this.biomechanicsWeaknesses,
      formScoreAverages: formScoreAverages ?? this.formScoreAverages,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
