import '../../models/recovery/readiness_inputs.dart';
import '../../models/coach_action.dart';
import '../../models/daily_coach_brief.dart';
import '../../models/fitness_context.dart';
import '../../models/health_metrics.dart';
import '../../models/recommended_workout.dart';
import '../../models/recovery_state.dart';
import '../../models/recovery_summary.dart';
import '../../models/workout_recommendation.dart';
import '../workout_planner_service.dart';
import 'memory/fitness_memory.dart';

/// Autonomous Daily AI Coach Brief Service transforming the AI Coach into a proactive fitness companion.
/// Synthesizes health telemetry, sleep, recovery readiness, scheduled training splits,
/// nutrition deltas, and athlete progress into actionable daily briefings.
class DailyCoachBriefService {
  final WorkoutPlannerService _workoutPlanner;

  DailyCoachBriefService({WorkoutPlannerService? workoutPlanner})
    : _workoutPlanner = workoutPlanner ?? WorkoutPlannerService.instance;

  /// Generates an autonomous, multi-domain [DailyCoachBrief].
  DailyCoachBrief generateBrief({
    required FitnessContext context,
    HealthMetrics? healthMetrics,
    RecoveryState? recoveryState,
    FitnessMemory? memory,
    DateTime? date,
  }) {
    final now = date ?? DateTime.now();

    // 1. GREETING & ATHLETE IDENTITY
    final rawName = context.userProfile?.name.trim() ?? '';
    final athleteName = rawName.isNotEmpty ? rawName : 'Athlete';
    final timeOfDayGreeting = _getTimeOfDayGreeting(now.hour);
    final greeting = '$timeOfDayGreeting, $athleteName.';

    // 2. HEALTH & RECOVERY SYNTHESIS
    // Recovery comes from recorded data only. With no sleep, HRV or heart-rate
    // reading the brief says so instead of showing a score or an invented night.
    final metricInputs = ReadinessInputs.fromMetrics(
      healthMetrics,
      hasWorkoutHistory: context.workoutHistory.isNotEmpty,
    );
    var effectiveRecovery =
        recoveryState ??
        context.recoveryState ??
        RecoveryState(
          id: 'rec_${now.millisecondsSinceEpoch}',
          inputs: metricInputs,
          lastUpdated: now,
        );
    if (!effectiveRecovery.isMeasured && metricInputs.hasPhysiological) {
      effectiveRecovery = effectiveRecovery.copyWith(inputs: metricInputs);
    }

    final recordedSleep = healthMetrics?.sleepHours;
    final double? sleepHours = (recordedSleep != null && recordedSleep > 0)
        ? double.parse(recordedSleep.toStringAsFixed(1))
        : null;

    final recoverySummary = RecoverySummary.fromRecoveryState(
      effectiveRecovery,
      sleepHours: sleepHours,
      restingHeartRate: healthMetrics?.restingHeartRate,
      hrv: healthMetrics?.hrv,
    );

    // 3. NUTRITION DELTAS & ANALYSIS
    final nutritionSummary = context.nutritionSummary;
    // Targets come from the user's goal only; none is made up.
    final double? targetProtein =
        (context.weightGoal?.proteinGrams ?? context.userGoal?.targetProtein)
            ?.toDouble();
    final double? targetCalories =
        (context.weightGoal?.dailyCalorieTarget ??
                context.userGoal?.targetCalories)
            ?.toDouble();

    // Evaluate recent/yesterday nutrition delta
    // Null when the protein behind the figure is unknown (foods without a
    // protein value): then no message says protein was low or on target.
    final todayLog = context.todayNutritionLog;
    final double? recentProtein =
        (nutritionSummary.proteinKnown && nutritionSummary.averageProtein > 0)
        ? nutritionSummary.averageProtein
        : (todayLog == null
              ? 0.0
              : (todayLog.totals.proteinComplete
                    ? todayLog.dailyProtein
                    : null));
    final double? proteinDelta =
        (recentProtein == null || targetProtein == null)
        ? null
        : targetProtein - recentProtein;

    // 4. WORKOUT SCHEDULING & READINESS ADAPTATION
    RecommendedWorkout recommendedWorkout;
    try {
      recommendedWorkout = _workoutPlanner.getTodayRecommendation(
        goal: context.userGoal,
        workoutHistory: context.workoutHistory,
      );
    } catch (_) {
      recommendedWorkout = RecommendedWorkout(
        id: 'rec_w_${now.millisecondsSinceEpoch}',
        title: 'Upper Push Power & Chest Builder',
        focusMuscleGroups: const ['Chest', 'Shoulders', 'Triceps'],
        intensity: 'moderate',
        exercises: const [
          'Barbell Bench Press',
          'Incline Dumbbell Press',
          'Dumbbell Lateral Raise',
          'Tricep Pushdown',
        ],
        reason: 'Scheduled push day progression.',
        estimatedDuration: 45,
      );
    }

    WorkoutRecommendation workoutRec;
    if (recoverySummary.isDeloadRecommended ||
        effectiveRecovery.fatigueLevel == FatigueLevel.critical) {
      workoutRec = WorkoutRecommendation.restDay(
        reasoning:
            'High fatigue detected. Active recovery & mobility will prevent overtraining and optimize readiness.',
      );
    } else {
      workoutRec = WorkoutRecommendation.fromRecommendedWorkout(
        recommendedWorkout,
        intensityLevel: effectiveRecovery.recoveryScore >= 80
            ? 'High'
            : 'Moderate',
      );
    }

    // 5. PROGRESS SUMMARY
    final progressSummary = context.progressSummary;

    // 6. PROACTIVE COACH ACTIONS
    final actions = <CoachAction>[];

    // Action A: Training
    if (workoutRec.isRestDay) {
      actions.add(
        CoachAction(
          id: 'act_rec_${now.millisecondsSinceEpoch}',
          title: 'Active Recovery & Mobility Flow',
          description: 'Spend 15-20 minutes on light mobility and stretching.',
          category: 'recovery',
          priority: CoachActionPriority.medium,
          actionRoute: 'open_recovery',
          actionLabel: 'Start Mobility',
          createdAt: now,
        ),
      );
    } else {
      actions.add(
        CoachAction(
          id: 'act_w_${now.millisecondsSinceEpoch}',
          title: 'Complete ${workoutRec.workoutTitle}',
          description:
              'Focus on progressive overload across ${workoutRec.exerciseCount} exercises (${workoutRec.estimatedDurationMinutes} min).',
          category: 'workout',
          priority: CoachActionPriority.high,
          actionRoute: 'open_workout',
          actionLabel: 'Start Workout',
          createdAt: now,
        ),
      );
    }

    // Action B: Nutrition
    if (proteinDelta != null && targetProtein != null && proteinDelta > 15) {
      actions.add(
        CoachAction(
          id: 'act_nut_${now.millisecondsSinceEpoch}',
          title: 'Hit ${targetProtein.round()}g Protein Target',
          description:
              'Protein intake was ${proteinDelta.round()}g below target yesterday. Add a high-protein meal or shake early.',
          category: 'nutrition',
          priority: CoachActionPriority.high,
          actionRoute: 'open_nutrition',
          actionLabel: 'Log Nutrition',
          createdAt: now,
        ),
      );
    } else {
      actions.add(
        CoachAction(
          id: 'act_nut_${now.millisecondsSinceEpoch}',
          title: 'Maintain Fuel & Macro Balance',
          description: (targetCalories != null && targetProtein != null)
              ? 'Target ${targetCalories.round()} kcal and ${targetProtein.round()}g protein today.'
              : 'Log your meals today so Atlas can track your calories and protein. Set targets in your goal to see them here.',
          category: 'nutrition',
          priority: CoachActionPriority.medium,
          actionRoute: 'open_nutrition',
          actionLabel: 'Log Meals',
          createdAt: now,
        ),
      );
    }

    // Action C: Hydration & Sleep Habit
    actions.add(
      CoachAction(
        id: 'act_hab_${now.millisecondsSinceEpoch}',
        title: 'Hydration & Recovery Focus',
        description:
            'Aim for 2.5L+ water and 8 hours of sleep to support muscle protein synthesis.',
        category: 'habit',
        priority: CoachActionPriority.low,
        actionRoute: 'open_health',
        actionLabel: 'View Health',
        createdAt: now,
      ),
    );

    // 7. AUTONOMOUS PROACTIVE NARRATIVE
    final proactiveMessage = _buildProactiveMessage(
      greeting: greeting,
      recovery: recoverySummary,
      workout: workoutRec,
      targetProtein: targetProtein,
      proteinDelta: proteinDelta,
      actions: actions,
    );

    return DailyCoachBrief(
      date: now,
      greeting: greeting,
      actions: actions,
      recovery: recoverySummary,
      nutrition: nutritionSummary,
      workout: workoutRec,
      progress: progressSummary,
      proactiveMessage: proactiveMessage,
    );
  }

