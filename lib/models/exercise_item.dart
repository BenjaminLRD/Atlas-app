class ExerciseItem {
  final String id;
  final String name;
  final String primaryTarget;
  final String? imagePath;
  final String? imageUrl;
  final List<String> tips;
  final int defaultSets;
  final int defaultReps;
  final double defaultWeight;
  final List<Map<String, dynamic>> sets;

  const ExerciseItem({
    required this.id,
    required this.name,
    required this.primaryTarget,
    this.imagePath,
    this.imageUrl,
    this.tips = const [],
    this.defaultSets = 4,
    this.defaultReps = 10,
    this.defaultWeight = 60.0,
    required this.sets,
  });

  factory ExerciseItem.fromJson(Map<String, dynamic> json) {
    final rawSets = json['sets'] as List?;
    final List<Map<String, dynamic>> setsList = rawSets != null
        ? rawSets.map((e) => Map<String, dynamic>.from(e as Map)).toList()
        : [];

    final rawTips = json['tips'] as List?;
    final List<String> tipsList = rawTips != null
        ? rawTips.map((e) => e.toString()).toList()
        : [];

    final rawImagePath = json['imagePath'] as String?;
    final sanitizedPath = rawImagePath != null && rawImagePath.startsWith('assets/assets/')
        ? rawImagePath.replaceFirst('assets/assets/', 'assets/')
        : rawImagePath;

    return ExerciseItem(
      id: json['id'] as String? ?? json['name']?.toString().toLowerCase().replaceAll(' ', '_') ?? '',
      name: json['name'] as String? ?? 'Exercise',
      primaryTarget: json['primaryTarget'] as String? ?? 'Target Muscle Group',
      imagePath: sanitizedPath,
      imageUrl: json['imageUrl'] as String?,
      tips: tipsList,
      defaultSets: (json['defaultSets'] as num?)?.toInt() ?? setsList.length,
      defaultReps: (json['defaultReps'] as num?)?.toInt() ?? (setsList.isNotEmpty ? (setsList.first['reps'] as num).toInt() : 10),
      defaultWeight: (json['defaultWeight'] as num?)?.toDouble() ?? (setsList.isNotEmpty ? (setsList.first['weight'] as num).toDouble() : 0.0),
      sets: setsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'primaryTarget': primaryTarget,
      'imagePath': imagePath,
      'imageUrl': imageUrl,
      'tips': tips,
      'defaultSets': defaultSets,
      'defaultReps': defaultReps,
      'defaultWeight': defaultWeight,
      'sets': sets,
    };
  }

  ExerciseItem copyWith({
    String? id,
    String? name,
    String? primaryTarget,
    String? imagePath,
    String? imageUrl,
    List<String>? tips,
    int? defaultSets,
    int? defaultReps,
    double? defaultWeight,
    List<Map<String, dynamic>>? sets,
  }) {
    return ExerciseItem(
      id: id ?? this.id,
      name: name ?? this.name,
      primaryTarget: primaryTarget ?? this.primaryTarget,
      imagePath: imagePath ?? this.imagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      tips: tips ?? List.from(this.tips),
      defaultSets: defaultSets ?? this.defaultSets,
      defaultReps: defaultReps ?? this.defaultReps,
      defaultWeight: defaultWeight ?? this.defaultWeight,
      sets: sets ?? List.from(this.sets),
    );
  }
}
