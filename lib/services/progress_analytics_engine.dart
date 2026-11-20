import 'dart:math';
import '../models/personal_record.dart';
import '../models/progress_analytics.dart';
import '../models/workout_history.dart';
import '../models/workout_session.dart';

/// Pure computation engine transforming raw workout execution data into actionable
/// athlete performance metrics, volume trends, plateau alerts, and AI coaching context.
class ProgressAnalyticsEngine {
  static ProgressAnalyticsEngine? _instance;

  ProgressAnalyticsEngine._();

  static ProgressAnalyticsEngine get instance {
    _instance ??= ProgressAnalyticsEngine._();
    return _instance!;
  }

  /// Evaluates strength progression per exercise across all historical sessions.
  List<StrengthProgress> analyzeStrengthProgress({
    required List<WorkoutSession> sessions,
    required List<WorkoutHistory> history,
  }) {
    if (sessions.isEmpty && history.isEmpty) {
      return [];
    }

    final Map<String, _ExerciseLogTracker> trackers = {};

    // 1. Process rich structured WorkoutSession exercises (Highest fidelity)
    final sortedSessions = List<WorkoutSession>.from(sessions)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    for (final session in sortedSessions) {
      for (final ex in session.exercises) {
        final completedSets = ex.sets.where((s) => s.completed).toList();
        if (completedSets.isEmpty) continue;

        final maxW = ex.maxWeight;
        if (maxW <= 0) continue;

        // Calculate peak 1RM in this exercise session using Epley formula
        double peak1RM = 0.0;
        for (final s in completedSets) {
          final oneRM = s.weight * (1.0 + (s.reps / 30.0));
          if (oneRM > peak1RM) peak1RM = oneRM;
        }

        final normName = _normalizeExerciseName(ex.name);
        final tracker = trackers.putIfAbsent(
          normName,
          () => _ExerciseLogTracker(displayName: ex.name, exerciseId: ex.id),
        );
        tracker.addEntry(
          date: session.startTime,
          weight: maxW,
          oneRepMax: peak1RM > 0 ? peak1RM : maxW,
        );
      }
    }

    // 2. Process legacy / text WorkoutHistory PR records if not already captured
    final sortedHistory = List<WorkoutHistory>.from(history)
      ..sort((a, b) => a.dateCompleted.compareTo(b.dateCompleted));

    for (final h in sortedHistory) {
      for (final pr in h.personalRecords) {
        if (pr.contains(':')) {
          final parts = pr.split(':');
          final rawName = parts[0].trim();
          final valStr = parts[1].replaceAll(RegExp(r'[^0-9.]'), '').trim();
          final weight = double.tryParse(valStr) ?? 0.0;
          if (weight > 0) {
            final normName = _normalizeExerciseName(rawName);
            final tracker = trackers.putIfAbsent(
              normName,
              () => _ExerciseLogTracker(
                displayName: rawName,
                exerciseId: normName.toLowerCase().replaceAll(' ', '_'),
              ),
            );
            // Only add if not duplicate for same date
            if (!tracker.dates.any(
              (d) =>
                  d.year == h.dateCompleted.year &&
                  d.month == h.dateCompleted.month &&
                  d.day == h.dateCompleted.day,
            )) {
              tracker.addEntry(
                date: h.dateCompleted,
                weight: weight,
                oneRepMax: weight * 1.0,
              );
            }
          }
        }
      }
    }

    if (trackers.isEmpty) return [];

    final List<StrengthProgress> results = [];

    trackers.forEach((_, tracker) {
      if (tracker.weights.isNotEmpty) {
        final earliest = tracker.weights.first;
        final current = tracker.weights.last;
        final improvement = current - earliest;
        final pct = earliest > 0 ? ((improvement / earliest) * 100.0) : 0.0;
        final peak1RM = tracker.oneRepMaxes.reduce(max);

        results.add(
          StrengthProgress(
            exerciseName: tracker.displayName,
            exerciseId: tracker.exerciseId,
            currentWeight: double.parse(current.toStringAsFixed(1)),
            previousWeight: double.parse(earliest.toStringAsFixed(1)),
            improvement: double.parse(improvement.toStringAsFixed(1)),
            estimatedOneRepMax: double.parse(peak1RM.toStringAsFixed(1)),
            percentageIncrease: double.parse(pct.toStringAsFixed(1)),
            lastLoggedDate: tracker.dates.last,
            weightHistory: tracker.weights,
            dateHistory: tracker.dates,
          ),
        );
      }
    });

    results.sort(
      (a, b) =>
          b.lastLoggedDate?.compareTo(a.lastLoggedDate ?? DateTime(0)) ?? 0,
    );
    return results;
  }

