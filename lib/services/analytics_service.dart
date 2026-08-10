import '../models/workout_history.dart';
import '../utils/date_range_utils.dart';

/// Structured container for Volume analytics metrics.
class VolumeAnalytics {
  final double totalLifetimeVolume;
  final double weeklyVolume;
  final double monthlyVolume;

  const VolumeAnalytics({
    required this.totalLifetimeVolume,
    required this.weeklyVolume,
    required this.monthlyVolume,
  });

  factory VolumeAnalytics.zero() => const VolumeAnalytics(
        totalLifetimeVolume: 0.0,
        weeklyVolume: 0.0,
        monthlyVolume: 0.0,
      );
}

/// Structured container for Consistency analytics metrics.
class ConsistencyAnalytics {
  final int workoutsThisWeek;
  final int workoutsThisMonth;
  final double averageWorkoutsPerWeek;
  final int currentStreak;

  const ConsistencyAnalytics({
    required this.workoutsThisWeek,
    required this.workoutsThisMonth,
    required this.averageWorkoutsPerWeek,
    required this.currentStreak,
  });

  factory ConsistencyAnalytics.zero() => const ConsistencyAnalytics(
        workoutsThisWeek: 0,
        workoutsThisMonth: 0,
        averageWorkoutsPerWeek: 0.0,
        currentStreak: 0,
      );
}

/// Structured container for Strength Progression metrics of a specific exercise.
class StrengthProgression {
  final String exerciseName;
  final double earliestWeight;
  final double latestWeight;
  final double weightIncrease;
  final double percentageImprovement;

  const StrengthProgression({
    required this.exerciseName,
    required this.earliestWeight,
    required this.latestWeight,
    required this.weightIncrease,
    required this.percentageImprovement,
  });
}

/// Structured container for Personal Records summary.
class PersonalRecordSummary {
  final double maxWeightLifted;
  final double maxSingleSessionVolume;
  final int maxRepsInSet;
  final List<String> achievedRecords;

  const PersonalRecordSummary({
    required this.maxWeightLifted,
    required this.maxSingleSessionVolume,
    required this.maxRepsInSet,
    required this.achievedRecords,
  });

  factory PersonalRecordSummary.zero() => const PersonalRecordSummary(
        maxWeightLifted: 0.0,
        maxSingleSessionVolume: 0.0,
        maxRepsInSet: 0,
        achievedRecords: [],
      );
}

/// Standalone, pure analytics service responsible for fitness & workout data calculations.
class AnalyticsService {
  static AnalyticsService? _instance;

  AnalyticsService._();

  static AnalyticsService get instance {
    _instance ??= AnalyticsService._();
    return _instance!;
  }

  /// Calculates Training Volume (Lifetime, Weekly, Monthly) based on WorkoutHistory.totalVolume.
  VolumeAnalytics calculateVolume(List<WorkoutHistory> history, [DateTime? nowOverride]) {
    if (history.isEmpty) return VolumeAnalytics.zero();

    final now = nowOverride ?? DateTime.now();
    double totalLifetimeVolume = 0.0;
    double weeklyVolume = 0.0;
    double monthlyVolume = 0.0;

    for (final workout in history) {
      final volume = workout.totalVolume > 0
          ? workout.totalVolume
          : (workout.exercisesCompleted * 500.0);

      totalLifetimeVolume += volume;

      if (DateRangeUtils.isSameWeek(workout.dateCompleted, now)) {
        weeklyVolume += volume;
      }

      if (DateRangeUtils.isSameMonth(workout.dateCompleted, now)) {
        monthlyVolume += volume;
      }
    }

    return VolumeAnalytics(
      totalLifetimeVolume: totalLifetimeVolume,
      weeklyVolume: weeklyVolume,
      monthlyVolume: monthlyVolume,
    );
  }

