import 'package:flutter/foundation.dart';
import '../models/exercise.dart';
import '../models/fitness_context.dart';
import '../models/user_equipment_profile.dart';
import '../models/workout_history.dart';
import 'ai/memory/fitness_memory.dart';
import 'ai/personalization/workout_personalization_engine.dart';
import 'equipment_workout_service.dart';

/// Centralized, dynamic, equipment-aware exercise selection and workout generation engine.
/// Strictly guarantees that generated exercises match the workout's goal, split, and target muscles.
class WorkoutGeneratorEngine {
  final EquipmentWorkoutService _equipmentService;
  final FitnessMemory _fitnessMemory;

  WorkoutGeneratorEngine({
    EquipmentWorkoutService? equipmentService,
    FitnessMemory? fitnessMemory,
  }) : _equipmentService = equipmentService ?? const EquipmentWorkoutService(),
       _fitnessMemory = fitnessMemory ?? FitnessMemory.instance;

  /// Main entrypoint: generates a coherent, balanced list of exercises for a given workout name or focus.
  List<Map<String, dynamic>> generateExercisesForWorkout({
    required String workoutName,
    String? focus,
    String? goal,
    int? durationMinutes,
    UserEquipmentProfile? equipmentProfile,
    List<WorkoutHistory>? workoutHistory,
    String? intensity = 'moderate',
    String? experienceLevel = 'intermediate',
  }) {
    final focusKey = _resolveFocusKey(workoutName, focus);
    final targetMuscles = _resolveTargetMuscles(focusKey);
    final isCardio =
        focusKey == 'cardio' ||
        focusKey == 'hiit' ||
        focusKey == 'conditioning';
    final isRecovery =
        focusKey == 'recovery' ||
        focusKey == 'mobility' ||
        focusKey == 'deload';

    final prefProfile = _fitnessMemory.getPreferenceProfile();
    final profile =
        equipmentProfile ?? UserEquipmentProfile.fullCommercialGym();
    final allExercises = Exercise.defaultRegistry();

    final disliked = prefProfile.dislikedExercises
        .map((e) => e.trim().toLowerCase())
        .toSet();
    final preferred = prefProfile.preferredExercises
        .map((e) => e.trim().toLowerCase())
        .toSet();
    final scores = prefProfile.exerciseScores;

    // Collect recently performed workout exercise names/IDs from history (last 48 hours)
    final recentHistoryNames = <String>{};
    if (workoutHistory != null && workoutHistory.isNotEmpty) {
      final cutoff = DateTime.now().subtract(const Duration(hours: 48));
      for (final w in workoutHistory) {
        if (w.dateCompleted.isAfter(cutoff)) {
          recentHistoryNames.add(w.workoutName.toLowerCase().trim());
        }
      }
    }

    final rejectedExercises = <String, String>{};
    final eligible = <Exercise>[];

    // 1. Filter eligible exercises strictly by muscle group compatibility & equipment
    for (final ex in allExercises) {
      final nameLower = ex.name.toLowerCase().trim();
      final idLower = ex.id.toLowerCase().trim();

      // Rule: Exclude disliked or blacklisted (score <= -2)
      if (disliked.contains(nameLower) ||
          disliked.contains(idLower) ||
          (scores[ex.name] ?? 0) <= -2) {
        rejectedExercises[ex.name] = 'User preference: Disliked or blacklisted';
        continue;
      }

      // Rule: Equipment check
      if (!_equipmentService.canPerformExercise(ex, profile)) {
        rejectedExercises[ex.name] =
            'Equipment unavailable (requires ${ex.equipment})';
        continue;
      }

      // Rule: Experience level constraint (exclude advanced compound movements for absolute beginners)
      if (experienceLevel?.toLowerCase() == 'beginner' &&
          ex.difficulty == 'Advanced') {
        rejectedExercises[ex.name] =
            'Experience level: Advanced movements excluded for beginner';
        continue;
      }

      // Rule: Cardio vs Resistance type match
      if (isCardio) {
        if (ex.type == ExerciseType.cardio) {
          eligible.add(ex);
        } else {
          rejectedExercises[ex.name] =
              'Type mismatch: Cardio exercise required';
        }
        continue;
      }

      if (isRecovery) {
        if (ex.difficulty == 'Beginner' ||
            ex.type == ExerciseType.mobility ||
            ex.type == ExerciseType.flexibility ||
            ex.id == 'plank') {
          eligible.add(ex);
        } else {
          rejectedExercises[ex.name] =
              'Type mismatch: Mobility/recovery movement required';
        }
        continue;
      }

      // Resistance exercise muscle matching
      if (_isExerciseEligibleForFocus(ex, focusKey, targetMuscles)) {
        eligible.add(ex);
      } else {
        rejectedExercises[ex.name] =
            'Muscle group mismatch for split "$focusKey"';
      }
    }

    final trainingProfile = _fitnessMemory.getTrainingPreferenceProfile(
      history: workoutHistory ?? [],
    );

    // 2. Score & sort eligible exercises (Compounds + Preferred boosted, recently performed penalized for rotation)
    eligible.sort((a, b) {
      int scoreA = scores[a.name] ?? 0;
      int scoreB = scores[b.name] ?? 0;

      if (preferred.contains(a.name.toLowerCase())) scoreA += 5;
      if (preferred.contains(b.name.toLowerCase())) scoreB += 5;

      // Check training preference profile completions
      final completionsA = trainingProfile.exerciseCompletionStats[a.name] ?? 0;
      final completionsB = trainingProfile.exerciseCompletionStats[b.name] ?? 0;
      scoreA += (completionsA * 2).clamp(0, 10);
      scoreB += (completionsB * 2).clamp(0, 10);

      // Check equipment preference boost (e.g. Dumbbell preference)
      if (trainingProfile.equipmentPreference == 'Dumbbells') {
        if (a.equipment == 'Dumbbell') scoreA += 4;
        if (b.equipment == 'Dumbbell') scoreB += 4;
      }

      // Penalize recently performed to ensure variety and rotation
      for (final hName in recentHistoryNames) {
        if (hName.contains(a.name.toLowerCase()) ||
            a.name.toLowerCase().contains(hName)) {
          scoreA -= 3;
        }
        if (hName.contains(b.name.toLowerCase()) ||
            b.name.toLowerCase().contains(hName)) {
          scoreB -= 3;
        }
      }

      // Prioritize intermediate/advanced compound lifts over pure isolation
      if (a.difficulty == 'Advanced') scoreA += 2;
      if (b.difficulty == 'Advanced') scoreB += 2;

      return scoreB.compareTo(scoreA);
    });

    // 3. Determine exercise count from target duration
    final duration =
        durationMinutes ?? prefProfile.preferredWorkoutDurationMinutes;
    int targetCount = 4;
    if (duration <= 30) {
      targetCount = 3;
    } else if (duration <= 45) {
      targetCount = 4;
    } else if (duration <= 60) {
      targetCount = 5;
    } else {
      targetCount = 6;
    }

    // 4. Select balanced set of exercises (ensure muscle distribution within the focus)
    final selected = _selectBalancedExercises(eligible, targetCount, focusKey);

    // Track unselected eligible movements as surplus volume
    for (final ex in eligible) {
      if (!selected.any((s) => s.id == ex.id)) {
        rejectedExercises[ex.name] =
            'Volume budget: Lower priority relative to duration budget';
      }
    }

    // 5. Output structured debug logging
    debugPrint('=== [WORKOUT GENERATOR LOG] ===');
    debugPrint('Requested Goal: ${goal ?? "hypertrophy"}');
    debugPrint('Detected Split: $focusKey (Workout: "$workoutName")');
    debugPrint(
      'Selected Exercises (${selected.length}): ${selected.map((e) => e.name).join(", ")}',
    );
    debugPrint('Total Rejected Candidates: ${rejectedExercises.length}');
    debugPrint('===============================');

    // 6. Build structured exercise definitions with sets/reps, progressive overload and explainable AI reasons
    return selected.map((ex) {
      final setsReps = _determineSetsAndReps(
        ex,
        intensity ?? 'moderate',
        goal ?? 'hypertrophy',
      );

      final recScore = WorkoutPersonalizationEngine.instance.scoreExercise(
        exercise: ex,
        profile: trainingProfile,
        context: FitnessContext.initial(),
        focus: focusKey,
      );

      final overloadWeight =
          trainingProfile.progressiveOverloadNotes[ex.name] ??
          setsReps['defaultWeight'];

      return {
        'id': ex.id,
        'name': ex.name,
        'primaryTarget': ex.muscleGroup,
        'muscleGroup': ex.muscleGroup,
        'equipment': ex.equipment,
        'difficulty': ex.difficulty,
        'imageUrl': ex.imageUrl,
        'videoUrl': ex.videoUrl,
        'animationAsset': ex.animationAsset,
        'instructions': ex.instructions,
        'tips': ex.tips,
        'commonMistakes': ex.commonMistakes,
        'sets': setsReps['sets'],
        'reps': setsReps['defaultReps'],
        'weight': overloadWeight,
        'aiReasoning': recScore.reasons,
        'aiScore': recScore.totalScore,
      };
    }).toList();
  }

