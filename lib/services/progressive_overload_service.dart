import 'dart:math';
import '../data/local_storage.dart';
import '../models/personal_record.dart';
import '../models/workout_history.dart';
import '../models/workout_session.dart';

/// Service calculating realistic progressive overload benchmarks,
/// authentic Personal Record (PR) achievements, and physiological energy expenditure.
class ProgressiveOverloadService {
  static ProgressiveOverloadService? _instance;

  ProgressiveOverloadService();

  static ProgressiveOverloadService get instance {
    _instance ??= ProgressiveOverloadService();
    return _instance!;
  }

  /// Reset singleton for testing
  static void resetInstance() {
    _instance = null;
  }

  /// Calculates estimated 1 Rep Max (1RM) using the Epley formula:
  /// 1RM = weight × (1 + reps / 30)
  double calculateEstimated1RM(double weight, int reps) {
    if (weight <= 0.0 || reps <= 0) return 0.0;
    if (reps == 1) return weight;
    return weight * (1.0 + (reps / 30.0));
  }

  /// Calculates energy expenditure estimate (kcal) based on:
  /// - User body weight in kg (from athlete profile)
  /// - Active training duration in minutes
  /// - Total mechanical work volume lifted
  /// - Training intensity (MET value: 5.5 for structured resistance training)
  double calculateCaloriesBurned({
    required double durationSeconds,
    required double totalVolumeKg,
    required int completedSets,
    double? athleteWeightKg,
  }) {
    final double weightKg = athleteWeightKg ?? _getAthleteWeightKg();
    final double durationMinutes = durationSeconds / 60.0;

    if (durationMinutes <= 0 || completedSets <= 0) {
      // Idle basal expenditure during zero active work
      return (1.2 * 3.5 * weightKg / 200.0) * (durationSeconds / 60.0);
    }

    // Standard resistance training MET: 5.5 (vigorous lifting)
    const double met = 5.5;
    final double baseCardioMetKcal =
        (met * 3.5 * weightKg / 200.0) * durationMinutes;

    // Mechanical load work expenditure: ~1.2 kcal per 1000 kg volume lifted
    final double mechanicalWorkKcal = (totalVolumeKg / 1000.0) * 1.2;

    return (baseCardioMetKcal + mechanicalWorkKcal).clamp(1.0, 3000.0);
  }

  /// Retrieves athlete's current weight in kg from storage with safe fallback
  double _getAthleteWeightKg() {
    final profile = LocalStorage.getUserProfile();
    final parsed = double.tryParse(profile.weight);
    if (parsed != null && parsed >= 30.0 && parsed <= 300.0) {
      return parsed;
    }
    return 70.0; // Standard athletic baseline weight
  }