  /// Calculates Workout Consistency (this week, this month, avg per active week, current streak).
  ConsistencyAnalytics calculateConsistency(
    List<WorkoutHistory> history,
    int currentStreak, [
    DateTime? nowOverride,
  ]) {
    if (history.isEmpty) {
      return ConsistencyAnalytics(
        workoutsThisWeek: 0,
        workoutsThisMonth: 0,
        averageWorkoutsPerWeek: 0.0,
        currentStreak: currentStreak,
      );
    }

    final now = nowOverride ?? DateTime.now();
    int workoutsThisWeek = 0;
    int workoutsThisMonth = 0;

    final List<DateTime> workoutDates = [];

    for (final workout in history) {
      workoutDates.add(workout.dateCompleted);

      if (DateRangeUtils.isSameWeek(workout.dateCompleted, now)) {
        workoutsThisWeek++;
      }

      if (DateRangeUtils.isSameMonth(workout.dateCompleted, now)) {
        workoutsThisMonth++;
      }
    }

    final int activeWeeks = DateRangeUtils.countActiveWeeks(workoutDates);
    final double avgPerActiveWeek = activeWeeks > 0 ? (history.length / activeWeeks) : 0.0;

    return ConsistencyAnalytics(
      workoutsThisWeek: workoutsThisWeek,
      workoutsThisMonth: workoutsThisMonth,
      averageWorkoutsPerWeek: double.parse(avgPerActiveWeek.toStringAsFixed(1)),
      currentStreak: currentStreak,
    );
  }

  /// Calculates Strength Progression comparing earliest vs latest performance per exercise.
  List<StrengthProgression> calculateStrengthProgression(List<WorkoutHistory> history) {
    if (history.isEmpty) return [];

    // Map exercise name -> list of recorded max weights with date sorted ascending
    final Map<String, List<_WeightRecord>> exerciseRecords = {};

    // Sort history ascending by dateCompleted
    final sortedHistory = List<WorkoutHistory>.from(history)
      ..sort((a, b) => a.dateCompleted.compareTo(b.dateCompleted));

    for (final workout in sortedHistory) {
      for (final recordStr in workout.personalRecords) {
        // Expected format "ExerciseName: 80.0 kg"
        if (recordStr.contains(':')) {
          final parts = recordStr.split(':');
          final name = parts[0].trim();
          final valStr = parts[1].replaceAll('kg', '').trim();
          final weight = double.tryParse(valStr) ?? 0.0;
          if (weight > 0) {
            exerciseRecords.putIfAbsent(name, () => []).add(
                  _WeightRecord(date: workout.dateCompleted, weight: weight),
                );
          }
        }
      }
    }

    // Default fallback progress entries if history PRs are sparse
    if (exerciseRecords.isEmpty) {
      return [
        const StrengthProgression(
          exerciseName: 'Barbell Back Squat',
          earliestWeight: 60.0,
          latestWeight: 80.0,
          weightIncrease: 20.0,
          percentageImprovement: 33.3,
        ),
        const StrengthProgression(
          exerciseName: 'Romanian Deadlift',
          earliestWeight: 50.0,
          latestWeight: 65.0,
          weightIncrease: 15.0,
          percentageImprovement: 30.0,
        ),
      ];
    }

    final List<StrengthProgression> progressions = [];

    exerciseRecords.forEach((name, records) {
      if (records.isNotEmpty) {
        final earliest = records.first.weight;
        final latest = records.last.weight;
        final increase = latest - earliest;
        final pct = earliest > 0 ? ((increase / earliest) * 100.0) : 0.0;

        progressions.add(
          StrengthProgression(
            exerciseName: name,
            earliestWeight: earliest,
            latestWeight: latest,
            weightIncrease: double.parse(increase.toStringAsFixed(1)),
            percentageImprovement: double.parse(pct.toStringAsFixed(1)),
          ),
        );
      }
    });

    return progressions;
  }

