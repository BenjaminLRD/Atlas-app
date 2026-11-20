import '../../workout_generator_engine.dart';
import '../../workout_validation_engine.dart';
import '../adaptation/adaptation_engine.dart';
import '../adaptation/training_adjustment.dart';
import '../adaptation/workout_performance_analyzer.dart';
import '../workout_intelligence_engine.dart';
import '../../../models/exercise.dart';
import '../../../models/user_equipment_profile.dart';
import '../../../data/local_storage.dart';
import '../../../data/workout_repository.dart';
import '../memory/fitness_memory.dart';
import 'ai_tool.dart';

/// AI Agent tool for generating, modifying, and saving personalized workouts.
class WorkoutTool extends AITool {
  final WorkoutRepository _workoutRepository;
  final WorkoutGeneratorEngine _generatorEngine;
  final FitnessMemory _fitnessMemory;
  final WorkoutValidationEngine _validationEngine;
  final WorkoutIntelligenceEngine _intelligenceEngine;
  final AdaptationEngine _adaptationEngine;

  WorkoutTool({
    WorkoutRepository? workoutRepository,
    WorkoutGeneratorEngine? generatorEngine,
    FitnessMemory? fitnessMemory,
    WorkoutValidationEngine? validationEngine,
    WorkoutIntelligenceEngine? intelligenceEngine,
    AdaptationEngine? adaptationEngine,
  }) : _workoutRepository = workoutRepository ?? LocalWorkoutRepository(),
       _generatorEngine = generatorEngine ?? WorkoutGeneratorEngine(),
       _fitnessMemory = fitnessMemory ?? FitnessMemory.instance,
       _validationEngine = validationEngine ?? const WorkoutValidationEngine(),
       _intelligenceEngine = intelligenceEngine ?? WorkoutIntelligenceEngine(),
       _adaptationEngine = adaptationEngine ?? AdaptationEngine();

  @override
  String get name => 'workout_tool';

  @override
  String get description =>
      'Generates custom equipment-aware workouts, modifies existing exercises/volume, analyzes completed workout telemetry, and adapts future routines.';

