import '../../../models/health_metrics.dart';
import '../../step_tracking_service.dart';
import '../../steps/step_counter_service.dart';
import '../../health/health_service.dart';
import '../../recovery_intelligence_service.dart';
import '../../../data/local_storage.dart';
import 'ai_tool.dart';

/// AI Agent tool for querying recovery scores, sleep metrics, fatigue, and physical activity.
class HealthTool extends AITool {
  final HealthService _healthService;
  final RecoveryIntelligenceService _recoveryService;

  HealthTool({
    HealthService? healthService,
    RecoveryIntelligenceService? recoveryService,
  }) : _healthService = healthService ?? HealthService.instance,
       _recoveryService =
           recoveryService ?? RecoveryIntelligenceService.instance;

  @override
  String get name => 'health_tool';

  @override
  String get description =>
      'Retrieves athlete recovery readiness score (0-100), sleep duration and quality, fatigue levels, and today\'s step/activity metrics.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'OBJECT',
    'properties': {
      'action': {
        'type': 'STRING',
        'enum': [
          'get_recovery_score',
          'get_sleep_data',
          'get_fatigue_level',
          'get_today_activity',
        ],
        'description': 'The health metric action to perform.',
      },
    },
    'required': ['action'],
  };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    final action = arguments['action'] as String? ?? 'get_recovery_score';

    switch (action) {
      case 'get_recovery_score':
        return _getRecoveryScore();
      case 'get_sleep_data':
        return _getSleepData();
      case 'get_fatigue_level':
        return _getFatigueLevel();
      case 'get_today_activity':
        return _getTodayActivity();
      default:
        return {'status': 'error', 'message': 'Unknown action: $action'};
    }
  }

  Future<Map<String, dynamic>> _getRecoveryScore() async {
    final metric = await _healthService.getTodayHealthMetric();
    final workouts = LocalStorage.getWorkoutHistory();

    // Built from recorded sleep, HRV and heart rate plus workout history. With
    // none of the recorded signals the result is "unavailable", never a score.
    final recoveryState = _recoveryService.analyzeRecoveryState(
      healthMetrics: HealthMetrics.fromUnified(metric),
      workouts: workouts,
    );
    if (!recoveryState.isMeasured) {
      return {
        'status': 'success',
        'action': 'get_recovery_score',
        'readiness_available': false,
        'recovery_score': null,
        'readiness_tier': 'Unavailable',
        'is_deload_recommended': false,
        'recommendation':
            'Recovery cannot be assessed: no sleep, HRV or heart-rate data is recorded. Do not estimate it.',
      };
    }

    final score = recoveryState.recoveryScore;
    final isDeload = recoveryState.isDeloadRecommended;

    String recommendation = 'Ready for heavy compound lifting.';
    if (score < 50 || isDeload) {
      recommendation =
          'High systemic fatigue detected. Deload or active recovery recommended.';
    } else if (score < 70) {
      recommendation =
          'Moderate readiness. Stick to planned volume without pushing to failure.';
    }

    return {
      'status': 'success',
      'action': 'get_recovery_score',
      'readiness_available': true,
      'recovery_score': score,
      'readiness_tier': score >= 80
          ? 'Optimal'
          : (score >= 60 ? 'Moderate' : 'Low'),
      'is_deload_recommended': isDeload,
      'recommendation': recommendation,
    };
  }

  Future<Map<String, dynamic>> _getSleepData() async {
    final metric = await _healthService.getTodayHealthMetric();
    // Nothing is estimated: no reading means null and an explicit note.
    final hasSleep = metric.sleepHours > 0;
    final rhr = metric.restingHeartRate;
    final restingHeartRate = (rhr != null && rhr > 0) ? rhr : null;

    return {
      'status': 'success',
      'action': 'get_sleep_data',
      'sleep_hours': hasSleep
          ? double.parse(metric.sleepHours.toStringAsFixed(1))
          : null,
      'formatted_sleep': hasSleep ? metric.formattedSleep : null,
      'resting_heart_rate_bpm': restingHeartRate,
      'is_optimal_sleep': hasSleep ? metric.sleepHours >= 7.0 : null,
      'data_note': hasSleep && restingHeartRate != null
          ? null
          : 'Sleep or heart-rate data is not recorded; do not estimate it.',
    };
  }

  Future<Map<String, dynamic>> _getFatigueLevel() async {
    // Based on workout history only; a step count is not a recovery signal.
    final recoveryState = _recoveryService.analyzeRecoveryState();

    return {
      'status': 'success',
      'action': 'get_fatigue_level',
      'fatigue_level': recoveryState.fatigueLevel.name,
      'recovery_score': recoveryState.recoveryScore,
      'can_train_heavy': recoveryState.recoveryScore >= 75,
      'suggested_focus': recoveryState.recoveryScore >= 75
          ? 'Strength / Hypertrophy'
          : 'Mobility / Light Cardio',
    };
  }

  Future<Map<String, dynamic>> _getTodayActivity() async {
    final metric = await _healthService.getTodayHealthMetric();
    // Steps come from the step service; nothing is filled in without a reading.
    final steps = StepCounterService.instance.today.steps;
    final stepGoal = const StepTrackingService().getStepGoal();
    final activeCalories = metric.activeCalories;

    return {
      'status': 'success',
      'action': 'get_today_activity',
      'steps': steps,
      'step_goal': stepGoal,
      'progress_percent': steps == null
          ? null
          : ((steps / stepGoal) * 100).round(),
      'active_calories': activeCalories.round(),
      'goal_achieved': steps == null ? null : steps >= stepGoal,
      'data_note': steps != null
          ? null
          : 'No step reading today (counter off, no permission or no sensor); do not estimate steps.',
    };
  }
}
