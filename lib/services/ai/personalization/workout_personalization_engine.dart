import '../../../models/exercise.dart';
import '../../../models/fitness_context.dart';
import '../../../models/workout_history.dart';
import '../memory/memory_event.dart';
import '../memory/preference_profile.dart';
import 'exercise_recommendation_score.dart';
import 'training_preference_profile.dart';

/// Progressive overload recommendation details for a specific exercise.
class ProgressiveOverloadRecommendation {
  final String exerciseName;
  final double currentWorkingWeight;
  final double recommendedWeight;
  final int recommendedSets;
  final int recommendedReps;
  final String rationale;

  const ProgressiveOverloadRecommendation({
    required this.exerciseName,
    required this.currentWorkingWeight,
    required this.recommendedWeight,
    required this.recommendedSets,
    required this.recommendedReps,
    required this.rationale,
  });

  Map<String, dynamic> toJson() => {
    'exerciseName': exerciseName,
    'currentWorkingWeight': currentWorkingWeight,
    'recommendedWeight': recommendedWeight,
    'recommendedSets': recommendedSets,
    'recommendedReps': recommendedReps,
    'rationale': rationale,
  };
}

/// Skipped workout pattern insight providing proactive scheduling or volume adaptation.
class SkippedWorkoutInsight {
  final String splitName;
  final int skipCount;
  final String recommendation;
  final bool requiresAdjustment;

  const SkippedWorkoutInsight({
    required this.splitName,
    required this.skipCount,
    required this.recommendation,
    required this.requiresAdjustment,
  });
}

/// Centralized AI Personalization Engine that transforms workout generation
/// into a continuously learning, adaptive recommendation system.
class WorkoutPersonalizationEngine {
  const WorkoutPersonalizationEngine();

  static const WorkoutPersonalizationEngine instance =
      WorkoutPersonalizationEngine();