  /// Calculates weekly training volume buckets across the previous N weeks.
  List<VolumeTrendPoint> calculateVolumeTrends({
    required List<WorkoutSession> sessions,
    required List<WorkoutHistory> history,
    int numberOfWeeks = 4,
    DateTime? nowOverride,
  }) {
    final now = nowOverride ?? DateTime.now();
    final List<VolumeTrendPoint> points = [];

    // Combine volume entries by date
    final Map<DateTime, _DateVolumeEntry> entriesByDay = {};

    for (final s in sessions) {
      final dayKey = DateTime(
        s.startTime.year,
        s.startTime.month,
        s.startTime.day,
      );
      final e = entriesByDay.putIfAbsent(dayKey, () => _DateVolumeEntry());
      e.volume += s.totalVolume;
      e.workoutCount++;
    }

    for (final h in history) {
      final dayKey = DateTime(
        h.dateCompleted.year,
        h.dateCompleted.month,
        h.dateCompleted.day,
      );
      // Avoid double counting if already present in sessions on same day with same volume
      if (!entriesByDay.containsKey(dayKey)) {
        final e = entriesByDay.putIfAbsent(dayKey, () => _DateVolumeEntry());
        e.volume += h.totalVolume;
        e.workoutCount++;
      }
    }

    // Build rolling week intervals from (numberOfWeeks - 1) weeks ago to current week
    for (int i = numberOfWeeks - 1; i >= 0; i--) {
      final weekStart = now.subtract(Duration(days: (i * 7) + now.weekday - 1));
      final cleanStart = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day,
      );
      final cleanEnd = cleanStart.add(
        const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
      );

      double weekVol = 0.0;
      int weekCount = 0;

      entriesByDay.forEach((date, entry) {
        if (date.isAfter(cleanStart.subtract(const Duration(seconds: 1))) &&
            date.isBefore(cleanEnd.add(const Duration(seconds: 1)))) {
          weekVol += entry.volume;
          weekCount += entry.workoutCount;
        }
      });

      final label = i == 0 ? 'This Wk' : (i == 1 ? 'Last Wk' : 'Wk -$i');
      points.add(
        VolumeTrendPoint(
          periodLabel: label,
          startDate: cleanStart,
          endDate: cleanEnd,
          volume: double.parse(weekVol.toStringAsFixed(1)),
          workoutsCount: weekCount,
        ),
      );
    }

    for (int p = 0; p < points.length; p++) {
      if (p > 0) {
        final prevVol = points[p - 1].volume;
        final currVol = points[p].volume;
        final change = prevVol > 0
            ? ((currVol - prevVol) / prevVol) * 100.0
            : 0.0;
        points[p] = VolumeTrendPoint(
          periodLabel: points[p].periodLabel,
          startDate: points[p].startDate,
          endDate: points[p].endDate,
          volume: points[p].volume,
          workoutsCount: points[p].workoutsCount,
          changePercentage: double.parse(change.toStringAsFixed(1)),
        );
      }
    }