  String _getTimeOfDayGreeting(int hour) {
    if (hour >= 5 && hour < 12) {
      return 'Good morning';
    } else if (hour >= 12 && hour < 17) {
      return 'Good afternoon';
    } else if (hour >= 17 && hour < 22) {
      return 'Good evening';
    } else {
      return 'Hello';
    }
  }

  String _buildProactiveMessage({
    required String greeting,
    required RecoverySummary recovery,
    required WorkoutRecommendation workout,
    required double? targetProtein,
    required double? proteinDelta,
    required List<CoachAction> actions,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(greeting);
    // Only recorded values are quoted; a missing night or score is said to be
    // unavailable.
    final sleep = recovery.sleepHours;
    buffer.writeln(
      recovery.isMeasured
          ? 'Your recovery score is ${recovery.recoveryScore}%. ${sleep == null ? 'Sleep is not available.' : 'You slept $sleep hours.'}'
          : 'Recovery and sleep are unavailable: no sleep, HRV or heart-rate data is recorded.',
    );

    if (workout.isRestDay) {
      buffer.writeln('Today is scheduled as an active recovery day.');
    } else {
      buffer.writeln('Your ${workout.splitType} workout is scheduled today.');
    }

    if (proteinDelta != null && proteinDelta > 15) {
      buffer.writeln();
      buffer.writeln(
        'Your protein intake yesterday was ${proteinDelta.round()}g below target.',
      );
    } else if (proteinDelta != null &&
        proteinDelta <= 0 &&
        targetProtein != null &&
        targetProtein > 0) {
      buffer.writeln();
      buffer.writeln('You successfully hit your daily protein goal yesterday!');
    }

    buffer.writeln();
    buffer.writeln('Recommendation:');
    if (workout.isRestDay) {
      buffer.write('Take an active recovery day with light mobility');
    } else {
      buffer.write("Complete today's ${workout.splitType} workout");
    }

    if (proteinDelta != null && proteinDelta > 15) {
      buffer.write(' and add a high-protein breakfast.');
    } else {
      buffer.write(' and maintain your macro targets.');
    }

    return buffer.toString();
  }
}
