/// Parameters configuring a hypothetical athlete training or nutrition scenario.
class HypotheticalScenario {
  final String scenarioTitle;
  final int missedWorkoutsCount;
  final double calorieDeltaPerDay;
  final double sleepDeltaHoursPerNight;
  final int extraVolumeSetsPerWeek;

  const HypotheticalScenario({
    required this.scenarioTitle,
    this.missedWorkoutsCount = 0,
    this.calorieDeltaPerDay = 0.0,
    this.sleepDeltaHoursPerNight = 0.0,
    this.extraVolumeSetsPerWeek = 0,
  });
}

/// Simulated outcome forecast for a hypothetical scenario.
class ScenarioSimulationOutcome {
  final String scenarioTitle;
  final double projectedFatigueIndex; // 0-100
  final double projected1RMDeltaKg;
  final double projectedMuscleDeltaKg;
  final double projectedFatDeltaKg;
  final String recommendation;

  const ScenarioSimulationOutcome({
    required this.scenarioTitle,
    required this.projectedFatigueIndex,
    required this.projected1RMDeltaKg,
    required this.projectedMuscleDeltaKg,
    required this.projectedFatDeltaKg,
    required this.recommendation,
  });

  Map<String, dynamic> toJson() => {
    'scenario': scenarioTitle,
    'fatigue_index': projectedFatigueIndex,
    'delta_1rm_kg': projected1RMDeltaKg,
    'delta_muscle_kg': projectedMuscleDeltaKg,
    'delta_fat_kg': projectedFatDeltaKg,
    'recommendation': recommendation,
  };
}

/// Digital Athlete Simulation Engine.
/// Models fatigue decay, hypertrophy kinetics, and strength adaptations to forecast outcomes of training scenarios.
class DigitalAthleteModel {
  static DigitalAthleteModel? _instance;
  static DigitalAthleteModel get instance =>
      _instance ??= DigitalAthleteModel();

  static void resetInstance() {
    _instance = null;
  }

  /// Simulates athlete adaptation over a 4-week horizon given a hypothetical lifestyle/training intervention.
  ScenarioSimulationOutcome simulateScenario(HypotheticalScenario scenario) {
    double fatigue = 45.0;
    double strengthDeltaKg = 2.5; // Baseline 4-week progression
    double muscleDeltaKg = 0.40;
    double fatDeltaKg = 0.0;

    // 1. Missed Workouts Penalty
    if (scenario.missedWorkoutsCount > 0) {
      final penalty = scenario.missedWorkoutsCount * 0.8;
      strengthDeltaKg = (strengthDeltaKg - penalty).clamp(0.0, 10.0);
      muscleDeltaKg = (muscleDeltaKg - (scenario.missedWorkoutsCount * 0.15))
          .clamp(0.0, 2.0);
      fatigue = (fatigue - (scenario.missedWorkoutsCount * 5.0)).clamp(
        20.0,
        100.0,
      );
    }

    // 2. Caloric Delta (7700 kcal ~= 1kg fat)
    if (scenario.calorieDeltaPerDay != 0) {
      final monthlyKcal = scenario.calorieDeltaPerDay * 28;
      fatDeltaKg = monthlyKcal / 7700.0;
      if (scenario.calorieDeltaPerDay > 0) {
        muscleDeltaKg += 0.20;
      }
    }

    // 3. Sleep Impact
    if (scenario.sleepDeltaHoursPerNight < 0) {
      fatigue += scenario.sleepDeltaHoursPerNight.abs() * 10.0;
      strengthDeltaKg *= 0.70;
    }

    // 4. Volume Step
    if (scenario.extraVolumeSetsPerWeek > 0) {
      fatigue += scenario.extraVolumeSetsPerWeek * 2.5;
      if (fatigue < 80.0) {
        muscleDeltaKg += 0.25;
        strengthDeltaKg += 1.0;
      } else {
        // Overtraining threshold exceeded
        muscleDeltaKg -= 0.10;
        strengthDeltaKg -= 1.5;
      }
    }

    final advice = fatigue > 75.0
        ? 'High systemic fatigue risk. Consider inserting a recovery deload.'
        : 'Positive adaptation trajectory. Proceed with programmed volume.';

    return ScenarioSimulationOutcome(
      scenarioTitle: scenario.scenarioTitle,
      projectedFatigueIndex: fatigue.clamp(10.0, 100.0),
      projected1RMDeltaKg: double.parse(strengthDeltaKg.toStringAsFixed(2)),
      projectedMuscleDeltaKg: double.parse(muscleDeltaKg.toStringAsFixed(2)),
      projectedFatDeltaKg: double.parse(fatDeltaKg.toStringAsFixed(2)),
      recommendation: advice,
    );
  }
}