    return points;
  }

  /// Analyzes muscle group volume distribution and classifies growth/fatigue status.
  List<MuscleGrowthMetric> analyzeMuscleGrowthMetrics({
    required List<WorkoutSession> sessions,
    required List<WorkoutHistory> history,
    DateTime? nowOverride,
  }) {
    if (sessions.isEmpty && history.isEmpty) {
      return [];
    }

    final now = nowOverride ?? DateTime.now();
    final thisWeekStart = now.subtract(Duration(days: now.weekday - 1));
    final cleanThisWeekStart = DateTime(
      thisWeekStart.year,
      thisWeekStart.month,
      thisWeekStart.day,
    );
    final lastWeekStart = cleanThisWeekStart.subtract(const Duration(days: 7));
    final lastWeekEnd = cleanThisWeekStart.subtract(const Duration(seconds: 1));

    final Map<String, double> thisWeekVolume = {
      'Chest': 0.0,
      'Back': 0.0,
      'Legs': 0.0,
      'Shoulders': 0.0,
      'Arms': 0.0,
      'Core': 0.0,
    };

    final Map<String, double> lastWeekVolume = {
      'Chest': 0.0,
      'Back': 0.0,
      'Legs': 0.0,
      'Shoulders': 0.0,
      'Arms': 0.0,
      'Core': 0.0,
    };

    // 1. Process structured workout sessions
    for (final s in sessions) {
      final isThisWk = s.startTime.isAfter(cleanThisWeekStart);
      final isLastWk =
          s.startTime.isAfter(lastWeekStart) &&
          s.startTime.isBefore(lastWeekEnd);

      if (!isThisWk && !isLastWk) continue;

      for (final ex in s.exercises) {
        final muscle = _categorizeMuscleGroup(ex.muscleGroup, ex.name);
        final vol = ex.totalVolume;

        if (isThisWk) {
          thisWeekVolume[muscle] = (thisWeekVolume[muscle] ?? 0.0) + vol;
        } else if (isLastWk) {
          lastWeekVolume[muscle] = (lastWeekVolume[muscle] ?? 0.0) + vol;
        }
      }
    }

    // 2. Process history workouts if sessions are sparse
    if (sessions.isEmpty) {
      for (final h in history) {
        final isThisWk = h.dateCompleted.isAfter(cleanThisWeekStart);
        final isLastWk =
            h.dateCompleted.isAfter(lastWeekStart) &&
            h.dateCompleted.isBefore(lastWeekEnd);

        if (!isThisWk && !isLastWk) continue;

        final muscle = _categorizeWorkoutTitle(h.workoutName);
        final vol = h.totalVolume;

        if (isThisWk) {
          thisWeekVolume[muscle] = (thisWeekVolume[muscle] ?? 0.0) + vol;
        } else if (isLastWk) {
          lastWeekVolume[muscle] = (lastWeekVolume[muscle] ?? 0.0) + vol;
        }
      }
    }

    final double totalCurrentWeek = thisWeekVolume.values.fold(
      0.0,
      (a, b) => a + b,
    );

    final List<MuscleGrowthMetric> metrics = [];

    thisWeekVolume.forEach((muscle, currentVol) {
      final prevVol = lastWeekVolume[muscle] ?? 0.0;
      double pctChange = 0.0;
      if (prevVol > 0) {
        pctChange = ((currentVol - prevVol) / prevVol) * 100.0;
      } else if (currentVol > 0) {
        pctChange = 100.0;
      }

      final pctOfTotal = totalCurrentWeek > 0
          ? ((currentVol / totalCurrentWeek) * 100.0)
          : 0.0;

      String status = 'Maintaining';
      if (totalCurrentWeek == 0) {
        status = 'Undertrained';
      } else if (pctOfTotal < 10.0 || (prevVol > 0 && pctChange <= -25.0)) {
        status = 'Undertrained';
      } else if (pctOfTotal > 45.0 && pctChange > 50.0) {
        status = 'Overtrained';
      } else if (pctChange >= 5.0 || pctOfTotal >= 20.0) {
        status = 'Growing';
      }

      metrics.add(
        MuscleGrowthMetric(
          muscleGroup: muscle,
          weeklyVolume: double.parse(currentVol.toStringAsFixed(1)),
          previousVolume: double.parse(prevVol.toStringAsFixed(1)),
          status: status,
          percentageChange: double.parse(pctChange.toStringAsFixed(1)),
          percentageOfTotal: double.parse(pctOfTotal.toStringAsFixed(1)),
        ),
      );
    });

    metrics.sort((a, b) => b.weeklyVolume.compareTo(a.weeklyVolume));
    return metrics;
  }

  /// Detects strength plateaus where an exercise has seen no improvement for 3+ weeks.
  List<PlateauInsight> detectPlateaus({
    required List<StrengthProgress> strengthProgressions,
    int thresholdWeeks = 3,
  }) {
    if (strengthProgressions.isEmpty) return [];

    final List<PlateauInsight> insights = [];

    for (final prog in strengthProgressions) {
      if (prog.weightHistory.length < 3 || prog.dateHistory.length < 3) {
        continue;
      }

      final earliest = prog.dateHistory.first;
      final latest = prog.dateHistory.last;
      final spanDays = latest.difference(earliest).inDays;

      if (spanDays >= (thresholdWeeks * 7)) {
        // Look at the last 3 performance points
        final recentWeights = prog.weightHistory.sublist(
          max(0, prog.weightHistory.length - 3),
        );
        final minW = recentWeights.reduce(min);
        final maxW = recentWeights.reduce(max);

        // If delta across last 3 sessions over 3+ weeks is under 1.0 kg
        if ((maxW - minW) <= 1.0) {
          final weeksStalled = (spanDays / 7).round();
          insights.add(
            PlateauInsight(
              exerciseName: prog.exerciseName,
              weeksWithoutImprovement: weeksStalled,
              currentPlateauWeight: prog.currentWeight,
              severity: weeksStalled >= 5 ? 'Significant' : 'Moderate',
              message:
                  'Strength plateau detected for ${prog.exerciseName} at ${prog.currentWeight.toStringAsFixed(1)} kg ($weeksStalled weeks without increase).',
              suggestions: const [
                'Deload load by 10-15% next session to reset neuromuscular fatigue.',
                'Introduce micro-loading (+1.0 to +2.5 kg) or cluster sets.',
                'Vary rep schemes (e.g. rotate from 8-10 reps to heavy 4-6 reps).',
                'Increase daily caloric intake by +200-300 kcal to fuel muscular adaptation.',
              ],
            ),
          );
        }
      }
    }

    return insights;
  }

  /// Calculates training consistency percentage based on target weekly frequency.
  double calculateConsistencyPercentage({
    required List<WorkoutHistory> history,
    int targetWorkoutsPerWeek = 4,
    int lookbackWeeks = 4,
    DateTime? nowOverride,
  }) {
    if (history.isEmpty) return 0.0;

    final now = nowOverride ?? DateTime.now();
    final lookbackStart = now.subtract(Duration(days: lookbackWeeks * 7));

    final recentWorkouts = history
        .where((h) => h.dateCompleted.isAfter(lookbackStart))
        .length;

    final targetTotal = targetWorkoutsPerWeek * lookbackWeeks;
    if (targetTotal <= 0) return 0.0;

    final consistency = (recentWorkouts / targetTotal) * 100.0;
    return double.parse(consistency.clamp(0.0, 100.0).toStringAsFixed(1));
  }

  /// Generates master athlete analytics report.
  AthleteAnalyticsReport generateAthleteReport({
    required List<WorkoutSession> sessions,
    required List<WorkoutHistory> history,
    double bodyWeight = 75.0,
    int targetWorkoutsPerWeek = 4,
    DateTime? nowOverride,
  }) {
    if (sessions.isEmpty && history.isEmpty) {
      return AthleteAnalyticsReport.empty();
    }

    final strengthProgressions = analyzeStrengthProgress(
      sessions: sessions,
      history: history,
    );

    final volumeTrends = calculateVolumeTrends(
      sessions: sessions,
      history: history,
      nowOverride: nowOverride,
    );

    final muscleMetrics = analyzeMuscleGrowthMetrics(
      sessions: sessions,
      history: history,
      nowOverride: nowOverride,
    );

    final plateauInsights = detectPlateaus(
      strengthProgressions: strengthProgressions,
    );

    final consistencyPct = calculateConsistencyPercentage(
      history: history,
      targetWorkoutsPerWeek: targetWorkoutsPerWeek,
      nowOverride: nowOverride,
    );

    // Calculate weekly volume delta percentage
    double weeklyVolumeDelta = 0.0;
    if (volumeTrends.length >= 2) {
      final thisWk = volumeTrends.last.volume;
      final prevWk = volumeTrends[volumeTrends.length - 2].volume;
      if (prevWk > 0) {
        weeklyVolumeDelta = ((thisWk - prevWk) / prevWk) * 100.0;
      } else if (thisWk > 0) {
        weeklyVolumeDelta = 100.0;
      }
    }

    // Extract all PRs
    final List<PersonalRecord> prs = [];
    for (final h in history) {
      for (final prStr in h.personalRecords) {
        prs.add(
          PersonalRecord(
            id: 'pr_${h.workoutName}_${h.dateCompleted.millisecondsSinceEpoch}_${prStr.hashCode}',
            exerciseName: prStr.split(':').first.trim(),
            recordType: 'Personal Record',
            value: 0.0,
            achievedDate: h.dateCompleted,
          ),
        );
      }
    }

    final totalVol = history.fold(0.0, (sum, h) => sum + h.totalVolume);

    final snapshot = ProgressSnapshot(
      date: DateTime.now(),
      bodyWeight: bodyWeight,
      totalVolume: totalVol,
      workoutsCompleted: history.length,
      averageIntensity: 8.0,
      muscleVolume: {
        for (final m in muscleMetrics) m.muscleGroup: m.weeklyVolume,
      },
      prs: prs,
    );

    final aiSummary = _buildAICoachSummary(
      strength: strengthProgressions,
      volumeTrends: volumeTrends,
      muscleMetrics: muscleMetrics,
      plateaus: plateauInsights,
      consistencyPct: consistencyPct,
    );

    return AthleteAnalyticsReport(
      currentSnapshot: snapshot,
      strengthProgressions: strengthProgressions,
      muscleMetrics: muscleMetrics,
      volumeTrends: volumeTrends,
      plateauInsights: plateauInsights,
      consistencyPercentage: consistencyPct,
      currentStreak: history.isNotEmpty ? 1 : 0,
      longestStreak: history.isNotEmpty ? 1 : 0,
      weeklyVolumeDeltaPercent: double.parse(
        weeklyVolumeDelta.toStringAsFixed(1),
      ),
      aiCoachSummary: aiSummary,
      generatedAt: DateTime.now(),
    );
  }

  /// Builds structured AI Coach context prompt block.
  String buildAICoachPromptContext(AthleteAnalyticsReport report) {
    if (report.strengthProgressions.isEmpty && report.volumeTrends.isEmpty) {
      return '''
[ATHLETE PROGRESS CONTEXT]
- Workout History: Insufficient workout history recorded.
- Strength Baseline: Not yet calibrated.
- Recommendation: Coach athlete to complete first structured workout to establish baseline volume and strength metrics.
''';
    }

    final buffer = StringBuffer();
    buffer.writeln('[ATHLETE PROGRESS & PERFORMANCE CONTEXT]');

    // Strength
    buffer.writeln('Strength Progression:');
    if (report.strengthProgressions.isNotEmpty) {
      for (final s in report.strengthProgressions.take(3)) {
        final sign = s.improvement >= 0 ? '+' : '';
        buffer.writeln(
          '  - ${s.exerciseName}: ${s.currentWeight}kg ($sign${s.improvement}kg, ${s.percentageIncrease}% increase, Est. 1RM ${s.estimatedOneRepMax}kg)',
        );
      }
    } else {
      buffer.writeln('  - Baseline lifting data active.');
    }

    // Plateaus
    if (report.plateauInsights.isNotEmpty) {
      buffer.writeln('Plateau Alerts:');
      for (final p in report.plateauInsights) {
        buffer.writeln(
          '  - ⚠️ ${p.exerciseName}: Plateau detected (${p.weeksWithoutImprovement} weeks at ${p.currentPlateauWeight}kg)',
        );
      }
    }

    // Volume
    if (report.volumeTrends.isNotEmpty) {
      final latest = report.volumeTrends.last;
      final sign = report.weeklyVolumeDeltaPercent >= 0 ? '+' : '';
      buffer.writeln(
        'Volume Trajectory: This week ${latest.volume.toStringAsFixed(0)} kg ($sign${report.weeklyVolumeDeltaPercent}% vs previous week across ${latest.workoutsCount} sessions)',
      );
    }

    // Muscle Balance & Undertrained Areas
    final undertrained = report.muscleMetrics
        .where((m) => m.status == 'Undertrained')
        .map((m) => m.muscleGroup)
        .toList();
    final growing = report.muscleMetrics
        .where((m) => m.status == 'Growing')
        .map((m) => m.muscleGroup)
        .toList();

    buffer.writeln('Muscle Balance:');
    if (growing.isNotEmpty) {
      buffer.writeln('  - Progressing: ${growing.join(', ')}');
    }
    if (undertrained.isNotEmpty) {
      buffer.writeln(
        '  - ⚠️ Undertrained: ${undertrained.join(', ')} (Recommend adding targeted assistance volume)',
      );
    }

    buffer.writeln(
      'Consistency Score: ${report.consistencyPercentage}% (${report.currentStreak} day streak)',
    );

    return buffer.toString();
  }

  String _buildAICoachSummary({
    required List<StrengthProgress> strength,
    required List<VolumeTrendPoint> volumeTrends,
    required List<MuscleGrowthMetric> muscleMetrics,
    required List<PlateauInsight> plateaus,
    required double consistencyPct,
  }) {
    final parts = <String>[];

    if (strength.isNotEmpty) {
      final topStrength = strength.first;
      if (topStrength.improvement > 0) {
        parts.add(
          '${topStrength.exerciseName} increased +${topStrength.improvement}kg (${topStrength.percentageIncrease}% gain).',
        );
      }
    }

    if (plateaus.isNotEmpty) {
      parts.add(
        'Plateau detected on ${plateaus.first.exerciseName}; consider varying rep schemes or increasing calories.',
      );
    }

    final undertrained = muscleMetrics
        .where((m) => m.status == 'Undertrained')
        .toList();
    if (undertrained.isNotEmpty) {
      parts.add(
        '${undertrained.first.muscleGroup} volume is low; recommend adding assistance work.',
      );
    }

    if (parts.isEmpty) {
      return 'Training progression is balanced. Maintain progressive overload and prioritize recovery.';
    }

    return parts.join(' ');
  }

  String _normalizeExerciseName(String name) {
    return name.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _categorizeMuscleGroup(String group, String name) {
    final combined = '${group.toLowerCase()} ${name.toLowerCase()}';
    if (combined.contains('chest') ||
        combined.contains('bench') ||
        combined.contains('push-up')) {
      return 'Chest';
    }
    if (combined.contains('back') ||
        combined.contains('pull') ||
        combined.contains('row') ||
        combined.contains('deadlift') ||
        combined.contains('lat')) {
      return 'Back';
    }
    if (combined.contains('leg') ||
        combined.contains('squat') ||
        combined.contains('quad') ||
        combined.contains('hamstring') ||
        combined.contains('calf') ||
        combined.contains('lunge')) {
      return 'Legs';
    }
    if (combined.contains('shoulder') ||
        combined.contains('overhead') ||
        combined.contains('delt') ||
        combined.contains('military')) {
      return 'Shoulders';
    }
    if (combined.contains('arm') ||
        combined.contains('bicep') ||
        combined.contains('tricep') ||
        combined.contains('curl') ||
        combined.contains('dip')) {
      return 'Arms';
    }
    if (combined.contains('core') ||
        combined.contains('ab') ||
        combined.contains('plank') ||
        combined.contains('crunch')) {
      return 'Core';
    }
    return 'Chest';
  }

  String _categorizeWorkoutTitle(String title) {
    final t = title.toLowerCase();
    if (t.contains('push') || t.contains('chest')) return 'Chest';
    if (t.contains('pull') || t.contains('back')) return 'Back';
    if (t.contains('leg') || t.contains('lower') || t.contains('squat')) {
      return 'Legs';
    }
    if (t.contains('shoulder')) return 'Shoulders';
    if (t.contains('arm')) return 'Arms';
    if (t.contains('core') || t.contains('ab')) return 'Core';
    return 'Legs';
  }
}

class _ExerciseLogTracker {
  final String displayName;
  final String exerciseId;
  final List<DateTime> dates = [];
  final List<double> weights = [];
  final List<double> oneRepMaxes = [];

  _ExerciseLogTracker({required this.displayName, required this.exerciseId});

  void addEntry({
    required DateTime date,
    required double weight,
    required double oneRepMax,
  }) {
    dates.add(date);
    weights.add(weight);
    oneRepMaxes.add(oneRepMax);
  }
}

class _DateVolumeEntry {
  double volume = 0.0;
  int workoutCount = 0;
}