  /// Evaluates completed exercises and detects authentic Personal Records (PRs)
  /// by comparing against stored historical performance.
  ///
  /// PRs are strictly:
  /// 1. Maximum weight PR (lifted heavier weight than previous best)
  /// 2. Estimated 1RM PR (higher calculated 1RM than previous best)
  /// 3. Total Exercise Volume PR (higher total exercise volume than previous best)
  ///
  /// Baseline / initial workouts with no prior history do NOT generate PRs.
  List<PersonalRecordResult> evaluatePersonalRecords({
    required List<WorkoutSessionExercise> exercises,
    required String workoutId,
    List<WorkoutSession>? pastSessions,
    List<WorkoutHistory>? pastHistory,
  }) {
    final sessions = pastSessions ?? LocalStorage.getWorkoutSessions();
    final results = <PersonalRecordResult>[];

    for (final ex in exercises) {
      final completedSets = ex.sets.where((s) => s.completed).toList();
      if (completedSets.isEmpty) continue;

      final double sessionMaxWeight = completedSets.fold(
        0.0,
        (maxW, s) => s.weight > maxW ? s.weight : maxW,
      );

      final double sessionVolume = completedSets.fold(
        0.0,
        (vol, s) => vol + (s.weight * s.reps),
      );

      final double sessionMax1RM = completedSets.fold(
        0.0,
        (max1RM, s) => max(max1RM, calculateEstimated1RM(s.weight, s.reps)),
      );

      final int sessionMaxReps = completedSets.fold(
        0,
        (maxR, s) => s.reps > maxR ? s.reps : maxR,
      );

      // Find historical max weight, 1RM, volume, and max reps for this exercise
      double historicalMaxWeight = 0.0;
      double historicalMax1RM = 0.0;
      double historicalMaxVolume = 0.0;
      int historicalMaxReps = 0;
      bool hadPriorHistory = false;

      for (final pastSession in sessions) {
        for (final pastEx in pastSession.exercises) {
          if (_isSameExercise(pastEx.name, ex.name, pastEx.id, ex.id)) {
            final pastCompleted = pastEx.sets
                .where((s) => s.completed)
                .toList();
            if (pastCompleted.isNotEmpty) {
              hadPriorHistory = true;
              if (pastEx.maxWeight > historicalMaxWeight) {
                historicalMaxWeight = pastEx.maxWeight;
              }
              if (pastEx.totalVolume > historicalMaxVolume) {
                historicalMaxVolume = pastEx.totalVolume;
              }
              for (final pSet in pastCompleted) {
                final p1RM = calculateEstimated1RM(pSet.weight, pSet.reps);
                if (p1RM > historicalMax1RM) {
                  historicalMax1RM = p1RM;
                }
                if (pSet.reps > historicalMaxReps) {
                  historicalMaxReps = pSet.reps;
                }
              }
            }
          }
        }
      }

      // First workout / baseline establishment does NOT produce fake PRs
      if (!hadPriorHistory) {
        continue;
      }

      bool weightPRAchieved = false;

      // 1. Max Weight PR Check
      if (sessionMaxWeight > historicalMaxWeight && historicalMaxWeight > 0.0) {
        weightPRAchieved = true;
        final improvementKg = sessionMaxWeight - historicalMaxWeight;
        final pct = (improvementKg / historicalMaxWeight) * 100.0;
        results.add(
          PersonalRecordResult(
            displayText:
                '${ex.name}: Weight PR ${sessionMaxWeight.toStringAsFixed(1)} kg (+${improvementKg.toStringAsFixed(1)} kg)',
            record: PersonalRecord(
              id: 'pr_weight_${ex.id}_${DateTime.now().millisecondsSinceEpoch}',
              exerciseId: ex.id,
              exerciseName: ex.name,
              muscleGroup: ex.muscleGroup,
              recordType: 'Heaviest Lift',
              value: sessionMaxWeight,
              previousValue: historicalMaxWeight,
              improvementPercentage: pct,
              achievedDate: DateTime.now(),
              workoutId: workoutId,
              isNew: true,
            ),
          ),
        );
      }

      // 2. Estimated 1RM PR Check (if max weight PR didn't already capture it or if 1RM increased via reps)
      if (!weightPRAchieved &&
          sessionMax1RM > historicalMax1RM &&
          historicalMax1RM > 0.0) {
        final improvement1RM = sessionMax1RM - historicalMax1RM;
        final pct = (improvement1RM / historicalMax1RM) * 100.0;
        results.add(
          PersonalRecordResult(
            displayText:
                '${ex.name}: Strength PR (Est. 1RM: ${sessionMax1RM.toStringAsFixed(1)} kg, +${improvement1RM.toStringAsFixed(1)} kg)',
            record: PersonalRecord(
              id: 'pr_1rm_${ex.id}_${DateTime.now().millisecondsSinceEpoch}',
              exerciseId: ex.id,
              exerciseName: ex.name,
              muscleGroup: ex.muscleGroup,
              recordType: 'Estimated 1RM',
              value: sessionMax1RM,
              previousValue: historicalMax1RM,
              improvementPercentage: pct,
              achievedDate: DateTime.now(),
              workoutId: workoutId,
              isNew: true,
            ),
          ),
        );
      }

      // 3. Max Volume PR Check
      if (sessionVolume > historicalMaxVolume &&
          sessionVolume > 0 &&
          historicalMaxVolume > 0) {
        final improvementVol = sessionVolume - historicalMaxVolume;
        final pct = (improvementVol / historicalMaxVolume) * 100.0;
        results.add(
          PersonalRecordResult(
            displayText:
                '${ex.name}: Volume PR ${sessionVolume.toStringAsFixed(0)} kg (+${improvementVol.toStringAsFixed(0)} kg)',
            record: PersonalRecord(
              id: 'pr_vol_${ex.id}_${DateTime.now().millisecondsSinceEpoch}',
              exerciseId: ex.id,
              exerciseName: ex.name,
              muscleGroup: ex.muscleGroup,
              recordType: 'Highest Session Volume',
              value: sessionVolume,
              previousValue: historicalMaxVolume,
              improvementPercentage: pct,
              achievedDate: DateTime.now(),
              workoutId: workoutId,
              isNew: true,
            ),
          ),
        );
      }

      // 4. Rep PR Check (Maximum reps completed in a single set)
      if (!weightPRAchieved &&
          sessionMaxReps > historicalMaxReps &&
          historicalMaxReps > 0 &&
          sessionMaxWeight >= historicalMaxWeight * 0.9) {
        final repDiff = sessionMaxReps - historicalMaxReps;
        final pct = (repDiff / historicalMaxReps) * 100.0;
        results.add(
          PersonalRecordResult(
            displayText:
                '${ex.name}: Rep PR $sessionMaxReps reps (+$repDiff reps)',
            record: PersonalRecord(
              id: 'pr_reps_${ex.id}_${DateTime.now().millisecondsSinceEpoch}',
              exerciseId: ex.id,
              exerciseName: ex.name,
              muscleGroup: ex.muscleGroup,
              recordType: 'Max Reps',
              value: sessionMaxReps.toDouble(),
              previousValue: historicalMaxReps.toDouble(),
              improvementPercentage: pct,
              achievedDate: DateTime.now(),
              workoutId: workoutId,
              isNew: true,
            ),
          ),
        );
      }
    }

    return results;
  }