  @override
  Map<String, dynamic> get parametersSchema => {
    'type': 'OBJECT',
    'properties': {
      'action': {
        'type': 'STRING',
        'enum': [
          'generate_workout',
          'save_workout',
          'modify_workout',
          'analyze_performance',
        ],
        'description': 'The workout action to perform.',
      },
      'muscle_group': {
        'type': 'STRING',
        'description':
            'Target muscle group or split (e.g. "push", "pull", "legs", "chest", "full_body").',
      },
      'available_equipment': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
        'description':
            'List of available equipment items (e.g. ["dumbbells", "barbell", "bench"]).',
      },
      'duration_minutes': {
        'type': 'INTEGER',
        'description': 'Estimated workout duration in minutes (e.g. 45).',
      },
      'goal': {
        'type': 'STRING',
        'description':
            'Training goal (e.g. "muscle_gain", "fat_loss", "strength").',
      },
      'workout_name': {
        'type': 'STRING',
        'description': 'Name of the workout to save.',
      },
      'exercises': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
        'description': 'List of exercise names for the workout.',
      },
      'exercise_to_replace': {
        'type': 'STRING',
        'description':
            'Name of the exercise to replace when modifying a routine.',
      },
      'replacement_preference': {
        'type': 'STRING',
        'description':
            'Equipment or style preference for the replacement (e.g. "dumbbells only", "bodyweight").',
      },
      'performance_data': {
        'type': 'OBJECT',
        'description':
            'Execution telemetry from completed workout (sets completed, reps, weight, RPE, feedback).',
      },
      'adjustments': {
        'type': 'ARRAY',
        'description':
            'Explicit list of training adjustments to apply to generation.',
      },
      'confirmed': {
        'type': 'BOOLEAN',
        'description':
            'Explicit athlete confirmation flag for saving workouts.',
      },
    },
    'required': ['action'],
  };

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> arguments) async {
    final action = arguments['action'] as String? ?? 'generate_workout';

    switch (action) {
      case 'generate_workout':
        return _generateWorkout(arguments);
      case 'save_workout':
        return _saveWorkout(arguments);
      case 'modify_workout':
        return _modifyWorkout(arguments);
      case 'analyze_performance':
        return _analyzePerformance(arguments);
      default:
        return {'status': 'error', 'message': 'Unknown action: $action'};
    }
  }

  Future<Map<String, dynamic>> _analyzePerformance(
    Map<String, dynamic> args,
  ) async {
    final rawPerformance = args['performance_data'] as Map<String, dynamic>?;
    if (rawPerformance == null) {
      return {'status': 'error', 'message': 'performance_data is required'};
    }
    final performance = WorkoutPerformanceData.fromJson(rawPerformance);
    final adjustments = await _adaptationEngine.analyzeSession(performance);
    return {
      'status': 'success',
      'action': 'analyze_performance',
      'adjustments_count': adjustments.length,
      'adjustments': adjustments.map((a) => a.toJson()).toList(),
    };
  }

  Future<Map<String, dynamic>> _generateWorkout(
    Map<String, dynamic> args,
  ) async {
    final muscleGroup = (args['muscle_group'] as String? ?? 'full_body')
        .toLowerCase();
    final prefProfile = _fitnessMemory.getPreferenceProfile();
    final duration =
        args['duration_minutes'] as int? ??
        prefProfile.preferredWorkoutDurationMinutes;
    final goal = args['goal'] as String? ?? 'hypertrophy';
    final equipmentList =
        (args['available_equipment'] as List<dynamic>?)
            ?.map((e) => e.toString().toLowerCase())
            .toList() ??
        const [];

    final profile = equipmentList.isNotEmpty
        ? UserEquipmentProfile(
            userId: 'local_user',
            availableEquipmentIds: equipmentList,
            updatedAt: DateTime.now(),
          )
        : UserEquipmentProfile.fullCommercialGym();

    final recentHistory = _workoutRepository.getWorkoutHistory();

    final workoutTitle = '${_capitalize(muscleGroup)} Hypertrophy Session';

    // 1. Generate base candidate exercises
    final rawExercisesData = _generatorEngine.generateExercisesForWorkout(
      workoutName: workoutTitle,
      focus: muscleGroup,
      goal: goal,
      durationMinutes: duration,
      equipmentProfile: profile,
      workoutHistory: recentHistory,
    );

    // 2. Parse or extract adjustments from performance data if provided
    final explicitAdjustments = <TrainingAdjustment>[];
    if (args['performance_data'] is Map) {
      final perf = WorkoutPerformanceData.fromJson(
        Map<String, dynamic>.from(args['performance_data'] as Map),
      );
      final analyzed = await _adaptationEngine.analyzeSession(perf);
      explicitAdjustments.addAll(analyzed);
    }
    if (args['adjustments'] is List) {
      for (final adjMap in (args['adjustments'] as List)) {
        if (adjMap is Map) {
          explicitAdjustments.add(
            TrainingAdjustment.fromJson(Map<String, dynamic>.from(adjMap)),
          );
        }
      }
    }

    final adaptationResult = _adaptationEngine.applyAdaptations(
      baseExercises: rawExercisesData,
      adjustments: explicitAdjustments,
    );

    final candidateExercises = adaptationResult.adaptedExercises;

    // 3. Validate and sanitize the generated workout against all constraints
    final validationReport = _validationEngine.validateAndSanitizeWorkout(
      proposedExercises: candidateExercises,
      focus: muscleGroup,
      durationMinutes: duration,
      equipmentProfile: profile,
      goal: goal,
    );

    final exercisesData = validationReport.sanitizedExercises.isNotEmpty
        ? validationReport.sanitizedExercises
        : candidateExercises;

    // 4. Score intelligence, evaluate progression, and synthesize AI coaching explanations
    final intelligenceReport = _intelligenceEngine.evaluateWorkout(
      exercises: exercisesData,
      focus: muscleGroup,
      durationMinutes: duration,
      goal: goal,
      equipmentProfile: profile,
      workoutHistory: recentHistory,
    );

    final combinedExplanation = [
      if (adaptationResult.summary.hasAdaptations)
        adaptationResult.summary.coachExplanation,
      ...intelligenceReport.aiExplanation,
    ];

    return {
      'status': 'success',
      'action': 'generate_workout',
      'workout': {
        'title': workoutTitle,
        'focus': muscleGroup,
        'duration_minutes': duration,
        'exercises_count': exercisesData.length,
        'exercises': exercisesData,
        'validation': validationReport.toJson(),
        'intelligence': intelligenceReport.toJson(),
        'adaptation': adaptationResult.summary.toJson(),
        'ai_explanation': combinedExplanation,
      },
    };
  }

  Future<Map<String, dynamic>> _saveWorkout(Map<String, dynamic> args) async {
    final workoutName = args['workout_name'] as String? ?? 'AI Custom Workout';
    final rawExercises = args['exercises'] as List<dynamic>? ?? const [];
    final duration = args['duration_minutes'] as int? ?? 45;
    final isConfirmed = args['confirmed'] == true;

    // Safety confirmation check
    if (!isConfirmed) {
      return {
        'status': 'confirmation_required',
        'action': 'save_workout',
        'requires_confirmation': true,
        'prompt':
            'I generated the "$workoutName" workout ($duration mins, ${rawExercises.length} exercises). Would you like me to save it to your workout library?',
        'payload': {
          'workout_name': workoutName,
          'exercises': rawExercises,
          'duration_minutes': duration,
        },
      };
    }

    // Execute save after confirmation. This keeps a plan for later. Nothing
    // says the workout was done, so it is not added to the workout history and
    // earns no XP, streak or volume; no sets, reps, volume or calories are
    // made up for it.
    final exerciseNames = rawExercises.map((e) => e.toString()).toList();
    final planId =
        'ai_plan|${workoutName.toLowerCase()}|'
        '${exerciseNames.map((e) => e.toLowerCase()).join(',')}';
    await LocalStorage.saveWorkoutPlan({
      'id': planId,
      'name': workoutName,
      'exercises': exerciseNames,
      'durationMinutes': duration,
      'status': 'planned',
      'source': 'ai_coach',
      'savedAt': DateTime.now().toIso8601String(),
    });

    return {
      'status': 'success',
      'action': 'save_workout',
      'saved': true,
      'completed': false,
      'recorded_as': 'planned',
      'workout_name': workoutName,
      'message':
          'Workout "$workoutName" saved to your workout library as a plan. '
          'It is not counted as a completed workout.',
    };
  }

  Future<Map<String, dynamic>> _modifyWorkout(Map<String, dynamic> args) async {
    final toReplace = args['exercise_to_replace'] as String? ?? '';
    final preference =
        args['replacement_preference'] as String? ?? 'bodyweight';

    final allExercises = Exercise.defaultRegistry();
    final targetOriginal = Exercise.findByName(toReplace);

    final replacements = allExercises
        .where((ex) {
          if (toReplace.isNotEmpty &&
              ex.name.toLowerCase() == toReplace.toLowerCase()) {
            return false;
          }
          // If we know original muscle group, match the same muscle group!
          if (targetOriginal != null) {
            final originalMuscle = targetOriginal.muscleGroup.toLowerCase();
            final candidateMuscle = ex.muscleGroup.toLowerCase();
            final matchesMuscle =
                candidateMuscle.contains(
                  originalMuscle.split(',').first.trim(),
                ) ||
                originalMuscle.contains(
                  candidateMuscle.split(',').first.trim(),
                );
            if (!matchesMuscle) return false;
          }

          return ex.equipment.toLowerCase().contains(
                preference.toLowerCase(),
              ) ||
              ex.name.toLowerCase().contains(preference.toLowerCase());
        })
        .take(3)
        .toList();

    // Automatically record learning feedback event in FitnessMemory
    if (toReplace.isNotEmpty && replacements.isNotEmpty) {
      final chosenNew = replacements.first.name;
      await _fitnessMemory.recordExerciseReplacement(
        oldExercise: toReplace,
        newExercise: chosenNew,
      );
    }

    return {
      'status': 'success',
      'action': 'modify_workout',
      'original_exercise': toReplace,
      'suggested_replacements': replacements
          .map(
            (e) => {
              'id': e.id,
              'name': e.name,
              'equipment': e.equipment,
              'muscleGroup': e.muscleGroup,
            },
          )
          .toList(),
    };
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