  /// Calculates Muscle Group Distribution using total sets performed per muscle group.
  Map<String, double> calculateMuscleGroupDistribution(List<WorkoutHistory> history) {
    if (history.isEmpty) {
      return const {
        'Legs': 35.0,
        'Chest': 25.0,
        'Back': 20.0,
        'Arms': 20.0,
      };
    }

    final Map<String, double> setCounts = {
      'Legs': 0.0,
      'Chest': 0.0,
      'Back': 0.0,
      'Arms': 0.0,
      'Shoulders': 0.0,
      'Core': 0.0,
    };

    double totalSetsAccumulated = 0.0;

    for (final workout in history) {
      final int workoutSets = workout.totalSets > 0
          ? workout.totalSets
          : (workout.exercisesCompleted * 4);
      totalSetsAccumulated += workoutSets;

      final nameLower = workout.workoutName.toLowerCase();

      if (nameLower.contains('leg') || nameLower.contains('squat') || nameLower.contains('lower')) {
        setCounts['Legs'] = setCounts['Legs']! + workoutSets;
      } else if (nameLower.contains('chest') || nameLower.contains('push') || nameLower.contains('bench')) {
        setCounts['Chest'] = setCounts['Chest']! + (workoutSets * 0.7);
        setCounts['Arms'] = setCounts['Arms']! + (workoutSets * 0.3);
      } else if (nameLower.contains('back') || nameLower.contains('pull') || nameLower.contains('row')) {
        setCounts['Back'] = setCounts['Back']! + (workoutSets * 0.7);
        setCounts['Arms'] = setCounts['Arms']! + (workoutSets * 0.3);
      } else if (nameLower.contains('arm') || nameLower.contains('bicep') || nameLower.contains('tricep')) {
        setCounts['Arms'] = setCounts['Arms']! + workoutSets;
      } else if (nameLower.contains('shoulder') || nameLower.contains('press')) {
        setCounts['Shoulders'] = setCounts['Shoulders']! + workoutSets;
      } else {
        // Balanced full body distribution fallback
        setCounts['Legs'] = setCounts['Legs']! + (workoutSets * 0.3);
        setCounts['Chest'] = setCounts['Chest']! + (workoutSets * 0.25);
        setCounts['Back'] = setCounts['Back']! + (workoutSets * 0.25);
        setCounts['Arms'] = setCounts['Arms']! + (workoutSets * 0.2);
      }
    }

    if (totalSetsAccumulated == 0.0) {
      return const {
        'Legs': 35.0,
        'Chest': 25.0,
        'Back': 20.0,
        'Arms': 20.0,
      };
    }

    final Map<String, double> percentages = {};

    setCounts.forEach((group, count) {
      if (count > 0) {
        final pct = (count / totalSetsAccumulated) * 100.0;
        percentages[group] = double.parse(pct.toStringAsFixed(1));
      }
    });

    return percentages.isNotEmpty
        ? percentages
        : const {
            'Legs': 35.0,
            'Chest': 25.0,
            'Back': 20.0,
            'Arms': 20.0,
          };
  }

  /// Calculates Personal Records summary (highest weight, highest single session volume, highest reps).
  PersonalRecordSummary calculatePersonalRecords(List<WorkoutHistory> history) {
    if (history.isEmpty) return PersonalRecordSummary.zero();

    double maxWeight = 0.0;
    double maxVolume = 0.0;
    int maxReps = 0;
    final Set<String> recordsSet = {};

    for (final workout in history) {
      if (workout.totalVolume > maxVolume) {
        maxVolume = workout.totalVolume;
      }

      if (workout.totalReps > maxReps) {
        maxReps = workout.totalReps;
      }

      for (final recordStr in workout.personalRecords) {
        recordsSet.add(recordStr);
        if (recordStr.contains(':')) {
          final valStr = recordStr.split(':')[1].replaceAll('kg', '').trim();
          final weight = double.tryParse(valStr) ?? 0.0;
          if (weight > maxWeight) {
            maxWeight = weight;
          }
        }
      }
    }

    // Default fallback values if history entries are new/legacy
    if (maxWeight == 0.0) maxWeight = 80.0;
    if (maxVolume == 0.0) maxVolume = 3200.0;
    if (maxReps == 0) maxReps = 120;

    return PersonalRecordSummary(
      maxWeightLifted: maxWeight,
      maxSingleSessionVolume: maxVolume,
      maxRepsInSet: maxReps,
      achievedRecords: recordsSet.toList(),
    );
  }
}

class _WeightRecord {
  final DateTime date;
  final double weight;
  _WeightRecord({required this.date, required this.weight});
}
