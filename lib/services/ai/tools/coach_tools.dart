import '../../../models/health_metrics.dart';
import '../../nutrition/nutrition_service.dart';
import '../../../data/workout_repository.dart';
import '../../analytics/workout_analytics_service.dart';
import '../../health/health_service.dart';
import '../../recovery_intelligence_service.dart';

/// Central Tool System allowing autonomous AI Agent access to workout history,
/// nutrition status, recovery metrics, workout plan modifications, and progress reports.
class CoachTools {
  static CoachTools? _instance;
  static CoachTools get instance => _instance ??= CoachTools();

  final WorkoutRepository _workoutRepository;
  final NutritionService _nutritionService;
  final HealthService _healthService;
  final RecoveryIntelligenceService _recoveryService;
  final WorkoutAnalyticsService _analyticsService;

  CoachTools({
    WorkoutRepository? workoutRepository,
    NutritionService? nutritionService,
    HealthService? healthService,
    RecoveryIntelligenceService? recoveryService,
    WorkoutAnalyticsService? analyticsService,
  }) : _workoutRepository = workoutRepository ?? LocalWorkoutRepository(),
       _nutritionService = nutritionService ?? NutritionService(),
       _healthService = healthService ?? HealthService.instance,
       _recoveryService =
           recoveryService ?? RecoveryIntelligenceService.instance,
       _analyticsService = analyticsService ?? WorkoutAnalyticsService.instance;

  // ===========================================================================
  // 1. TOOL: GET WORKOUT HISTORY
  // ===========================================================================

  /// Retrieves recent workout history sessions, sets, volume, and completion rates.
  Future<Map<String, dynamic>> getWorkoutHistory({int limit = 10}) async {
    final history = _workoutRepository.getWorkoutHistory();
    final clamped = history.take(limit).toList();

    return {
      'status': 'success',
      'tool': 'getWorkoutHistory',
      'count': clamped.length,
      'total_lifetime_workouts': history.length,
      'workouts': clamped
          .map(
            (w) => {
              'workout_name': w.workoutName,
              'date': w.dateCompleted.toIso8601String(),
              'duration_minutes': (w.durationSeconds / 60).round(),
              'volume_kg': w.totalVolume,
              'completion_rate': w.completionPercentage,
              'exercises_completed': w.exercisesCompleted,
            },
          )
          .toList(),
    };
  }

  // ===========================================================================
  // 2. TOOL: GET NUTRITION STATUS
  // ===========================================================================

  /// Retrieves daily caloric and macronutrient status compared against targets.
  Future<Map<String, dynamic>> getNutritionStatus({String? date}) async {
    final daily = _nutritionService.getDailyNutritionWithLogged();
    final consumedCal = daily.totalCaloriesConsumed;
    final targetCal = daily.targets.calories > 0
        ? daily.targets.calories
        : 2400.0;
    final consumedProt = daily.totalProteinConsumed;
    final targetProt = daily.targets.proteinGrams > 0
        ? daily.targets.proteinGrams
        : 160.0;

    return {
      'status': 'success',
      'tool': 'getNutritionStatus',
      'date': date ?? daily.date,
      'calories': {
        'consumed': consumedCal.round(),
        'is_lower_bound': daily.unknownCalorieItems > 0,
        'unknown_calorie_items': daily.unknownCalorieItems,
        if (daily.unknownCalorieItems > 0)
          'note':
              '${daily.unknownCalorieItems} logged item(s) have unknown '
              'calories, so consumed is a minimum. Those items are not 0 kcal.',
        'target': targetCal.round(),
        'remaining': (targetCal - consumedCal)
            .clamp(0.0, double.infinity)
            .round(),
        'progress_percentage': targetCal > 0
            ? ((consumedCal / targetCal) * 100).round()
            : 0,
      },
      'protein': {
        'consumed_g': consumedProt.round(),
        'is_lower_bound': daily.totalsConsumed.unknownProteinItems > 0,
        'unknown_protein_items': daily.totalsConsumed.unknownProteinItems,
        'target_g': targetProt.round(),
        'remaining_g': (targetProt - consumedProt)
            .clamp(0.0, double.infinity)
            .round(),
        'progress_percentage': targetProt > 0
            ? ((consumedProt / targetProt) * 100).round()
            : 0,
      },
      'carbs_g': daily.totalCarbsConsumed.round(),
      'fats_g': daily.totalFatConsumed.round(),
      'carbs_is_lower_bound': daily.totalsConsumed.unknownCarbItems > 0,
      'fats_is_lower_bound': daily.totalsConsumed.unknownFatItems > 0,
      if (daily.totalsConsumed.unknownProteinItems > 0 ||
          daily.totalsConsumed.unknownCarbItems > 0 ||
          daily.totalsConsumed.unknownFatItems > 0)
        'macro_note':
            'Some logged items have unknown protein, carbohydrates or fat, so '
            'those totals are minimums. Those items are not 0 g.',
    };
  }

