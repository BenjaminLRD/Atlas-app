/// Report outcome generated when evaluating athlete goal trajectory and plateaus.
class GoalAdaptationReport {
  final String goalType;
  final bool hasPlateau;
  final String analysis;
  final String recommendedAction;
  final int calorieAdjustment; // +200, -150, 0
  final Map<String, dynamic> trainingModifications;
  final DateTime evaluatedAt;

  const GoalAdaptationReport({
    required this.goalType,
    required this.hasPlateau,
    required this.analysis,
    required this.recommendedAction,
    this.calorieAdjustment = 0,
    this.trainingModifications = const {},
    required this.evaluatedAt,
  });
}

/// Autonomous Goal Adaptation Engine evaluating weight trends, PR progression,
/// and metabolic stagnation to prescribe automatic calorie and programming adjustments.
class GoalAdaptationEngine {
  static GoalAdaptationEngine? _instance;
  static GoalAdaptationEngine get instance =>
      _instance ??= GoalAdaptationEngine();

  /// Analyzes athlete progression and returns goal adaptation recommendations.
  GoalAdaptationReport evaluate({
    required String
    goalType, // 'weight_gain', 'fat_loss', 'strength', 'general_fitness'
    required double startWeight,
    required double currentWeight,
    required double targetWeight,
    required int weeksElapsed,
    int consecutivePlateauWeeks = 0,
    bool hasStrengthPlateau = false,
  }) {
    final lowerGoal = goalType.toLowerCase();

    // 1. Weight Gain / Hypertrophy Goal
    if (lowerGoal.contains('gain') ||
        lowerGoal.contains('bulk') ||
        lowerGoal.contains('hypertrophy') ||
        lowerGoal.contains('muscle')) {
      final actualGain = currentWeight - startWeight;
      final expectedGain =
          weeksElapsed * 0.25; // Target ~0.25kg to 0.5kg / week

      if (weeksElapsed >= 4 && actualGain < expectedGain * 0.6) {
        return GoalAdaptationReport(
          goalType: 'Weight Gain / Bulk',
          hasPlateau: true,
          analysis:
              'Weight gain is slower than expected (${actualGain.toStringAsFixed(1)}kg in $weeksElapsed weeks vs ${expectedGain.toStringAsFixed(1)}kg target).',
          recommendedAction:
              'Increase daily caloric surplus by +200 kcal/day to support muscle mass gain.',
          calorieAdjustment: 200,
          trainingModifications: const {
            'focus': 'Hypertrophy volume',
            'rep_range': '8-12 reps',
            'rest_seconds': 90,
          },
          evaluatedAt: DateTime.now(),
        );
      } else {
        return GoalAdaptationReport(
          goalType: 'Weight Gain / Bulk',
          hasPlateau: false,
          analysis:
              'Weight gain trajectory is on target (${actualGain.toStringAsFixed(1)}kg gained).',
          recommendedAction:
              'Maintain current nutrition and progressive overload split.',
          calorieAdjustment: 0,
          trainingModifications: const {},
          evaluatedAt: DateTime.now(),
        );
      }
    }

    // 2. Fat Loss / Cutting Goal
    if (lowerGoal.contains('loss') || lowerGoal.contains('cut')) {
      if (consecutivePlateauWeeks >= 3) {
        return GoalAdaptationReport(
          goalType: 'Fat Loss / Cut',
          hasPlateau: true,
          analysis:
              'Weight has remained unchanged for $consecutivePlateauWeeks consecutive weeks. Metabolic adaptation detected.',
          recommendedAction:
              'Reduce daily caloric target by -150 kcal/day and increase daily NEAT/steps.',
          calorieAdjustment: -150,
          trainingModifications: const {
            'focus': 'Maintain strength intensity',
            'cardio_sessions': '+1 weekly HIIT/LISS session',
          },
          evaluatedAt: DateTime.now(),
        );
      } else {
        return GoalAdaptationReport(
          goalType: 'Fat Loss / Cut',
          hasPlateau: false,
          analysis: 'Fat loss progression is active and steady.',
          recommendedAction:
              'Maintain current caloric deficit and strength preservation workouts.',
          calorieAdjustment: 0,
          trainingModifications: const {},
          evaluatedAt: DateTime.now(),
        );
      }
    }

    // 3. Strength / Powerlifting Goal
    if (lowerGoal.contains('strength') || hasStrengthPlateau) {
      if (hasStrengthPlateau) {
        return GoalAdaptationReport(
          goalType: 'Strength / Plateau Breakthrough',
          hasPlateau: true,
          analysis:
              'Primary lift progression has plateaued across the last 3 weeks.',
          recommendedAction:
              'Switch to wave-loading periodization: reduce rep range to 3-5 reps, increase rest to 3 minutes, and add accessory volume.',
          calorieAdjustment: 100, // slight surplus to fuel neural recovery
          trainingModifications: const {
            'rep_range': '3-5 reps',
            'intensity_rpe': '8-9 RPE',
            'rest_seconds': 180,
            'technique': 'Wave loading periodization',
          },
          evaluatedAt: DateTime.now(),
        );
      }
    }

    // Default General Fitness
    return GoalAdaptationReport(
      goalType: 'General Fitness',
      hasPlateau: false,
      analysis: 'Consistency is strong. Balanced progression observed.',
      recommendedAction: 'Continue current training and nutrition balance.',
      calorieAdjustment: 0,
      trainingModifications: const {},
      evaluatedAt: DateTime.now(),
    );
  }
}