  /// Analyzes workout history, completed sessions, and feedback memory to synthesize
  /// an updated [TrainingPreferenceProfile].
  TrainingPreferenceProfile analyzeHistoryAndMemory({
    required List<WorkoutHistory> history,
    required List<MemoryEvent> memoryEvents,
    PreferenceProfile? baseProfile,
  }) {
    final completionStats = <String, int>{};
    final skipStats = <String, int>{};
    final splitCompletions = <String, int>{};
    final splitSkips = <String, int>{};
    final progressiveOverloadNotes = <String, double>{};
    final difficultyRatings = <String>[];

    int dumbbellCount = 0;
    int barbellCount = 0;
    int cableMachineCount = 0;
    int bodyweightCount = 0;

    final preferredExercises = <String>{};
    final avoidedExercises = <String>{};

    if (baseProfile != null) {
      preferredExercises.addAll(baseProfile.preferredExercises);
      avoidedExercises.addAll(baseProfile.dislikedExercises);
    }

    // 1. Process Memory Events (likes, dislikes, replacements, skips, difficulty)
    for (final evt in memoryEvents) {
      final target = evt.target.trim();
      switch (evt.type) {
        case MemoryEventType.exerciseLiked:
        case MemoryEventType.exerciseEnjoyed:
          preferredExercises.add(target);
          avoidedExercises.remove(target);
          completionStats[target] = (completionStats[target] ?? 0) + 2;
          break;
        case MemoryEventType.exerciseDisliked:
          avoidedExercises.add(target);
          preferredExercises.remove(target);
          break;
        case MemoryEventType.exerciseReplaced:
          avoidedExercises.add(target);
          preferredExercises.remove(target);
          if (evt.secondaryTarget != null &&
              evt.secondaryTarget!.trim().isNotEmpty) {
            preferredExercises.add(evt.secondaryTarget!.trim());
          }
          break;
        case MemoryEventType.exerciseSkipped:
          skipStats[target] = (skipStats[target] ?? 0) + 1;
          break;
        case MemoryEventType.workoutSkipped:
          final split = evt.target.trim();
          splitSkips[split] = (splitSkips[split] ?? 0) + 1;
          break;
        case MemoryEventType.workoutDifficultyFeedback:
          if (evt.notes != null && evt.notes!.isNotEmpty) {
            difficultyRatings.add(evt.notes!);
          }
          break;
        default:
          break;
      }
    }

    // 2. Process Workout History & Equipment Usage Patterns
    for (final workout in history) {
      final name = workout.workoutName.toLowerCase();

      // Categorize Split
      if (name.contains('push') || name.contains('chest')) {
        splitCompletions['Push'] = (splitCompletions['Push'] ?? 0) + 1;
      } else if (name.contains('pull') || name.contains('back')) {
        splitCompletions['Pull'] = (splitCompletions['Pull'] ?? 0) + 1;
      } else if (name.contains('leg') ||
          name.contains('lower') ||
          name.contains('squat')) {
        splitCompletions['Legs'] = (splitCompletions['Legs'] ?? 0) + 1;
      } else if (name.contains('upper')) {
        splitCompletions['Upper'] = (splitCompletions['Upper'] ?? 0) + 1;
      } else {
        splitCompletions['Full Body'] =
            (splitCompletions['Full Body'] ?? 0) + 1;
      }
    }

    // Inspect exercise performance logs for equipment habits and progressive overload
    for (final evt in memoryEvents) {
      if (evt.type == MemoryEventType.workoutCompleted &&
          evt.target.isNotEmpty) {
        final exName = evt.target.trim();
        final lower = exName.toLowerCase();

        completionStats[exName] = (completionStats[exName] ?? 0) + 1;

        if (lower.contains('dumbbell') || lower.contains('db ')) {
          dumbbellCount++;
        } else if (lower.contains('barbell') || lower.contains('bb ')) {
          barbellCount++;
        } else if (lower.contains('cable') || lower.contains('machine')) {
          cableMachineCount++;
        } else if (lower.contains('pull-up') ||
            lower.contains('push-up') ||
            lower.contains('bodyweight') ||
            lower.contains('dip')) {
          bodyweightCount++;
        }
      }
    }

    // 3. Determine Learned Equipment & Training Style Preferences
    String learnedEquipment = 'All Equipment';
    String learnedStyle = baseProfile?.trainingStyle ?? 'Hypertrophy';

    if (dumbbellCount >= 10 && dumbbellCount > (barbellCount * 1.5)) {
      learnedEquipment = 'Dumbbells';
      learnedStyle = 'Dumbbell-Dominant Hypertrophy';
    } else if (barbellCount >= 10 && barbellCount > (dumbbellCount * 1.5)) {
      learnedEquipment = 'Barbells';
      learnedStyle = 'Power & Strength';
    } else if (cableMachineCount >= 10 && cableMachineCount > dumbbellCount) {
      learnedEquipment = 'Cables & Machines';
      learnedStyle = 'Machine & Cable Hypertrophy';
    } else if (bodyweightCount >= 10 && bodyweightCount > dumbbellCount) {
      learnedEquipment = 'Calisthenics & Bodyweight';
      learnedStyle = 'Functional Calisthenics';
    }

    // 4. Calculate Progressive Overload Notes from History
    final keyLifts = [
      'Bench Press',
      'Incline Dumbbell Press',
      'Squat',
      'Deadlift',
      'Barbell Row',
      'Overhead Press',
    ];
    for (final lift in keyLifts) {
      final overload = calculateNextOverload(
        exerciseName: lift,
        history: history,
        memoryEvents: memoryEvents,
      );
      if (overload != null) {
        progressiveOverloadNotes[lift] = overload.recommendedWeight;
      }
    }

    return TrainingPreferenceProfile(
      preferredExercises: preferredExercises.toList(),
      avoidedExercises: avoidedExercises.toList(),
      favoriteMuscleGroups:
          baseProfile?.preferredFoods ?? ['Chest', 'Back', 'Legs'],
      preferredWorkoutDurationMinutes:
          baseProfile?.preferredWorkoutDurationMinutes ?? 45,
      preferredTrainingStyle: learnedStyle,
      averageIntensity: 'RPE 8',
      preferredRepRanges: '8-12',
      equipmentPreference: learnedEquipment,
      exerciseCompletionStats: completionStats,
      exerciseSkipStats: skipStats,
      workoutSplitCompletionStats: splitCompletions,
      workoutSplitSkipStats: splitSkips,
      progressiveOverloadNotes: progressiveOverloadNotes,
      difficultyRatings: difficultyRatings,
    );
  }

