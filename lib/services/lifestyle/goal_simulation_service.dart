/// Types of fitness goals supported by the predictive simulator.
enum SimulationGoalType {
  muscleGain('Lean Muscle Accrual'),
  fatLoss('Fat Loss & Definition'),
  strengthMilestone('1RM Strength Milestone'),
  endurance('Endurance & Conditioning');

  final String label;
  const SimulationGoalType(this.label);
}

/// Projected physiological milestone at a future week.
class ProjectedMilestone {
  final int weekNumber;
  final double projectedWeightKg;
  final double projectedStrengthKg;
  final String milestoneTitle;

  const ProjectedMilestone({
    required this.weekNumber,
    required this.projectedWeightKg,
    required this.projectedStrengthKg,
    required this.milestoneTitle,
  });

  Map<String, dynamic> toJson() => {
    'week': weekNumber,
    'projected_weight_kg': projectedWeightKg,
    'projected_strength_kg': projectedStrengthKg,
    'milestone': milestoneTitle,
  };
}

/// Complete predictive goal simulation report.
class GoalSimulationReport {
  final SimulationGoalType goalType;
  final double currentMetricValue;
  final double targetMetricValue;
  final int estimatedWeeksToAchieve;
  final double targetDailyCalories;
  final double targetDailyProteinGrams;
  final int weeklySetsPerMuscleGroup;
  final double feasibilityScore; // 0.0 to 1.0
  final List<ProjectedMilestone> milestones;
  final String physiologicalRoadmap;

  const GoalSimulationReport({
    required this.goalType,
    required this.currentMetricValue,
    required this.targetMetricValue,
    required this.estimatedWeeksToAchieve,
    required this.targetDailyCalories,
    required this.targetDailyProteinGrams,
    required this.weeklySetsPerMuscleGroup,
    required this.feasibilityScore,
    required this.milestones,
    required this.physiologicalRoadmap,
  });

  Map<String, dynamic> toJson() => {
    'goal_type': goalType.name,
    'current_val': currentMetricValue,
    'target_val': targetMetricValue,
    'estimated_weeks': estimatedWeeksToAchieve,
    'target_calories': targetDailyCalories,
    'target_protein_g': targetDailyProteinGrams,
    'weekly_sets_per_muscle': weeklySetsPerMuscleGroup,
    'feasibility_score': feasibilityScore,
    'milestones': milestones.map((m) => m.toJson()).toList(),
    'roadmap': physiologicalRoadmap,
  };
}

/// Predictive Goal Simulation Engine.
/// Forecasts physiological timelines, energy deficits/surpluses,
/// and progressive volume requirements based on evidence-based kinetics.
class GoalSimulationService {
  static GoalSimulationService? _instance;
  static GoalSimulationService get instance =>
      _instance ??= GoalSimulationService();

  static void resetInstance() {
    _instance = null;
  }

  /// Simulates timeline and requirements for achieving a specific fitness goal.
  GoalSimulationReport simulateGoal({
    required SimulationGoalType goalType,
    required double currentWeightKg,
    required double targetWeightKg,
    double current1RMKg = 100.0,
    double target1RMKg = 120.0,
    double maintenanceCalories = 2400.0,
  }) {
    int weeks = 12;
    double calories = maintenanceCalories;
    double protein = currentWeightKg * 2.0; // 2.0g/kg baseline
    int sets = 14;
    double feasibility = 0.90;
    final milestones = <ProjectedMilestone>[];

    switch (goalType) {
      case SimulationGoalType.muscleGain:
        final weightDelta = (targetWeightKg - currentWeightKg).abs();
        weeks = (weightDelta / 0.25).ceil().clamp(4, 52); // ~0.25kg lean gain per week
        calories = maintenanceCalories + 300.0; // +300 kcal lean surplus
        protein = currentWeightKg * 2.2;
        sets = 16;
        milestones.addAll([
          ProjectedMilestone(
            weekNumber: (weeks * 0.33).round(),
            projectedWeightKg: currentWeightKg + (weightDelta * 0.33),
            projectedStrengthKg: current1RMKg + 5.0,
            milestoneTitle: 'Early Neuromuscular Adaptation',
          ),
          ProjectedMilestone(
            weekNumber: (weeks * 0.66).round(),
            projectedWeightKg: currentWeightKg + (weightDelta * 0.66),
            projectedStrengthKg: current1RMKg + 10.0,
            milestoneTitle: 'Hypertrophic Accrual Checkpoint',
          ),
          ProjectedMilestone(
            weekNumber: weeks,
            projectedWeightKg: targetWeightKg,
            projectedStrengthKg: current1RMKg + 15.0,
            milestoneTitle: 'Target Goal Reached',
          ),
        ]);
        break;

      case SimulationGoalType.fatLoss:
        final weightLossDelta = (currentWeightKg - targetWeightKg).abs();
        weeks = (weightLossDelta / 0.50).ceil().clamp(4, 52); // ~0.50kg per week safe deficit
        calories = maintenanceCalories - 500.0; // -500 kcal safe deficit
        protein = currentWeightKg * 2.4; // Elevated protein to spare lean mass
        sets = 12;
        milestones.addAll([
          ProjectedMilestone(
            weekNumber: (weeks * 0.5).round(),
            projectedWeightKg: currentWeightKg - (weightLossDelta * 0.5),
            projectedStrengthKg: current1RMKg,
            milestoneTitle: 'Halfway Definition Checkpoint',
          ),
          ProjectedMilestone(
            weekNumber: weeks,
            projectedWeightKg: targetWeightKg,
            projectedStrengthKg: current1RMKg,
            milestoneTitle: 'Target Lean Body Composition',
          ),
        ]);
        break;

      case SimulationGoalType.strengthMilestone:
        final strengthDelta = (target1RMKg - current1RMKg).abs();
        weeks = (strengthDelta / 1.5).ceil().clamp(4, 48); // ~1.5kg 1RM gain per week
        calories = maintenanceCalories + 150.0;
        sets = 18;
        milestones.add(ProjectedMilestone(
          weekNumber: weeks,
          projectedWeightKg: currentWeightKg,
          projectedStrengthKg: target1RMKg,
          milestoneTitle: '1RM Strength Milestone Peak',
        ));
        break;

      case SimulationGoalType.endurance:
        weeks = 8;
        calories = maintenanceCalories + 200.0;
        sets = 10;
        break;
    }

    final roadmap =
        'To achieve $targetWeightKg kg in $weeks weeks, maintain ${calories.round()} kcal/day '
        'with ${protein.round()}g protein and $sets weekly working sets per muscle group.';

    return GoalSimulationReport(
      goalType: goalType,
      currentMetricValue: currentWeightKg,
      targetMetricValue: targetWeightKg,
      estimatedWeeksToAchieve: weeks,
      targetDailyCalories: calories,
      targetDailyProteinGrams: protein,
      weeklySetsPerMuscleGroup: sets,
      feasibilityScore: feasibility,
      milestones: milestones,
      physiologicalRoadmap: roadmap,
    );
  }
}
