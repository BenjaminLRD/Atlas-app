import 'package:flutter/material.dart';
import 'exercise_media.dart';
import '../services/exercise_media_service.dart';

/// Exercise type categorization for strength, cardio, and mobility.
enum ExerciseType { strength, cardio, flexibility, mobility }

/// Canonical, production-ready Exercise model for analytics, AI coaching, and exercise registry.
class Exercise {
  final String id;
  final String name;
  final String category;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final String equipment;
  final List<String> requiredEquipment;
  final String difficulty;
  final String movementPattern;
  final String exerciseType;
  final List<String> instructions;
  final List<String> tips;
  final List<String> commonMistakes;
  final List<String> alternatives;
  final String? imageUrl;
  final String? videoUrl;
  final String? animationAsset;
  final int estimatedCalories;
  final int? durationSeconds;
  final List<String> tags;
  final ExerciseType type;
  final double? metValue;
  final String? cardioCategory;
  final int? recommendedDuration;
  final double? estimatedCaloriesPerMinute;
  final String _legacyMuscleGroup;

  /// Alias for ID for canonical compliance
  String get exerciseId => id;

  /// Media asset descriptor resolving highest fidelity media
  ExerciseMedia get media => ExerciseMediaService().resolveMedia(this);

  /// Alias for coaching tips for natural guidance API usage
  List<String> get coachingTips => tips;

  /// Alias for local / remote image asset
  String? get imageAsset => animationAsset ?? imageUrl;

  /// Alias for local / remote video asset
  String? get videoAsset => videoUrl;

