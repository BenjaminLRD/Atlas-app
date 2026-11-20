import '../steps/step_counter_service.dart';
import '../../models/daily_nutrition.dart';
import '../../models/health_metric.dart';
import '../../models/recovery_summary.dart';
import '../../models/user_goal.dart';
import '../../models/user_profile.dart';
import '../../models/weight_goal.dart';
import '../../models/workout_history.dart';
import '../ai/memory/fitness_memory.dart';
import '../ai/memory/memory_event.dart';
import 'athlete_state_engine.dart';

/// Summarized training and workout performance state.
class WorkoutStateSummary {
  final int totalWorkouts;
  final int weeklyWorkoutsCompleted;
  final String lastWorkoutName;
  final int daysSinceLastWorkout;
  final double recentVolumeKg;
  final List<String> prsAchieved;

  const WorkoutStateSummary({
    this.totalWorkouts = 0,
    this.weeklyWorkoutsCompleted = 0,
    this.lastWorkoutName = '',
    this.daysSinceLastWorkout = 0,
    this.recentVolumeKg = 0.0,
    this.prsAchieved = const [],
  });

  factory WorkoutStateSummary.fromJson(Map<String, dynamic> json) {
    return WorkoutStateSummary(
      totalWorkouts: (json['total_workouts'] as num?)?.toInt() ?? 0,
      weeklyWorkoutsCompleted:
          (json['weekly_workouts_completed'] as num?)?.toInt() ?? 0,
      lastWorkoutName: json['last_workout_name']?.toString() ?? '',
      daysSinceLastWorkout:
          (json['days_since_last_workout'] as num?)?.toInt() ?? 0,
      recentVolumeKg:
          (json['recent_volume_kg'] as num?)?.toDouble() ?? 0.0,
      prsAchieved:
          (json['prs_achieved'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'total_workouts': totalWorkouts,
    'weekly_workouts_completed': weeklyWorkoutsCompleted,
    'last_workout_name': lastWorkoutName,
    'days_since_last_workout': daysSinceLastWorkout,
    'recent_volume_kg': recentVolumeKg,
    'prs_achieved': prsAchieved,
  };
}

/// Summarized nutrition intake and macronutrient adherence.
class NutritionStateSummary {
  final int caloriesConsumed;
  final int targetCalories;
  final double proteinGramsConsumed;
  final double targetProteinGrams;
  final double carbsGramsConsumed;
  final double fatGramsConsumed;
  final double adherenceRate;
  final int calorieDelta; // consumed - target

  /// False when some food logged today has no calorie / protein value. The
  /// consumed figures are then minimums, so [calorieDelta] and
  /// [adherenceRate] are not reliable and [proteinDelta] is null.
  final bool caloriesComplete;
  final bool proteinComplete;

  const NutritionStateSummary({
    this.caloriesConsumed = 0,
    this.targetCalories = 2200,
    this.proteinGramsConsumed = 0.0,
    this.targetProteinGrams = 150.0,
    this.carbsGramsConsumed = 0.0,
    this.fatGramsConsumed = 0.0,
    this.adherenceRate = 0.0,
    this.calorieDelta = -2200,
    this.caloriesComplete = true,
    this.proteinComplete = true,
  });

  /// Protein still needed to reach the target (negative when exceeded), or
  /// null when the protein total is incomplete and the real figure unknown.
  double? get proteinDelta =>
      proteinComplete ? targetProteinGrams - proteinGramsConsumed : null;

  factory NutritionStateSummary.fromJson(Map<String, dynamic> json) {
    return NutritionStateSummary(
      caloriesConsumed: (json['calories_consumed'] as num?)?.toInt() ?? 0,
      targetCalories: (json['target_calories'] as num?)?.toInt() ?? 2200,
      proteinGramsConsumed:
          (json['protein_grams_consumed'] as num?)?.toDouble() ?? 0.0,
      targetProteinGrams:
          (json['target_protein_grams'] as num?)?.toDouble() ?? 150.0,
      carbsGramsConsumed:
          (json['carbs_grams_consumed'] as num?)?.toDouble() ?? 0.0,
      fatGramsConsumed:
          (json['fat_grams_consumed'] as num?)?.toDouble() ?? 0.0,
      adherenceRate: (json['adherence_rate'] as num?)?.toDouble() ?? 0.0,
      calorieDelta: (json['calorie_delta'] as num?)?.toInt() ?? 0,
      caloriesComplete: json['calories_complete'] as bool? ?? true,
      proteinComplete: json['protein_complete'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'calories_consumed': caloriesConsumed,
    'target_calories': targetCalories,
    'protein_grams_consumed': proteinGramsConsumed,
    'target_protein_grams': targetProteinGrams,
    'carbs_grams_consumed': carbsGramsConsumed,
    'fat_grams_consumed': fatGramsConsumed,
    'adherence_rate': adherenceRate,
    'calorie_delta': calorieDelta,
    if (!caloriesComplete) 'calories_complete': false,
    if (!proteinComplete) 'protein_complete': false,
  };
}

/// Summarized recovery, sleep, and fatigue state.
///
/// [isMeasured] is true only when a sleep, HRV or heart-rate reading backs it.
/// Otherwise [readinessScore] is a neutral placeholder, [fatigueLevel] is
/// 'unknown' and no engine or message may treat them as measurements. Sleep,
/// HRV and resting heart rate are null when not recorded.
class RecoveryStateSummary {
  final bool isMeasured;
  final int readinessScore; // 0 to 100 (meaningful only when [isMeasured])
  final double? sleepHours;
  final double? hrvAverage;
  final int? restingHeartRate;
  final String fatigueLevel; // 'low', 'moderate', 'high', 'critical', 'unknown'
  final bool isDeloadRecommended;

  const RecoveryStateSummary({
    this.isMeasured = false,
    this.readinessScore = 80,
    this.sleepHours,
    this.hrvAverage,
    this.restingHeartRate,
    this.fatigueLevel = 'unknown',
    this.isDeloadRecommended = false,
  });

  /// Saved summaries from before this flag existed read as not measured.
  factory RecoveryStateSummary.fromJson(Map<String, dynamic> json) {
    final measured = json['is_measured'] == true;
    return RecoveryStateSummary(
      isMeasured: measured,
      readinessScore: (json['readiness_score'] as num?)?.toInt() ?? 80,
      sleepHours: (json['sleep_hours'] as num?)?.toDouble(),
      hrvAverage: (json['hrv_average'] as num?)?.toDouble(),
      restingHeartRate: (json['resting_heart_rate'] as num?)?.toInt(),
      fatigueLevel: measured ? (json['fatigue_level']?.toString() ?? 'unknown') : 'unknown',
      isDeloadRecommended: measured && json['is_deload_recommended'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'is_measured': isMeasured,
    'readiness_score': readinessScore,
    if (sleepHours != null) 'sleep_hours': sleepHours,
    if (hrvAverage != null) 'hrv_average': hrvAverage,
    if (restingHeartRate != null) 'resting_heart_rate': restingHeartRate,
    'fatigue_level': fatigueLevel,
    'is_deload_recommended': isDeloadRecommended,
  };
}

/// Summarized daily physical activity telemetry.
class HealthStateSummary {
  /// Null when there is no step reading (never read as zero steps).
  final int? todaySteps;
  final int stepGoal;
  final double activeCalories;

  const HealthStateSummary({
    this.todaySteps,
    this.stepGoal = 10000,
    this.activeCalories = 0.0,
  });

  factory HealthStateSummary.fromJson(Map<String, dynamic> json) {
    return HealthStateSummary(
      todaySteps: (json['today_steps'] as num?)?.toInt(),
      stepGoal: (json['step_goal'] as num?)?.toInt() ?? 10000,
      activeCalories: (json['active_calories'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    if (todaySteps != null) 'today_steps': todaySteps,
    'step_goal': stepGoal,
    'active_calories': activeCalories,
  };
}

/// Summarized behavioral patterns, consistency, and habits.
class BehaviorStateSummary {
  final double consistencyScore; // 0 to 100
  final String preferredWorkoutTime; // 'morning', 'afternoon', 'evening'
  final double habitContinuityRate;
  final int streakDays;
  final String missedSessionTrigger;

  const BehaviorStateSummary({
    this.consistencyScore = 85.0,
    this.preferredWorkoutTime = 'evening',
    this.habitContinuityRate = 0.9,
    this.streakDays = 0,
    this.missedSessionTrigger = 'fatigue',
  });

  factory BehaviorStateSummary.fromJson(Map<String, dynamic> json) {
    return BehaviorStateSummary(
      consistencyScore:
          (json['consistency_score'] as num?)?.toDouble() ?? 85.0,
      preferredWorkoutTime:
          json['preferred_workout_time']?.toString() ?? 'evening',
      habitContinuityRate:
          (json['habit_continuity_rate'] as num?)?.toDouble() ?? 0.9,
      streakDays: (json['streak_days'] as num?)?.toInt() ?? 0,
      missedSessionTrigger:
          json['missed_session_trigger']?.toString() ?? 'fatigue',
    );
  }

  Map<String, dynamic> toJson() => {
    'consistency_score': consistencyScore,
    'preferred_workout_time': preferredWorkoutTime,
    'habit_continuity_rate': habitContinuityRate,
    'streak_days': streakDays,
    'missed_session_trigger': missedSessionTrigger,
  };
}

/// Summarized athlete targets, primary goal, and milestones.
class GoalStateSummary {
  final String primaryGoal; // 'hypertrophy', 'strength', 'fat_loss', 'endurance'
  final double targetWeightKg;
  final double currentWeightKg;
  final Map<String, double> targetStrengthMilestones;

  const GoalStateSummary({
    this.primaryGoal = 'hypertrophy',
    this.targetWeightKg = 75.0,
    this.currentWeightKg = 75.0,
    this.targetStrengthMilestones = const {},
  });

  factory GoalStateSummary.fromJson(Map<String, dynamic> json) {
    final rawM =
        json['target_strength_milestones'] as Map<String, dynamic>? ?? {};
    final map = rawM.map((k, v) => MapEntry(k, (v as num).toDouble()));

    return GoalStateSummary(
      primaryGoal: json['primary_goal']?.toString() ?? 'hypertrophy',
      targetWeightKg: (json['target_weight_kg'] as num?)?.toDouble() ?? 75.0,
      currentWeightKg: (json['current_weight_kg'] as num?)?.toDouble() ?? 75.0,
      targetStrengthMilestones: map,
    );
  }

  Map<String, dynamic> toJson() => {
    'primary_goal': primaryGoal,
    'target_weight_kg': targetWeightKg,
    'current_weight_kg': currentWeightKg,
    'target_strength_milestones': targetStrengthMilestones,
  };
}

/// Comprehensive, multi-dimensional snapshot of athlete state.
class AthleteStateSnapshot {
  final String userId;
  final DateTime timestamp;
  final String overallReadinessTier; // 'optimal', 'moderate', 'fatigued', 'critical'
  final WorkoutStateSummary workout;
  final NutritionStateSummary nutrition;
  final RecoveryStateSummary recovery;
  final HealthStateSummary health;
  final BehaviorStateSummary behavior;
  final GoalStateSummary goal;

  const AthleteStateSnapshot({
    required this.userId,
    required this.timestamp,
    required this.overallReadinessTier,
    required this.workout,
    required this.nutrition,
    required this.recovery,
    required this.health,
    required this.behavior,
    required this.goal,
  });

  factory AthleteStateSnapshot.initial(String userId) {
    return AthleteStateSnapshot(
      userId: userId,
      timestamp: DateTime.now(),
      overallReadinessTier: 'optimal',
      workout: const WorkoutStateSummary(),
      nutrition: const NutritionStateSummary(),
      recovery: const RecoveryStateSummary(),
      health: const HealthStateSummary(),
      behavior: const BehaviorStateSummary(),
      goal: const GoalStateSummary(),
    );
  }

  factory AthleteStateSnapshot.fromJson(Map<String, dynamic> json) {
    return AthleteStateSnapshot(
      userId: json['user_id']?.toString() ?? 'user_local',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      overallReadinessTier:
          json['overall_readiness_tier']?.toString() ?? 'optimal',
      workout: json['workout'] != null
          ? WorkoutStateSummary.fromJson(
              Map<String, dynamic>.from(json['workout'] as Map),
            )
          : const WorkoutStateSummary(),
      nutrition: json['nutrition'] != null
          ? NutritionStateSummary.fromJson(
              Map<String, dynamic>.from(json['nutrition'] as Map),
            )
          : const NutritionStateSummary(),
      recovery: json['recovery'] != null
          ? RecoveryStateSummary.fromJson(
              Map<String, dynamic>.from(json['recovery'] as Map),
            )
          : const RecoveryStateSummary(),
      health: json['health'] != null
          ? HealthStateSummary.fromJson(
              Map<String, dynamic>.from(json['health'] as Map),
            )
          : const HealthStateSummary(),
      behavior: json['behavior'] != null
          ? BehaviorStateSummary.fromJson(
              Map<String, dynamic>.from(json['behavior'] as Map),
            )
          : const BehaviorStateSummary(),
      goal: json['goal'] != null
          ? GoalStateSummary.fromJson(
              Map<String, dynamic>.from(json['goal'] as Map),
            )
          : const GoalStateSummary(),
    );
  }

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'timestamp': timestamp.toIso8601String(),
    'overall_readiness_tier': overallReadinessTier,
    'workout': workout.toJson(),
    'nutrition': nutrition.toJson(),
    'recovery': recovery.toJson(),
    'health': health.toJson(),
    'behavior': behavior.toJson(),
    'goal': goal.toJson(),
  };

  /// Generates a rich, structured prompt string describing current athlete state.
  String toPromptContext() {
    final buffer = StringBuffer();
    buffer.writeln('--- ATHLETE STATE SNAPSHOT ---');
    if (recovery.isMeasured) {
      buffer.writeln('Readiness Tier: ${overallReadinessTier.toUpperCase()} (Score: ${recovery.readinessScore}/100, Sleep: ${recovery.sleepHours == null ? 'not recorded' : '${recovery.sleepHours}h'}, Fatigue: ${recovery.fatigueLevel})');
    } else {
      buffer.writeln('Readiness: unavailable (no sleep, HRV or heart-rate data recorded; do not estimate it). Sleep: ${recovery.sleepHours == null ? 'not recorded' : '${recovery.sleepHours}h'}.');
    }
    buffer.writeln('Workouts: ${workout.totalWorkouts} total, ${workout.weeklyWorkoutsCompleted} this week. Last: "${workout.lastWorkoutName}" (${workout.daysSinceLastWorkout}d ago).');
    buffer.writeln('Nutrition: ${nutrition.caloriesConsumed}/${nutrition.targetCalories} kcal, ${nutrition.proteinGramsConsumed.round()}/${nutrition.targetProteinGrams.round()}g Protein.');
    buffer.writeln('Health: ${health.todaySteps == null ? 'steps not recorded' : '${health.todaySteps}/${health.stepGoal} steps'}, ${health.activeCalories.round()} active kcal.');
    buffer.writeln('Behavior: Consistency: ${behavior.consistencyScore.round()}%, Streak: ${behavior.streakDays} days, Preferred Time: ${behavior.preferredWorkoutTime}.');
    buffer.writeln('Goal: ${goal.primaryGoal} (Target Weight: ${goal.targetWeightKg}kg, Current: ${goal.currentWeightKg}kg).');
    return buffer.toString();
  }
}

/// Central aggregator assembling raw athlete telemetry across workouts, nutrition,
/// recovery, health, behavior, and goals into a unified [AthleteStateSnapshot].
class AthleteStateAggregator {
  static AthleteStateAggregator? _instance;
  static AthleteStateAggregator get instance =>
      _instance ??= AthleteStateAggregator();

  final AthleteStateEngine _athleteEngine;

  AthleteStateAggregator({AthleteStateEngine? athleteEngine})
    : _athleteEngine = athleteEngine ?? AthleteStateEngine.instance;

  /// Aggregates multi-source telemetry into a cohesive snapshot.
  AthleteStateSnapshot aggregateSnapshot({
    required String userId,
    List<WorkoutHistory> workoutHistory = const [],
    DailyNutrition? todayNutrition,
    RecoverySummary? recovery,
    List<HealthMetric> healthMetrics = const [],
    UserProfile? profile,
    UserGoal? userGoal,
    WeightGoal? weightGoal,
    FitnessMemory? memory,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    final digitalAthlete = _athleteEngine.getAthlete(userId);

    // 1. WORKOUT DATA
    final totalWorkouts = workoutHistory.length;
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final weeklyWorkouts = workoutHistory
        .where((w) => w.dateCompleted.isAfter(sevenDaysAgo))
        .toList();
    final lastWorkout = workoutHistory.isNotEmpty ? workoutHistory.first : null;
    final daysSinceLast = lastWorkout != null
        ? now.difference(lastWorkout.dateCompleted).inDays
        : 99;
    final recentVolume = weeklyWorkouts.fold<double>(
      0.0,
      (sum, w) => sum + w.totalVolume,
    );

    final prs = <String>[];
    for (final w in workoutHistory.take(5)) {
      if (w.completionPercentage >= 100 && w.totalVolume > 2000) {
        prs.add('${w.workoutName} Volume PR');
      }
    }

    final workoutSummary = WorkoutStateSummary(
      totalWorkouts: totalWorkouts,
      weeklyWorkoutsCompleted: weeklyWorkouts.length,
      lastWorkoutName: lastWorkout?.workoutName ?? 'None',
      daysSinceLastWorkout: daysSinceLast,
      recentVolumeKg: recentVolume,
      prsAchieved: prs.toSet().toList(),
    );

    // 2. NUTRITION DATA
    final int targetCal = (weightGoal?.dailyCalorieTarget.round() ??
            userGoal?.targetCalories.round() ??
            digitalAthlete.nutritionProfile.dailyCalories);
    final targetProt = weightGoal?.proteinGrams ??
        userGoal?.targetProtein ??
        digitalAthlete.nutritionProfile.dailyProteinGrams;

    final consumedCal = todayNutrition?.totalCaloriesConsumed.round() ?? 0;
    final consumedProt = todayNutrition?.totalProteinConsumed ?? 0.0;
    final consumedCarb = todayNutrition?.totalCarbsConsumed ?? 0.0;
    final consumedFat = todayNutrition?.totalFatConsumed ?? 0.0;
    // With unknown values the figures above are minimums (see the flags).
    final consumedTotals = todayNutrition?.totalsConsumed;

    final adherence = targetCal > 0 ? (consumedCal / targetCal).clamp(0.0, 1.5) : 0.0;

    final nutritionSummary = NutritionStateSummary(
      caloriesConsumed: consumedCal,
      targetCalories: targetCal,
      proteinGramsConsumed: consumedProt,
      targetProteinGrams: targetProt,
      carbsGramsConsumed: consumedCarb,
      fatGramsConsumed: consumedFat,
      adherenceRate: adherence,
      calorieDelta: consumedCal - targetCal,
      caloriesComplete: consumedTotals?.caloriesComplete ?? true,
      proteinComplete: consumedTotals?.proteinComplete ?? true,
    );

    // 3. RECOVERY DATA
    // Only recorded values: no learned or default sleep, HRV or heart rate
    // stands in for a missing reading, and no score is made up.
    final measured = recovery != null && recovery.isMeasured;
    final readiness = measured ? recovery.score : 80; // placeholder if !measured
    final sleepRaw = recovery?.sleepHours;
    final double? sleep = (sleepRaw != null && sleepRaw > 0) ? sleepRaw : null;
    final hrv = recovery?.hrv;
    final rhr = recovery?.restingHeartRate?.round();
    final isDeload = measured && recovery.isDeloadRecommended;

    String fatigueTier;
    if (!measured) {
      fatigueTier = 'unknown';
    } else if (readiness >= 80) {
      fatigueTier = 'low';
    } else if (readiness >= 60) {
      fatigueTier = 'moderate';
    } else if (readiness >= 45) {
      fatigueTier = 'high';
    } else {
      fatigueTier = 'critical';
    }

    final recoverySummary = RecoveryStateSummary(
      isMeasured: measured,
      readinessScore: readiness,
      sleepHours: sleep,
      hrvAverage: hrv,
      restingHeartRate: rhr,
      fatigueLevel: fatigueTier,
      isDeloadRecommended: isDeload,
    );

    // 4. HEALTH DATA
    // Steps come from the step service (phone sensor and Health Connect).
    final int? steps = StepCounterService.instance.today.steps;
    double activeCal = 0.0;
    if (healthMetrics.isNotEmpty) {
      activeCal = healthMetrics.first.activeCalories;
    }

    final healthSummary = HealthStateSummary(
      todaySteps: steps,
      stepGoal: 10000,
      activeCalories: activeCal,
    );

    // 5. BEHAVIOR DATA
    final consistency = digitalAthlete.behaviorProfile.consistencyScore;
    final preferredTime = digitalAthlete.behaviorProfile.preferredWorkoutTime;
    final habitRate = digitalAthlete.behaviorProfile.habitContinuityRate;
    final missedTrigger = digitalAthlete.behaviorProfile.missedSessionTrigger;

    final streakCount = memory?.getEvents().where((e) => e.type == MemoryEventType.workoutCompleted).length ?? weeklyWorkouts.length;

    final behaviorSummary = BehaviorStateSummary(
      consistencyScore: consistency,
      preferredWorkoutTime: preferredTime,
      habitContinuityRate: habitRate,
      streakDays: streakCount,
      missedSessionTrigger: missedTrigger,
    );

    // 6. GOALS DATA
    final primaryGoal = weightGoal?.type.displayName ??
        userGoal?.goalType.name ??
        digitalAthlete.goalProfile.primaryGoal;
    final targetWeight = weightGoal?.targetWeight ??
        digitalAthlete.goalProfile.targetWeightKg;
    final currentWeight = weightGoal?.currentWeight ??
        (profile?.weight.isNotEmpty == true
            ? double.tryParse(profile!.weight) ?? 75.0
            : digitalAthlete.physicalProfile.weightKg);

    final goalSummary = GoalStateSummary(
      primaryGoal: primaryGoal,
      targetWeightKg: targetWeight,
      currentWeightKg: currentWeight,
      targetStrengthMilestones:
          digitalAthlete.goalProfile.targetStrengthMilestones,
    );

    // Calculate Overall Readiness Tier
    String overallTier;
    if (!measured) {
      overallTier = 'unknown';
    } else if (readiness >= 80 && (sleep == null || sleep >= 7.0)) {
      overallTier = 'optimal';
    } else if (readiness >= 60 && (sleep == null || sleep >= 6.0)) {
      overallTier = 'moderate';
    } else if (readiness >= 45) {
      overallTier = 'fatigued';
    } else {
      overallTier = 'critical';
    }

    return AthleteStateSnapshot(
      userId: userId,
      timestamp: now,
      overallReadinessTier: overallTier,
      workout: workoutSummary,
      nutrition: nutritionSummary,
      recovery: recoverySummary,
      health: healthSummary,
      behavior: behaviorSummary,
      goal: goalSummary,
    );
  }
}
