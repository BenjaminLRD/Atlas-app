/// Enum representing target weight objective
enum WeightGoalType {
  gain('Weight Gain / Lean Bulk'),
  lose('Fat Loss / Cut'),
  maintain('Weight Maintenance'),
  recomposition('Body Recomposition');

  final String displayName;
  const WeightGoalType(this.displayName);
}

/// Enum representing dietary preference
enum DietPreference {
  vegetarian('Vegetarian'),
  nonVegetarian('Non-Vegetarian'),
  vegan('Vegan'),
  noRestrictions('No Restrictions');

  final String displayName;
  const DietPreference(this.displayName);
}

/// Enum representing daily meal frequency
enum MealFrequency {
  threeMeals(3, '3 Meals / Day'),
  fourMeals(4, '4 Meals / Day'),
  fiveMeals(5, '5 Meals / Day');

  final int count;
  final String displayName;
  const MealFrequency(this.count, this.displayName);
}

/// Enum representing user budget tier for grocery and meal generation
enum BudgetTier {
  low('Budget-Friendly'),
  medium('Standard / Balanced'),
  high('Premium / Gourmet');

  final String displayName;
  const BudgetTier(this.displayName);
}

/// Domain model representing a user's target transformation goal,
/// timeline, dietary preferences, and generated nutritional targets.
class WeightGoal {
  final String id;
  final String userId;
  final double currentWeight;
  final double targetWeight;
  final int targetWeeks;
  final WeightGoalType type;
  final DietPreference diet;
  final MealFrequency mealsPerDay;
  final BudgetTier budget;
  final double dailyCalorieTarget;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final double expectedWeeklyRateKg;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WeightGoal({
    required this.id,
    required this.userId,
    required this.currentWeight,
    required this.targetWeight,
    required this.targetWeeks,
    required this.type,
    required this.diet,
    required this.mealsPerDay,
    this.budget = BudgetTier.medium,
    required this.dailyCalorieTarget,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.expectedWeeklyRateKg,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Total kilograms to change (positive for gain, negative for loss)
  double get weightDifferenceKg => targetWeight - currentWeight;

  /// Absolute kilogram delta
  double get totalTargetDeltaKg => (targetWeight - currentWeight).abs();

  /// Whether this goal is an active mass gain program
  bool get isWeightGain =>
      type == WeightGoalType.gain || targetWeight > currentWeight;

  /// Computes progress fraction (0.0 to 1.0) given the user's latest logged weight
  double progressFraction(double currentLoggedWeight) {
    if (totalTargetDeltaKg == 0) return 1.0;
    if (isWeightGain) {
      final gained = currentLoggedWeight - currentWeight;
      return (gained / totalTargetDeltaKg).clamp(0.0, 1.0);
    } else {
      final lost = currentWeight - currentLoggedWeight;
      return (lost / totalTargetDeltaKg).clamp(0.0, 1.0);
    }
  }

  /// Calculates elapsed weeks since creation
  int get weeksElapsed {
    final diff = DateTime.now().difference(createdAt).inDays;
    return (diff / 7).floor().clamp(0, targetWeeks);
  }

  /// Estimated completion date
  DateTime get targetCompletionDate =>
      createdAt.add(Duration(days: targetWeeks * 7));

  /// Factory constructor for initial default sample goal (e.g. 55kg -> 70kg in 24 weeks)
  factory WeightGoal.sampleGain() {
    final now = DateTime.now();
    return WeightGoal(
      id: 'wg_sample_gain',
      userId: 'user_01',
      currentWeight: 55.0,
      targetWeight: 70.0,
      targetWeeks: 24, // 6 months
      type: WeightGoalType.gain,
      diet: DietPreference.nonVegetarian,
      mealsPerDay: MealFrequency.fourMeals,
      budget: BudgetTier.medium,
      dailyCalorieTarget: 2900.0,
      proteinGrams: 140.0,
      carbsGrams: 375.0,
      fatGrams: 90.0,
      expectedWeeklyRateKg: 0.625,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory WeightGoal.fromJson(Map<String, dynamic> json) {
    return WeightGoal(
      id:
          json['id'] as String? ??
          'wg_${DateTime.now().millisecondsSinceEpoch}',
      userId: json['userId'] as String? ?? 'default_user',
      currentWeight: (json['currentWeight'] as num?)?.toDouble() ?? 55.0,
      targetWeight: (json['targetWeight'] as num?)?.toDouble() ?? 70.0,
      targetWeeks: (json['targetWeeks'] as num?)?.toInt() ?? 24,
      type: _parseGoalType(json['type'] as String?),
      diet: _parseDietPreference(json['diet'] as String?),
      mealsPerDay: _parseMealFrequency(json['mealsPerDay'] as String?),
      budget: _parseBudgetTier(json['budget'] as String?),
      dailyCalorieTarget:
          (json['dailyCalorieTarget'] as num?)?.toDouble() ?? 2900.0,
      proteinGrams: (json['proteinGrams'] as num?)?.toDouble() ?? 140.0,
      carbsGrams: (json['carbsGrams'] as num?)?.toDouble() ?? 375.0,
      fatGrams: (json['fatGrams'] as num?)?.toDouble() ?? 90.0,
      expectedWeeklyRateKg:
          (json['expectedWeeklyRateKg'] as num?)?.toDouble() ?? 0.625,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'currentWeight': currentWeight,
      'targetWeight': targetWeight,
      'targetWeeks': targetWeeks,
      'type': type.name,
      'diet': diet.name,
      'mealsPerDay': mealsPerDay.name,
      'budget': budget.name,
      'dailyCalorieTarget': dailyCalorieTarget,
      'proteinGrams': proteinGrams,
      'carbsGrams': carbsGrams,
      'fatGrams': fatGrams,
      'expectedWeeklyRateKg': expectedWeeklyRateKg,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  WeightGoal copyWith({
    String? id,
    String? userId,
    double? currentWeight,
    double? targetWeight,
    int? targetWeeks,
    WeightGoalType? type,
    DietPreference? diet,
    MealFrequency? mealsPerDay,
    BudgetTier? budget,
    double? dailyCalorieTarget,
    double? proteinGrams,
    double? carbsGrams,
    double? fatGrams,
    double? expectedWeeklyRateKg,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WeightGoal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      currentWeight: currentWeight ?? this.currentWeight,
      targetWeight: targetWeight ?? this.targetWeight,
      targetWeeks: targetWeeks ?? this.targetWeeks,
      type: type ?? this.type,
      diet: diet ?? this.diet,
      mealsPerDay: mealsPerDay ?? this.mealsPerDay,
      budget: budget ?? this.budget,
      dailyCalorieTarget: dailyCalorieTarget ?? this.dailyCalorieTarget,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      carbsGrams: carbsGrams ?? this.carbsGrams,
      fatGrams: fatGrams ?? this.fatGrams,
      expectedWeeklyRateKg: expectedWeeklyRateKg ?? this.expectedWeeklyRateKg,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static WeightGoalType _parseGoalType(String? str) {
    if (str == null) return WeightGoalType.gain;
    return WeightGoalType.values.firstWhere(
      (e) => e.name.toLowerCase() == str.toLowerCase(),
      orElse: () => WeightGoalType.gain,
    );
  }

  static DietPreference _parseDietPreference(String? str) {
    if (str == null) return DietPreference.nonVegetarian;
    return DietPreference.values.firstWhere(
      (e) => e.name.toLowerCase() == str.toLowerCase(),
      orElse: () => DietPreference.nonVegetarian,
    );
  }

  static MealFrequency _parseMealFrequency(String? str) {
    if (str == null) return MealFrequency.fourMeals;
    return MealFrequency.values.firstWhere(
      (e) => e.name.toLowerCase() == str.toLowerCase(),
      orElse: () => MealFrequency.fourMeals,
    );
  }

  static BudgetTier _parseBudgetTier(String? str) {
    if (str == null) return BudgetTier.medium;
    return BudgetTier.values.firstWhere(
      (e) => e.name.toLowerCase() == str.toLowerCase(),
      orElse: () => BudgetTier.medium,
    );
  }
}