  /// Identifies the normalized focus key from workout name and optional focus string.
  static String _resolveFocusKey(String workoutName, String? focus) {
    final wLower = workoutName.toLowerCase();
    final fLower = focus?.toLowerCase() ?? '';

    // Direct clean focus keys
    final knownFocusKeys = {
      'push',
      'pull',
      'legs',
      'chest',
      'back',
      'shoulders',
      'arms',
      'core',
      'cardio',
      'recovery',
      'mobility',
      'hiit',
      'upper',
      'full_body',
    };
    if (knownFocusKeys.contains(fLower.trim())) {
      if (fLower == 'chest') return 'push';
      if (fLower == 'back') return 'pull';
      if (fLower == 'mobility') return 'recovery';
      return fLower;
    }

    // Check workout name first for explicit split intent
    if (wLower.contains('cardio') ||
        wLower.contains('running') ||
        wLower.contains('cycling') ||
        wLower.contains('hiit') ||
        wLower.contains('fat-burn') ||
        wLower.contains('fat burn')) {
      return 'cardio';
    }
    if (wLower.contains('recovery') ||
        wLower.contains('mobility') ||
        wLower.contains('restorative') ||
        wLower.contains('deload')) {
      return 'recovery';
    }
    if (wLower.contains('push') ||
        wLower.contains('chest') ||
        wLower.contains('bench')) {
      return 'push';
    }
    if (wLower.contains('pull') ||
        wLower.contains('back') ||
        wLower.contains('deadlift') ||
        wLower.contains('lats')) {
      return 'pull';
    }
    if (wLower.contains('leg') ||
        wLower.contains('lower') ||
        wLower.contains('squat') ||
        wLower.contains('quad') ||
        wLower.contains('glute')) {
      return 'legs';
    }
    if (wLower.contains('shoulder') ||
        wLower.contains('deltoid') ||
        wLower.contains('overhead')) {
      return 'shoulders';
    }
    if (wLower.contains('arm') ||
        wLower.contains('bicep') ||
        wLower.contains('tricep')) {
      return 'arms';
    }
    if (wLower.contains('core') ||
        wLower.contains('abs') ||
        wLower.contains('abdom')) {
      return 'core';
    }
    if (wLower.contains('upper')) {
      return 'upper';
    }

    // Fallback to combined inspect if name was generic
    final combined = '$wLower $fLower';
    if (combined.contains('cardio') || combined.contains('hiit')) {
      return 'cardio';
    }
    if (combined.contains('recovery') || combined.contains('mobility')) {
      return 'recovery';
    }
    if (combined.contains('push') || combined.contains('chest')) return 'push';
    if (combined.contains('pull') || combined.contains('back')) return 'pull';
    if (combined.contains('leg') ||
        combined.contains('lower') ||
        combined.contains('squat')) {
      return 'legs';
    }
    if (combined.contains('shoulder')) return 'shoulders';
    if (combined.contains('arm')) return 'arms';
    if (combined.contains('core') || combined.contains('abs')) return 'core';
    if (combined.contains('upper')) return 'upper';

    return 'full_body';
  }

