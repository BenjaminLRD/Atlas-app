/// Structured Exercise model for advanced analytics, AI coaching, and exercise registry.
class Exercise {
  final String id;
  final String name;
  final String muscleGroup;
  final String equipment;
  final String difficulty;
  final List<String> instructions;
  final List<String> tips;
  final List<String> commonMistakes;
  final String? imageUrl;
  final String? videoUrl;
  final List<String> alternatives;

  const Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.equipment,
    this.difficulty = 'Intermediate',
    this.instructions = const [],
    this.tips = const [],
    this.commonMistakes = const [],
    this.imageUrl,
    this.videoUrl,
    this.alternatives = const [],
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    final rawInstructions = json['instructions'] as List?;
    final List<String> instructionsList = rawInstructions != null
        ? rawInstructions.map((e) => e.toString()).toList()
        : [];

    final rawTips = json['tips'] as List?;
    final List<String> tipsList = rawTips != null
        ? rawTips.map((e) => e.toString()).toList()
        : [];

    final rawMistakes = json['commonMistakes'] as List?;
    final List<String> mistakesList = rawMistakes != null
        ? rawMistakes.map((e) => e.toString()).toList()
        : [];

    final rawAlternatives = json['alternatives'] as List?;
    final List<String> alternativesList = rawAlternatives != null
        ? rawAlternatives.map((e) => e.toString()).toList()
        : [];

    return Exercise(
      id: json['id'] as String? ?? json['name']?.toString().toLowerCase().replaceAll(' ', '_') ?? '',
      name: json['name'] as String? ?? 'Exercise',
      muscleGroup: json['muscleGroup'] as String? ?? json['primaryTarget'] as String? ?? 'Full Body',
      equipment: json['equipment'] as String? ?? 'Barbell',
      difficulty: json['difficulty'] as String? ?? 'Intermediate',
      instructions: instructionsList,
      tips: tipsList,
      commonMistakes: mistakesList,
      imageUrl: json['imageUrl'] as String? ?? json['imagePath'] as String?,
      videoUrl: json['videoUrl'] as String?,
      alternatives: alternativesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'muscleGroup': muscleGroup,
      'equipment': equipment,
      'difficulty': difficulty,
      'instructions': instructions,
      'tips': tips,
      'commonMistakes': commonMistakes,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'alternatives': alternatives,
    };
  }

  Exercise copyWith({
    String? id,
    String? name,
    String? muscleGroup,
    String? equipment,
    String? difficulty,
    List<String>? instructions,
    List<String>? tips,
    List<String>? commonMistakes,
    String? imageUrl,
    String? videoUrl,
    List<String>? alternatives,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      equipment: equipment ?? this.equipment,
      difficulty: difficulty ?? this.difficulty,
      instructions: instructions ?? List.from(this.instructions),
      tips: tips ?? List.from(this.tips),
      commonMistakes: commonMistakes ?? List.from(this.commonMistakes),
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      alternatives: alternatives ?? List.from(this.alternatives),
    );
  }

  /// Built-in static registry of default exercises
  static List<Exercise> defaultRegistry() {
    return const [
      Exercise(
        id: 'barbell_back_squat',
        name: 'Barbell Back Squat',
        muscleGroup: 'Quadriceps, Glutes',
        equipment: 'Barbell',
        difficulty: 'Intermediate',
        instructions: [
          'Rest barbell across upper trapezius muscles.',
          'Inhale deeply and brace core tight.',
          'Hinge hips back and bend knees until thighs are parallel to ground.',
          'Drive firmly through heels to return to standing position.'
        ],
        tips: [
          'Keep chest upright and eyes facing forward.',
          'Brace core tight before descent.',
          'Drive through heels and maintain knee alignment.'
        ],
        commonMistakes: [
          'Knees caving inward during ascent.',
          'Curving lower back (butt wink).',
          'Lifting heels off the floor.'
        ],
        imageUrl: 'assets/exercises/squat.png',
        alternatives: ['Goblet Squat', 'Leg Press', 'Front Squat'],
      ),
      Exercise(
        id: 'romanian_deadlift',
        name: 'Romanian Deadlift',
        muscleGroup: 'Hamstrings, Glutes',
        equipment: 'Barbell',
        difficulty: 'Intermediate',
        instructions: [
          'Stand erect holding barbell with overhand grip.',
          'Push hips back while maintaining slight bend in knees.',
          'Lower bar along thighs until deep stretch is felt in hamstrings.',
          'Engage glutes to drive hips forward back to starting position.'
        ],
        tips: [
          'Push hips backward with soft knee bend.',
          'Keep back flat and spine neutral throughout.',
          'Control eccentric lowering phase.'
        ],
        commonMistakes: [
          'Rounding upper or lower spine.',
          'Bending knees too much turning it into a squat.',
          'Allowing bar to drift away from legs.'
        ],
        imageUrl: 'assets/exercises/rdl.png',
        alternatives: ['Dumbbell RDL', 'Glute Ham Raise', 'Single-Leg RDL'],
      ),
      Exercise(
        id: 'bench_press',
        name: 'Barbell Bench Press',
        muscleGroup: 'Chest, Triceps, Anterior Deltoids',
        equipment: 'Barbell & Bench',
        difficulty: 'Intermediate',
        instructions: [
          'Lie on bench with feet flat on floor.',
          'Unrack bar with grip slightly wider than shoulder-width.',
          'Lower bar under control to mid-chest level.',
          'Press bar upwards forcefully until arms are extended.'
        ],
        tips: [
          'Retract shoulder blades into bench.',
          'Maintain 45-degree elbow angle to protect shoulders.',
          'Keep feet firmly planted for leg drive.'
        ],
        commonMistakes: [
          'Flaring elbows out at 90 degrees.',
          'Bouncing bar off chest.',
          'Lifting glutes off bench during press.'
        ],
        imageUrl: 'assets/exercises/bench_press.png',
        alternatives: ['Dumbbell Bench Press', 'Push-ups', 'Incline Press'],
      ),
    ];
  }
}
