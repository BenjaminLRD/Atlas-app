/// Enum representing primary user fitness goal objectives
enum FitnessGoalType {
  muscleGain,
  fatLoss,
  maintenance,
  strength,
  endurance,
}

/// Enum representing training experience and fitness level
enum FitnessLevel {
  beginner,
  intermediate,
  advanced,
}

/// Enum representing daily physical activity level
enum ActivityLevel {
  sedentary,
  light,
  moderate,
  active,
  veryActive,
}

/// Model representing personalized user fitness goals, biometrics, and calculated macro/calorie targets
class UserGoal {
  final String id;
  final FitnessGoalType goalType;
  final FitnessLevel fitnessLevel;
  final ActivityLevel activityLevel;
  final int age;
  final double height; // cm
  final double currentWeight; // kg
  final double targetWeight; // kg
  final double targetCalories;
  final double targetProtein; // grams
  final double targetCarbohydrates; // grams
  final double targetFats; // grams
  final DateTime createdDate;
  final DateTime updatedDate;

  const UserGoal({
    required this.id,
    required this.goalType,
    required this.fitnessLevel,
    required this.activityLevel,
    required this.age,
    required this.height,
    required this.currentWeight,
    required this.targetWeight,
    required this.targetCalories,
    required this.targetProtein,
    required this.targetCarbohydrates,
    required this.targetFats,
    required this.createdDate,
    required this.updatedDate,
  });

  /// Factory helper for initial default UserGoal state
  factory UserGoal.initial() {
    final now = DateTime.now();
    return UserGoal(
      id: 'default_goal',
      goalType: FitnessGoalType.muscleGain,
      fitnessLevel: FitnessLevel.intermediate,
      activityLevel: ActivityLevel.moderate,
      age: 25,
      height: 175.0,
      currentWeight: 70.0,
      targetWeight: 75.0,
      targetCalories: 2500.0,
      targetProtein: 150.0,
      targetCarbohydrates: 300.0,
      targetFats: 70.0,
      createdDate: now,
      updatedDate: now,
    );
  }

  factory UserGoal.fromJson(Map<String, dynamic> json) {
    return UserGoal(
      id: json['id'] as String? ?? 'goal_${DateTime.now().millisecondsSinceEpoch}',
      goalType: _parseGoalType(json['goalType'] as String?),
      fitnessLevel: _parseFitnessLevel(json['fitnessLevel'] as String?),
      activityLevel: _parseActivityLevel(json['activityLevel'] as String?),
      age: (json['age'] as num?)?.toInt() ?? 25,
      height: (json['height'] as num?)?.toDouble() ?? 175.0,
      currentWeight: (json['currentWeight'] as num?)?.toDouble() ?? 70.0,
      targetWeight: (json['targetWeight'] as num?)?.toDouble() ?? 75.0,
      targetCalories: (json['targetCalories'] as num?)?.toDouble() ?? 2500.0,
      targetProtein: (json['targetProtein'] as num?)?.toDouble() ?? 150.0,
      targetCarbohydrates: (json['targetCarbohydrates'] as num?)?.toDouble() ?? 300.0,
      targetFats: (json['targetFats'] as num?)?.toDouble() ?? 70.0,
      createdDate: json['createdDate'] != null
          ? DateTime.tryParse(json['createdDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedDate: json['updatedDate'] != null
          ? DateTime.tryParse(json['updatedDate'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'goalType': goalType.name,
      'fitnessLevel': fitnessLevel.name,
      'activityLevel': activityLevel.name,
      'age': age,
      'height': height,
      'currentWeight': currentWeight,
      'targetWeight': targetWeight,
      'targetCalories': targetCalories,
      'targetProtein': targetProtein,
      'targetCarbohydrates': targetCarbohydrates,
      'targetFats': targetFats,
      'createdDate': createdDate.toIso8601String(),
      'updatedDate': updatedDate.toIso8601String(),
    };
  }

  UserGoal copyWith({
    String? id,
    FitnessGoalType? goalType,
    FitnessLevel? fitnessLevel,
    ActivityLevel? activityLevel,
    int? age,
    double? height,
    double? currentWeight,
    double? targetWeight,
    double? targetCalories,
    double? targetProtein,
    double? targetCarbohydrates,
    double? targetFats,
    DateTime? createdDate,
    DateTime? updatedDate,
  }) {
    return UserGoal(
      id: id ?? this.id,
      goalType: goalType ?? this.goalType,
      fitnessLevel: fitnessLevel ?? this.fitnessLevel,
      activityLevel: activityLevel ?? this.activityLevel,
      age: age ?? this.age,
      height: height ?? this.height,
      currentWeight: currentWeight ?? this.currentWeight,
      targetWeight: targetWeight ?? this.targetWeight,
      targetCalories: targetCalories ?? this.targetCalories,
      targetProtein: targetProtein ?? this.targetProtein,
      targetCarbohydrates: targetCarbohydrates ?? this.targetCarbohydrates,
      targetFats: targetFats ?? this.targetFats,
      createdDate: createdDate ?? this.createdDate,
      updatedDate: updatedDate ?? this.updatedDate,
    );
  }

  static FitnessGoalType _parseGoalType(String? name) {
    if (name == null) return FitnessGoalType.muscleGain;
    return FitnessGoalType.values.firstWhere(
      (e) => e.name == name,
      orElse: () => FitnessGoalType.muscleGain,
    );
  }

  static FitnessLevel _parseFitnessLevel(String? name) {
    if (name == null) return FitnessLevel.intermediate;
    return FitnessLevel.values.firstWhere(
      (e) => e.name == name,
      orElse: () => FitnessLevel.intermediate,
    );
  }

  static ActivityLevel _parseActivityLevel(String? name) {
    if (name == null) return ActivityLevel.moderate;
    return ActivityLevel.values.firstWhere(
      (e) => e.name == name,
      orElse: () => ActivityLevel.moderate,
    );
  }

  @override
  String toString() {
    return 'UserGoal(id: $id, goalType: ${goalType.name}, fitnessLevel: ${fitnessLevel.name}, activityLevel: ${activityLevel.name}, weight: ${currentWeight}kg -> ${targetWeight}kg, calories: ${targetCalories}kcal)';
  }
}
