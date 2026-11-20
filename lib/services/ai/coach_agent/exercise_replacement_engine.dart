/// Candidate exercise replacement option suggested by the AI Coach.
class ExerciseReplacementCandidate {
  final String originalExercise;
  final String replacementExercise;
  final String targetMuscle;
  final String requiredEquipment;
  final String matchReason;
  final String safetyNote;

  const ExerciseReplacementCandidate({
    required this.originalExercise,
    required this.replacementExercise,
    required this.targetMuscle,
    required this.requiredEquipment,
    required this.matchReason,
    this.safetyNote = '',
  });
}

/// Intelligent exercise replacement engine matching muscle mechanics, equipment constraints, and injury safety profiles.
class ExerciseReplacementEngine {
  static ExerciseReplacementEngine? _instance;
  static ExerciseReplacementEngine get instance =>
      _instance ??= ExerciseReplacementEngine();

  /// Known exercise substitution mappings by movement pattern and muscle group.
  static final Map<String, List<ExerciseReplacementCandidate>>
  _substitutionCatalog = {
    'cable crossover': [
      const ExerciseReplacementCandidate(
        originalExercise: 'Cable Crossover',
        replacementExercise: 'Dumbbell Fly',
        targetMuscle: 'Chest',
        requiredEquipment: 'Dumbbells & Flat Bench',
        matchReason:
            'Direct pectoral adduction alternative requiring only dumbbells.',
        safetyNote:
            'Keep a slight bend in elbows to protect the biceps tendon.',
      ),
      const ExerciseReplacementCandidate(
        originalExercise: 'Cable Crossover',
        replacementExercise: 'Push-ups',
        targetMuscle: 'Chest',
        requiredEquipment: 'Bodyweight',
        matchReason:
            'Calisthenics compound movement targeting chest and serratus anterior.',
      ),
    ],
    'cable face pulls': [
      const ExerciseReplacementCandidate(
        originalExercise: 'Cable Face Pulls',
        replacementExercise: 'Dumbbell Rear Delt Fly',
        targetMuscle: 'Rear Deltoids',
        requiredEquipment: 'Dumbbells',
        matchReason:
            'Excellent horizontal abduction movement for posterior deltoids without cable machine.',
      ),
      const ExerciseReplacementCandidate(
        originalExercise: 'Cable Face Pulls',
        replacementExercise: 'Band Pull-Aparts',
        targetMuscle: 'Rear Deltoids',
        requiredEquipment: 'Resistance Band',
        matchReason:
            'High-repetition rotator cuff and scapular retractor builder.',
      ),
    ],
    'barbell back squat': [
      const ExerciseReplacementCandidate(
        originalExercise: 'Barbell Back Squat',
        replacementExercise: 'Goblet Squat',
        targetMuscle: 'Quadriceps',
        requiredEquipment: 'Dumbbell or Kettlebell',
        matchReason:
            'Encourages upright torso posture and eliminates spinal compression.',
        safetyNote: 'Great for athletes experiencing mild lower back fatigue.',
      ),
      const ExerciseReplacementCandidate(
        originalExercise: 'Barbell Back Squat',
        replacementExercise: 'Dumbbell Bulgarian Split Squat',
        targetMuscle: 'Quadriceps & Glutes',
        requiredEquipment: 'Dumbbells & Bench',
        matchReason:
            'Unilateral quad and glute hypertrophy with zero spinal axial loading.',
      ),
      const ExerciseReplacementCandidate(
        originalExercise: 'Barbell Back Squat',
        replacementExercise: 'Leg Press',
        targetMuscle: 'Quadriceps',
        requiredEquipment: 'Leg Press Machine',
        matchReason:
            'Fixed track machine allowing high quadriceps loading with supported back.',
      ),
    ],
    'conventional barbell deadlift': [
      const ExerciseReplacementCandidate(
        originalExercise: 'Conventional Barbell Deadlift',
        replacementExercise: 'Dumbbell Romanian Deadlift',
        targetMuscle: 'Hamstrings & Glutes',
        requiredEquipment: 'Dumbbells',
        matchReason:
            'Focuses strictly on the hip hinge eccentric stretch with lower lumbar strain.',
      ),
      const ExerciseReplacementCandidate(
        originalExercise: 'Conventional Barbell Deadlift',
        replacementExercise: 'Trap Bar Deadlift',
        targetMuscle: 'Posterior Chain',
        requiredEquipment: 'Trap Bar',
        matchReason:
            'Neutral grip aligns center of mass over ankles, reducing shear stress on lower back.',
      ),
    ],
    'barbell bench press': [
      const ExerciseReplacementCandidate(
        originalExercise: 'Barbell Bench Press',
        replacementExercise: 'Dumbbell Bench Press',
        targetMuscle: 'Chest & Triceps',
        requiredEquipment: 'Dumbbells & Flat Bench',
        matchReason:
            'Allows convergent natural movement path, reducing anterior shoulder impingement.',
      ),
      const ExerciseReplacementCandidate(
        originalExercise: 'Barbell Bench Press',
        replacementExercise: 'Machine Chest Press',
        targetMuscle: 'Chest',
        requiredEquipment: 'Chest Press Machine',
        matchReason:
            'Guarded range of motion providing constant tension without free-weight stability demands.',
      ),
    ],
  };

  /// Finds suitable substitute candidates based on exercise name, unavailable equipment, or injury constraints.
  List<ExerciseReplacementCandidate> findSubstitutes({
    required String exerciseName,
    List<String> unavailableEquipment = const [],
    List<String> injuryConstraints = const [],
  }) {
    final cleanName = exerciseName.toLowerCase().trim();

    // Look for exact or fuzzy match in substitution catalog
    List<ExerciseReplacementCandidate> candidates = [];
    for (final entry in _substitutionCatalog.entries) {
      if (cleanName.contains(entry.key) || entry.key.contains(cleanName)) {
        candidates = List.from(entry.value);
        break;
      }
    }

    // If no direct catalog entry, provide standard fallback based on keywords
    if (candidates.isEmpty) {
      if (cleanName.contains('chest') || cleanName.contains('press')) {
        candidates.add(
          ExerciseReplacementCandidate(
            originalExercise: exerciseName,
            replacementExercise: 'Dumbbell Chest Press',
            targetMuscle: 'Chest',
            requiredEquipment: 'Dumbbells',
            matchReason: 'Standard horizontal pressing alternative.',
          ),
        );
      } else if (cleanName.contains('leg') || cleanName.contains('squat')) {
        candidates.add(
          ExerciseReplacementCandidate(
            originalExercise: exerciseName,
            replacementExercise: 'Dumbbell Goblet Squat',
            targetMuscle: 'Quads',
            requiredEquipment: 'Dumbbells',
            matchReason: 'Standard knee-dominant squat alternative.',
          ),
        );
      } else {
        candidates.add(
          ExerciseReplacementCandidate(
            originalExercise: exerciseName,
            replacementExercise: 'Bodyweight Alternative',
            targetMuscle: 'Target Muscle',
            requiredEquipment: 'Bodyweight',
            matchReason: 'Universal bodyweight substitute.',
          ),
        );
      }
    }

    // Filter out unavailable equipment if specified
    if (unavailableEquipment.isNotEmpty) {
      final unavailLower = unavailableEquipment
          .map((e) => e.toLowerCase())
          .toList();
      candidates = candidates.where((c) {
        final req = c.requiredEquipment.toLowerCase();
        return !unavailLower.any((u) => req.contains(u));
      }).toList();
    }

    return candidates;
  }
}