  /// Evaluates and scores an individual candidate exercise using multi-variable weighting.
  ExerciseRecommendationScore scoreExercise({
    required Exercise exercise,
    required TrainingPreferenceProfile profile,
    required FitnessContext context,
    String? focus,
  }) {
    final exName = exercise.name;
    final nameLower = exName.toLowerCase().trim();
    final reasons = <String>[];

    // 1. Check Avoided / Disliked Constraint
    if (profile.isExerciseAvoided(exName)) {
      return ExerciseRecommendationScore(
        exerciseName: exName,
        preferenceMatch: 0,
        performanceHistory: 0,
        goalAlignment: 0,
        recoveryCompatibility: 0,
        equipmentAvailability: 0,
        totalScore: 0,
        reasons: ['✗ Marked as avoided in athlete preferences.'],
        alternativeSuggestion: findSmartAlternative(exercise, profile)?.name,
      );
    }

    // 2. Preference Match (0 to 30)
    int preferenceScore = 15;
    if (profile.isExercisePreferred(exName)) {
      preferenceScore = 30;
      reasons.add('✓ Marked as favorite exercise.');
    } else if (profile.equipmentPreference == 'Dumbbells' &&
        nameLower.contains('dumbbell')) {
      preferenceScore += 10;
      reasons.add('✓ Matches learned dumbbell preference.');
    }

    // 3. Performance History (0 to 25)
    int performanceScore = 10;
    final completions = profile.exerciseCompletionStats[exName] ?? 0;
    if (completions >= 10) {
      performanceScore = 25;
      reasons.add('✓ Completed successfully $completions times.');
    } else if (completions >= 3) {
      performanceScore = 20;
      reasons.add('✓ Proven consistency in previous sessions.');
    }

    // 4. Goal Alignment (0 to 20)
    int goalScore = 15;
    final goal = context.userGoal?.goalType.name ?? 'hypertrophy';
    if (goal.contains('muscle') || goal.contains('hypertrophy')) {
      if (exercise.type == ExerciseType.strength ||
          exercise.category.toLowerCase().contains('strength') ||
          exercise.category.toLowerCase().contains('hypertrophy')) {
        goalScore = 20;
        reasons.add('✓ Aligned with muscle hypertrophy goal.');
      }
    } else if (goal.contains('strength')) {
      if (exercise.isCompound) {
        goalScore = 20;
        reasons.add('✓ Primary compound movement for maximum strength.');
      }
    }

    // 5. Recovery Compatibility (0 to 15)
    int recoveryScore = 10;
    // Only a recorded readiness changes this score and its wording. With no
    // recovery data the exercise gets the neutral 10 and no claim is made.
    final int? readiness =
        context.recoveryBreakdown?.totalScore ??
        ((context.recoveryState?.isMeasured ?? false)
            ? context.recoveryState!.recoveryScore
            : null);
    if (readiness == null) {
      recoveryScore = 10;
    } else if (readiness >= 75) {
      recoveryScore = 15;
      reasons.add('✓ Recovery readiness ($readiness%) supports full loading.');
    } else {
      recoveryScore = 8;
      reasons.add('✓ Recovery score is moderate; manage working intensity.');
    }

    // 6. Equipment Availability (0 to 10)
    int equipmentScore = 10;
    final availableEq = context.availableEquipmentNames
        .map((e) => e.toLowerCase().trim())
        .toSet();
    if (availableEq.isNotEmpty &&
        !availableEq.contains(exercise.equipment.toLowerCase().trim())) {
      equipmentScore = 0;
    }

    final total =
        (preferenceScore +
                performanceScore +
                goalScore +
                recoveryScore +
                equipmentScore)
            .clamp(0, 100);

    return ExerciseRecommendationScore(
      exerciseName: exName,
      preferenceMatch: preferenceScore,
      performanceHistory: performanceScore,
      goalAlignment: goalScore,
      recoveryCompatibility: recoveryScore,
      equipmentAvailability: equipmentScore,
      totalScore: total,
      reasons: reasons,
    );
  }

  /// Calculates progressive overload recommendation for a given lift.
  ProgressiveOverloadRecommendation? calculateNextOverload({
    required String exerciseName,
    required List<WorkoutHistory> history,
    List<MemoryEvent>? memoryEvents,
  }) {
    final nameLower = exerciseName.toLowerCase().trim();

    // Find previous performance events or records
    double lastWeight = 0.0;
    int completedReps = 8;

    if (memoryEvents != null) {
      for (final evt in memoryEvents.reversed) {
        if (evt.target.toLowerCase().contains(nameLower) &&
            evt.notes != null &&
            evt.notes!.contains('peak')) {
          final match = RegExp(r'peak\s*([0-9.]+)\s*kg').firstMatch(evt.notes!);
          if (match != null) {
            lastWeight = double.tryParse(match.group(1)!) ?? 0.0;
            break;
          }
        }
      }
    }

    // Fallback benchmark if not recorded in memory
    if (lastWeight == 0.0) {
      if (nameLower.contains('bench press')) {
        lastWeight = 85.0;
      } else if (nameLower.contains('squat')) {
        lastWeight = 100.0;
      } else if (nameLower.contains('deadlift')) {
        lastWeight = 120.0;
      } else {
        lastWeight = 24.0;
      }
    }

    final isLowerBody =
        nameLower.contains('squat') ||
        nameLower.contains('deadlift') ||
        nameLower.contains('leg press');
    final increment = isLowerBody ? 5.0 : 2.5;
    final nextWeight = lastWeight + increment;

    return ProgressiveOverloadRecommendation(
      exerciseName: exerciseName,
      currentWorkingWeight: lastWeight,
      recommendedWeight: nextWeight,
      recommendedSets: 3,
      recommendedReps: completedReps,
      rationale:
          'Hit target rep ceiling consistently in previous sessions (+${increment.toStringAsFixed(1)}kg progressive overload).',
    );
  }

