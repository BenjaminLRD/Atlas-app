import '../../models/hydration.dart';

/// An activity that adds to the day's water need. The id makes sure one
/// workout or ride is counted once, however often it is passed in.
class HydrationActivity {
  final String id;
  final int minutes;

  /// True for running, cycling and other cardio; false for strength training.
  final bool cardio;

  /// MET of the activity when known, used to tell hard cardio from easy.
  final double? met;

  const HydrationActivity({
    required this.id,
    required this.minutes,
    required this.cardio,
    this.met,
  });
}

/// Works out a daily water target from what Atlas actually knows.
///
/// It is a general estimate, not medical advice: needs vary with the person,
/// the weather and what they eat. The method is deliberately plain:
/// * baseline: 32 ml per kg of body weight (within the commonly quoted
///   30 to 35 ml/kg), kept between 1.5 L and 3.5 L;
/// * activity: a conservative replacement of part of the sweat lost, 5 ml per
///   minute of strength training and 7 to 9 ml per minute of cardio, at most
///   1 L per day;
/// * heat is not used: Atlas has no reliable local weather;
/// * rounded to the nearest 50 ml so it does not look more exact than it is.
class HydrationGoalCalculator {
  const HydrationGoalCalculator._();

  static const double mlPerKg = 32;
  static const int provisionalMl = 2000;
  static const int minBaselineMl = 1500;
  static const int maxBaselineMl = 3500;
  static const int maxActivityMl = 1000;
  static const int maxGoalMl = 4000;
  static const int minManualMl = 500;
  static const int maxManualMl = 6000;
  static const double minWeightKg = 30;
  static const double maxWeightKg = 300;
  static const int maxMinutesPerActivity = 240;

  static int _round50(num v) => ((v / 50).round()) * 50;

  /// True for a weight that is believable.
  static bool validWeight(double? kg) =>
      kg != null && kg >= minWeightKg && kg <= maxWeightKg;

  static int activityMl(List<HydrationActivity> activities) {
    final seen = <String>{};
    var total = 0.0;
    for (final a in activities) {
      if (!seen.add(a.id) || a.minutes <= 0) continue;
      final minutes = a.minutes.clamp(0, maxMinutesPerActivity);
      final perMin = a.cardio ? ((a.met ?? 7) >= 8 ? 9.0 : 7.0) : 5.0;
      total += minutes * perMin;
    }
    return total > maxActivityMl ? maxActivityMl : total.round();
  }

  static HydrationGoal calculate({
    double? weightKg,
    List<HydrationActivity> activities = const [],
    int? manualMl,
  }) {
    final weightKnown = validWeight(weightKg);
    final baseline = weightKnown
        ? _round50(weightKg! * mlPerKg).clamp(minBaselineMl, maxBaselineMl)
        : provisionalMl;
    final act = _round50(activityMl(activities));
    var goal = baseline + act;
    if (goal > maxGoalMl) goal = maxGoalMl;

    if (manualMl != null) {
      final m = manualMl.clamp(minManualMl, maxManualMl);
      return HydrationGoal(
        goalMl: m,
        baselineMl: baseline,
        activityMl: act,
        basis: HydrationGoalBasis.manual,
        explanation:
            'You set this target. Atlas would suggest about $goal ml today.',
      );
    }

    final String why;
    final HydrationGoalBasis basis;
    if (!weightKnown) {
      basis = HydrationGoalBasis.provisional;
      why = act > 0
          ? 'A general starting value of $provisionalMl ml plus $act ml for '
                'activity you recorded today. Add your weight in your profile '
                'for a target that fits you.'
          : 'A general starting value, because no body weight is saved. '
                'Add your weight in your profile for a target that fits you.';
    } else if (act > 0) {
      basis = HydrationGoalBasis.activityAdjusted;
      why =
          '$baseline ml from your body weight plus $act ml for activity you '
          'recorded today.';
    } else {
      basis = HydrationGoalBasis.baseline;
      why =
          'About 32 ml per kg of body weight ($baseline ml). It rises on days '
          'you train.';
    }
    return HydrationGoal(
      goalMl: goal,
      baselineMl: baseline,
      activityMl: act,
      basis: basis,
      explanation: why,
    );
  }
}
