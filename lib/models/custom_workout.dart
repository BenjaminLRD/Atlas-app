import 'dart:convert';

/// One exercise in a workout the athlete built: how many sets, and either reps
/// per set or, for a timed exercise, seconds per set.
class CustomExercise {
  final String exerciseId;
  final String name;
  final String muscleGroup;
  final int sets;
  final int reps;

  /// Seconds per set for a timed exercise (a plank); null for rep-based ones.
  final int? durationSec;

  const CustomExercise({
    required this.exerciseId,
    required this.name,
    this.muscleGroup = '',
    this.sets = 3,
    this.reps = 10,
    this.durationSec,
  });

  static const int maxSets = 10;
  static const int maxReps = 100;
  static const int maxDurationSec = 600;

  bool get isTimed => durationSec != null;

  CustomExercise copyWith({int? sets, int? reps, int? durationSec}) =>
      CustomExercise(
        exerciseId: exerciseId,
        name: name,
        muscleGroup: muscleGroup,
        sets: (sets ?? this.sets).clamp(1, maxSets),
        reps: (reps ?? this.reps).clamp(1, maxReps),
        durationSec: durationSec == null
            ? this.durationSec
            : durationSec.clamp(5, maxDurationSec),
      );

  Map<String, dynamic> toJson() => {
    'id': exerciseId,
    'name': name,
    'muscle': muscleGroup,
    'sets': sets,
    'reps': reps,
    if (durationSec != null) 'durationSec': durationSec,
  };

  static CustomExercise? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    if (id is! String || name is! String || name.trim().isEmpty) return null;
    int n(Object? v, int fallback, int lo, int hi) =>
        v is num ? v.toInt().clamp(lo, hi) : fallback;
    final dur = raw['durationSec'];
    return CustomExercise(
      exerciseId: id,
      name: name,
      muscleGroup: raw['muscle'] is String ? raw['muscle'] as String : '',
      sets: n(raw['sets'], 3, 1, maxSets),
      reps: n(raw['reps'], 10, 1, maxReps),
      durationSec: dur is num ? dur.toInt().clamp(5, maxDurationSec) : null,
    );
  }
}

/// A workout the athlete built and saved.
class CustomWorkout {
  final String id;
  final String name;
  final List<CustomExercise> exercises;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomWorkout({
    required this.id,
    required this.name,
    required this.exercises,
    required this.createdAt,
    required this.updatedAt,
  });

  static const int maxNameLength = 40;
  static const int maxExercises = 30;

  int get totalSets => exercises.fold(0, (a, e) => a + e.sets);

  /// Rough session length, labelled as an estimate everywhere it is shown:
  /// working time (3 s per rep, or the set's seconds) plus about 75 s of rest
  /// after each set. The session itself chooses the real rest per exercise.
  int get estimatedMinutes {
    var seconds = 0;
    for (final e in exercises) {
      final work = e.durationSec ?? e.reps * 3;
      seconds += e.sets * (work + 75);
    }
    return (seconds / 60).round();
  }

  CustomWorkout copyWith({
    String? name,
    List<CustomExercise>? exercises,
    DateTime? updatedAt,
  }) => CustomWorkout(
    id: id,
    name: name ?? this.name,
    exercises: exercises ?? this.exercises,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// What the workout session screen takes to run this workout.
  List<Map<String, dynamic>> toSessionExercises() => [
    for (final e in exercises)
      {
        'id': e.exerciseId,
        'name': e.name,
        'muscleGroup': e.muscleGroup,
        'sets': [
          for (var i = 0; i < e.sets; i++)
            {
              'reps': e.isTimed ? 1 : e.reps,
              // No load is invented: the athlete enters their own weight.
              'weight': 0.0,
              if (e.isTimed) 'durationSeconds': e.durationSec,
              'completed': false,
            },
        ],
      },
  ];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'exercises': [for (final e in exercises) e.toJson()],
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  static CustomWorkout? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    if (id is! String || name is! String) return null;
    final list = raw['exercises'];
    final exercises = <CustomExercise>[
      if (list is List)
        for (final e in list) ?CustomExercise.tryParse(e),
    ];
    final now = DateTime.now();
    return CustomWorkout(
      id: id,
      name: name,
      exercises: exercises,
      createdAt: DateTime.tryParse('${raw['createdAt']}') ?? now,
      updatedAt: DateTime.tryParse('${raw['updatedAt']}') ?? now,
    );
  }

  static String encodeAll(List<CustomWorkout> all) =>
      jsonEncode([for (final w in all) w.toJson()]);

  static List<CustomWorkout> decodeAll(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return [for (final e in list) ?tryParse(e)];
    } catch (_) {
      return [];
    }
  }
}