  /// Full list of target muscle groups (primary + secondary)
  List<String> get muscleGroups {
    if (primaryMuscles.isNotEmpty) {
      return [...primaryMuscles, ...secondaryMuscles];
    }
    if (_legacyMuscleGroup.isNotEmpty) {
      return _legacyMuscleGroup
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const ['Full Body'];
  }

  /// Alias for target muscles
  List<String> get targetMuscles => muscleGroups;

  /// Backwards-compatible muscle group string
  String get muscleGroup {
    if (_legacyMuscleGroup.isNotEmpty) return _legacyMuscleGroup;
    if (primaryMuscles.isNotEmpty) return primaryMuscles.join(', ');
    return 'Full Body';
  }

  /// Returns a category/movement-aware icon for visual presentation
  IconData get categoryIcon {
    final lowerId = id.toLowerCase();
    final lowerName = name.toLowerCase();
    final lowerCat = category.toLowerCase();
    final lowerEq = equipment.toLowerCase();

    // Cycling / Spin / Bike
    if (lowerId.contains('bike') ||
        lowerId.contains('cycling') ||
        lowerName.contains('bike') ||
        lowerName.contains('cycling') ||
        lowerEq.contains('bike')) {
      return Icons.directions_bike_rounded;
    }

    // Running / Sprint / Jogging / Treadmill
    if (lowerId.contains('run') ||
        lowerId.contains('sprint') ||
        lowerId.contains('jog') ||
        lowerId.contains('treadmill') ||
        lowerName.contains('run') ||
        lowerName.contains('sprint') ||
        lowerName.contains('treadmill')) {
      return Icons.directions_run_rounded;
    }

    // Swimming
    if (lowerId.contains('swim') || lowerName.contains('swimming')) {
      return Icons.pool_rounded;
    }

    // Rowing
    if (lowerId.contains('rowing') || lowerName.contains('rowing')) {
      return Icons.rowing_rounded;
    }

    // Boxing / Martial Arts
    if (lowerId.contains('box') || lowerName.contains('boxing')) {
      return Icons.sports_mma_rounded;
    }

    // Football / Soccer
    if (lowerId.contains('football') ||
        lowerName.contains('soccer') ||
        lowerName.contains('football')) {
      return Icons.sports_soccer_rounded;
    }

    // Basketball
    if (lowerId.contains('basketball') || lowerName.contains('basketball')) {
      return Icons.sports_basketball_rounded;
    }

    // HIIT / Jump Rope / Burpees / Climbers / Circuit
    if (lowerCat == 'hiit' ||
        lowerId.contains('jump_rope') ||
        lowerId.contains('burpee') ||
        lowerId.contains('climber') ||
        lowerId.contains('circuit') ||
        lowerName.contains('hiit') ||
        lowerName.contains('jump rope') ||
        lowerName.contains('burpees')) {
      return Icons.local_fire_department_rounded;
    }

    // Mobility / Stretching / Yoga / Foam Rolling
    if (lowerCat == 'mobility' ||
        lowerCat == 'stretching' ||
        lowerCat == 'flexibility' ||
        type == ExerciseType.mobility ||
        type == ExerciseType.flexibility ||
        lowerId.contains('stretch') ||
        lowerId.contains('foam_rolling') ||
        lowerId.contains('mobility') ||
        lowerName.contains('stretch') ||
        lowerName.contains('foam roll')) {
      return Icons.self_improvement_rounded;
    }

    // Core / Abs / Plank
    if (lowerCat == 'core' ||
        lowerId.contains('plank') ||
        lowerId.contains('leg_raise') ||
        lowerId.contains('crunch') ||
        lowerName.contains('plank') ||
        lowerName.contains('abs') ||
        lowerName.contains('core')) {
      return Icons.timer_outlined;
    }

    // Legs / Squats / Lunges / Calves
    if (lowerCat == 'legs' ||
        lowerId.contains('squat') ||
        lowerId.contains('lunge') ||
        lowerId.contains('calf') ||
        lowerId.contains('leg_press') ||
        lowerName.contains('squat') ||
        lowerName.contains('lunge')) {
      return Icons.accessibility_new_rounded;
    }

    // Default Strength / Push / Pull / Dumbbells / Barbells
    return Icons.fitness_center_rounded;
  }

  /// Whether this exercise is a compound multi-joint movement
  bool get isCompound =>
      exerciseType.toLowerCase().contains('compound') ||
      movementPattern.toLowerCase().contains('compound') ||
      primaryMuscles.length > 1;

  const Exercise({
    required this.id,
    required this.name,
    this.category = 'strength',
    this.primaryMuscles = const [],
    this.secondaryMuscles = const [],
    this.equipment = 'Bodyweight',
    this.requiredEquipment = const [],
    this.difficulty = 'Intermediate',
    this.movementPattern = 'push',
    this.exerciseType = 'compound',
    this.instructions = const [],
    List<String> tips = const [],
    List<String>? coachingTips,
    this.commonMistakes = const [],
    this.alternatives = const [],
    this.imageUrl,
    this.videoUrl,
    this.animationAsset,
    this.estimatedCalories = 0,
    this.durationSeconds,
    this.tags = const [],
    ExerciseType? type,
    this.metValue,
    this.cardioCategory,
    this.recommendedDuration,
    this.estimatedCaloriesPerMinute,
    String muscleGroup = '',
  }) : _legacyMuscleGroup = muscleGroup,
       tips = coachingTips ?? tips,
       type =
           type ??
           (category == 'cardio'
               ? ExerciseType.cardio
               : (category == 'mobility'
                     ? ExerciseType.mobility
                     : (category == 'stretching'
                           ? ExerciseType.flexibility
                           : ExerciseType.strength)));

  factory Exercise.fromJson(Map<String, dynamic> json) {
    final rawInstructions = json['instructions'] as List?;
    final List<String> instructionsList = rawInstructions != null
        ? rawInstructions.map((e) => e.toString()).toList()
        : [];

    final rawTips =
        json['tips'] as List? ??
        (json['coachingTips'] as List?) ??
        (json['coaching_tips'] as List?);
    final List<String> tipsList = rawTips != null
        ? rawTips.map((e) => e.toString()).toList()
        : [];

    final rawMistakes =
        json['commonMistakes'] as List? ??
        (json['common_mistakes'] as List?) ??
        (json['mistakes'] as List?);
    final List<String> mistakesList = rawMistakes != null
        ? rawMistakes.map((e) => e.toString()).toList()
        : [];

    final rawAlternatives = json['alternatives'] as List?;
    final List<String> alternativesList = rawAlternatives != null
        ? rawAlternatives.map((e) => e.toString()).toList()
        : [];

    final rawReqEquipment =
        json['requiredEquipment'] as List? ??
        (json['required_equipment'] as List?);
    final List<String> reqEquipmentList = rawReqEquipment != null
        ? rawReqEquipment.map((e) => e.toString().toLowerCase()).toList()
        : (json['equipment'] != null
              ? [
                  json['equipment'].toString().toLowerCase().replaceAll(
                    ' ',
                    '_',
                  ),
                ]
              : const []);

    final rawPrimary =
        json['primaryMuscles'] as List? ??
        json['primary_muscles'] as List? ??
        json['targetMuscles'] as List? ??
        json['target_muscles'] as List? ??
        json['muscleGroups'] as List?;
    List<String> primaryList = rawPrimary != null
        ? rawPrimary.map((e) => e.toString().trim()).toList()
        : [];

    final rawMuscleGroup =
        json['muscleGroup'] as String? ??
        json['muscle_group'] as String? ??
        json['primaryTarget'] as String?;

    if (primaryList.isEmpty &&
        rawMuscleGroup != null &&
        rawMuscleGroup.isNotEmpty) {
      primaryList = rawMuscleGroup
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    final rawSecondary =
        json['secondaryMuscles'] as List? ?? json['secondary_muscles'] as List?;
    final List<String> secondaryList = rawSecondary != null
        ? rawSecondary.map((e) => e.toString().trim()).toList()
        : [];

    final rawTags = json['tags'] as List?;
    final List<String> tagsList = rawTags != null
        ? rawTags.map((e) => e.toString().trim()).toList()
        : [];

    final rawCategory =
        json['category'] as String? ?? (json['type'] as String?) ?? 'strength';

    final rawMovement =
        json['movementPattern'] as String? ??
        json['movement_pattern'] as String? ??
        'push';

    final rawExType =
        json['exerciseType'] as String? ??
        json['exercise_type'] as String? ??
        'compound';

    final rawCalories =
        (json['estimatedCalories'] as num?)?.toInt() ??
        (json['estimated_calories'] as num?)?.toInt() ??
        0;

    final rawType = json['type'] as String? ?? json['exerciseType'] as String?;
    final parsedType = ExerciseType.values.firstWhere(
      (e) => e.name.toLowerCase() == rawType?.toLowerCase(),
      orElse: () => rawCategory == 'cardio'
          ? ExerciseType.cardio
          : (rawCategory == 'mobility'
                ? ExerciseType.mobility
                : (rawCategory == 'stretching'
                      ? ExerciseType.flexibility
                      : ExerciseType.strength)),
    );

    final resolvedId =
        json['exerciseId'] as String? ??
        json['id'] as String? ??
        json['name']?.toString().toLowerCase().replaceAll(' ', '_') ??
        '';

    final resolvedImage =
        json['imageAsset'] as String? ??
        json['imageUrl'] as String? ??
        json['image_url'] as String? ??
        json['imagePath'] as String?;

    final resolvedVideo =
        json['videoUrl'] as String? ??
        json['video_url'] as String? ??
        json['videoAsset'] as String? ??
        json['video_asset'] as String?;

    return Exercise(
      id: resolvedId,
      name: json['name'] as String? ?? 'Exercise',
      category: rawCategory,
      primaryMuscles: primaryList,
      secondaryMuscles: secondaryList,
      muscleGroup:
          rawMuscleGroup ??
          (primaryList.isNotEmpty ? primaryList.join(', ') : 'Full Body'),
      equipment: json['equipment'] as String? ?? 'Bodyweight',
      requiredEquipment: reqEquipmentList,
      difficulty: json['difficulty'] as String? ?? 'Intermediate',
      movementPattern: rawMovement,
      exerciseType: rawExType,
      instructions: instructionsList,
      tips: tipsList,
      commonMistakes: mistakesList,
      alternatives: alternativesList,
      imageUrl: resolvedImage,
      videoUrl: resolvedVideo,
      animationAsset:
          json['animationAsset'] as String? ??
          json['animation_asset'] as String?,
      estimatedCalories: rawCalories,
      durationSeconds:
          (json['durationSeconds'] as num?)?.toInt() ??
          (json['duration_seconds'] as num?)?.toInt(),
      tags: tagsList,
      type: parsedType,
      metValue:
          (json['metValue'] as num?)?.toDouble() ??
          (json['met_value'] as num?)?.toDouble(),
      cardioCategory:
          json['cardioCategory'] as String? ??
          json['cardio_category'] as String?,
      recommendedDuration:
          (json['recommendedDuration'] as num?)?.toInt() ??
          (json['recommended_duration'] as num?)?.toInt(),
      estimatedCaloriesPerMinute:
          (json['estimatedCaloriesPerMinute'] as num?)?.toDouble() ??
          (json['estimated_calories_per_minute'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exerciseId': id,
      'name': name,
      'category': category,
      'primaryMuscles': primaryMuscles,
      'secondaryMuscles': secondaryMuscles,
      'muscleGroups': muscleGroups,
      'muscleGroup': muscleGroup,
      'targetMuscles': targetMuscles,
      'equipment': equipment,
      'requiredEquipment': requiredEquipment,
      'difficulty': difficulty,
      'movementPattern': movementPattern,
      'exerciseType': exerciseType,
      'instructions': instructions,
      'tips': tips,
      'coachingTips': tips,
      'commonMistakes': commonMistakes,
      'alternatives': alternatives,
      'imageUrl': imageUrl,
      'imageAsset': imageAsset,
      'videoUrl': videoUrl,
      'videoAsset': videoAsset,
      'animationAsset': animationAsset,
      'estimatedCalories': estimatedCalories,
      'durationSeconds': durationSeconds,
      'tags': tags,
      'type': type.name,
      'metValue': metValue,
      'cardioCategory': cardioCategory,
      'recommendedDuration': recommendedDuration,
      'estimatedCaloriesPerMinute': estimatedCaloriesPerMinute,
    };
  }

  Exercise copyWith({
    String? id,
    String? name,
    String? category,
    List<String>? primaryMuscles,
    List<String>? secondaryMuscles,
    String? muscleGroup,
    String? equipment,
    List<String>? requiredEquipment,
    String? difficulty,
    String? movementPattern,
    String? exerciseType,
    List<String>? instructions,
    List<String>? tips,
    List<String>? coachingTips,
    List<String>? commonMistakes,
    List<String>? alternatives,
    String? imageUrl,
    String? videoUrl,
    String? animationAsset,
    int? estimatedCalories,
    int? durationSeconds,
    List<String>? tags,
    ExerciseType? type,
    double? metValue,
    String? cardioCategory,
    int? recommendedDuration,
    double? estimatedCaloriesPerMinute,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      primaryMuscles: primaryMuscles ?? this.primaryMuscles,
      secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      equipment: equipment ?? this.equipment,
      requiredEquipment: requiredEquipment ?? this.requiredEquipment,
      difficulty: difficulty ?? this.difficulty,
      movementPattern: movementPattern ?? this.movementPattern,
      exerciseType: exerciseType ?? this.exerciseType,
      instructions: instructions ?? this.instructions,
      tips: tips ?? this.tips,
      coachingTips: coachingTips,
      commonMistakes: commonMistakes ?? this.commonMistakes,
      alternatives: alternatives ?? this.alternatives,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      animationAsset: animationAsset ?? this.animationAsset,
      estimatedCalories: estimatedCalories ?? this.estimatedCalories,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      tags: tags ?? this.tags,
      type: type ?? this.type,
      metValue: metValue ?? this.metValue,
      cardioCategory: cardioCategory ?? this.cardioCategory,
      recommendedDuration: recommendedDuration ?? this.recommendedDuration,
      estimatedCaloriesPerMinute:
          estimatedCaloriesPerMinute ?? this.estimatedCaloriesPerMinute,
    );
  }

  /// Lookup exercise by ID from the default registry
  static Exercise? getById(String id) {
    final cleanId = id
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    if (cleanId.isEmpty) return null;
    final all = defaultRegistry();
    try {
      return all.firstWhere((e) => e.id.toLowerCase() == cleanId);
    } catch (_) {
      try {
        return all.firstWhere(
          (e) =>
              e.id.toLowerCase().replaceAll('_', '') ==
              cleanId.replaceAll('_', ''),
        );
      } catch (_) {
        return null;
      }
    }
  }

  /// Find exercise by name (case-insensitive, normalized, and fuzzy matching)
  static Exercise? findByName(String name) {
    final cleanName = name.trim().toLowerCase();
    if (cleanName.isEmpty) return null;

    final all = defaultRegistry();
    // 1. Exact match
    try {
      return all.firstWhere((e) => e.name.toLowerCase() == cleanName);
    } catch (_) {}

    // 2. ID match
    final normalizedId = cleanName.replaceAll('-', '_').replaceAll(' ', '_');
    try {
      return all.firstWhere((e) => e.id.toLowerCase() == normalizedId);
    } catch (_) {}

    // 3. Substring match
    try {
      return all.firstWhere(
        (e) =>
            e.name.toLowerCase().contains(cleanName) ||
            cleanName.contains(e.name.toLowerCase()),
      );
    } catch (_) {}

    return null;
  }

  /// Resolves the list of alternative exercises as full Exercise objects from the registry
  static List<Exercise> getAlternatives(Exercise exercise) {
    final results = <Exercise>[];
    for (final altId in exercise.alternatives) {
      final found = getById(altId) ?? findByName(altId);
      if (found != null && !results.any((e) => e.id == found.id)) {
        results.add(found);
      }
    }
    return results;
  }

  /// Built-in static registry of canonical exercises with verified metadata and deterministic media mappings
  static List<Exercise> defaultRegistry() {
    return const [
      // ==========================================
      // 1. CHEST / UPPER BODY PUSH
      // ==========================================
      Exercise(
        id: 'bench_press',
        name: 'Barbell Bench Press',
        category: 'chest',
        primaryMuscles: ['Chest', 'Triceps'],
        secondaryMuscles: ['Front Deltoids'],
        muscleGroup: 'Chest, Triceps, Front Deltoids',
        equipment: 'Barbell & Bench',
        requiredEquipment: ['barbell', 'bench'],
        difficulty: 'Intermediate',
        movementPattern: 'push',
        exerciseType: 'compound',
        durationSeconds: 45,
        videoUrl:
            'https://upload.wikimedia.org/wikipedia/commons/d/df/Bench_press_-_exercise_demonstration_video.webm',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/d/df/Bench_press_-_exercise_demonstration_video.webm/960px--Bench_press_-_exercise_demonstration_video.webm.jpg',
        instructions: [
          'Lie flat on the bench with feet firmly planted on the floor.',
          'Grip the barbell slightly wider than shoulder-width.',
          'Unrack the bar and lower it under control to the mid-chest level.',
          'Press the bar upward forcefully along a slight J-curve path to lockout.',
        ],
        tips: [
          'Retract and depress shoulder blades into the bench.',
          'Maintain a 45-degree elbow angle to protect shoulders.',
          'Drive through your heels to engage leg drive.',
        ],
        commonMistakes: [
          'Flaring elbows out at 90 degrees.',
          'Bouncing the bar off the ribcage.',
          'Lifting hips or glutes off the bench.',
        ],
        alternatives: [
          'dumbbell_bench_press',
          'chest_press_machine',
          'push_ups',
        ],
      ),
      Exercise(
        id: 'incline_bench_press',
        name: 'Incline Barbell Bench Press',
        category: 'chest',
        primaryMuscles: ['Upper Chest', 'Front Deltoids'],
        secondaryMuscles: ['Triceps'],
        muscleGroup: 'Upper Chest, Front Deltoids, Triceps',
        equipment: 'Barbell & Incline Bench',
        requiredEquipment: ['barbell', 'bench'],
        difficulty: 'Intermediate',
        movementPattern: 'push',
        exerciseType: 'compound',
        durationSeconds: 45,
        videoUrl:
            'https://upload.wikimedia.org/wikipedia/commons/8/80/Incline_press_-_exercise_demonstration_video.webm',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/8/80/Incline_press_-_exercise_demonstration_video.webm/960px--Incline_press_-_exercise_demonstration_video.webm.jpg',
        instructions: [
          'Set the incline bench to 30 degrees.',
          'Grip the barbell slightly wider than shoulder-width.',
          'Lower the bar smoothly to your upper clavicular chest.',
          'Press vertically until arms are fully extended.',
        ],
        tips: [
          'Keep bench angle under 45 degrees to target upper chest rather than front deltoids.',
          'Maintain tight shoulder blade retraction.',
        ],
        commonMistakes: [
          'Arching lower back excessively.',
          'Bouncing barbell off the chest.',
        ],
        alternatives: [
          'incline_dumbbell_press',
          'dumbbell_bench_press',
          'push_ups',
        ],
      ),
      Exercise(
        id: 'dumbbell_bench_press',
        name: 'Dumbbell Bench Press',
        category: 'chest',
        primaryMuscles: ['Chest', 'Triceps'],
        secondaryMuscles: ['Front Deltoids'],
        muscleGroup: 'Chest, Triceps, Front Deltoids',
        equipment: 'Dumbbells & Bench',
        requiredEquipment: ['dumbbells', 'bench'],
        difficulty: 'Intermediate',
        movementPattern: 'push',
        exerciseType: 'compound',
        durationSeconds: 40,
        videoUrl:
            'https://upload.wikimedia.org/wikipedia/commons/c/c0/Video_showing_how_to_perform_the_dumbbell_bench_press_and_the_dumbbell_incline_bench_press.webm',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c0/Video_showing_how_to_perform_the_dumbbell_bench_press_and_the_dumbbell_incline_bench_press.webm/960px--Video_showing_how_to_perform_the_dumbbell_bench_press_and_the_dumbbell_incline_bench_press.webm.jpg',
        instructions: [
          'Lie on a flat bench with a pair of dumbbells at chest level.',
          'Press the dumbbells upward in a slight convergent arc over the chest.',
          'Lower the weights under control until elbows break 90 degrees.',
        ],
        tips: [
          'Enjoy the greater active range of motion at the bottom of the stretch.',
          'Keep wrists stacked directly above elbows.',
        ],
        commonMistakes: [
          'Clanking dumbbells aggressively at the top.',
          'Allowing elbows to flare excessively.',
        ],
        alternatives: ['bench_press', 'chest_press_machine', 'push_ups'],
      ),
      Exercise(
        id: 'incline_dumbbell_press',
        name: 'Incline Dumbbell Press',
        category: 'chest',
        primaryMuscles: ['Upper Chest', 'Front Deltoids'],
        secondaryMuscles: ['Triceps'],
        muscleGroup: 'Upper Chest, Front Deltoids, Triceps',
        equipment: 'Dumbbells & Incline Bench',
        requiredEquipment: ['dumbbells'],
        difficulty: 'Intermediate',
        movementPattern: 'push',
        exerciseType: 'compound',
        durationSeconds: 40,
        videoUrl:
            'https://upload.wikimedia.org/wikipedia/commons/c/c0/Video_showing_how_to_perform_the_dumbbell_bench_press_and_the_dumbbell_incline_bench_press.webm',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/9/97/Dumbbell-incline-bench-press-1.png',
        instructions: [
          'Set bench at a 30–45 degree incline.',
          'Hold dumbbells at shoulder height with palms facing forward.',
          'Drive dumbbells upward directly over the upper chest.',
          'Lower with a 2-second eccentric cadence.',
        ],
        tips: [
          'Press in an arc without letting the dumbbells touch at the top.',
          'Control the descent to maximize hypertrophic stretch.',
        ],
        commonMistakes: [
          'Setting incline too steep (focus shifts to shoulders).',
          'Dropping elbows below the plane of the bench abruptly.',
        ],
        alternatives: [
          'incline_bench_press',
          'dumbbell_bench_press',
          'push_ups',
        ],
      ),
      Exercise(
        id: 'cable_chest_fly',
        name: 'Cable Chest Fly / Crossover',
        category: 'chest',
        primaryMuscles: ['Chest (Pectoralis Major)'],
        secondaryMuscles: ['Front Deltoids'],
        muscleGroup: 'Chest (Pectoralis Major)',
        equipment: 'Cable Machine',
        requiredEquipment: ['cable_machine'],
        difficulty: 'Beginner',
        movementPattern: 'isolation',
        exerciseType: 'isolation',
        durationSeconds: 35,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/b/bb/Cable-crossover-1.png/960px-Cable-crossover-1.png',
        instructions: [
          'Set dual pulleys to chest height.',
          'Step forward with one foot for a stable base.',
          'Bring handles together in a hugging motion with a slight elbow bend.',
          'Squeeze chest muscles hard for 1 second at full contraction.',
        ],
        tips: [
          'Maintain a consistent slight bend in the elbows throughout.',
          'Focus on moving through the shoulder joints.',
        ],
        commonMistakes: [
          'Turning the fly into a press by bending elbows.',
          'Using momentum or swinging the torso.',
        ],
        alternatives: ['dumbbell_chest_fly', 'push_ups'],
      ),
      Exercise(
        id: 'dumbbell_chest_fly',
        name: 'Dumbbell Chest Fly',
        category: 'chest',
        primaryMuscles: ['Chest (Pectoralis Major)'],
        secondaryMuscles: ['Front Deltoids'],
        muscleGroup: 'Chest (Pectoralis Major)',
        equipment: 'Dumbbells & Bench',
        requiredEquipment: ['dumbbells'],
        difficulty: 'Intermediate',
        movementPattern: 'isolation',
        exerciseType: 'isolation',
        durationSeconds: 35,
        animationAsset:
            'https://upload.wikimedia.org/wikipedia/commons/a/a5/DumbbellFlye.gif',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a5/DumbbellFlye.gif/960px-DumbbellFlye.gif',
        instructions: [
          'Lie on flat bench holding dumbbells with palms facing each other.',
          'Lower arms out laterally in a wide arc until chest is stretched.',
          'Bring dumbbells back together over the chest.',
        ],
        tips: [
          'Keep a slight bend in elbows to protect joints.',
          'Do not over-stretch past shoulder level.',
        ],
        commonMistakes: [
          'Dropping weights too low risking shoulder strain.',
          'Straightening arms completely.',
        ],
        alternatives: ['cable_chest_fly', 'push_ups'],
      ),
      Exercise(
        id: 'chest_press_machine',
        name: 'Machine Chest Press',
        category: 'chest',
        primaryMuscles: ['Chest', 'Triceps'],
        secondaryMuscles: ['Front Deltoids'],
        muscleGroup: 'Chest, Triceps, Front Deltoids',
        equipment: 'Chest Press Machine',
        requiredEquipment: ['chest_press_machine'],
        difficulty: 'Beginner',
        movementPattern: 'push',
        exerciseType: 'compound',
        durationSeconds: 40,
        videoUrl:
            'https://upload.wikimedia.org/wikipedia/commons/6/6f/Muscle_Strengthening_at_the_Gym_-_Chest_Press.webm',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/7/70/Muscle_Strengthening_at_the_Gym_-_Chest_Press.webm/250px--Muscle_Strengthening_at_the_Gym_-_Chest_Press.webm.jpg',
        instructions: [
          'Adjust seat height so handles align with mid-chest.',
          'Drive handles forward smoothly without violently locking elbows.',
          'Return slowly to the starting position.',
        ],
        tips: [
          'Keep back firmly against the backrest.',
          'Great for high-volume hypertrophy with minimal stabilizer fatigue.',
        ],
        commonMistakes: [
          'Shoulders hunching forward off the pad.',
          'Letting weights slam at the bottom.',
        ],
        alternatives: ['dumbbell_bench_press', 'bench_press', 'push_ups'],
      ),
      Exercise(
        id: 'push_ups',
        name: 'Push-ups',
        category: 'chest',
        primaryMuscles: ['Chest', 'Triceps'],
        secondaryMuscles: ['Core', 'Front Deltoids'],
        muscleGroup: 'Chest, Triceps, Core, Shoulders',
        equipment: 'Bodyweight / Mat',
        requiredEquipment: ['exercise_mat'],
        difficulty: 'Beginner',
        movementPattern: 'push',
        exerciseType: 'compound',
        durationSeconds: 30,
        animationAsset:
            'https://upload.wikimedia.org/wikipedia/commons/8/8f/Pushups.gif',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8f/Pushups.gif/960px-Pushups.gif',
        instructions: [
          'Place hands shoulder-width apart on the floor or mat.',
          'Maintain a rigid plank from head to heels.',
          'Lower chest until 2 inches from the ground, then press up.',
        ],
        tips: [
          'Engage glutes and core throughout.',
          'Keep elbows at a 45-degree angle to the torso.',
        ],
        commonMistakes: [
          'Sagging lower back (lumbar hyperextension).',
          'Flaring elbows out horizontally.',
        ],
        alternatives: [
          'bench_press',
          'dumbbell_bench_press',
          'chest_press_machine',
        ],
      ),
      Exercise(
        id: 'chest_dips',
        name: 'Parallel Bar Dips',
        category: 'chest',
        primaryMuscles: ['Lower Chest', 'Triceps'],
        secondaryMuscles: ['Front Deltoids'],
        muscleGroup: 'Lower Chest, Triceps, Front Deltoids',
        equipment: 'Dip Station',
        requiredEquipment: ['dip_station'],
        difficulty: 'Intermediate',
        movementPattern: 'push',
        exerciseType: 'compound',
        durationSeconds: 40,
        animationAsset:
            'https://upload.wikimedia.org/wikipedia/commons/6/63/Tricep-dips-2-1.gif',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5b/Dips.png/960px-Dips.png',
        instructions: [
          'Support bodyweight on parallel bars with arms extended.',
          'Lean torso slightly forward (15–20 degrees) to emphasize chest.',
          'Lower body until elbows reach 90 degrees, then press back up.',
        ],
        tips: [
          'Forward lean recruits chest; upright posture shifts focus to triceps.',
          'Control the descent to protect anterior shoulder capsules.',
        ],
        commonMistakes: [
          'Dropping too deep causing shoulder impingement.',
          'Kicking legs for momentum.',
        ],
        alternatives: ['push_ups', 'tricep_pushdown', 'bench_press'],
      ),

      // ==========================================
      // 2. SHOULDERS / VERTICAL PUSH
      // ==========================================
      Exercise(
        id: 'overhead_press',
        name: 'Barbell Overhead Press',
        category: 'shoulders',
        primaryMuscles: ['Shoulders (Deltoids)', 'Triceps'],
        secondaryMuscles: ['Upper Chest', 'Core'],
        muscleGroup: 'Shoulders (Deltoids), Triceps, Upper Chest, Core',
        equipment: 'Barbell',
        requiredEquipment: ['barbell'],
        difficulty: 'Intermediate',
        movementPattern: 'push',
        exerciseType: 'compound',
        durationSeconds: 45,
        videoUrl:
            'https://upload.wikimedia.org/wikipedia/commons/6/69/Shoulder_press_-_exercise_demonstration_video.webm',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/6/69/Shoulder_press_-_exercise_demonstration_video.webm/960px--Shoulder_press_-_exercise_demonstration_video.webm.jpg',
        instructions: [
          'Hold barbell at clavicle level with forearms vertical.',
          'Brace core and glutes firmly.',
          'Press the bar straight overhead, moving head slightly back then through at lockout.',
        ],
        tips: [
          'Squeeze glutes to protect the lower spine.',
          'Do not bend knees (avoid turning it into a push press).',
        ],
        commonMistakes: [
          'Excessive lower back arching.',
          'Pressing the bar too far in front of the body.',
        ],
        alternatives: [
          'dumbbell_shoulder_press',
          'arnold_press',
          'lateral_raise',
        ],
      ),
      Exercise(
        id: 'dumbbell_shoulder_press',
        name: 'Seated Dumbbell Shoulder Press',
        category: 'shoulders',
        primaryMuscles: ['Shoulders (Deltoids)', 'Triceps'],
        secondaryMuscles: ['Upper Chest'],
        muscleGroup: 'Shoulders (Deltoids), Triceps',
        equipment: 'Dumbbells & Bench',
        requiredEquipment: ['dumbbells'],
        difficulty: 'Intermediate',
        movementPattern: 'push',
        exerciseType: 'compound',
        durationSeconds: 40,
        animationAsset:
            'https://upload.wikimedia.org/wikipedia/commons/b/b2/Overhead_press-CDC_strength_training_for_older_adults.gif',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/b/b2/Overhead_press-CDC_strength_training_for_older_adults.gif',
        instructions: [
          'Sit upright on a 90-degree bench holding dumbbells at ear level.',
          'Press dumbbells vertically overhead until arms are nearly straight.',
          'Lower under control back to ear level.',
        ],
        tips: [
          'Keep elbows slightly in front of the coronal plane.',
          'Avoid clanging dumbbells together overhead.',
        ],
        commonMistakes: [
          'Arching lower back off the backrest.',
          'Shortening the range of motion.',
        ],
        alternatives: ['overhead_press', 'arnold_press'],
      ),
      Exercise(
        id: 'lateral_raise',
        name: 'Dumbbell Lateral Raise',
        category: 'shoulders',
        primaryMuscles: ['Side Deltoids (Medial Head)'],
        secondaryMuscles: ['Traps'],
        muscleGroup: 'Side Deltoids (Medial Head)',
        equipment: 'Dumbbells',
        requiredEquipment: ['dumbbells'],
        difficulty: 'Beginner',
        movementPattern: 'isolation',
        exerciseType: 'isolation',
        durationSeconds: 30,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d8/DumbbellLateralRaise.JPG/960px-DumbbellLateralRaise.JPG',
        instructions: [
          'Stand tall holding light dumbbells at your sides.',
          'Raise arms outward until parallel with the floor with a slight forward angle.',
          'Lower slowly resisting gravity.',
        ],
        tips: [
          'Lead with elbows and keep pinkies slightly higher than thumbs.',
          'Use moderate weights with strict form rather than swinging heavy weights.',
        ],
        commonMistakes: [
          'Using torso swing momentum.',
          'Shrugging traps up to the ears.',
        ],
        alternatives: ['cable_lateral_raise'],
      ),
      Exercise(
        id: 'cable_lateral_raise',
        name: 'Cable Lateral Raise',
        category: 'shoulders',
        primaryMuscles: ['Side Deltoids (Medial Head)'],
        secondaryMuscles: ['Traps'],
        muscleGroup: 'Side Deltoids (Medial Head)',
        equipment: 'Cable Machine',
        requiredEquipment: ['cable_machine'],
        difficulty: 'Beginner',
        movementPattern: 'isolation',
        exerciseType: 'isolation',
        durationSeconds: 30,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/0/03/Bent-over-cable-lateral-raises-1.png',
        instructions: [
          'Set pulley to lowest level.',
          'Stand side-on and raise handle laterally to shoulder height.',
          'Enjoy continuous tension through the entire range of motion.',
        ],
        tips: ['Keep movement slow and deliberate.'],
        commonMistakes: ['Twisting torso to lift weight.'],
        alternatives: ['lateral_raise'],
      ),
      Exercise(
        id: 'rear_delt_fly',
        name: 'Dumbbell Rear Delt Fly',
        category: 'shoulders',
        primaryMuscles: ['Rear Deltoids', 'Rhomboids'],
        secondaryMuscles: ['Upper Back'],
        muscleGroup: 'Rear Deltoids, Upper Back, Rhomboids',
        equipment: 'Dumbbells & Bench',
        requiredEquipment: ['dumbbells'],
        difficulty: 'Beginner',
        movementPattern: 'isolation',
        exerciseType: 'isolation',
        durationSeconds: 30,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/5/51/Lying-rear-lateral-raise-1.png',
        instructions: [
          'Hinge forward at hips with flat back, holding light dumbbells.',
          'Raise arms out to sides squeezing rear shoulder muscles.',
          'Lower under control.',
        ],
        tips: [
          'Keep elbows slightly bent.',
          'Focus on rear delts rather than pulling with upper traps.',
        ],
        commonMistakes: ['Jerking weights upward.'],
        alternatives: ['face_pulls'],
      ),
      Exercise(
        id: 'face_pulls',
        name: 'Cable Face Pulls',
        category: 'shoulders',
        primaryMuscles: ['Rear Deltoids', 'Rotator Cuff'],
        secondaryMuscles: ['Upper Traps', 'Rhomboids'],
        muscleGroup: 'Rear Deltoids, Rotator Cuff, Upper Traps',
        equipment: 'Cable Machine',
        requiredEquipment: ['cable_machine'],
        difficulty: 'Beginner',
        movementPattern: 'pull',
        exerciseType: 'isolation',
        durationSeconds: 35,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/f/f2/Cable-seated-rear-lateral-raise-1.png',
        instructions: [
          'Attach rope to upper pulley.',
          'Grip rope ends with thumbs pointing backward.',
          'Pull rope towards forehead/eyes, rotating hands back and flaring elbows.',
          'Hold 1 second for shoulder health.',
        ],
        tips: [
          'Crucial movement for shoulder posture and balance.',
          'Use light to moderate weight with high reps.',
        ],
        commonMistakes: ['Pulling downwards to chest instead of face.'],
        alternatives: ['rear_delt_fly'],
      ),
      Exercise(
        id: 'arnold_press',
        name: 'Arnold Dumbbell Press',
        category: 'shoulders',
        primaryMuscles: ['Shoulders (All 3 Heads)', 'Triceps'],
        secondaryMuscles: ['Upper Chest'],
        muscleGroup: 'Shoulders (All 3 Heads), Triceps',
        equipment: 'Dumbbells & Bench',
        requiredEquipment: ['dumbbells', 'bench'],
        difficulty: 'Intermediate',
        movementPattern: 'push',
        exerciseType: 'compound',
        durationSeconds: 40,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/2/2e/Arnold-press-1.png',
        instructions: [
          'Start with dumbbells at chest level, palms facing your body.',
          'As you press upward, rotate wrists so palms face forward at the top.',
          'Reverse rotation on the controlled descent.',
        ],
        tips: ['Smooth rotation throughout the movement.'],
        commonMistakes: ['Rushing the rotational phase.'],
        alternatives: ['dumbbell_shoulder_press', 'overhead_press'],
      ),

      // ==========================================
      // 3. BACK / UPPER BODY PULL
      // ==========================================
      Exercise(
        id: 'conventional_deadlift',
        name: 'Conventional Barbell Deadlift',
        category: 'back',
        primaryMuscles: ['Back', 'Glutes', 'Hamstrings'],
        secondaryMuscles: ['Traps', 'Forearms', 'Core'],
        muscleGroup: 'Back, Glutes, Hamstrings, Traps, Core',
        equipment: 'Barbell',
        requiredEquipment: ['barbell'],
        difficulty: 'Advanced',
        movementPattern: 'hinge',
        exerciseType: 'compound',
        durationSeconds: 50,
        videoUrl:
            'https://upload.wikimedia.org/wikipedia/commons/6/62/Deadlift_-_exercise_demonstration_video.webm',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/6/62/Deadlift_-_exercise_demonstration_video.webm/960px--Deadlift_-_exercise_demonstration_video.webm.jpg',
        instructions: [
          'Stand with feet hip-width apart, midfoot under the barbell.',
          'Hinge at hips, grip the bar just outside knees with a flat back.',
          'Drive through the floor, extending hips and knees simultaneously to lockout.',
          'Hinge back down with control.',
        ],
        tips: [
          'Pull slack out of the bar before driving through the floor.',
          'Keep the bar in contact with your legs throughout the lift.',
        ],
        commonMistakes: [
          'Rounding the lumbar spine.',
          'Hips shooting up before the chest.',
        ],
        alternatives: ['romanian_deadlift', 'barbell_row'],
      ),
      Exercise(
        id: 'pull_ups',
        name: 'Pull-ups',
        category: 'back',
        primaryMuscles: ['Lats', 'Upper Back'],
        secondaryMuscles: ['Biceps', 'Rhomboids', 'Core'],
        muscleGroup: 'Lats, Upper Back, Biceps, Rhomboids',
        equipment: 'Pull-up Bar',
        requiredEquipment: ['pull_up_bar'],
        difficulty: 'Intermediate',
        movementPattern: 'pull',
        exerciseType: 'compound',
        durationSeconds: 40,
        videoUrl:
            'https://upload.wikimedia.org/wikipedia/commons/1/15/Pull-ups_-_exercise_demonstration_video.webm',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/1/15/Pull-ups_-_exercise_demonstration_video.webm/960px--Pull-ups_-_exercise_demonstration_video.webm.jpg',
        instructions: [
          'Hang from an overhead bar with an overhand grip slightly wider than shoulders.',
          'Depress shoulder blades and pull chest upward toward the bar.',
          'Lower all the way down to a full dead hang with control.',
        ],
        tips: [
          'Drive elbows down towards your hips.',
          'Avoid kipping or swinging legs.',
        ],
        commonMistakes: [
          'Half-reps (not locking out or not clearing chin).',
          'Excessive swinging.',
        ],
        alternatives: ['lat_pulldown', 'chin_ups', 'barbell_row'],
      ),
      Exercise(
        id: 'chin_ups',
        name: 'Chin-ups',
        category: 'back',
        primaryMuscles: ['Lats', 'Biceps'],
        secondaryMuscles: ['Forearms', 'Upper Back'],
        muscleGroup: 'Lats, Biceps, Forearms, Upper Back',
        equipment: 'Pull-up Bar',
        requiredEquipment: ['pull_up_bar'],
        difficulty: 'Intermediate',
        movementPattern: 'pull',
        exerciseType: 'compound',
        durationSeconds: 40,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/b/bd/Chin-ups-1.png/960px-Chin-ups-1.png',
        instructions: [
          'Grip overhead bar with underhand (supinated) shoulder-width grip.',
          'Pull body upward until chin passes the bar.',
          'Lower under control to full extension.',
        ],
        tips: ['Emphasizes biceps and lower lats.'],
        commonMistakes: ['Kicking legs for momentum.'],
        alternatives: ['pull_ups', 'lat_pulldown', 'bicep_curl'],
      ),
      Exercise(
        id: 'lat_pulldown',
        name: 'Wide-Grip Lat Pulldown',
        category: 'back',
        primaryMuscles: ['Lats', 'Upper Back'],
        secondaryMuscles: ['Biceps', 'Rhomboids'],
        muscleGroup: 'Lats, Upper Back, Biceps, Rhomboids',
        equipment: 'Lat Pulldown Machine / Cable',
        requiredEquipment: ['lat_pulldown'],
        difficulty: 'Beginner',
        movementPattern: 'pull',
        exerciseType: 'compound',
        durationSeconds: 40,
        videoUrl:
            'https://upload.wikimedia.org/wikipedia/commons/0/03/Common_Lat_Pulldown_Mistakes.webm',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/0/03/Common_Lat_Pulldown_Mistakes.webm/960px--Common_Lat_Pulldown_Mistakes.webm.jpg',
        instructions: [
          'Sit securely with thighs anchored under the pads.',
          'Grip wide bar overhead with an overhand grip.',
          'Pull the bar smoothly down to upper chest while arching slightly.',
          'Control the return to full stretch.',
        ],
        tips: ['Pull with elbows, not hands.', 'Do not pull behind the neck.'],
        commonMistakes: [
          'Leaning excessively backward (turning it into a row).',
          'Letting the stack slam at the top.',
        ],
        alternatives: ['pull_ups', 'dumbbell_row', 'seated_cable_row'],
      ),
      Exercise(
        id: 'barbell_row',
        name: 'Barbell Bent-Over Row',
        category: 'back',
        primaryMuscles: ['Lats', 'Rhomboids', 'Middle Back'],
        secondaryMuscles: ['Biceps', 'Spinal Erectors'],
        muscleGroup: 'Lats, Rhomboids, Middle Back, Biceps',
        equipment: 'Barbell',
        requiredEquipment: ['barbell'],
        difficulty: 'Intermediate',
        movementPattern: 'pull',
        exerciseType: 'compound',
        durationSeconds: 45,
        videoUrl:
            'https://upload.wikimedia.org/wikipedia/commons/b/b2/Bent-over_row_-_exercise_demonstration_video.webm',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b2/Bent-over_row_-_exercise_demonstration_video.webm/960px--Bent-over_row_-_exercise_demonstration_video.webm.jpg',
        instructions: [
          'Hinge forward at 45 degrees holding a barbell with overhand grip.',
          'Keep spine neutral and knees softly bent.',
          'Row the bar toward your belly button, squeezing shoulder blades together.',
          'Lower bar with control.',
        ],
        tips: [
          'Keep core braced to protect lumbar spine.',
          'Drive elbows behind the torso.',
        ],
        commonMistakes: [
          'Rounding the lower back.',
          'Jerking upper body upward to generate momentum.',
        ],
        alternatives: ['dumbbell_row', 'seated_cable_row', 'lat_pulldown'],
      ),
      Exercise(
        id: 'dumbbell_row',
        name: 'Single-Arm Dumbbell Row',
        category: 'back',
        primaryMuscles: ['Lats', 'Upper Back'],
        secondaryMuscles: ['Rhomboids', 'Biceps'],
        muscleGroup: 'Lats, Upper Back, Rhomboids, Biceps',
        equipment: 'Dumbbells & Bench',
        requiredEquipment: ['dumbbells', 'bench'],
        difficulty: 'Beginner',
        movementPattern: 'pull',
        exerciseType: 'compound',
        durationSeconds: 40,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0e/Rear_deltoid_row_dumbbell_1.svg/960px-Rear_deltoid_row_dumbbell_1.svg.png',
        instructions: [
          'Place one knee and hand on a flat bench.',
          'Hold dumbbell with free hand, arm hanging straight down.',
          'Row dumbbell up toward your hip pocket.',
          'Lower under control to a deep stretch.',
        ],
        tips: [
          'Keep hips and shoulders square to the bench.',
          'Pull with back muscles rather than arm.',
        ],
        commonMistakes: [
          'Twisting torso to heave the weight up.',
          'Letting shoulder slump excessively at the bottom.',
        ],
        alternatives: ['barbell_row', 'seated_cable_row'],
      ),
      Exercise(
        id: 'seated_cable_row',
        name: 'Seated Cable Row',
        category: 'back',
        primaryMuscles: ['Middle Back', 'Lats', 'Rhomboids'],
        secondaryMuscles: ['Biceps', 'Rear Delts'],
        muscleGroup: 'Middle Back, Lats, Rhomboids, Biceps',
        equipment: 'Cable Machine',
        requiredEquipment: ['cable_machine'],
        difficulty: 'Beginner',
        movementPattern: 'pull',
        exerciseType: 'compound',
        durationSeconds: 40,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/2/2d/Cable-seated-rows-1.png',
        instructions: [
          'Sit on bench with feet on footrests and knees slightly bent.',
          'Grip V-bar handle with arms extended.',
          'Pull handle to abdomen, sitting tall and squeezing shoulder blades.',
          'Return slowly to the stretch.',
        ],
        tips: ['Avoid rocking back and forth excessively.'],
        commonMistakes: ['Rounding back on the forward reach.'],
        alternatives: ['barbell_row', 'dumbbell_row', 'lat_pulldown'],
      ),

      // ==========================================
      // 4. ARMS (BICEPS & TRICEPS)
      // ==========================================
      Exercise(
        id: 'bicep_curl',
        name: 'Dumbbell Bicep Curl',
        category: 'arms',
        primaryMuscles: ['Biceps Brachii'],
        secondaryMuscles: ['Forearms', 'Brachialis'],
        muscleGroup: 'Biceps Brachii, Forearms',
        equipment: 'Dumbbells',
        requiredEquipment: ['dumbbells'],
        difficulty: 'Beginner',
        movementPattern: 'pull',
        exerciseType: 'isolation',
        durationSeconds: 30,
        videoUrl:
            'https://upload.wikimedia.org/wikipedia/commons/e/ec/Video_of_EZ_Bar_Curl_and_Straight_Bar_Curl.webm',
        animationAsset:
            'https://upload.wikimedia.org/wikipedia/commons/6/66/Biceps_curl-CDC_strength_training_for_older_adults.gif',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/e/ec/Video_of_EZ_Bar_Curl_and_Straight_Bar_Curl.webm/960px--Video_of_EZ_Bar_Curl_and_Straight_Bar_Curl.webm.jpg',
        instructions: [
          'Stand tall holding dumbbells at sides.',
          'Curl weights upward while supinating wrists (palms up).',
          'Squeeze biceps at the top and lower with 2-second control.',
        ],
        tips: ['Keep elbows pinned to your sides.'],
        commonMistakes: ['Swinging torso or elbows forward.'],
        alternatives: ['hammer_curl', 'barbell_bicep_curl'],
      ),
      Exercise(
        id: 'barbell_bicep_curl',
        name: 'Barbell Bicep Curl',
        category: 'arms',
        primaryMuscles: ['Biceps Brachii'],
        secondaryMuscles: ['Forearms'],
        muscleGroup: 'Biceps Brachii',
        equipment: 'Barbell',
        requiredEquipment: ['barbell'],
        difficulty: 'Beginner',
        movementPattern: 'pull',
        exerciseType: 'isolation',
        durationSeconds: 35,
        videoUrl:
            'https://upload.wikimedia.org/wikipedia/commons/e/ec/Video_of_EZ_Bar_Curl_and_Straight_Bar_Curl.webm',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/e/ec/Video_of_EZ_Bar_Curl_and_Straight_Bar_Curl.webm/960px--Video_of_EZ_Bar_Curl_and_Straight_Bar_Curl.webm.jpg',
        instructions: [
          'Hold barbell with underhand shoulder-width grip.',
          'Curl bar toward upper chest keeping upper arms stationary.',
          'Lower smoothly to full extension.',
        ],
        tips: ['Maintain strict upright torso posture.'],
        commonMistakes: ['Leaning back to swing the bar up.'],
        alternatives: ['bicep_curl', 'hammer_curl'],
      ),
      Exercise(
        id: 'hammer_curl',
        name: 'Dumbbell Hammer Curl',
        category: 'arms',
        primaryMuscles: ['Brachialis', 'Biceps'],
        secondaryMuscles: ['Forearms'],
        muscleGroup: 'Brachialis, Biceps, Forearms',
        equipment: 'Dumbbells',
        requiredEquipment: ['dumbbells'],
        difficulty: 'Beginner',
        movementPattern: 'pull',
        exerciseType: 'isolation',
        durationSeconds: 30,
        animationAsset:
            'https://upload.wikimedia.org/wikipedia/commons/0/0e/Hammer-curls-with-rope-1.gif',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/6/66/Bicep-hammer-curl-1.png/960px-Bicep-hammer-curl-1.png',
        instructions: [
          'Hold dumbbells with neutral grip (palms facing each other).',
          'Curl weights upward maintaining neutral wrist position.',
          'Lower under control.',
        ],
        tips: ['Builds upper arm thickness and forearm strength.'],
        commonMistakes: ['Elbows drifting forward.'],
        alternatives: ['bicep_curl', 'barbell_bicep_curl'],
      ),
      Exercise(
        id: 'tricep_pushdown',
        name: 'Cable Tricep Pushdown',
        category: 'arms',
        primaryMuscles: ['Triceps Brachii'],
        secondaryMuscles: ['Forearms'],
        muscleGroup: 'Triceps Brachii',
        equipment: 'Cable Machine',
        requiredEquipment: ['cable_machine'],
        difficulty: 'Beginner',
        movementPattern: 'push',
        exerciseType: 'isolation',
        durationSeconds: 30,
        animationAsset:
            'https://upload.wikimedia.org/wikipedia/commons/2/28/Triceps-pushdown-with-rope-2.gif',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/2/28/Triceps-pushdown-with-rope-2.gif',
        instructions: [
          'Attach straight bar or rope to high pulley.',
          'Tuck elbows at sides and push handle down until arms are fully locked.',
          'Return slowly to 90 degrees.',
        ],
        tips: ['Keep upper arms locked in place; move only forearms.'],
        commonMistakes: ['Flaring elbows out or leaning over the cable.'],
        alternatives: ['skull_crushers', 'chest_dips'],
      ),
      Exercise(
        id: 'skull_crushers',
        name: 'EZ-Bar Skull Crushers',
        category: 'arms',
        primaryMuscles: ['Triceps Brachii (Long Head)'],
        secondaryMuscles: ['Triceps Lateral Head'],
        muscleGroup: 'Triceps Brachii (Long Head)',
        equipment: 'EZ-Bar / Barbell & Bench',
        requiredEquipment: ['barbell', 'bench'],
        difficulty: 'Intermediate',
        movementPattern: 'push',
        exerciseType: 'isolation',
        durationSeconds: 40,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/5/51/DumbbellTricepsExtension.JPG/960px-DumbbellTricepsExtension.JPG',
        instructions: [
          'Lie on flat bench holding EZ-bar with arms extended over chest.',
          'Hinge only at elbows, lowering bar slowly toward forehead.',
          'Extend elbows to press the bar back up.',
        ],
        tips: ['Angle upper arms slightly back for constant tricep tension.'],
        commonMistakes: ['Flaring elbows wide or dropping bar too fast.'],
        alternatives: ['tricep_pushdown', 'chest_dips'],
      ),
      Exercise(
        id: 'preacher_curl',
        name: 'Preacher Curl (Scott Curl)',
        category: 'arms',
        primaryMuscles: ['Biceps Brachii (Short Head)', 'Brachialis'],
        secondaryMuscles: ['Forearms'],
        muscleGroup: 'Biceps Brachii (Short Head), Brachialis',
        equipment: 'Preacher Bench & EZ-Bar / Dumbbells',
        requiredEquipment: ['barbell', 'bench'],
        difficulty: 'Intermediate',
        movementPattern: 'pull',
        exerciseType: 'isolation',
        durationSeconds: 35,
        animationAsset:
            'https://upload.wikimedia.org/wikipedia/commons/c/c6/Two-arm-preacher-curl-2.gif',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/c/cc/PreacherBenchBicepsCurl.JPG/960px-PreacherBenchBicepsCurl.JPG',
        instructions: [
          'Sit on preacher bench with upper arms resting flush against the angled pad.',
          'Grip EZ-bar or dumbbells with palms facing upward at shoulder width.',
          'Curl the weight upward until forearms are near vertical, squeezing biceps.',
          'Lower the weight smoothly under control without hyperextending elbows at the bottom.',
        ],
        tips: [
          'Keep upper arms pinned to pad to prevent shoulder assistance.',
          'Avoid bouncing out of the bottom position to protect the distal biceps tendon.',
        ],
        commonMistakes: [
          'Lifting elbows off the pad during the curl.',
          'Hyperextending elbows at full stretch under heavy load.',
        ],
        alternatives: [
          'bicep_curl',
          'incline_dumbbell_curl',
          'barbell_bicep_curl',
        ],
      ),
      Exercise(
        id: 'concentration_curl',
        name: 'Dumbbell Concentration Curl',
        category: 'arms',
        primaryMuscles: ['Biceps Brachii (Peak Hypertrophy)'],
        secondaryMuscles: ['Brachialis', 'Forearms'],
        muscleGroup: 'Biceps Brachii',
        equipment: 'Dumbbells & Bench',
        requiredEquipment: ['dumbbells', 'bench'],
        difficulty: 'Beginner',
        movementPattern: 'pull',
        exerciseType: 'isolation',
        durationSeconds: 30,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/6/6a/Concentration-curls-1.png',
        instructions: [
          'Sit on edge of bench with legs spread wider than shoulder-width.',
          'Rest back of working tricep against inner thigh of same side.',
          'Curl dumbbell upward toward shoulder while keeping upper arm stationary.',
          'Lower slowly under control for complete eccentric stretch.',
        ],
        tips: [
          'Do not swing torso; isolate strictly with the biceps.',
          'Supinate wrist fully at top of contraction.',
        ],
        commonMistakes: [
          'Using momentum from torso to swing dumbbell up.',
          'Allowing elbow to slide off inner thigh.',
        ],
        alternatives: ['preacher_curl', 'bicep_curl', 'hammer_curl'],
      ),
      Exercise(
        id: 'incline_dumbbell_curl',
        name: 'Incline Dumbbell Curl',
        category: 'arms',
        primaryMuscles: ['Biceps Brachii (Long Head)'],
        secondaryMuscles: ['Brachialis', 'Forearms'],
        muscleGroup: 'Biceps Brachii (Long Head)',
        equipment: 'Dumbbells & Incline Bench',
        requiredEquipment: ['dumbbells', 'bench'],
        difficulty: 'Intermediate',
        movementPattern: 'pull',
        exerciseType: 'isolation',
        durationSeconds: 35,
        animationAsset:
            'https://upload.wikimedia.org/wikipedia/commons/8/81/Incline-biceps-curl-1.gif',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/5/52/Alternate-incline-curl-1.png',
        instructions: [
          'Set incline bench to 45–60 degrees and lean back with dumbbells hanging straight down.',
          'Keep elbows pointed at floor and curl dumbbells upward with supinated wrists.',
          'Squeeze biceps at the top and lower slowly under full long-head stretch.',
        ],
        tips: [
          'Keep upper arms perpendicular to floor to maintain deep stretch on long head.',
          'Avoid pulling elbows forward as weight rises.',
        ],
        commonMistakes: [
          'Swinging elbows forward turning it into a front raise.',
          'Setting bench incline too flat placing excessive strain on shoulder capsule.',
        ],
        alternatives: ['bicep_curl', 'preacher_curl', 'cable_bicep_curl'],
      ),
      Exercise(
        id: 'cable_bicep_curl',
        name: 'Cable Bicep Curl',
        category: 'arms',
        primaryMuscles: ['Biceps Brachii'],
        secondaryMuscles: ['Brachialis', 'Forearms'],
        muscleGroup: 'Biceps Brachii, Forearms',
        equipment: 'Cable Machine',
        requiredEquipment: ['cable_machine'],
        difficulty: 'Beginner',
        movementPattern: 'pull',
        exerciseType: 'isolation',
        durationSeconds: 30,
        animationAsset:
            'https://upload.wikimedia.org/wikipedia/commons/d/d3/Standing-biceps-curl-1.gif',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d3/Standing-biceps-curl-1.gif/960px-Standing-biceps-curl-1.gif',
        instructions: [
          'Attach straight or EZ bar to low pulley of cable station.',
          'Stand tall with elbows tucked at sides and palms facing up.',
          'Curl handle toward shoulders while maintaining constant cable tension.',
          'Lower smoothly back to starting position.',
        ],
        tips: [
          'Cable provides uniform continuous tension throughout entire range of motion.',
          'Maintain braced core and upright posture.',
        ],
        commonMistakes: [
          'Leaning backward to jerk cable upward.',
          'Letting elbows drift forward.',
        ],
        alternatives: ['barbell_bicep_curl', 'bicep_curl', 'preacher_curl'],
      ),
      Exercise(
        id: 'overhead_tricep_extension',
        name: 'Overhead Tricep Extension',
        category: 'arms',
        primaryMuscles: ['Triceps Brachii (Long Head)'],
        secondaryMuscles: ['Core'],
        muscleGroup: 'Triceps Brachii (Long Head)',
        equipment: 'Dumbbell / Cable',
        requiredEquipment: ['dumbbells'],
        difficulty: 'Beginner',
        movementPattern: 'push',
        exerciseType: 'isolation',
        durationSeconds: 35,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/5/51/DumbbellTricepsExtension.JPG/960px-DumbbellTricepsExtension.JPG',
        instructions: [
          'Sit or stand holding a dumbbell vertically overhead with both hands cup-gripping upper plate.',
          'Lower dumbbell behind head by bending elbows while keeping upper arms close to ears.',
          'Extend elbows to press dumbbell back overhead into peak contraction.',
        ],
        tips: [
          'Overhead position places long head of triceps on maximum stretch.',
          'Keep elbows tucked inward rather than flaring wide.',
        ],
        commonMistakes: [
          'Flaring elbows out to sides excessively.',
          'Arching lower back under heavy load.',
        ],
        alternatives: ['skull_crushers', 'tricep_pushdown', 'chest_dips'],
      ),
      Exercise(
        id: 'tricep_kickbacks',
        name: 'Dumbbell Tricep Kickbacks',
        category: 'arms',
        primaryMuscles: ['Triceps Brachii (Lateral & Medial Heads)'],
        secondaryMuscles: ['Rear Deltoids'],
        muscleGroup: 'Triceps Brachii',
        equipment: 'Dumbbells & Bench',
        requiredEquipment: ['dumbbells'],
        difficulty: 'Beginner',
        movementPattern: 'push',
        exerciseType: 'isolation',
        durationSeconds: 30,
        animationAsset:
            'https://upload.wikimedia.org/wikipedia/commons/7/73/Triceps_brachii_muscle_-_animation02.gif',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/7/73/Triceps_brachii_muscle_-_animation02.gif/960px-Triceps_brachii_muscle_-_animation02.gif',
        instructions: [
          'Hinge torso forward with flat back, holding dumbbell with elbow bent at 90 degrees tucked high.',
          'Extend forearm backward until entire arm is parallel to torso.',
          'Squeeze tricep firmly at peak contraction before lowering forearm under control.',
        ],
        tips: [
          'Keep upper arm pinned horizontally throughout the entire movement.',
          'Use moderate weight to avoid swinging.',
        ],
        commonMistakes: [
          'Dropping elbow below torso level.',
          'Swinging dumbbell with shoulder momentum.',
        ],
        alternatives: [
          'tricep_pushdown',
          'overhead_tricep_extension',
          'skull_crushers',
        ],
      ),

      // ==========================================
      // 5. LEGS / LOWER BODY
      // ==========================================
      Exercise(
        id: 'barbell_back_squat',
        name: 'Barbell Back Squat',
        category: 'legs',
        primaryMuscles: ['Quadriceps', 'Glutes'],
        secondaryMuscles: ['Hamstrings', 'Core', 'Calves'],
        muscleGroup: 'Quadriceps, Glutes, Hamstrings, Core',
        equipment: 'Barbell & Squat Rack',
        requiredEquipment: ['barbell', 'squat_rack'],
        difficulty: 'Advanced',
        movementPattern: 'squat',
        exerciseType: 'compound',
        durationSeconds: 50,
        videoUrl:
            'https://upload.wikimedia.org/wikipedia/commons/5/5c/Squat_-_exercise_demonstration_video.webm',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5c/Squat_-_exercise_demonstration_video.webm/960px--Squat_-_exercise_demonstration_video.webm.jpg',
        instructions: [
          'Rest barbell across upper trapezius muscles.',
          'Inhale deeply and brace core tight.',
          'Hinge hips back and bend knees until thighs are parallel to ground.',
          'Drive firmly through heels to return to standing position.',
        ],
        tips: [
          'Keep chest upright and eyes facing forward.',
          'Brace core tight before descent.',
          'Drive through heels and maintain knee alignment.',
        ],
        commonMistakes: [
          'Knees caving inward during ascent.',
          'Curving lower back (butt wink).',
          'Lifting heels off the floor.',
        ],
        alternatives: [
          'dumbbell_goblet_squat',
          'leg_press',
          'bulgarian_split_squat',
          'bodyweight_squat',
        ],
      ),
      Exercise(
        id: 'bodyweight_squat',
        name: 'Bodyweight Air Squat',
        category: 'legs',
        primaryMuscles: ['Quadriceps', 'Glutes'],
        secondaryMuscles: ['Hamstrings', 'Core', 'Calves'],
        muscleGroup: 'Quadriceps, Glutes, Core',
        equipment: 'Bodyweight',
        requiredEquipment: [],
        difficulty: 'Beginner',
        movementPattern: 'squat',
        exerciseType: 'compound',
        durationSeconds: 35,
        animationAsset:
            'https://upload.wikimedia.org/wikipedia/commons/4/4f/Squats_wbs.gif',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/6/6a/Kniebeuge.jpg/960px-Kniebeuge.jpg',
        instructions: [
          'Stand with feet shoulder-width apart, toes pointed slightly outward.',
          'Hinge hips backward and bend knees to lower thighs to parallel or deeper.',
          'Keep chest tall and drive through whole foot to return to standing.',
        ],
        tips: [
          'Excellent foundational movement for mobility and squat motor patterning.',
          'Keep weight distributed across midfoot and heels.',
        ],
        commonMistakes: [
          'Knees caving inward during descent.',
          'Heels rising off the floor.',
        ],
        alternatives: [
          'barbell_back_squat',
          'dumbbell_goblet_squat',
          'leg_press',
        ],
      ),
      Exercise(
        id: 'romanian_deadlift',
        name: 'Barbell Romanian Deadlift',
        category: 'legs',
        primaryMuscles: ['Hamstrings', 'Glutes'],
        secondaryMuscles: ['Lower Back', 'Core'],
        muscleGroup: 'Hamstrings, Glutes, Lower Back',
        equipment: 'Barbell',
        requiredEquipment: ['barbell'],
        difficulty: 'Intermediate',
        movementPattern: 'hinge',
        exerciseType: 'compound',
        durationSeconds: 45,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/e/e8/Romanian-deadlift-1.png',
        instructions: [
          'Stand erect holding barbell with overhand grip.',
          'Push hips back while maintaining slight bend in knees.',
          'Lower bar along thighs until deep stretch is felt in hamstrings.',
          'Engage glutes to drive hips forward back to starting position.',
        ],
        tips: [
          'Push hips backward with soft knee bend.',
          'Keep back flat and spine neutral throughout.',
          'Control eccentric lowering phase.',
        ],
        commonMistakes: [
          'Rounding upper or lower spine.',
          'Bending knees too much turning it into a squat.',
          'Allowing bar to drift away from legs.',
        ],
        alternatives: [
          'dumbbell_rdl',
          'hamstring_curl',
          'conventional_deadlift',
        ],
      ),
      Exercise(
        id: 'dumbbell_goblet_squat',
        name: 'Dumbbell Goblet Squat',
        category: 'legs',
        primaryMuscles: ['Quadriceps', 'Glutes'],
        secondaryMuscles: ['Core', 'Calves'],
        muscleGroup: 'Quadriceps, Glutes, Core',
        equipment: 'Dumbbells',
        requiredEquipment: ['dumbbells'],
        difficulty: 'Beginner',
        movementPattern: 'squat',
        exerciseType: 'compound',
        durationSeconds: 40,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/c/c3/Kettlebell_Front_Squat_1.jpg',
        instructions: [
          'Hold a single dumbbell vertically against your chest with both hands.',
          'Squat deeply between knees keeping chest high.',
          'Drive through heels back to upright standing.',
        ],
        tips: ['Great for teaching upright squat mechanics.'],
        commonMistakes: ['Letting dumbbell pull torso forward.'],
        alternatives: [
          'barbell_back_squat',
          'leg_press',
          'bulgarian_split_squat',
          'bodyweight_squat',
        ],
      ),
      Exercise(
        id: 'dumbbell_rdl',
        name: 'Dumbbell Romanian Deadlift',
        category: 'legs',
        primaryMuscles: ['Hamstrings', 'Glutes'],
        secondaryMuscles: ['Lower Back'],
        muscleGroup: 'Hamstrings, Glutes, Lower Back',
        equipment: 'Dumbbells',
        requiredEquipment: ['dumbbells'],
        difficulty: 'Beginner',
        movementPattern: 'hinge',
        exerciseType: 'compound',
        durationSeconds: 40,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/e/e8/Romanian-deadlift-1.png',
        instructions: [
          'Hold pair of dumbbells in front of thighs.',
          'Hinge at hips, pushing glutes backward while keeping spine flat.',
          'Drive through heels and squeeze glutes at the top.',
        ],
        tips: ['Feel the tension in hamstrings, not lower back.'],
        commonMistakes: ['Bending at the waist without hip hinge.'],
        alternatives: ['romanian_deadlift', 'hamstring_curl'],
      ),
      Exercise(
        id: 'leg_press',
        name: 'Leg Press Sled',
        category: 'legs',
        primaryMuscles: ['Quadriceps', 'Glutes'],
        secondaryMuscles: ['Hamstrings'],
        muscleGroup: 'Quadriceps, Glutes, Hamstrings',
        equipment: 'Leg Press Machine',
        requiredEquipment: ['leg_press'],
        difficulty: 'Beginner',
        movementPattern: 'squat',
        exerciseType: 'compound',
        durationSeconds: 45,
        videoUrl:
            'https://upload.wikimedia.org/wikipedia/commons/4/44/Hip_Sled_-_How_to_perform_a_45_degree_leg_press.webm',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/4/44/Hip_Sled_-_How_to_perform_a_45_degree_leg_press.webm/960px--Hip_Sled_-_How_to_perform_a_45_degree_leg_press.webm.jpg',
        instructions: [
          'Place feet shoulder-width in middle of the footplate.',
          'Release safety handles and lower sled until knees reach 90 degrees.',
          'Press sled away without hyperextending or locking knees.',
        ],
        tips: ['Keep lower back and hips glued to the seat.'],
        commonMistakes: [
          'Lifting lower back off the pad at bottom.',
          'Hard knee hyperextension at top.',
        ],
        alternatives: ['barbell_back_squat', 'dumbbell_goblet_squat'],
      ),
      Exercise(
        id: 'leg_extension',
        name: 'Leg Extension Machine',
        category: 'legs',
        primaryMuscles: ['Quadriceps (Isolated)'],
        secondaryMuscles: [],
        muscleGroup: 'Quadriceps (Isolated)',
        equipment: 'Leg Extension Machine',
        requiredEquipment: ['leg_extension'],
        difficulty: 'Beginner',
        movementPattern: 'isolation',
        exerciseType: 'isolation',
        durationSeconds: 35,
        videoUrl:
            'https://upload.wikimedia.org/wikipedia/commons/1/13/Muscle_Strengthening_at_the_Gym_-_Leg_Extension.webm',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/1/13/Muscle_Strengthening_at_the_Gym_-_Leg_Extension.webm/960px--Muscle_Strengthening_at_the_Gym_-_Leg_Extension.webm.jpg',
        instructions: [
          'Align knees with machine pivot point, shin pad just above ankles.',
          'Extend legs to full knee extension, pausing at the top.',
          'Lower with 2-second control.',
        ],
        tips: ['Ideal for quad hypertrophy pump.'],
        commonMistakes: ['Kicking weights up rapidly with momentum.'],
        alternatives: ['dumbbell_goblet_squat', 'leg_press'],
      ),
      Exercise(
        id: 'hamstring_curl',
        name: 'Leg Curl Machine',
        category: 'legs',
        primaryMuscles: ['Hamstrings (Isolated)'],
        secondaryMuscles: ['Calves'],
        muscleGroup: 'Hamstrings (Isolated)',
        equipment: 'Leg Curl Machine',
        requiredEquipment: ['leg_curl'],
        difficulty: 'Beginner',
        movementPattern: 'isolation',
        exerciseType: 'isolation',
        durationSeconds: 35,
        videoUrl:
            'https://upload.wikimedia.org/wikipedia/commons/1/14/Muscle_Strengthening_at_the_Gym_-_Leg_Curl.webm',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/1/14/Muscle_Strengthening_at_the_Gym_-_Leg_Curl.webm/960px--Muscle_Strengthening_at_the_Gym_-_Leg_Curl.webm.jpg',
        instructions: [
          'Adjust machine pad to rest just below calves.',
          'Curl heels toward glutes with maximum hamstring contraction.',
          'Control the return to full stretch.',
        ],
        tips: ['Keep hips down on pad.'],
        commonMistakes: ['Lifting hips off the seat.'],
        alternatives: ['romanian_deadlift', 'dumbbell_rdl'],
      ),
      Exercise(
        id: 'bulgarian_split_squat',
        name: 'Bulgarian Split Squat',
        category: 'legs',
        primaryMuscles: ['Quadriceps', 'Glutes'],
        secondaryMuscles: ['Hamstrings', 'Core'],
        muscleGroup: 'Quadriceps, Glutes, Hamstrings',
        equipment: 'Dumbbells & Bench',
        requiredEquipment: ['dumbbells', 'bench'],
        difficulty: 'Intermediate',
        movementPattern: 'lunge',
        exerciseType: 'compound',
        durationSeconds: 45,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/5/55/Jumping_split_squat_with_dumbbells_1.png',
        instructions: [
          'Stand 2 feet in front of a bench; rest one foot laces-down on the bench.',
          'Lower rear knee towards floor while front thigh reaches parallel.',
          'Drive through front heel back to start.',
        ],
        tips: [
          'Slight forward torso lean targets glutes; upright posture targets quads.',
        ],
        commonMistakes: ['Front foot placed too close to bench.'],
        alternatives: ['walking_lunges', 'dumbbell_goblet_squat'],
      ),
      Exercise(
        id: 'standing_calf_raise',
        name: 'Standing Calf Raise',
        category: 'legs',
        primaryMuscles: ['Calves (Gastrocnemius, Soleus)'],
        secondaryMuscles: [],
        muscleGroup: 'Calves (Gastrocnemius, Soleus)',
        equipment: 'Calf Machine / Dumbbells',
        requiredEquipment: ['dumbbells'],
        difficulty: 'Beginner',
        movementPattern: 'isolation',
        exerciseType: 'isolation',
        durationSeconds: 30,
        animationAsset:
            'https://upload.wikimedia.org/wikipedia/commons/1/10/Toe_stand-CDC_strength_training_for_older_adults.gif',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/1/10/Toe_stand-CDC_strength_training_for_older_adults.gif',
        instructions: [
          'Stand on edge of step on balls of feet.',
          'Lower heels for deep calf stretch, then rise onto tiptoes.',
          'Hold top contraction for 1 full second.',
        ],
        tips: ['Full range of motion is crucial for calf growth.'],
        commonMistakes: ['Bouncing fast without pauses.'],
        alternatives: [
          'jump_rope',
          'seated_calf_raise',
          'calf_press_leg_press',
        ],
      ),
      Exercise(
        id: 'seated_calf_raise',
        name: 'Seated Calf Raise',
        category: 'legs',
        primaryMuscles: ['Calves (Soleus Muscle)'],
        secondaryMuscles: ['Gastrocnemius'],
        muscleGroup: 'Calves (Soleus)',
        equipment: 'Seated Calf Machine / Dumbbells',
        requiredEquipment: ['dumbbells'],
        difficulty: 'Beginner',
        movementPattern: 'isolation',
        exerciseType: 'isolation',
        durationSeconds: 30,
        animationAsset:
            'https://upload.wikimedia.org/wikipedia/commons/1/10/Toe_stand-CDC_strength_training_for_older_adults.gif',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/1/10/Toe_stand-CDC_strength_training_for_older_adults.gif',
        instructions: [
          'Sit with thigh pads resting snugly just above knees with balls of feet on platform.',
          'Lower heels down into deep calf stretch.',
          'Drive balls of feet down to raise heels into full plantarflexion contraction, pausing at top.',
        ],
        tips: [
          'Seated 90-degree knee bend deactivates gastrocnemius and directly isolates the deep soleus muscle.',
          'Pause for 1 second at the top and bottom to avoid bouncing.',
        ],
        commonMistakes: [
          'Using fast bouncing cadence.',
          'Cutting range of motion.',
        ],
        alternatives: ['standing_calf_raise', 'calf_press_leg_press'],
      ),
      Exercise(
        id: 'calf_press_leg_press',
        name: 'Calf Press on Leg Press Machine',
        category: 'legs',
        primaryMuscles: ['Calves (Gastrocnemius)'],
        secondaryMuscles: ['Soleus'],
        muscleGroup: 'Calves (Gastrocnemius)',
        equipment: 'Leg Press Machine',
        requiredEquipment: ['leg_press'],
        difficulty: 'Intermediate',
        movementPattern: 'isolation',
        exerciseType: 'isolation',
        durationSeconds: 35,
        videoUrl:
            'https://upload.wikimedia.org/wikipedia/commons/4/44/Hip_Sled_-_How_to_perform_a_45_degree_leg_press.webm',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/4/44/Hip_Sled_-_How_to_perform_a_45_degree_leg_press.webm/960px--Hip_Sled_-_How_to_perform_a_45_degree_leg_press.webm.jpg',
        instructions: [
          'Sit in leg press machine with only balls of feet resting on bottom edge of sled footplate.',
          'Release safeties keeping legs nearly straight with a slight soft knee bend.',
          'Lower sled by letting ankles dorsiflex for full calf stretch, then press sled forward on tiptoes.',
        ],
        tips: [
          'Never lock knees completely during the press to keep stress solely on calves.',
          'Keep safeties engaged at an appropriate height for security.',
        ],
        commonMistakes: [
          'Hyperextending knees.',
          'Letting feet slip off the bottom plate edge.',
        ],
        alternatives: ['standing_calf_raise', 'seated_calf_raise'],
      ),
      Exercise(
        id: 'walking_lunges',
        name: 'Dumbbell Walking Lunges',
        category: 'legs',
        primaryMuscles: ['Quadriceps', 'Glutes'],
        secondaryMuscles: ['Hamstrings', 'Calves'],
        muscleGroup: 'Quadriceps, Glutes, Hamstrings',
        equipment: 'Dumbbells',
        requiredEquipment: ['dumbbells'],
        difficulty: 'Intermediate',
        movementPattern: 'lunge',
        exerciseType: 'compound',
        durationSeconds: 40,
        animationAsset:
            'https://upload.wikimedia.org/wikipedia/commons/a/af/Lunge-CDC_strength_training_for_older_adults.gif',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/2/29/Airman_performing_lunge.jpg/960px-Airman_performing_lunge.jpg',
        instructions: [
          'Take a long step forward, lowering back knee toward the ground.',
          'Push through front heel to step forward into the next lunge.',
        ],
        tips: ['Keep torso tall and core engaged.'],
        commonMistakes: ['Front knee shooting way past toes.'],
        alternatives: ['bulgarian_split_squat', 'dumbbell_goblet_squat'],
      ),

      // ==========================================
      // 6. CORE & ABDOMINALS
      // ==========================================
      Exercise(
        id: 'hanging_leg_raise',
        name: 'Hanging Leg Raise',
        category: 'core',
        primaryMuscles: ['Rectus Abdominis', 'Hip Flexors'],
        secondaryMuscles: ['Obliques', 'Grip'],
        muscleGroup: 'Rectus Abdominis, Hip Flexors, Obliques',
        equipment: 'Pull-up Bar',
        requiredEquipment: ['pull_up_bar'],
        difficulty: 'Intermediate',
        movementPattern: 'isolation',
        exerciseType: 'isolation',
        durationSeconds: 30,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/4/41/Leg-raises-1.png',
        instructions: [
          'Hang from pull-up bar with arms extended.',
          'Engage abs and curl legs/knees upward until parallel or higher.',
          'Lower with control without swinging.',
        ],
        tips: ['Curl pelvis up to engage abs rather than just hip flexors.'],
        commonMistakes: ['Swinging torso back and forth.'],
        alternatives: ['plank'],
      ),
      Exercise(
        id: 'plank',
        name: 'Forearm Plank Hold',
        category: 'core',
        primaryMuscles: ['Core (Transverse Abdominis)'],
        secondaryMuscles: ['Glutes', 'Shoulders'],
        muscleGroup: 'Core (Transverse Abdominis, Glutes)',
        equipment: 'Bodyweight / Mat',
        requiredEquipment: ['exercise_mat'],
        difficulty: 'Beginner',
        movementPattern: 'isolation',
        exerciseType: 'isolation',
        durationSeconds: 45,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/e/ee/Plank.jpg/960px-Plank.jpg',
        instructions: [
          'Rest on forearms and toes with body in a straight line.',
          'Brace abs tight as if about to be punched.',
          'Hold static position while breathing steadily.',
        ],
        tips: ['Squeeze glutes and press elbows into floor.'],
        commonMistakes: ['Hips sagging or hiking high in the air.'],
        alternatives: ['hanging_leg_raise'],
      ),

      // ==========================================
      // 7. CARDIO, CONDITIONING & SPORTS
      // ==========================================
      Exercise(
        id: 'outdoor_run',
        name: 'Outdoor Run',
        category: 'cardio',
        primaryMuscles: ['Cardiovascular', 'Quads'],
        secondaryMuscles: ['Calves', 'Hamstrings'],
        muscleGroup: 'Cardiovascular, Quads, Calves',
        equipment: 'None',
        requiredEquipment: [],
        difficulty: 'Intermediate',
        movementPattern: 'cardio',
        exerciseType: 'cardio',
        type: ExerciseType.cardio,
        cardioCategory: 'Running',
        metValue: 9.8,
        recommendedDuration: 30,
        estimatedCaloriesPerMinute: 11.5,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0a/Speedsuit.jpg/960px-Speedsuit.jpg',
        instructions: [
          'Maintain an upright posture with a slight forward lean from ankles.',
          'Land softly on midfoot under your center of gravity.',
          'Maintain a cadence around 160-180 steps per minute.',
        ],
        tips: [
          'Focus on rhythmic breathing in 2:2 or 3:3 pattern.',
          'Keep shoulders relaxed and arms swinging in sagittal plane.',
        ],
        commonMistakes: [
          'Overstriding ahead of hips.',
          'Slouching shoulders or looking down.',
        ],
        alternatives: ['treadmill_run', 'jogging', 'sprint_intervals'],
      ),
      Exercise(
        id: 'treadmill_run',
        name: 'Treadmill Run',
        category: 'cardio',
        primaryMuscles: ['Cardiovascular', 'Legs'],
        secondaryMuscles: ['Calves', 'Core'],
        muscleGroup: 'Cardiovascular, Legs',
        equipment: 'Treadmill',
        requiredEquipment: ['treadmill'],
        difficulty: 'Beginner',
        movementPattern: 'cardio',
        exerciseType: 'cardio',
        type: ExerciseType.cardio,
        cardioCategory: 'Running',
        metValue: 9.0,
        recommendedDuration: 25,
        estimatedCaloriesPerMinute: 10.5,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/2/26/Close-up_of_a_determined_athlete_running_on_a_treadmill.jpg/960px-Close-up_of_a_determined_athlete_running_on_a_treadmill.jpg',
        instructions: [
          'Set a 1% incline to simulate outdoor air resistance.',
          'Keep your gaze forward and avoid holding onto handrails.',
          'Run with a steady, controlled stride.',
        ],
        tips: [
          'Use intervals for higher calorie expenditure.',
          'Maintain steady breathing rhythm.',
        ],
        commonMistakes: [
          'Holding side rails while running.',
          'Looking down at feet.',
        ],
        alternatives: ['outdoor_run', 'jogging', 'stationary_bike'],
      ),
      Exercise(
        id: 'sprint_intervals',
        name: 'Sprint Intervals (HIIT)',
        category: 'cardio',
        primaryMuscles: ['Hamstrings', 'Glutes'],
        secondaryMuscles: ['Calves', 'Core', 'Cardiovascular'],
        muscleGroup: 'Hamstrings, Glutes, Calves, Core',
        equipment: 'None',
        requiredEquipment: [],
        difficulty: 'Advanced',
        movementPattern: 'cardio',
        exerciseType: 'cardio',
        type: ExerciseType.cardio,
        cardioCategory: 'Running',
        metValue: 12.5,
        recommendedDuration: 20,
        estimatedCaloriesPerMinute: 14.5,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/d/d6/Tulane_Track_and_Field_sprinting%2C_George_G._Westfeldt_Complex_and_Danny_Thiel_Track.jpg',
        instructions: [
          'Sprint at 90-100% maximum effort for 20-30 seconds.',
          'Recover with active walk or rest for 60 seconds.',
          'Repeat for 6 to 10 rounds.',
        ],
        tips: [
          'Drive knees up and pump arms vigorously.',
          'Stay on forefoot during acceleration.',
        ],
        commonMistakes: [
          'Insufficient warm-up before all-out sprints.',
          'Decelerating abruptly.',
        ],
        alternatives: ['hiit_cycling', 'rowing_intervals', 'burpees'],
      ),
      Exercise(
        id: 'jogging',
        name: 'Recovery Jog',
        category: 'cardio',
        primaryMuscles: ['Cardiovascular', 'Full Body'],
        secondaryMuscles: ['Calves'],
        muscleGroup: 'Cardiovascular, Full Body',
        equipment: 'None',
        requiredEquipment: [],
        difficulty: 'Beginner',
        movementPattern: 'cardio',
        exerciseType: 'cardio',
        type: ExerciseType.cardio,
        cardioCategory: 'Running',
        metValue: 7.0,
        recommendedDuration: 35,
        estimatedCaloriesPerMinute: 8.2,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0a/Speedsuit.jpg/960px-Speedsuit.jpg',
        instructions: [
          'Maintain a conversational, low-intensity pace (Zone 2).',
          'Keep arms relaxed and shoulders low.',
        ],
        tips: [
          'Ideal for active recovery days and aerobic base building.',
          'Breathe through your nose if possible.',
        ],
        commonMistakes: ['Running too fast into Zone 3/4 on recovery days.'],
        alternatives: ['outdoor_run', 'stationary_bike'],
      ),
      Exercise(
        id: 'stationary_bike',
        name: 'Stationary Bike',
        category: 'cardio',
        primaryMuscles: ['Quadriceps', 'Glutes'],
        secondaryMuscles: ['Calves', 'Cardiovascular'],
        muscleGroup: 'Quadriceps, Glutes, Calves',
        equipment: 'Stationary Bike',
        requiredEquipment: ['stationary_bike'],
        difficulty: 'Beginner',
        movementPattern: 'cardio',
        exerciseType: 'cardio',
        type: ExerciseType.cardio,
        cardioCategory: 'Cycling',
        metValue: 7.0,
        recommendedDuration: 30,
        estimatedCaloriesPerMinute: 8.0,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/0/00/Fahrrad-Ergometer_01_KMJ.jpg/960px-Fahrrad-Ergometer_01_KMJ.jpg',
        instructions: [
          'Adjust seat height so knee has a slight 10-15 degree bend at bottom of pedal stroke.',
          'Keep core engaged and avoid excessive upper body movement.',
          'Pedal smoothly in complete circles.',
        ],
        tips: [
          'Target cadence of 80-90 RPM.',
          'Keep upper body relaxed without death-gripping handlebars.',
        ],
        commonMistakes: [
          'Seat set too low causing knee strain.',
          'Rocking hips side to side.',
        ],
        alternatives: ['outdoor_cycling', 'hiit_cycling', 'treadmill_run'],
      ),
      Exercise(
        id: 'outdoor_cycling',
        name: 'Outdoor Cycling',
        category: 'cardio',
        primaryMuscles: ['Legs', 'Cardiovascular'],
        secondaryMuscles: ['Core', 'Calves'],
        muscleGroup: 'Legs, Core, Cardio',
        equipment: 'Bicycle',
        requiredEquipment: [],
        difficulty: 'Intermediate',
        movementPattern: 'cardio',
        exerciseType: 'cardio',
        type: ExerciseType.cardio,
        cardioCategory: 'Cycling',
        metValue: 8.5,
        recommendedDuration: 45,
        estimatedCaloriesPerMinute: 10.0,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d0/Cycliste_%C3%A0_place_d%27Italie-Paris_crop.jpg/960px-Cycliste_%C3%A0_place_d%27Italie-Paris_crop.jpg',
        instructions: [
          'Ride with cadence between 80-100 RPM.',
          'Shift gears proactively on climbs.',
        ],
        tips: [
          'Maintain situational awareness and scan road ahead.',
          'Hydrate regularly on long rides.',
        ],
        commonMistakes: ['Grinding in too high a gear at low cadence.'],
        alternatives: ['stationary_bike', 'hiit_cycling'],
      ),
      Exercise(
        id: 'hiit_cycling',
        name: 'HIIT Bike Sprints',
        category: 'cardio',
        primaryMuscles: ['Quadriceps', 'Glutes'],
        secondaryMuscles: ['Cardiovascular', 'Calves'],
        muscleGroup: 'Quads, Glutes, Cardiovascular',
        equipment: 'Air Bike / Spin Bike',
        requiredEquipment: ['stationary_bike'],
        difficulty: 'Advanced',
        movementPattern: 'cardio',
        exerciseType: 'cardio',
        type: ExerciseType.cardio,
        cardioCategory: 'Cycling',
        metValue: 10.5,
        recommendedDuration: 15,
        estimatedCaloriesPerMinute: 13.0,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/0/00/Fahrrad-Ergometer_01_KMJ.jpg/960px-Fahrrad-Ergometer_01_KMJ.jpg',
        instructions: [
          'Pedal maximum power for 15 seconds.',
          'Slow spin for 45 seconds recovery.',
          'Repeat for 8-12 cycles.',
        ],
        tips: [
          'Drive hard through balls of feet on sprints.',
          'Use arms actively if on an air bike.',
        ],
        commonMistakes: [
          'Giving up early on high-resistance sprint intervals.',
        ],
        alternatives: ['sprint_intervals', 'rowing_intervals'],
      ),
      Exercise(
        id: 'rowing_machine',
        name: 'Rowing Machine',
        category: 'cardio',
        primaryMuscles: ['Lats', 'Upper Back'],
        secondaryMuscles: ['Legs', 'Core', 'Cardiovascular'],
        muscleGroup: 'Lats, Upper Back, Legs, Core',
        equipment: 'Rowing Machine',
        requiredEquipment: ['rowing_machine'],
        difficulty: 'Intermediate',
        movementPattern: 'cardio',
        exerciseType: 'cardio',
        type: ExerciseType.cardio,
        cardioCategory: 'Rowing',
        metValue: 7.0,
        recommendedDuration: 20,
        estimatedCaloriesPerMinute: 8.5,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d8/Rowing_Machines.jpg/960px-Rowing_Machines.jpg',
        instructions: [
          'Drive with legs first (60%), swing torso back (20%), pull with arms to chest (20%).',
          'Reverse order on recovery: arms, torso, legs.',
        ],
        tips: [
          'Power on drive, relax on return.',
          'Keep back flat without hunching at catch position.',
        ],
        commonMistakes: [
          'Bending knees before arms have extended on the recovery.',
          'Pulling with arms before legs have driven.',
        ],
        alternatives: ['rowing_intervals', 'stationary_bike', 'treadmill_run'],
      ),
      Exercise(
        id: 'rowing_intervals',
        name: 'Rowing 500m Sprints',
        category: 'cardio',
        primaryMuscles: ['Full Body', 'Cardiovascular'],
        secondaryMuscles: ['Lats', 'Legs'],
        muscleGroup: 'Full Body, Cardiovascular',
        equipment: 'Rowing Machine',
        requiredEquipment: ['rowing_machine'],
        difficulty: 'Advanced',
        movementPattern: 'cardio',
        exerciseType: 'cardio',
        type: ExerciseType.cardio,
        cardioCategory: 'Rowing',
        metValue: 9.5,
        recommendedDuration: 18,
        estimatedCaloriesPerMinute: 12.0,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d8/Rowing_Machines.jpg/960px-Rowing_Machines.jpg',
        instructions: [
          'Row 500 meters at sub-2:00 / 500m split pace.',
          'Rest 90 seconds. Repeat 4 to 6 sets.',
        ],
        tips: [
          'Maintain stroke rate around 28-32 SPM.',
          'Focus on powerful leg drive on every stroke.',
        ],
        commonMistakes: ['Opening torso too early.'],
        alternatives: ['rowing_machine', 'sprint_intervals', 'hiit_cycling'],
      ),
      Exercise(
        id: 'jump_rope',
        name: 'Jump Rope',
        category: 'cardio',
        primaryMuscles: ['Calves', 'Cardiovascular'],
        secondaryMuscles: ['Shoulders', 'Forearms'],
        muscleGroup: 'Calves, Shoulders, Cardiovascular',
        equipment: 'Jump Rope',
        requiredEquipment: ['jump_rope'],
        difficulty: 'Beginner',
        movementPattern: 'cardio',
        exerciseType: 'cardio',
        type: ExerciseType.cardio,
        cardioCategory: 'Conditioning',
        metValue: 11.0,
        recommendedDuration: 15,
        estimatedCaloriesPerMinute: 13.0,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/2/24/Ghanaian_kid_%28skipping_rope%29_06_%28cropped%29.jpg/960px-Ghanaian_kid_%28skipping_rope%29_06_%28cropped%29.jpg',
        instructions: [
          'Stay on balls of feet with light, fast ankle bounces.',
          'Turn rope using wrist rotations rather than entire arms.',
        ],
        tips: [
          'Jump just high enough to clear the rope (1 inch).',
          'Keep elbows close to hips.',
        ],
        commonMistakes: [
          'Double-bouncing between rope turns.',
          'Jumping with excessive knee bend.',
        ],
        alternatives: ['standing_calf_raise', 'burpees', 'mountain_climbers'],
      ),
      Exercise(
        id: 'burpees',
        name: 'Burpees',
        category: 'cardio',
        primaryMuscles: ['Chest', 'Quads', 'Core'],
        secondaryMuscles: ['Shoulders', 'Cardiovascular'],
        muscleGroup: 'Chest, Quads, Core, Full Body',
        equipment: 'None',
        requiredEquipment: [],
        difficulty: 'Intermediate',
        movementPattern: 'cardio',
        exerciseType: 'cardio',
        type: ExerciseType.cardio,
        cardioCategory: 'Conditioning',
        metValue: 8.0,
        recommendedDuration: 12,
        estimatedCaloriesPerMinute: 9.5,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7a/Airborne_Burpee.jpg/960px-Airborne_Burpee.jpg',
        instructions: [
          'Drop into squat, kick feet back into push-up plank, perform push-up.',
          'Jump feet forward and explode vertically with hands overhead.',
        ],
        tips: [
          'Find a consistent, steady rhythm.',
          'Step back instead of jumping back if modifying for lower impact.',
        ],
        commonMistakes: ['Arching lower back on the plank jump-back.'],
        alternatives: ['mountain_climbers', 'push_ups', 'sprint_intervals'],
      ),
      Exercise(
        id: 'mountain_climbers',
        name: 'Mountain Climbers',
        category: 'cardio',
        primaryMuscles: ['Core', 'Hip Flexors'],
        secondaryMuscles: ['Shoulders', 'Cardiovascular'],
        muscleGroup: 'Core, Hip Flexors, Shoulders, Cardio',
        equipment: 'None',
        requiredEquipment: [],
        difficulty: 'Beginner',
        movementPattern: 'cardio',
        exerciseType: 'cardio',
        type: ExerciseType.cardio,
        cardioCategory: 'Conditioning',
        metValue: 8.0,
        recommendedDuration: 10,
        estimatedCaloriesPerMinute: 9.0,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/e/ee/Plank.jpg',
        instructions: [
          'Start in a strong high push-up plank position with hands under shoulders.',
          'Drive knees alternatively towards chest in an explosive, rhythmic running tempo.',
          'Keep core braced and hips level throughout the interval.',
        ],
        tips: [
          'Keep hips level with shoulders.',
          'Press floor away firmly through hands.',
        ],
        commonMistakes: ['Bouncing hips high in the air.'],
        alternatives: ['burpees', 'plank', 'hanging_leg_raise'],
      ),
      Exercise(
        id: 'hiit_circuit',
        name: 'HIIT Full-Body Circuit',
        category: 'cardio',
        primaryMuscles: ['Full Body', 'Cardiovascular'],
        secondaryMuscles: ['Core', 'Legs'],
        muscleGroup: 'Full Body, Cardiovascular',
        equipment: 'None',
        requiredEquipment: [],
        difficulty: 'Intermediate',
        movementPattern: 'cardio',
        exerciseType: 'cardio',
        type: ExerciseType.cardio,
        cardioCategory: 'Conditioning',
        metValue: 10.0,
        recommendedDuration: 20,
        estimatedCaloriesPerMinute: 12.0,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7a/Airborne_Burpee.jpg/960px-Airborne_Burpee.jpg',
        instructions: [
          'Perform 40 seconds work followed by 20 seconds rest across bodyweight movements.',
          'Complete 4 total rounds.',
        ],
        tips: [
          'Push hard during work intervals, catch your breath during rest.',
        ],
        commonMistakes: [
          'Starting at an unsustainable sprint and burning out in round 1.',
        ],
        alternatives: ['burpees', 'sprint_intervals'],
      ),
      Exercise(
        id: 'football',
        name: 'Football / Soccer',
        category: 'cardio',
        primaryMuscles: ['Legs', 'Cardiovascular'],
        secondaryMuscles: ['Core', 'Calves'],
        muscleGroup: 'Legs, Core, Agility, Cardiovascular',
        equipment: 'Football',
        requiredEquipment: [],
        difficulty: 'Intermediate',
        movementPattern: 'cardio',
        exerciseType: 'cardio',
        type: ExerciseType.cardio,
        cardioCategory: 'Sports',
        metValue: 8.0,
        recommendedDuration: 60,
        estimatedCaloriesPerMinute: 9.5,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/4/42/Football_in_Bloomington%2C_Indiana%2C_1995.jpg/960px-Football_in_Bloomington%2C_Indiana%2C_1995.jpg',
        instructions: [
          'Competitive team play with continuous interval changes in direction and sprinting.',
        ],
        tips: ['Keep ankles warm and wear proper footwear for the turf.'],
        commonMistakes: ['Skipping dynamic warm-up before match play.'],
        alternatives: ['basketball', 'outdoor_run', 'sprint_intervals'],
      ),
      Exercise(
        id: 'basketball',
        name: 'Basketball',
        category: 'cardio',
        primaryMuscles: ['Calves', 'Quadriceps'],
        secondaryMuscles: ['Shoulders', 'Cardiovascular'],
        muscleGroup: 'Calves, Quads, Agility, Cardio',
        equipment: 'Basketball Court',
        requiredEquipment: [],
        difficulty: 'Intermediate',
        movementPattern: 'cardio',
        exerciseType: 'cardio',
        type: ExerciseType.cardio,
        cardioCategory: 'Sports',
        metValue: 8.0,
        recommendedDuration: 45,
        estimatedCaloriesPerMinute: 9.5,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/0/06/Steph_Curry_%2851915116957%29.jpg/960px-Steph_Curry_%2851915116957%29.jpg',
        instructions: [
          'Full-court play involving fast breaks, jumping, and defensive slides.',
        ],
        tips: ['Stay low in defensive athletic stance.'],
        commonMistakes: ['Landing stiff-legged after rebounds.'],
        alternatives: ['football', 'sprint_intervals'],
      ),
      Exercise(
        id: 'swimming',
        name: 'Lap Swimming (Freestyle)',
        category: 'cardio',
        primaryMuscles: ['Lats', 'Shoulders'],
        secondaryMuscles: ['Core', 'Cardiovascular'],
        muscleGroup: 'Lats, Shoulders, Core, Cardiovascular',
        equipment: 'Swimming Pool',
        requiredEquipment: [],
        difficulty: 'Intermediate',
        movementPattern: 'cardio',
        exerciseType: 'cardio',
        type: ExerciseType.cardio,
        cardioCategory: 'Sports',
        metValue: 8.3,
        recommendedDuration: 30,
        estimatedCaloriesPerMinute: 9.8,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/b/b6/Incheon_AsianGames_Swimming_19_%2815178565298%29.jpg/960px-Incheon_AsianGames_Swimming_19_%2815178565298%29.jpg',
        instructions: [
          'Maintain horizontal body alignment with continuous flutter kicks.',
          'Rotate hips and shoulders together on each stroke.',
        ],
        tips: ['Exhale smoothly underwater and breathe to the side.'],
        commonMistakes: ['Lifting head straight up out of water to breathe.'],
        alternatives: ['rowing_machine', 'outdoor_run'],
      ),
      Exercise(
        id: 'boxing',
        name: 'Boxing / Heavy Bag',
        category: 'cardio',
        primaryMuscles: ['Shoulders', 'Core'],
        secondaryMuscles: ['Arms', 'Cardiovascular'],
        muscleGroup: 'Shoulders, Core, Cardio, Arms',
        equipment: 'Heavy Bag & Gloves',
        requiredEquipment: [],
        difficulty: 'Intermediate',
        movementPattern: 'cardio',
        exerciseType: 'cardio',
        type: ExerciseType.cardio,
        cardioCategory: 'Sports',
        metValue: 9.0,
        recommendedDuration: 25,
        estimatedCaloriesPerMinute: 11.0,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/d/dd/USMC-100509-M-2339L-173.jpg/960px-USMC-100509-M-2339L-173.jpg',
        instructions: [
          'Throw combinations from strong athletic stance.',
          'Move feet continuously and circle the bag between punch combinations.',
        ],
        tips: [
          'Turn hips and pivot rear foot on punches for maximum power.',
          'Keep hands up protecting chin.',
        ],
        commonMistakes: ['Bending wrists on bag impact.'],
        alternatives: ['burpees', 'hiit_circuit'],
      ),

      // ==========================================
      // 8. MOBILITY & FLEXIBILITY
      // ==========================================
      Exercise(
        id: 'cat_cow_stretch',
        name: 'Cat-Cow Spinal Mobility',
        category: 'mobility',
        primaryMuscles: ['Spine', 'Erectors'],
        secondaryMuscles: ['Core', 'Neck'],
        muscleGroup: 'Spine, Erector Spinae, Core',
        equipment: 'Mat',
        requiredEquipment: ['exercise_mat'],
        difficulty: 'Beginner',
        movementPattern: 'mobility',
        exerciseType: 'mobility',
        type: ExerciseType.mobility,
        cardioCategory: 'Mobility',
        metValue: 3.0,
        recommendedDuration: 10,
        estimatedCaloriesPerMinute: 3.5,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/b/be/Yoga_at_Your_Park_-_Bitilasana.jpg/960px-Yoga_at_Your_Park_-_Bitilasana.jpg',
        instructions: [
          'Start on hands and knees with wrists under shoulders and knees under hips.',
          'Inhale and arch your back, dropping belly toward floor and lifting gaze (Cow).',
          'Exhale and round your spine upward, tucking chin to chest (Cat).',
          'Flow smoothly between positions for 10-12 breath cycles.',
        ],
        tips: [
          'Initiate movement from the tailbone and ripple up the spine.',
          'Keep movement gentle and synchronised with breathing.',
        ],
        commonMistakes: [
          'Rushing through the transitions.',
          'Collapsing into shoulders.',
        ],
        alternatives: ['world_greatest_stretch', 'foam_rolling_full_body'],
      ),
      Exercise(
        id: 'world_greatest_stretch',
        name: "World's Greatest Stretch",
        category: 'mobility',
        primaryMuscles: ['Thoracic Spine', 'Hip Flexors', 'Hamstrings'],
        secondaryMuscles: ['Glutes', 'Adductors'],
        muscleGroup: 'Thoracic Spine, Hip Flexors, Hamstrings',
        equipment: 'Mat',
        requiredEquipment: ['exercise_mat'],
        difficulty: 'Intermediate',
        movementPattern: 'mobility',
        exerciseType: 'mobility',
        type: ExerciseType.mobility,
        cardioCategory: 'Mobility',
        metValue: 3.5,
        recommendedDuration: 10,
        estimatedCaloriesPerMinute: 4.0,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/7/74/Yoga_class_in_Parivritta_Anjaneyasana.jpg',
        instructions: [
          'Step forward into a deep lunge with both hands inside front foot.',
          'Drop back knee lightly, then reach same-side arm up toward ceiling, rotating thoracic spine.',
          'Return hand to floor, shift hips back and straighten front leg for hamstring stretch.',
          'Repeat 5 times per side.',
        ],
        tips: [
          'Follow your rotating hand with your eyes.',
          'Keep back long and breathe deeply.',
        ],
        commonMistakes: ['Rounding thoracic spine instead of rotating.'],
        alternatives: ['cat_cow_stretch', 'hip_flexor_stretch'],
      ),
      Exercise(
        id: 'foam_rolling_full_body',
        name: 'Full-Body Foam Rolling',
        category: 'mobility',
        primaryMuscles: ['Myofascial Tissue', 'Lats', 'Quads'],
        secondaryMuscles: ['Hamstrings', 'Calves'],
        muscleGroup: 'Myofascial Tissue, Lats, Quads, Hamstrings',
        equipment: 'Foam Roller',
        requiredEquipment: [],
        difficulty: 'Beginner',
        movementPattern: 'mobility',
        exerciseType: 'mobility',
        type: ExerciseType.mobility,
        cardioCategory: 'Mobility',
        metValue: 2.8,
        recommendedDuration: 15,
        estimatedCaloriesPerMinute: 3.0,
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/thumb/3/31/Wa%C5%82ek_do_masa%C5%BCu3.jpg/960px-Wa%C5%82ek_do_masa%C5%BCu3.jpg',
        instructions: [
          'Position roller under target muscle group (quads, IT band, upper back, or calves).',
          'Slowly roll back and forth over muscle belly for 30-60 seconds.',
          'Pause on tender trigger points and take deep diaphragmatic breaths.',
        ],
        tips: [
          'Never roll directly over joints or lower back.',
          'Relax muscles being rolled.',
        ],
        commonMistakes: [
          'Rolling too fast.',
          'Holding breath while on tender spots.',
        ],
        alternatives: ['cat_cow_stretch', 'world_greatest_stretch'],
      ),
      Exercise(
        id: 'doorway_chest_stretch',
        name: 'Doorway Pectoral Stretch',
        category: 'mobility',
        primaryMuscles: ['Chest (Pectoralis Major)', 'Anterior Deltoids'],
        secondaryMuscles: ['Biceps'],
        muscleGroup: 'Chest, Anterior Deltoids',
        equipment: 'Doorway / Frame',
        requiredEquipment: [],
        difficulty: 'Beginner',
        movementPattern: 'mobility',
        exerciseType: 'flexibility',
        type: ExerciseType.flexibility,
        cardioCategory: 'Mobility',
        metValue: 2.5,
        recommendedDuration: 8,
        estimatedCaloriesPerMinute: 2.8,
        animationAsset:
            'https://upload.wikimedia.org/wikipedia/commons/4/41/Chest_stretch-CDC_strength_training_for_older_adults.gif',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/4/41/Chest_stretch-CDC_strength_training_for_older_adults.gif',
        instructions: [
          'Stand in doorway and place forearms vertically on doorframes at 90 degrees.',
          'Step one foot forward until a gentle stretch is felt across chest and shoulders.',
          'Hold for 30 seconds while maintaining upright posture.',
        ],
        tips: ['Keep core gently engaged so lower back does not overarch.'],
        commonMistakes: ['Arching lower back instead of opening chest.'],
        alternatives: ['cat_cow_stretch'],
      ),
      Exercise(
        id: 'hip_flexor_stretch',
        name: 'Kneeling Hip Flexor Stretch',
        category: 'mobility',
        primaryMuscles: ['Iliopsoas', 'Rectus Femoris'],
        secondaryMuscles: ['Quadriceps'],
        muscleGroup: 'Iliopsoas, Rectus Femoris, Quads',
        equipment: 'Mat',
        requiredEquipment: ['exercise_mat'],
        difficulty: 'Beginner',
        movementPattern: 'mobility',
        exerciseType: 'flexibility',
        type: ExerciseType.flexibility,
        cardioCategory: 'Mobility',
        metValue: 2.5,
        recommendedDuration: 8,
        estimatedCaloriesPerMinute: 2.8,
        animationAsset:
            'https://upload.wikimedia.org/wikipedia/commons/a/af/Lunge-CDC_strength_training_for_older_adults.gif',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/a/af/Lunge-CDC_strength_training_for_older_adults.gif',
        instructions: [
          'Kneel on one knee with other foot planted forward at 90 degrees.',
          'Tuck pelvis under (posterior pelvic tilt) and squeeze back glute.',
          'Shift weight forward slightly until deep stretch is felt in front of hip.',
          'Hold for 30-45 seconds per side.',
        ],
        tips: [
          'Glute squeeze on back leg is the key to unlocking the hip flexor.',
        ],
        commonMistakes: [
          'Hyperextending lower spine instead of tilting pelvis.',
        ],
        alternatives: ['world_greatest_stretch', 'couch_stretch'],
      ),
      Exercise(
        id: 'couch_stretch',
        name: 'Couch Stretch',
        category: 'mobility',
        primaryMuscles: ['Quadriceps', 'Hip Flexors'],
        secondaryMuscles: ['Glutes'],
        muscleGroup: 'Quadriceps, Hip Flexors, Psoas',
        equipment: 'Wall / Bench / Mat',
        requiredEquipment: ['exercise_mat'],
        difficulty: 'Intermediate',
        movementPattern: 'mobility',
        exerciseType: 'flexibility',
        type: ExerciseType.flexibility,
        cardioCategory: 'Mobility',
        metValue: 2.8,
        recommendedDuration: 8,
        estimatedCaloriesPerMinute: 3.0,
        animationAsset:
            'https://upload.wikimedia.org/wikipedia/commons/8/81/Quad_stretch-CDC_strength_training_for_older_adults.gif',
        imageUrl:
            'https://upload.wikimedia.org/wikipedia/commons/8/81/Quad_stretch-CDC_strength_training_for_older_adults.gif',
        instructions: [
          'Place back shin against a wall or couch with knee close to the corner.',
          'Step other foot forward into a lunge position.',
          'Raise torso upright and squeeze glutes to feel deep quad and hip stretch.',
          'Hold for 45-60 seconds per leg.',
        ],
        tips: [
          'Use yoga blocks or chair to support hands if torso cannot reach full upright.',
        ],
        commonMistakes: ['Leaning forward collapsing the stretch.'],
        alternatives: ['hip_flexor_stretch', 'world_greatest_stretch'],
      ),
    ];
  }
}