  /// Determines if two exercises represent the same movement
  bool _isSameExercise(String nameA, String nameB, String idA, String idB) {
    if (idA.isNotEmpty &&
        idB.isNotEmpty &&
        idA.toLowerCase() == idB.toLowerCase()) {
      return true;
    }
    return nameA.trim().toLowerCase() == nameB.trim().toLowerCase();
  }

  /// Calculates conservative progressive overload benchmark suggestions for an exercise
  /// based on prior completed workouts.
  ///
  /// - If user successfully completed all prescribed reps: suggests conservative increase (+2.5kg or +1 rep)
  /// - If user had incomplete sets or missed target reps: maintains weight or reduces reps conservatively
  ({
    double targetWeight,
    int targetReps,
    String? progressionNote,
    bool isOverloadApplied,
  })
  getSuggestedProgression({
    required String exerciseName,
    String? exerciseId,
    double defaultWeight = 40.0,
    int defaultReps = 10,
    int prescribedTargetReps = 8,
    List<WorkoutSession>? pastSessions,
  }) {
    final sessions = pastSessions ?? LocalStorage.getWorkoutSessions();

    for (final session in sessions) {
      for (final ex in session.exercises) {
        if (_isSameExercise(ex.name, exerciseName, ex.id, exerciseId ?? '')) {
          final completed = ex.sets.where((s) => s.completed).toList();
          if (completed.isNotEmpty) {
            final lastSet = completed.last;
            final double lastWeight = lastSet.weight;
            final int lastReps = lastSet.reps;

            // Evaluate if all completed sets achieved the target threshold
            final bool hitAllTargetReps = completed.every(
              (s) => s.reps >= prescribedTargetReps,
            );

            if (hitAllTargetReps && lastWeight > 0) {
              // Successful performance -> Conservative progressive overload (+2.5 kg)
              return (
                targetWeight: lastWeight + 2.5,
                targetReps: defaultReps,
                progressionNote:
                    'Target: +2.5 kg overload vs previous ${lastWeight.toStringAsFixed(1)} kg',
                isOverloadApplied: true,
              );
            } else if (lastReps >= prescribedTargetReps && lastWeight > 0) {
              // Met target on final set -> Push +1 rep overload at current load
              return (
                targetWeight: lastWeight,
                targetReps: lastReps + 1,
                progressionNote:
                    'Target: +1 rep overload at ${lastWeight.toStringAsFixed(1)} kg',
                isOverloadApplied: true,
              );
            } else if (lastWeight > 0) {
              // Incomplete or failed target -> Do NOT increase weight; maintain conservative load
              return (
                targetWeight: lastWeight,
                targetReps: prescribedTargetReps,
                progressionNote:
                    'Maintain ${lastWeight.toStringAsFixed(1)} kg to consolidate form and volume',
                isOverloadApplied: false,
              );
            }
          }
        }
      }
    }

    return (
      targetWeight: defaultWeight,
      targetReps: defaultReps,
      progressionNote: null,
      isOverloadApplied: false,
    );
  }