  /// Detects patterns in skipped workouts and generates actionable adjustments.
  SkippedWorkoutInsight detectSkippedPatterns({
    required List<WorkoutHistory> history,
    required List<MemoryEvent> memoryEvents,
  }) {
    int legSkips = 0;
    int pushSkips = 0;
    int pullSkips = 0;

    for (final evt in memoryEvents) {
      if (evt.type == MemoryEventType.workoutSkipped) {
        final target = evt.target.toLowerCase();
        if (target.contains('leg')) legSkips++;
        if (target.contains('push')) pushSkips++;
        if (target.contains('pull')) pullSkips++;
      }
    }

    if (legSkips >= 3) {
      return SkippedWorkoutInsight(
        splitName: 'Leg Day',
        skipCount: legSkips,
        recommendation:
            'Leg sessions are frequently skipped ($legSkips times). Would you prefer shorter 30-minute sessions or higher frequency split?',
        requiresAdjustment: true,
      );
    }

    if (pushSkips >= 3) {
      return SkippedWorkoutInsight(
        splitName: 'Push Day',
        skipCount: pushSkips,
        recommendation:
            'Push sessions were skipped $pushSkips times. Recommend reducing volume to 3 exercises.',
        requiresAdjustment: true,
      );
    }

    if (pullSkips >= 3) {
      return SkippedWorkoutInsight(
        splitName: 'Pull Day',
        skipCount: pullSkips,
        recommendation:
            'Pull sessions were skipped $pullSkips times. Recommend swapping heavy deadlifts for chest-supported rows.',
        requiresAdjustment: true,
      );
    }

    return const SkippedWorkoutInsight(
      splitName: 'None',
      skipCount: 0,
      recommendation: 'Workout consistency is optimal.',
      requiresAdjustment: false,
    );
  }

  /// Finds the best available alternative exercise targeting the same muscle group
  /// when a primary exercise is avoided or unavailable.
  Exercise? findSmartAlternative(
    Exercise avoidedExercise,
    TrainingPreferenceProfile profile,
  ) {
    final all = Exercise.defaultRegistry();

    // 1. Check explicit alternatives from the Exercise model first
    if (avoidedExercise.alternatives.isNotEmpty) {
      final altIds = avoidedExercise.alternatives
          .map((a) => a.toLowerCase().trim())
          .toSet();
      final availableAlt = all.where((ex) {
        if (!altIds.contains(ex.id.toLowerCase().trim()) &&
            !altIds.contains(ex.name.toLowerCase().trim())) {
          return false;
        }
        if (profile.isExerciseAvoided(ex.name) ||
            profile.isExerciseAvoided(ex.id)) {
          return false;
        }
        return true;
      }).toList();

      if (availableAlt.isNotEmpty) {
        // If user prefers dumbbells, look for dumbbell alternative first
        if (profile.equipmentPreference == 'Dumbbells') {
          final dbAlt = availableAlt
              .where((a) => a.equipment.toLowerCase().contains('dumbbell'))
              .toList();
          if (dbAlt.isNotEmpty) return dbAlt.first;
        }
        return availableAlt.first;
      }
    }
    final targetCategory = avoidedExercise.category.toLowerCase();
    final targetMuscles = avoidedExercise.primaryMuscles
        .map((m) => m.toLowerCase().trim())
        .toSet();
    final targetMg = avoidedExercise.muscleGroup.toLowerCase().trim();

    final candidates = all.where((ex) {
      if (ex.name.toLowerCase() == avoidedExercise.name.toLowerCase() ||
          ex.id == avoidedExercise.id) {
        return false;
      }
      if (profile.isExerciseAvoided(ex.name) ||
          profile.isExerciseAvoided(ex.id)) {
        return false;
      }

      // Match by category
      if (targetCategory.isNotEmpty &&
          targetCategory != 'strength' &&
          ex.category.toLowerCase() == targetCategory) {
        return true;
      }

      // Match by primary muscle overlap
      if (ex.primaryMuscles.any(
        (m) => targetMuscles.contains(m.toLowerCase().trim()),
      )) {
        return true;
      }

      // Match by muscle group text overlap
      if (targetMg.isNotEmpty &&
          (ex.muscleGroup.toLowerCase().contains(targetMg) ||
              targetMg.contains(ex.muscleGroup.toLowerCase()))) {
        return true;
      }

      return false;
    }).toList();

    if (candidates.isEmpty) return null;

    // Prefer exercises that are explicitly preferred by user
    for (final c in candidates) {
      if (profile.isExercisePreferred(c.name)) return c;
    }

    // Prefer matching equipment preference
    if (profile.equipmentPreference == 'Dumbbells') {
      final dbMatch = candidates
          .where((c) => c.equipment.toLowerCase().contains('dumbbell'))
          .toList();
      if (dbMatch.isNotEmpty) return dbMatch.first;
    }

    return candidates.first;
  }
}