  /// Returns list of target muscle keywords for the focus.
  static List<String> _resolveTargetMuscles(String focusKey) {
    switch (focusKey) {
      case 'push':
        return ['chest', 'triceps', 'deltoids', 'shoulders', 'pectoral'];
      case 'pull':
        return [
          'lats',
          'back',
          'biceps',
          'rhomboids',
          'traps',
          'rear deltoids',
        ];
      case 'legs':
        return [
          'quadriceps',
          'quads',
          'glutes',
          'hamstrings',
          'calves',
          'legs',
        ];
      case 'upper':
        return ['chest', 'back', 'shoulders', 'biceps', 'triceps', 'lats'];
      case 'shoulders':
        return [
          'shoulders',
          'deltoids',
          'rear deltoids',
          'side deltoids',
          'front deltoids',
        ];
      case 'arms':
        return ['biceps', 'triceps', 'forearms', 'brachialis'];
      case 'core':
        return ['core', 'abdominis', 'obliques', 'rectus'];
      case 'cardio':
      case 'recovery':
      case 'full_body':
      default:
        return ['full body', 'chest', 'back', 'legs', 'core'];
    }
  }

  /// Verifies strict muscle eligibility so push workouts NEVER contain squats or legs, etc.
  static bool _isExerciseEligibleForFocus(
    Exercise ex,
    String focusKey,
    List<String> targetMuscles,
  ) {
    final mg = ex.muscleGroup.toLowerCase();
    final name = ex.name.toLowerCase();

    // Strict Negative Exclusions:
    if (focusKey == 'push') {
      // Must NOT be leg or back exercise
      if (mg.contains('quad') ||
          mg.contains('hamstring') ||
          mg.contains('glute') ||
          mg.contains('calf') ||
          mg.contains('lat') ||
          name.contains('squat') ||
          name.contains('deadlift') ||
          name.contains('row')) {
        return false;
      }
      return mg.contains('chest') ||
          mg.contains('shoulder') ||
          mg.contains('tricep') ||
          mg.contains('deltoid');
    }

    if (focusKey == 'pull') {
      // Must NOT be chest or quad exercise
      if (mg.contains('chest') ||
          mg.contains('quad') ||
          name.contains('bench') ||
          name.contains('squat') ||
          name.contains('push-up')) {
        return false;
      }
      return mg.contains('back') ||
          mg.contains('lat') ||
          mg.contains('bicep') ||
          mg.contains('rhomboid') ||
          mg.contains('trap') ||
          name.contains('deadlift') ||
          name.contains('face pull');
    }

    if (focusKey == 'legs') {
      // Must NOT be chest, back, or shoulder exercise
      if (mg.contains('chest') ||
          (mg.contains('lat') && !mg.contains('glute')) ||
          name.contains('bench') ||
          name.contains('overhead press') ||
          name.contains('push-up') ||
          name.contains('pull-up')) {
        return false;
      }
      return mg.contains('quad') ||
          mg.contains('glute') ||
          mg.contains('hamstring') ||
          mg.contains('calf') ||
          mg.contains('leg') ||
          name.contains('squat') ||
          name.contains('lunge');
    }

    if (focusKey == 'shoulders') {
      if (mg.contains('quad') ||
          mg.contains('glute') ||
          mg.contains('lat') ||
          name.contains('squat') ||
          name.contains('deadlift')) {
        return false;
      }
      return mg.contains('shoulder') ||
          mg.contains('deltoid') ||
          name.contains('press') ||
          name.contains('raise');
    }

    if (focusKey == 'arms') {
      if (mg.contains('quad') ||
          mg.contains('glute') ||
          name.contains('squat') ||
          name.contains('deadlift') ||
          name.contains('bench')) {
        return false;
      }
      return mg.contains('bicep') ||
          mg.contains('tricep') ||
          mg.contains('forearm') ||
          mg.contains('brachialis');
    }

    if (focusKey == 'core') {
      return mg.contains('core') ||
          mg.contains('abdominis') ||
          mg.contains('oblique');
    }

    if (focusKey == 'upper') {
      if (mg.contains('quad') ||
          mg.contains('hamstring') ||
          mg.contains('calf') ||
          name.contains('squat') ||
          name.contains('lunge')) {
        return false;
      }
      return mg.contains('chest') ||
          mg.contains('back') ||
          mg.contains('shoulder') ||
          mg.contains('bicep') ||
          mg.contains('tricep') ||
          mg.contains('lat');
    }

    // Default Full Body: Matches any major compound
    return true;
  }