  /// Compares current performance against historical lifting records for an exercise.
  ProgressiveOverloadFeedback comparePerformance({
    required String exerciseName,
    required double currentWeight,
    required int currentReps,
    List<WorkoutSession>? history,
  }) {
    final sessions = history ?? LocalStorage.getWorkoutSessions();
    double prevWeight = 0.0;
    int prevReps = 0;
    bool foundHistory = false;

    for (final s in sessions) {
      for (final ex in s.exercises) {
        if (_isSameExercise(ex.name, exerciseName, ex.id, exerciseName)) {
          final completed = ex.sets.where((st) => st.completed).toList();
          if (completed.isNotEmpty) {
            foundHistory = true;
            if (ex.maxWeight > prevWeight) {
              prevWeight = ex.maxWeight;
            }
            final maxR = completed.fold(
              0,
              (maxReps, st) => st.reps > maxReps ? st.reps : maxReps,
            );
            if (maxR > prevReps) {
              prevReps = maxR;
            }
          }
        }
      }
    }

    final isLower =
        exerciseName.toLowerCase().contains('squat') ||
        exerciseName.toLowerCase().contains('deadlift') ||
        exerciseName.toLowerCase().contains('leg press');
    final increment = isLower ? 5.0 : 2.5;

    if (!foundHistory) {
      return ProgressiveOverloadFeedback(
        exerciseName: exerciseName,
        currentWeight: currentWeight,
        currentReps: currentReps,
        isProgression: true,
        isWeightPR: false,
        isRepPR: false,
        recommendedNextWeight: currentWeight,
        recommendedNextReps: currentReps + 1,
        recommendationMessage:
            'Baseline established at ${currentWeight.toStringAsFixed(1)}kg x $currentReps reps.',
      );
    }

    final bool isWeightPR = currentWeight > prevWeight;
    final bool isRepPR =
        (currentWeight == prevWeight && currentReps > prevReps);
    final bool isProgression = isWeightPR || isRepPR;

    double nextWeight = currentWeight;
    int nextReps = currentReps;
    String message;

    if (isWeightPR) {
      nextWeight = currentWeight;
      nextReps = currentReps;
      message =
          'New Weight PR! Lifted ${currentWeight.toStringAsFixed(1)}kg (+${(currentWeight - prevWeight).toStringAsFixed(1)}kg over previous best).';
    } else if (isRepPR) {
      nextWeight = currentWeight + increment;
      nextReps = 8;
      message =
          'Rep goal achieved (${currentWeight.toStringAsFixed(1)}kg x $currentReps reps). Increase weight to ${nextWeight.toStringAsFixed(1)}kg (+${increment.toStringAsFixed(1)}kg) next session.';
    } else if (currentWeight == prevWeight && currentReps == prevReps) {
      nextWeight = currentWeight;
      nextReps = currentReps + 1;
      message =
          'Consistently matching working load. Aim for +1 rep ($nextReps reps) next session.';
    } else {
      nextWeight = currentWeight;
      nextReps = prevReps;
      message =
          'Focus on form consolidation at ${currentWeight.toStringAsFixed(1)}kg.';
    }

    return ProgressiveOverloadFeedback(
      exerciseName: exerciseName,
      currentWeight: currentWeight,
      currentReps: currentReps,
      previousWeight: prevWeight > 0 ? prevWeight : null,
      previousReps: prevReps > 0 ? prevReps : null,
      isProgression: isProgression,
      isWeightPR: isWeightPR,
      isRepPR: isRepPR,
      recommendedNextWeight: nextWeight,
      recommendedNextReps: nextReps,
      recommendationMessage: message,
    );
  }
}

/// Structured feedback comparing current performance to historical benchmarks
class ProgressiveOverloadFeedback {
  final String exerciseName;
  final double currentWeight;
  final int currentReps;
  final double? previousWeight;
  final int? previousReps;
  final bool isProgression;
  final bool isWeightPR;
  final bool isRepPR;
  final double recommendedNextWeight;
  final int recommendedNextReps;
  final String recommendationMessage;

  const ProgressiveOverloadFeedback({
    required this.exerciseName,
    required this.currentWeight,
    required this.currentReps,
    this.previousWeight,
    this.previousReps,
    required this.isProgression,
    required this.isWeightPR,
    required this.isRepPR,
    required this.recommendedNextWeight,
    required this.recommendedNextReps,
    required this.recommendationMessage,
  });

  Map<String, dynamic> toJson() => {
    'exerciseName': exerciseName,
    'currentWeight': currentWeight,
    'currentReps': currentReps,
    'previousWeight': previousWeight,
    'previousReps': previousReps,
    'isProgression': isProgression,
    'isWeightPR': isWeightPR,
    'isRepPR': isRepPR,
    'recommendedNextWeight': recommendedNextWeight,
    'recommendedNextReps': recommendedNextReps,
    'recommendationMessage': recommendationMessage,
  };
}

/// Result container holding display text and typed PersonalRecord model
class PersonalRecordResult {
  final String displayText;
  final PersonalRecord record;

  const PersonalRecordResult({required this.displayText, required this.record});
}
