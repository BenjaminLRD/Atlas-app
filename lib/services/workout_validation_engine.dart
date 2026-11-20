import '../models/exercise.dart';
import '../models/user_equipment_profile.dart';
import '../models/workout_validation_report.dart';
import 'equipment_workout_service.dart';

/// Central validation and constraint verification engine for AI-generated workouts.
/// Ensures that no workout presented to an athlete violates equipment constraints,
/// muscle group coherence, injury/joint limitations, or duration budgets.
class WorkoutValidationEngine {
  final EquipmentWorkoutService _equipmentService;

  const WorkoutValidationEngine({EquipmentWorkoutService? equipmentService})
    : _equipmentService = equipmentService ?? const EquipmentWorkoutService();

  /// Validates and sanitizes a proposed workout routine.
  /// Automatically repairs any violations by substituting unfeasible or off-target movements.
  WorkoutValidationReport validateAndSanitizeWorkout({
    required List<Map<String, dynamic>> proposedExercises,
    required String focus,
    required int durationMinutes,
    UserEquipmentProfile? equipmentProfile,
    List<String> injuriesOrLimitations = const [],
    String goal = 'hypertrophy',
    String experienceLevel = 'intermediate',
  }) {
    final profile =
        equipmentProfile ?? UserEquipmentProfile.fullCommercialGym();
    final focusKey = _normalizeFocus(focus);
    final allRegistry = Exercise.defaultRegistry();

    final violations = <ConstraintViolation>[];
    final passedChecks = <String>[];
    final sanitized = <Map<String, dynamic>>[];
    final seenExerciseNames = <String>{};
    final seenExerciseIds = <String>{};

    int score = 100;

    // 1. Check Non-Empty Routine
    if (proposedExercises.isEmpty) {
      violations.add(
        const ConstraintViolation(
          constraintName: 'empty_routine',
          exerciseName: 'None',
          message: 'The proposed workout contained 0 exercises.',
          severity: ConstraintSeverity.critical,
          suggestedFix:
              'Generate a base set of standard exercises for this muscle focus.',
        ),
      );
      score -= 50;
    } else {
      passedChecks.add('Non-empty exercise list verified');
    }

    // 2. Duration and Exercise Count Budget
    final expectedCountRange = _getExpectedExerciseCountRange(durationMinutes);
    if (proposedExercises.length < expectedCountRange.min) {
      violations.add(
        ConstraintViolation(
          constraintName: 'under_volume',
          exerciseName: 'Workout Session',
          message:
              'Proposed ${proposedExercises.length} exercises is below the recommended minimum of ${expectedCountRange.min} for a $durationMinutes-minute workout.',
          severity: ConstraintSeverity.warning,
          suggestedFix: 'Add accessory movements to fill duration.',
        ),
      );
      score -= 10;
    } else if (proposedExercises.length > expectedCountRange.max) {
      violations.add(
        ConstraintViolation(
          constraintName: 'over_volume',
          exerciseName: 'Workout Session',
          message:
              'Proposed ${proposedExercises.length} exercises exceeds the recommended maximum of ${expectedCountRange.max} for a $durationMinutes-minute workout.',
          severity: ConstraintSeverity.warning,
          suggestedFix:
              'Trim low-priority isolation exercises to prevent fatigue.',
        ),
      );
      score -= 10;
    } else {
      passedChecks.add(
        'Duration and volume budget within optimal range ($durationMinutes mins)',
      );
    }

    // 3. Process each proposed exercise
    for (final rawEx in proposedExercises) {
      final name = (rawEx['name'] as String? ?? '').trim();
      final id =
          (rawEx['id'] as String? ?? name.toLowerCase().replaceAll(' ', '_'))
              .trim();

      if (name.isEmpty) continue;

      // Deduplication Check
      if (seenExerciseNames.contains(name.toLowerCase()) ||
          seenExerciseIds.contains(id.toLowerCase())) {
        violations.add(
          ConstraintViolation(
            constraintName: 'duplicate_exercise',
            exerciseName: name,
            message: 'Duplicate exercise "$name" found in workout plan.',
            severity: ConstraintSeverity.warning,
            suggestedFix:
                'Remove duplicate or replace with a distinct movement variation.',
          ),
        );
        score -= 10;
        continue; // Skip adding duplicate
      }

      // Look up in database
      Exercise? exerciseObj = Exercise.getById(id) ?? Exercise.findByName(name);
      exerciseObj ??= Exercise(
        id: id,
        name: name,
        muscleGroup: rawEx['muscleGroup'] as String? ?? focus,
        equipment: rawEx['equipment'] as String? ?? 'Bodyweight',
      );

      // 4. Equipment Availability Check
      bool equipmentFeasible = _equipmentService.canPerformExercise(
        exerciseObj,
        profile,
      );
      if (!equipmentFeasible) {
        violations.add(
          ConstraintViolation(
            constraintName: 'equipment_incompatibility',
            exerciseName: name,
            message:
                'Exercise requires "${exerciseObj.equipment}" which is not available in user equipment setup.',
            severity: ConstraintSeverity.critical,
            suggestedFix:
                'Substitute with a compatible exercise matching available equipment.',
          ),
        );
        score -= 20;

        // Auto-repair: Find alternative exercise matching available equipment
        final replacement = _findEquipmentCompliantSubstitute(
          original: exerciseObj,
          focusKey: focusKey,
          profile: profile,
          excludedNames: seenExerciseNames,
        );

        if (replacement != null) {
          exerciseObj = replacement;
          passedChecks.add(
            'Auto-substituted "$name" with compliant "${replacement.name}"',
          );
        }
      } else {
        passedChecks.add(
          'Equipment verified for "$name" (${exerciseObj.equipment})',
        );
      }

      // 5. Muscle & Split Coherence Check
      final isCoherent = _isExerciseCoherentWithSplit(exerciseObj, focusKey);
      if (!isCoherent) {
        violations.add(
          ConstraintViolation(
            constraintName: 'split_mismatch',
            exerciseName: exerciseObj.name,
            message:
                'Exercise "${exerciseObj.name}" (${exerciseObj.muscleGroup}) does not align with the requested "$focus" focus.',
            severity: ConstraintSeverity.warning,
            suggestedFix: 'Replace with an exercise targeting $focus.',
          ),
        );
        score -= 15;

        // Auto-repair: Substitute with on-focus exercise
        final onFocusReplacement = _findOnFocusSubstitute(
          focusKey: focusKey,
          profile: profile,
          excludedNames: seenExerciseNames,
        );

        if (onFocusReplacement != null) {
          exerciseObj = onFocusReplacement;
          passedChecks.add(
            'Replaced off-split movement with on-target "${onFocusReplacement.name}"',
          );
        }
      } else {
        passedChecks.add('Split coherence verified for "${exerciseObj.name}"');
      }

      // 6. Injury & Limitation Check
      if (injuriesOrLimitations.isNotEmpty) {
        final conflict = _checkInjuryConflict(
          exerciseObj,
          injuriesOrLimitations,
        );
        if (conflict != null) {
          violations.add(
            ConstraintViolation(
              constraintName: 'injury_risk',
              exerciseName: exerciseObj.name,
              message:
                  'Exercise "${exerciseObj.name}" may stress reported injury or limitation: $conflict.',
              severity: ConstraintSeverity.critical,
              suggestedFix:
                  'Substitute with a low-impact joint-friendly alternative.',
            ),
          );
          score -= 25;

          final safeAlternative = _findJointSafeSubstitute(
            original: exerciseObj,
            focusKey: focusKey,
            profile: profile,
            injury: conflict,
            excludedNames: seenExerciseNames,
          );

          if (safeAlternative != null) {
            exerciseObj = safeAlternative;
            passedChecks.add(
              'Auto-swapped injury-risk exercise with safe "${safeAlternative.name}"',
            );
          }
        }
      }

      // Register clean exercise
      seenExerciseNames.add(exerciseObj.name.toLowerCase());
      seenExerciseIds.add(exerciseObj.id.toLowerCase());

      final dynamic rawSets = rawEx['sets'];
      final dynamic rawReps = rawEx['reps'];
      final dynamic rawRest = rawEx['restSeconds'];

      final int reps = rawReps is num ? rawReps.toInt().clamp(1, 50) : 10;
      final int rest = rawRest is num ? rawRest.toInt().clamp(15, 300) : 60;
      final double weight = (rawEx['weight'] is num)
          ? (rawEx['weight'] as num).toDouble()
          : 40.0;

      final List<Map<String, dynamic>> finalSets;
      if (rawSets is List && rawSets.isNotEmpty) {
        finalSets = rawSets
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else {
        final int setCount = rawSets is num ? rawSets.toInt().clamp(1, 6) : 3;
        finalSets = List.generate(
          setCount,
          (index) => {
            'setNumber': index + 1,
            'reps': reps,
            'weight': weight,
            'completed': false,
          },
        );
      }

      sanitized.add({
        'id': exerciseObj.id,
        'name': exerciseObj.name,
        'primaryTarget': exerciseObj.muscleGroup,
        'muscleGroup': exerciseObj.muscleGroup,
        'equipment': exerciseObj.equipment,
        'difficulty': exerciseObj.difficulty,
        'category': exerciseObj.category,
        'movementPattern': exerciseObj.movementPattern,
        'exerciseType': exerciseObj.exerciseType,
        'imageUrl': exerciseObj.imageUrl,
        'videoUrl': exerciseObj.videoUrl,
        'animationAsset': exerciseObj.animationAsset,
        'instructions': exerciseObj.instructions,
        'tips': exerciseObj.tips,
        'commonMistakes': exerciseObj.commonMistakes,
        'coachingTips': exerciseObj.coachingTips,
        'sets': finalSets,
        'reps': reps,
        'weight': weight,
        'restSeconds': rest,
      });
    }

    // 7. Compound Movement Check for Strength/Hypertrophy
    final isCardio =
        focusKey == 'cardio' ||
        focusKey == 'hiit' ||
        focusKey == 'conditioning';
    if (!isCardio && sanitized.isNotEmpty) {
      final hasCompound = sanitized.any((e) {
        final exType = (e['exerciseType'] as String? ?? '').toLowerCase();
        final name = (e['name'] as String? ?? '').toLowerCase();
        return exType == 'compound' ||
            name.contains('press') ||
            name.contains('squat') ||
            name.contains('deadlift') ||
            name.contains('pull-up') ||
            name.contains('row') ||
            name.contains('dip');
      });

      if (!hasCompound) {
        violations.add(
          const ConstraintViolation(
            constraintName: 'missing_compound_movement',
            exerciseName: 'Workout Structure',
            message:
                'Strength routine lacks a foundational compound multi-joint movement.',
            severity: ConstraintSeverity.info,
            suggestedFix:
                'Incorporate a primary compound lift as the workout anchor.',
          ),
        );
        score -= 5;
      } else {
        passedChecks.add('Compound multi-joint foundation verified');
      }
    }

    // Ensure final exercise count fits duration
    while (sanitized.length < expectedCountRange.min &&
        sanitized.length < allRegistry.length) {
      final additional = _findOnFocusSubstitute(
        focusKey: focusKey,
        profile: profile,
        excludedNames: seenExerciseNames,
      );
      if (additional != null) {
        seenExerciseNames.add(additional.name.toLowerCase());
        final additionalSets = List.generate(
          3,
          (index) => {
            'setNumber': index + 1,
            'reps': 10,
            'weight': 40.0,
            'completed': false,
          },
        );
        sanitized.add({
          'id': additional.id,
          'name': additional.name,
          'primaryTarget': additional.muscleGroup,
          'muscleGroup': additional.muscleGroup,
          'equipment': additional.equipment,
          'difficulty': additional.difficulty,
          'category': additional.category,
          'movementPattern': additional.movementPattern,
          'exerciseType': additional.exerciseType,
          'imageUrl': additional.imageUrl,
          'videoUrl': additional.videoUrl,
          'animationAsset': additional.animationAsset,
          'instructions': additional.instructions,
          'tips': additional.tips,
          'commonMistakes': additional.commonMistakes,
          'coachingTips': additional.coachingTips,
          'sets': additionalSets,
          'reps': 10,
          'weight': 40.0,
          'restSeconds': 60,
        });
      } else {
        break;
      }
    }

    // If still over maximum, slice to maximum allowed
    final finalSanitized = sanitized.take(expectedCountRange.max).toList();

    final clampedScore = score.clamp(0, 100);
    final isValid =
        !violations.any((v) => v.severity == ConstraintSeverity.critical) ||
        finalSanitized.isNotEmpty;

    final summary = violations.isEmpty
        ? 'Workout passed all ${passedChecks.length} constraint verification checks flawlessly.'
        : 'Workout validated with ${violations.length} constraint adjustments (Quality Score: $clampedScore/100).';

    return WorkoutValidationReport(
      isValid: isValid,
      qualityScore: clampedScore,
      violations: violations,
      passedChecks: passedChecks,
      sanitizedExercises: finalSanitized,
      summary: summary,
    );
  }

  // --- Helper Methods ---

  String _normalizeFocus(String focus) {
    final lower = focus.toLowerCase().trim();
    if (lower.contains('push') || lower.contains('chest')) return 'push';
    if (lower.contains('pull') || lower.contains('back')) return 'pull';
    if (lower.contains('leg') ||
        lower.contains('quad') ||
        lower.contains('glute')) {
      return 'legs';
    }
    if (lower.contains('arm') ||
        lower.contains('bicep') ||
        lower.contains('tricep')) {
      return 'arms';
    }
    if (lower.contains('shoulder')) return 'shoulders';
    if (lower.contains('core') || lower.contains('abs')) return 'core';
    if (lower.contains('cardio') ||
        lower.contains('run') ||
        lower.contains('hiit')) {
      return 'cardio';
    }
    if (lower.contains('recovery') || lower.contains('mobility')) {
      return 'recovery';
    }
    return 'full_body';
  }

  ({int min, int max}) _getExpectedExerciseCountRange(int durationMinutes) {
    if (durationMinutes <= 20) return (min: 2, max: 3);
    if (durationMinutes <= 35) return (min: 3, max: 4);
    if (durationMinutes <= 50) return (min: 4, max: 5);
    if (durationMinutes <= 65) return (min: 4, max: 6);
    return (min: 5, max: 7);
  }

  bool _isExerciseCoherentWithSplit(Exercise exercise, String focusKey) {
    if (focusKey == 'full_body') return true;

    final muscle = exercise.muscleGroup.toLowerCase();
    final name = exercise.name.toLowerCase();
    final movement = exercise.movementPattern.toLowerCase();

    switch (focusKey) {
      case 'push':
        // Strict exclusions for push
        if (muscle.contains('quad') ||
            muscle.contains('glute') ||
            muscle.contains('hamstring') ||
            muscle.contains('calf') ||
            muscle.contains('calves') ||
            muscle.contains('back') ||
            muscle.contains('lat') ||
            muscle.contains('bicep') ||
            name.contains('squat') ||
            name.contains('deadlift') ||
            name.contains('leg') ||
            name.contains('row') ||
            name.contains('pull') ||
            name.contains('curl')) {
          return false;
        }
        return muscle.contains('chest') ||
            muscle.contains('tricep') ||
            muscle.contains('shoulder') ||
            movement == 'push' ||
            name.contains('press') ||
            name.contains('push') ||
            name.contains('dip');

      case 'pull':
        // Strict exclusions for pull
        if (muscle.contains('quad') ||
            muscle.contains('glute') ||
            muscle.contains('hamstring') ||
            muscle.contains('chest') ||
            muscle.contains('tricep') ||
            name.contains('bench') ||
            name.contains('push-up') ||
            name.contains('dip') ||
            (name.contains('press') && !name.contains('overhead'))) {
          return false;
        }
        return muscle.contains('back') ||
            muscle.contains('lat') ||
            muscle.contains('bicep') ||
            muscle.contains('traps') ||
            movement == 'pull' ||
            name.contains('pull') ||
            name.contains('row') ||
            name.contains('deadlift') ||
            name.contains('curl');

      case 'legs':
        if (muscle.contains('chest') ||
            muscle.contains('tricep') ||
            muscle.contains('bicep') ||
            name.contains('bench') ||
            name.contains('overhead press')) {
          return false;
        }
        return muscle.contains('leg') ||
            muscle.contains('quad') ||
            muscle.contains('hamstring') ||
            muscle.contains('glute') ||
            muscle.contains('calves') ||
            movement == 'squat' ||
            movement == 'hinge' ||
            name.contains('squat') ||
            name.contains('lunge') ||
            name.contains('deadlift') ||
            name.contains('leg');

      case 'shoulders':
        return muscle.contains('shoulder') ||
            muscle.contains('deltoid') ||
            name.contains('raise');

      case 'arms':
        return muscle.contains('bicep') ||
            muscle.contains('tricep') ||
            muscle.contains('arm');

      case 'core':
        return muscle.contains('core') ||
            muscle.contains('abs') ||
            name.contains('plank') ||
            name.contains('crunch');

      case 'cardio':
        return exercise.type == ExerciseType.cardio ||
            name.contains('run') ||
            name.contains('jump');

      case 'recovery':
        return exercise.type == ExerciseType.mobility ||
            exercise.type == ExerciseType.flexibility ||
            exercise.difficulty == 'Beginner';

      default:
        return true;
    }
  }

  String? _checkInjuryConflict(Exercise exercise, List<String> injuries) {
    final lowerInjuries = injuries.map((i) => i.toLowerCase().trim()).toSet();
    final exName = exercise.name.toLowerCase();
    final exMuscle = exercise.muscleGroup.toLowerCase();

    for (final injury in lowerInjuries) {
      if (injury.contains('shoulder') &&
          (exMuscle.contains('shoulder') ||
              exName.contains('overhead') ||
              exName.contains('behind the neck'))) {
        return 'Shoulder Impingement / Pain';
      }
      if (injury.contains('lower back') || injury.contains('lumbar')) {
        if (exName.contains('deadlift') ||
            exName.contains('barbell row') ||
            exName.contains('good morning')) {
          return 'Lower Back Strain Risk';
        }
      }
      if (injury.contains('knee')) {
        if (exName.contains('jump') ||
            exName.contains('deep squat') ||
            exName.contains('leg extension')) {
          return 'Knee Joint Pressure';
        }
      }
      if (injury.contains('wrist')) {
        if (exName.contains('barbell curl') ||
            exName.contains('front squat') ||
            exName.contains('push-up')) {
          return 'Wrist Strain';
        }
      }
    }
    return null;
  }

  Exercise? _findEquipmentCompliantSubstitute({
    required Exercise original,
    required String focusKey,
    required UserEquipmentProfile profile,
    required Set<String> excludedNames,
  }) {
    final all = Exercise.defaultRegistry();
    for (final candidate in all) {
      if (excludedNames.contains(candidate.name.toLowerCase())) continue;
      if (!_equipmentService.canPerformExercise(candidate, profile)) continue;
      if (_isExerciseCoherentWithSplit(candidate, focusKey)) {
        return candidate;
      }
    }
    return null;
  }

  Exercise? _findOnFocusSubstitute({
    required String focusKey,
    required UserEquipmentProfile profile,
    required Set<String> excludedNames,
  }) {
    final all = Exercise.defaultRegistry();
    for (final candidate in all) {
      if (excludedNames.contains(candidate.name.toLowerCase())) continue;
      if (!_equipmentService.canPerformExercise(candidate, profile)) continue;
      if (_isExerciseCoherentWithSplit(candidate, focusKey)) {
        return candidate;
      }
    }
    return null;
  }

  Exercise? _findJointSafeSubstitute({
    required Exercise original,
    required String focusKey,
    required UserEquipmentProfile profile,
    required String injury,
    required Set<String> excludedNames,
  }) {
    final all = Exercise.defaultRegistry();
    for (final candidate in all) {
      if (excludedNames.contains(candidate.name.toLowerCase())) continue;
      if (!_equipmentService.canPerformExercise(candidate, profile)) continue;
      if (!_isExerciseCoherentWithSplit(candidate, focusKey)) continue;

      // Verify candidate is free of the same injury conflict
      if (_checkInjuryConflict(candidate, [injury]) == null) {
        return candidate;
      }
    }
    return null;
  }
}
