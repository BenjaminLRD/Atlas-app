import 'dart:math' as math;
import '../../models/activity_record.dart';
import '../../models/workout_history.dart';
import '../../models/workout_session.dart';
import 'rank_ladder.dart';
import 'ranked_catalog.dart';

/// Best performance and level reached for one milestone.
class MilestoneProgress {
  final RankedMilestone milestone;

  /// Best value: bodyweight multiple, reps, 5 km minutes or workout count.
  /// Null when there is no qualifying data yet.
  final double? best;
  final int level;

  const MilestoneProgress({
    required this.milestone,
    required this.best,
    required this.level,
  });

  /// Target for the next level, or null at level 5.
  double? nextTarget(String gender) {
    final targets = milestone.targetsFor(gender);
    return level < targets.length ? targets[level] : null;
  }
}

/// What the device's own data supports. The server repeats this evaluation
/// on synced data and only approved milestones count for rank.
class RankedEvaluation {
  final Map<String, MilestoneProgress> milestones;
  final Map<String, int> statLevels;

  /// False when body weight is missing, so strength cannot be judged.
  final bool hasBodyweight;

  const RankedEvaluation({
    required this.milestones,
    required this.statLevels,
    required this.hasBodyweight,
  });

  int get points => statLevels.values.fold(0, (a, b) => a + b);
  RankPosition get rank => RankLadder.fromPoints(points);
}

/// Judges Ranked milestones from logged workouts and cardio sessions.
class RankedEvaluator {
  final RankedCatalog catalog;

  const RankedEvaluator(this.catalog);

  /// Estimated one-rep max (Epley) from a set of 1–5 reps. Higher-rep sets
  /// are too unreliable for a strength milestone.
  static double? estimatedOneRepMax(double weight, int reps) {
    if (weight <= 0 || reps < 1 || reps > 5) return null;
    return reps == 1 ? weight : weight * (1 + reps / 30);
  }

  RankedEvaluation evaluate({
    required List<WorkoutHistory> history,
    required List<WorkoutSession> sessions,
    required List<CardioSession> cardio,
    required double? bodyweight,
    required String gender,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final exercises = <WorkoutSessionExercise>[
      for (final h in history) ...?h.sessionExercises,
      for (final s in sessions) ...s.exercises,
    ];
    final hasBodyweight = bodyweight != null && bodyweight > 0;

    final results = <String, MilestoneProgress>{};
    for (final m in catalog.milestones) {
      double? best;
      switch (m.measure) {
        case MilestoneMeasure.bodyweightMultiple:
          if (!hasBodyweight) break;
          for (final ex in exercises.where((e) => m.matchesExercise(e.name))) {
            for (final set in ex.sets.where((s) => s.completed)) {
              final e1rm = estimatedOneRepMax(set.weight, set.reps);
              if (e1rm != null) best = math.max(best ?? 0, e1rm / bodyweight);
            }
          }
        case MilestoneMeasure.maxReps:
          for (final ex in exercises.where((e) => m.matchesExercise(e.name))) {
            for (final set in ex.sets.where((s) => s.completed)) {
              best = math.max(best ?? 0, set.reps.toDouble());
            }
          }
        case MilestoneMeasure.time5kMinutes:
          for (final c in cardio) {
            final name = '${c.exerciseName} ${c.category}';
            if (!m.matchesExercise(name) || c.distanceKm < 5) continue;
            if (c.durationSeconds <= 0) continue;
            // Average pace over the run, scaled to 5 km.
            final minutes = c.durationSeconds / 60 * (5 / c.distanceKm);
            best = best == null ? minutes : math.min(best, minutes);
          }
        case MilestoneMeasure.workoutsInWindow:
          final since = today.subtract(
            Duration(days: catalog.consistencyWindowDays),
          );
          final count =
              history.where((h) => h.dateCompleted.isAfter(since)).length +
              cardio.where((c) => c.startTime.isAfter(since)).length;
          best = count.toDouble();
      }
      results[m.id] = MilestoneProgress(
        milestone: m,
        best: best,
        level: best == null ? 0 : m.levelFor(best, gender),
      );
    }

    final levelsById = {
      for (final r in results.values) r.milestone.id: r.level,
    };
    return RankedEvaluation(
      milestones: results,
      statLevels: {
        for (final s in catalog.stats) s.id: s.levelFrom(levelsById),
      },
      hasBodyweight: hasBodyweight,
    );
  }
}