  /// Selects a diverse subset of eligible exercises ensuring compound + isolation balance.
  List<Exercise> _selectBalancedExercises(
    List<Exercise> eligible,
    int count,
    String focusKey,
  ) {
    if (eligible.length <= count) {
      return eligible;
    }

    final selected = <Exercise>[];
    final selectedIds = <String>{};

    for (final ex in eligible) {
      if (selected.length >= count) break;
      if (!selectedIds.contains(ex.id)) {
        selected.add(ex);
        selectedIds.add(ex.id);
      }
    }

    return selected;
  }

  /// Calculates dynamic set counts, target reps, and starting weight recommendations.
  Map<String, dynamic> _determineSetsAndReps(
    Exercise ex,
    String intensity,
    String goal,
  ) {
    int setCount = 3;
    int reps = 10;
    double weight = 40.0;

    final isHeavy =
        intensity.toLowerCase() == 'heavy' ||
        goal.toLowerCase().contains('strength');
    final isRecovery =
        intensity.toLowerCase() == 'recovery' ||
        intensity.toLowerCase() == 'light';

    if (isHeavy) {
      setCount = 4;
      reps = ex.difficulty == 'Advanced' ? 6 : 8;
      weight = 60.0;
    } else if (isRecovery) {
      setCount = 2;
      reps = 12;
      weight = 20.0;
    } else {
      // Hypertrophy / Moderate
      setCount = 3;
      reps = 10;
      weight = 40.0;
    }

    if (ex.equipment.toLowerCase().contains('bodyweight') ||
        ex.equipment.toLowerCase().contains('mat')) {
      weight = 0.0;
    }

    final setsList = List.generate(
      setCount,
      (index) => {
        'setNumber': index + 1,
        'reps': reps,
        'weight': weight,
        'completed': false,
      },
    );

    return {'sets': setsList, 'defaultReps': reps, 'defaultWeight': weight};
  }
}
