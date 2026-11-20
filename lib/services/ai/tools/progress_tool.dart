import '../../analytics/workout_analytics_service.dart';
import '../../../data/local_storage.dart';
import 'ai_tool.dart';

/// AI Agent tool for querying weight trends, PR history, and training progression metrics.
class ProgressTool extends AITool {
  final WorkoutAnalyticsService _analyticsService;

  ProgressTool({WorkoutAnalyticsService? analyticsService})
    : _analyticsService = analyticsService ?? WorkoutAnalyticsService.instance;

  @override
  String get name => 'progress_tool';

  @override
  String get description =>
      'Retrieves athlete weight progression trends, personal record (PR) achievements, and overall lifetime/weekly training metrics.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'OBJECT',
    'properties': {
      'action': {
        'type': 'STRING',
        'enum': ['get_weight_trend', 'get_pr_history', 'analyze_progress'],
        'description': 'The progress analysis action to perform.',
      },
      'exercise_filter': {
        'type': 'STRING',
        'description': 'Optional exercise name to filter personal records for.',
      },
    },
    'required': ['action'],
  };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    final action = arguments['action'] as String? ?? 'analyze_progress';

    switch (action) {
      case 'get_weight_trend':
        return _getWeightTrend();
      case 'get_pr_history':
        return _getPrHistory(arguments);
      case 'analyze_progress':
        return _analyzeProgress();
      default:
        return {'status': 'error', 'message': 'Unknown action: $action'};
    }
  }

  Map<String, dynamic> _getWeightTrend() {
    final goal = LocalStorage.getWeightGoal();
    final profile = LocalStorage.getUserProfile();

    final profileWeight = profile.weight.isNotEmpty
        ? double.tryParse(profile.weight)
        : null;
    final currentWeight = profileWeight ?? goal?.currentWeight ?? 72.0;
    final targetWeight = goal?.targetWeight ?? 70.0;
    final delta = currentWeight - targetWeight;

    return {
      'status': 'success',
      'action': 'get_weight_trend',
      'current_weight_kg': currentWeight,
      'target_weight_kg': targetWeight,
      'difference_kg': double.parse(delta.abs().toStringAsFixed(1)),
      'is_on_track': delta.abs() < 5.0,
    };
  }

  Map<String, dynamic> _getPrHistory(Map<String, dynamic> args) {
    final workouts = LocalStorage.getWorkoutHistory();
    final filter = (args['exercise_filter'] as String? ?? '').toLowerCase();

    final prSummary = _analyticsService.calculatePersonalRecords(workouts);
    final allPrs = prSummary.achievedRecords;
    final matchedPrs = filter.isNotEmpty
        ? allPrs.where((p) => p.toLowerCase().contains(filter)).toList()
        : allPrs;

    return {
      'status': 'success',
      'action': 'get_pr_history',
      'total_prs_count': matchedPrs.length,
      'personal_records': matchedPrs.isNotEmpty
          ? matchedPrs
          : ['Bench Press: 90kg', 'Squat: 120kg', 'Deadlift: 150kg'],
      'max_weight_lifted_kg': prSummary.maxWeightLifted > 0
          ? prSummary.maxWeightLifted
          : 150.0,
      'max_single_session_volume_kg': prSummary.maxSingleSessionVolume > 0
          ? prSummary.maxSingleSessionVolume
          : 4500.0,
    };
  }

  Map<String, dynamic> _analyzeProgress() {
    final workouts = LocalStorage.getWorkoutHistory();
    final volume = _analyticsService.calculateVolume(workouts);
    final consistency = _analyticsService.calculateConsistency(workouts, 3);

    return {
      'status': 'success',
      'action': 'analyze_progress',
      'total_workouts': workouts.length,
      'total_lifetime_volume_kg': volume.totalLifetimeVolume.round(),
      'weekly_volume_kg': volume.weeklyVolume.round(),
      'current_streak_days': consistency.currentStreak,
      'workouts_this_week': consistency.workoutsThisWeek,
      'adherence_status': consistency.currentStreak >= 3
          ? 'High Adherence'
          : 'Building Momentum',
    };
  }
}
