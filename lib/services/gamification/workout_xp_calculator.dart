/// The one place the XP for a finished workout is worked out.
///
/// Pure rules, no storage and no state: the same inputs always give the same
/// amount. The completion flow, the saved workout record and the celebration
/// all read the amount from here (through `FitnessProvider`), so they cannot
/// disagree.
class WorkoutXpBreakdown {
  final int base;
  final int completionBonus;
  final int personalRecordBonus;
  final int streakBonus;

  const WorkoutXpBreakdown({
    required this.base,
    required this.completionBonus,
    required this.personalRecordBonus,
    required this.streakBonus,
  });

  int get total => base + completionBonus + personalRecordBonus + streakBonus;
}

class WorkoutXpCalculator {
  const WorkoutXpCalculator._();

  /// Every completed workout.
  static const int baseXp = 100;

  /// Added when at least [completionThreshold] percent of the workout was done.
  static const int completionBonusXp = 25;
  static const double completionThreshold = 90.0;

  /// Added once when the workout set at least one personal record.
  static const int personalRecordBonusXp = 250;

  /// Added when the streak, counting this workout, reaches a multiple of
  /// [streakMilestoneDays].
  static const int streakBonusXp = 250;
  static const int streakMilestoneDays = 7;

  /// XP for a strength workout. [streakAfterWorkout] is the streak including
  /// this workout.
  static WorkoutXpBreakdown forWorkout({
    required double completionPercentage,
    required bool hasPersonalRecord,
    required int streakAfterWorkout,
  }) {
    return WorkoutXpBreakdown(
      base: baseXp,
      completionBonus: completionPercentage >= completionThreshold
          ? completionBonusXp
          : 0,
      personalRecordBonus: hasPersonalRecord ? personalRecordBonusXp : 0,
      streakBonus:
          streakAfterWorkout > 0 &&
              streakAfterWorkout % streakMilestoneDays == 0
          ? streakBonusXp
          : 0,
    );
  }

  /// XP for a cardio session: 15 per full minute plus 50.
  static int forCardio({required int durationSeconds}) =>
      (durationSeconds ~/ 60) * 15 + 50;
}
