import 'food_item.dart';
import 'macro_target.dart';
import 'meal_entry.dart';

class DailyNutrition {
  final String date;
  final MacroTarget targets;
  final List<MealEntry> meals;
  final double waterLiters;
  final double baseCalories;
  final double baseProtein;
  final double baseCarbs;
  final double baseFat;

  const DailyNutrition({
    required this.date,
    required this.targets,
    required this.meals,
    this.waterLiters = 2.0,
    this.baseCalories = 300.0,
    this.baseProtein = 25.0,
    this.baseCarbs = 40.0,
    this.baseFat = 15.0,
  });

  double get totalCaloriesConsumed {
    final completedCals = meals
        .where((m) => m.isCompleted)
        .fold(0.0, (sum, meal) => sum + meal.totalCalories);
    return baseCalories + completedCals;
  }

  double get totalProteinConsumed {
    final completedProtein = meals
        .where((m) => m.isCompleted)
        .fold(0.0, (sum, meal) => sum + meal.totalProtein);
    return baseProtein + completedProtein;
  }

  double get totalCarbsConsumed {
    final completedCarbs = meals
        .where((m) => m.isCompleted)
        .fold(0.0, (sum, meal) => sum + meal.totalCarbs);
    return baseCarbs + completedCarbs;
  }

  double get totalFatConsumed {
    final completedFat = meals
        .where((m) => m.isCompleted)
        .fold(0.0, (sum, meal) => sum + meal.totalFat);
    return baseFat + completedFat;
  }

  double get caloriesRemaining {
    return (targets.calories - totalCaloriesConsumed).clamp(0.0, targets.calories);
  }

  /// Helper getter evaluating whether daily target goals have been achieved
  bool get isGoalAchieved =>
      totalCaloriesConsumed >= targets.calories ||
      totalProteinConsumed >= targets.proteinGrams ||
      (meals.isNotEmpty && meals.every((m) => m.isCompleted));

  factory DailyNutrition.defaultForDate(String date, [MacroTarget? target]) {
    final t = target ?? MacroTarget.defaultTarget();
    return DailyNutrition(
      date: date,
      targets: t,
      baseCalories: 300.0,
      baseProtein: 25.0,
      baseCarbs: 40.0,
      baseFat: 15.0,
      meals: [
        MealEntry(
          id: 'breakfast_$date',
          name: 'Breakfast',
          category: MealCategory.breakfast,
          timeLabel: '8:00 AM',
          isCompleted: false,
          items: const [
            FoodItem(id: 'b1', name: 'Oatmeal', calories: 350, proteinGrams: 12, carbsGrams: 60, fatGrams: 6, servingSize: '1 cup'),
            FoodItem(id: 'b2', name: 'Whole Eggs', calories: 210, proteinGrams: 18, carbsGrams: 2, fatGrams: 14, servingSize: '3 eggs'),
            FoodItem(id: 'b3', name: 'Banana', calories: 105, proteinGrams: 1.3, carbsGrams: 27, fatGrams: 0.3, servingSize: '1 medium'),
          ],
        ),
        MealEntry(
          id: 'lunch_$date',
          name: 'Lunch',
          category: MealCategory.lunch,
          timeLabel: '1:00 PM',
          isCompleted: false,
          items: const [
            FoodItem(id: 'l1', name: 'Grilled Chicken Breast', calories: 420, proteinGrams: 52, carbsGrams: 0, fatGrams: 8, servingSize: '200g'),
            FoodItem(id: 'l2', name: 'Brown Rice', calories: 215, proteinGrams: 5, carbsGrams: 45, fatGrams: 1.8, servingSize: '1 cup cooked'),
            FoodItem(id: 'l3', name: 'Steamed Broccoli', calories: 55, proteinGrams: 3.7, carbsGrams: 11, fatGrams: 0.6, servingSize: '150g'),
          ],
        ),
        MealEntry(
          id: 'snack_$date',
          name: 'Snack',
          category: MealCategory.snack,
          timeLabel: '4:00 PM',
          isCompleted: false,
          items: const [
            FoodItem(id: 's1', name: 'Whey Protein Shake', calories: 140, proteinGrams: 25, carbsGrams: 3, fatGrams: 2, servingSize: '1 scoop'),
            FoodItem(id: 's2', name: 'Raw Almonds', calories: 160, proteinGrams: 6, carbsGrams: 6, fatGrams: 14, servingSize: '28g'),
          ],
        ),
        MealEntry(
          id: 'dinner_$date',
          name: 'Dinner',
          category: MealCategory.dinner,
          timeLabel: '7:30 PM',
          isCompleted: false,
          items: const [
            FoodItem(id: 'd1', name: 'Atlantic Salmon Filet', calories: 380, proteinGrams: 34, carbsGrams: 0, fatGrams: 22, servingSize: '180g'),
            FoodItem(id: 'd2', name: 'Baked Sweet Potato', calories: 180, proteinGrams: 4, carbsGrams: 41, fatGrams: 0.3, servingSize: '200g'),
          ],
        ),
      ],
      waterLiters: 1.75,
    );
  }

  factory DailyNutrition.fromJson(Map<String, dynamic> json) {
    final bool isLegacy = json['baseCalories'] == null;
    final rawMeals = json['meals'] as List?;
    List<MealEntry> mealList = rawMeals != null
        ? rawMeals.map((e) => MealEntry.fromJson(Map<String, dynamic>.from(e))).toList()
        : <MealEntry>[];

    if (isLegacy) {
      mealList = mealList.map((m) => m.copyWith(isCompleted: false)).toList();
    }

    final targetMap = json['targets'] as Map<String, dynamic>?;
    final targets = targetMap != null ? MacroTarget.fromJson(targetMap) : MacroTarget.defaultTarget();

    return DailyNutrition(
      date: json['date'] as String? ?? DateTime.now().toIso8601String().split('T')[0],
      targets: targets,
      meals: mealList,
      waterLiters: (json['waterLiters'] as num?)?.toDouble() ?? 2.0,
      baseCalories: (json['baseCalories'] as num?)?.toDouble() ?? 300.0,
      baseProtein: (json['baseProtein'] as num?)?.toDouble() ?? 25.0,
      baseCarbs: (json['baseCarbs'] as num?)?.toDouble() ?? 40.0,
      baseFat: (json['baseFat'] as num?)?.toDouble() ?? 15.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'targets': targets.toJson(),
      'meals': meals.map((e) => e.toJson()).toList(),
      'waterLiters': waterLiters,
      'baseCalories': baseCalories,
      'baseProtein': baseProtein,
      'baseCarbs': baseCarbs,
      'baseFat': baseFat,
    };
  }

  DailyNutrition copyWith({
    String? date,
    MacroTarget? targets,
    List<MealEntry>? meals,
    double? waterLiters,
    double? baseCalories,
    double? baseProtein,
    double? baseCarbs,
    double? baseFat,
  }) {
    return DailyNutrition(
      date: date ?? this.date,
      targets: targets ?? this.targets,
      meals: meals ?? List.from(this.meals),
      waterLiters: waterLiters ?? this.waterLiters,
      baseCalories: baseCalories ?? this.baseCalories,
      baseProtein: baseProtein ?? this.baseProtein,
      baseCarbs: baseCarbs ?? this.baseCarbs,
      baseFat: baseFat ?? this.baseFat,
    );
  }
}