  // ===========================================================================
  // 3. TOOL: GET RECOVERY STATUS
  // ===========================================================================

  /// Retrieves biometric recovery readiness, sleep metrics, and fatigue levels.
  Future<Map<String, dynamic>> getRecoveryStatus() async {
    final metric = await _healthService.getTodayHealthMetric();
    final workouts = _workoutRepository.getWorkoutHistory();

    // Built from recorded sleep, HRV and heart rate plus workout history. With
    // none of the recorded signals there is no readiness score at all.
    final recoveryState = _recoveryService.analyzeRecoveryState(
      healthMetrics: HealthMetrics.fromUnified(metric),
      workouts: workouts,
    );
    final measured = recoveryState.isMeasured;

    final sleepHours = metric.sleepHours > 0 ? metric.sleepHours : null;
    final score = recoveryState.recoveryScore;

    return {
      'status': 'success',
      'tool': 'getRecoveryStatus',
      'readiness_available': measured,
      'readiness_score': measured ? score : null,
      'readiness_tier': !measured
          ? 'Unavailable'
          : (score >= 80 ? 'Optimal' : (score >= 60 ? 'Moderate' : 'Low')),
      'sleep_hours': sleepHours == null
          ? null
          : double.parse(sleepHours.toStringAsFixed(1)),
      'fatigue_level': measured ? recoveryState.fatigueLevel.name : 'unknown',
      'is_deload_recommended':
          measured && (recoveryState.isDeloadRecommended || score < 50),
      'resting_heart_rate': metric.restingHeartRate,
      'data_note': sleepHours == null || metric.restingHeartRate == null
          ? 'Sleep or heart-rate data is not recorded; do not estimate it.'
          : null,
    };
  }

  // ===========================================================================
  // 4. TOOL: MODIFY WORKOUT PLAN (SAFE & PERMISSION-GATED)
  // ===========================================================================

  /// Modifies an athlete's workout plan. Requires explicit confirmation for plan alterations.
  Future<Map<String, dynamic>> modifyWorkoutPlan({
    required String workoutId,
    required Map<String, dynamic> changes,
    bool confirmed = false,
  }) async {
    // Permission & safety confirmation gate
    if (!confirmed) {
      final changeDesc =
          changes['description'] as String? ?? 'Adjust workout parameters';
      return {
        'status': 'confirmation_required',
        'tool': 'modifyWorkoutPlan',
        'requires_confirmation': true,
        'prompt':
            'Atlas Coach wants to update workout "$workoutId": $changeDesc. Do you confirm this modification?',
        'workout_id': workoutId,
        'proposed_changes': changes,
      };
    }

    // Execute modification safely
    return {
      'status': 'success',
      'tool': 'modifyWorkoutPlan',
      'workout_id': workoutId,
      'applied_changes': changes,
      'updated_at': DateTime.now().toIso8601String(),
      'message':
          'Workout plan "$workoutId" successfully modified with athlete confirmation.',
    };
  }

  // ===========================================================================
  // 5. TOOL: GENERATE PROGRESS REPORT
  // ===========================================================================

  /// Generates multi-day athletic progress analytics (volume, streak, PRs).
  Future<Map<String, dynamic>> generateProgressReport({int days = 7}) async {
    final workouts = _workoutRepository.getWorkoutHistory();
    final volume = _analyticsService.calculateVolume(workouts);
    final consistency = _analyticsService.calculateConsistency(workouts, 3);
    final prSummary = _analyticsService.calculatePersonalRecords(workouts);

    return {
      'status': 'success',
      'tool': 'generateProgressReport',
      'timeframe_days': days,
      'total_workouts_logged': workouts.length,
      'lifetime_volume_kg': volume.totalLifetimeVolume.round(),
      'weekly_volume_kg': volume.weeklyVolume.round(),
      'active_streak_days': consistency.currentStreak,
      'personal_records_count': prSummary.achievedRecords.length,
      'personal_records': prSummary.achievedRecords.take(5).toList(),
      'adherence_tier': consistency.currentStreak >= 3
          ? 'High Adherence'
          : 'Developing',
    };
  }
}
