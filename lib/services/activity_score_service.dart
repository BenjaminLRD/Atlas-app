import '../data/local_storage.dart';
import 'step_tracking_service.dart';

/// Activity Score result containing composite score, category breakdown, and rating badge.
class ActivityScoreResult {
  final int totalScore;
  final double stepsScore;

  /// False when there is no step reading: the steps part is then left out of
  /// the total (which is scaled to the parts that are known) instead of
  /// counting as zero steps.
  final bool stepsKnown;
  final double workoutScore;
  final double cardioScore;
  final String rating;
  final String emoji;
  final String recommendation;

  const ActivityScoreResult({
    required this.totalScore,
    required this.stepsScore,
    this.stepsKnown = true,
    required this.workoutScore,
    required this.cardioScore,
    required this.rating,
    required this.emoji,
    required this.recommendation,
  });

  /// Factory for clean display
  factory ActivityScoreResult.calculate({
    required int? steps,
    required int stepGoal,
    required bool isWorkoutCompleted,
    required int workoutMinutes,
    required int cardioMinutes,
  }) {
    // 1. Steps Component (40% weight)
    final stepsKnown = steps != null;
    final stepRatio = (stepsKnown && stepGoal > 0)
        ? (steps / stepGoal).clamp(0.0, 1.25)
        : 0.0;
    final stepsScore = (stepRatio.clamp(0.0, 1.0) * 40.0);

    // 2. Workout Component (40% weight)
    final double workoutScore;
    if (isWorkoutCompleted) {
      workoutScore = 40.0;
    } else {
      workoutScore = (workoutMinutes / 45.0).clamp(0.0, 1.0) * 40.0;
    }

    // 3. Cardio Component (20% weight)
    final cardioScore = (cardioMinutes / 20.0).clamp(0.0, 1.0) * 20.0;

    // Without a step reading the score covers the other 60 points only.
    final earned = stepsScore + workoutScore + cardioScore;
    final total = (stepsKnown ? earned : earned / 60.0 * 100.0).round().clamp(
      0,
      100,
    );

    final String rating;
    final String emoji;
    final String recommendation;

    if (total >= 85) {
      rating = 'Excellent';
      emoji = '🔥';
      recommendation =
          'Outstanding daily movement! Peak energy & recovery in sync.';
    } else if (total >= 70) {
      rating = 'Great';
      emoji = '⚡';
      recommendation =
          'Strong activity foundation. Hit your step goal to reach 90+.';
    } else if (total >= 50) {
      rating = 'Good';
      emoji = '👍';
      recommendation =
          'Solid progress! Add a brisk 15-minute walk to elevate your score.';
    } else {
      rating = 'Keep Moving';
      emoji = '🚶';
      recommendation =
          'Take regular movement breaks today to avoid sedentary fatigue.';
    }

    return ActivityScoreResult(
      totalScore: total,
      stepsScore: double.parse(stepsScore.toStringAsFixed(1)),
      stepsKnown: stepsKnown,
      workoutScore: double.parse(workoutScore.toStringAsFixed(1)),
      cardioScore: double.parse(cardioScore.toStringAsFixed(1)),
      rating: rating,
      emoji: emoji,
      recommendation: recommendation,
    );
  }
}

/// Service computing holistic daily and weekly activity scores.
class ActivityScoreService {
  final StepTrackingService stepService;

  const ActivityScoreService({this.stepService = const StepTrackingService()});

  StepTrackingService get _stepService => stepService;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Minutes of completed cardio sessions on [day] (real session data).
  static int cardioMinutesOn(DateTime day) {
    return LocalStorage.getCardioSessions()
        .where((s) => s.isCompleted && _sameDay(s.startTime, day))
        .fold<int>(0, (sum, s) => sum + (s.durationSeconds ~/ 60));
  }

  /// Today's Activity Score from the day's steps (null steps are left out),
  /// logged workout minutes and completed cardio sessions.
  ActivityScoreResult getTodayScore({
    bool isWorkoutCompleted = false,
    int workoutMinutes = 0,
  }) {
    return ActivityScoreResult.calculate(
      steps: _stepService.today.steps,
      stepGoal: _stepService.getStepGoal(),
      isWorkoutCompleted: isWorkoutCompleted,
      workoutMinutes: workoutMinutes,
      cardioMinutes: cardioMinutesOn(DateTime.now()),
    );
  }

  /// Scores for the last 7 days, today last. A day with neither a step reading
  /// nor a cardio session has no score (null).
  List<int?> getWeeklyActivityScores() {
    final goal = _stepService.getStepGoal();
    return _stepService.week.map((day) {
      final date = DateTime.parse(day.dayKey);
      final cardio = cardioMinutesOn(date);
      if (day.steps == null && cardio == 0) return null;
      return ActivityScoreResult.calculate(
        steps: day.steps,
        stepGoal: goal,
        isWorkoutCompleted: false,
        workoutMinutes: 0,
        cardioMinutes: cardio,
      ).totalScore;
    }).toList();
  }
}
