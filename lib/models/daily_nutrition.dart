import 'food_item.dart';
import 'macro_target.dart';
import 'meal_entry.dart';
import 'nutrition_totals.dart';

class DailyNutrition {
  final String date;
  final MacroTarget targets;
  final List<MealEntry> meals;
  final double waterLiters;

  /// Amounts counted as consumed on top of completed meals. Zero by default:
  /// they only hold a value when something explicitly recorded one.
  final double baseCalories;
  final double baseProtein;
  final double baseCarbs;
  final double baseFat;

  /// Items counted in the base amounts whose calories are unknown. For
  /// reading only (set by [withLogged]); it is not saved.
  final int baseUnknownCalorieItems;
  final int baseUnknownProteinItems;
  final int baseUnknownCarbItems;
  final int baseUnknownFatItems;
  final int baseItemCount;

  /// Written with every saved day: the base amounts are real, not the old
  /// automatic starting amount (see [fromJson]).
  static const String baseAmountsVersionKey = 'baseAmountsVersion';
  static const int baseAmountsVersion = 2;

  const DailyNutrition({
    required this.date,
    required this.targets,
    required this.meals,
    this.waterLiters = 2.0,
    this.baseCalories = 0.0,
    this.baseProtein = 0.0,
    this.baseCarbs = 0.0,
    this.baseFat = 0.0,
    this.baseUnknownCalorieItems = 0,
    this.baseUnknownProteinItems = 0,
    this.baseUnknownCarbItems = 0,
    this.baseUnknownFatItems = 0,
    this.baseItemCount = 0,
  });

  /// Consumed amounts: the explicit base amounts (zero unless something set
  /// them) plus the meals marked completed.
  NutritionTotals get totalsConsumed =>
      NutritionTotals(
        calories: baseCalories,
        protein: baseProtein,
        carbs: baseCarbs,
        fat: baseFat,
        unknownCalorieItems: baseUnknownCalorieItems,
        unknownProteinItems: baseUnknownProteinItems,
        unknownCarbItems: baseUnknownCarbItems,
        unknownFatItems: baseUnknownFatItems,
        itemCount: baseItemCount,
      ) +
      NutritionTotals.fromMeals(meals.where((m) => m.isCompleted));

  double get totalCaloriesConsumed => totalsConsumed.calories;

  /// Consumed items whose calories are unknown ([totalCaloriesConsumed] is
  /// then a minimum).
  int get unknownCalorieItems => totalsConsumed.unknownCalorieItems;

  /// [totalCaloriesConsumed] as shown: "190", or "190+" when a minimum.
  String get totalCaloriesLabel => totalsConsumed.caloriesLabel;

  /// The macros as shown ("14", "14+" or a dash), without the unit.
  String get totalProteinLabel => totalsConsumed.proteinLabel;
  String get totalCarbsLabel => totalsConsumed.carbsLabel;
  String get totalFatLabel => totalsConsumed.fatLabel;

  /// What is left to reach [target], or null when some food lacks the value
  /// (see [NutritionTotals.proteinRemaining]).
  double? proteinRemaining(double target) =>
      totalsConsumed.proteinRemaining(target);

  double? caloriesRemainingTo(double target) =>
      totalsConsumed.caloriesRemaining(target);

  double get totalProteinConsumed => totalsConsumed.protein;

  double get totalCarbsConsumed => totalsConsumed.carbs;

  double get totalFatConsumed => totalsConsumed.fat;

  /// A copy that also counts [logged] (the foods logged that day) as consumed.
  /// For reading only; the logged foods live in the nutrition log, not here.
  DailyNutrition withLogged(NutritionTotals logged) => copyWith(
    baseCalories: baseCalories + logged.calories,
    baseProtein: baseProtein + logged.protein,
    baseCarbs: baseCarbs + logged.carbs,
    baseFat: baseFat + logged.fat,
    baseUnknownCalorieItems:
        baseUnknownCalorieItems + logged.unknownCalorieItems,
    baseUnknownProteinItems:
        baseUnknownProteinItems + logged.unknownProteinItems,
    baseUnknownCarbItems: baseUnknownCarbItems + logged.unknownCarbItems,
    baseUnknownFatItems: baseUnknownFatItems + logged.unknownFatItems,
    baseItemCount: baseItemCount + logged.itemCount,
  );

  double get caloriesRemaining {
    return (targets.calories - totalCaloriesConsumed).clamp(
      0.0,
      targets.calories,
    );
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
      meals: [
        MealEntry(
          id: 'breakfast_$date',
          name: 'Breakfast',
          category: MealCategory.breakfast,
          timeLabel: '8:00 AM',
          isCompleted: false,
          items: const [
            FoodItem(
              id: 'b1',
              name: 'Oatmeal',
              calories: 350,
              proteinGrams: 12,
              carbsGrams: 60,
              fatGrams: 6,
              servingSize: '1 cup',
            ),
            FoodItem(
              id: 'b2',
              name: 'Whole Eggs',
              calories: 210,
              proteinGrams: 18,
              carbsGrams: 2,
              fatGrams: 14,
              servingSize: '3 eggs',
            ),
            FoodItem(
              id: 'b3',
              name: 'Banana',
              calories: 105,
              proteinGrams: 1.3,
              carbsGrams: 27,
              fatGrams: 0.3,
              servingSize: '1 medium',
            ),
          ],
        ),
        MealEntry(
          id: 'lunch_$date',
          name: 'Lunch',
          category: MealCategory.lunch,
          timeLabel: '1:00 PM',
          isCompleted: false,
          items: const [
            FoodItem(
              id: 'l1',
              name: 'Grilled Chicken Breast',
              calories: 420,
              proteinGrams: 52,
              carbsGrams: 0,
              fatGrams: 8,
              servingSize: '200g',
            ),
            FoodItem(
              id: 'l2',
              name: 'Brown Rice',
              calories: 215,
              proteinGrams: 5,
              carbsGrams: 45,
              fatGrams: 1.8,
              servingSize: '1 cup cooked',
            ),
            FoodItem(
              id: 'l3',
              name: 'Steamed Broccoli',
              calories: 55,
              proteinGrams: 3.7,
              carbsGrams: 11,
              fatGrams: 0.6,
              servingSize: '150g',
            ),
          ],
        ),
        MealEntry(
          id: 'snack_$date',
          name: 'Snack',
          category: MealCategory.snack,
          timeLabel: '4:00 PM',
          isCompleted: false,
          items: const [
            FoodItem(
              id: 's1',
              name: 'Whey Protein Shake',
              calories: 140,
              proteinGrams: 25,
              carbsGrams: 3,
              fatGrams: 2,
              servingSize: '1 scoop',
            ),
            FoodItem(
              id: 's2',
              name: 'Raw Almonds',
              calories: 160,
              proteinGrams: 6,
              carbsGrams: 6,
              fatGrams: 14,
              servingSize: '28g',
            ),
          ],
        ),
        MealEntry(
          id: 'dinner_$date',
          name: 'Dinner',
          category: MealCategory.dinner,
          timeLabel: '7:30 PM',
          isCompleted: false,
          items: const [
            FoodItem(
              id: 'd1',
              name: 'Atlantic Salmon Filet',
              calories: 380,
              proteinGrams: 34,
              carbsGrams: 0,
              fatGrams: 22,
              servingSize: '180g',
            ),
            FoodItem(
              id: 'd2',
              name: 'Baked Sweet Potato',
              calories: 180,
              proteinGrams: 4,
              carbsGrams: 41,
              fatGrams: 0.3,
              servingSize: '200g',
            ),
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
        ? rawMeals
              .map((e) => MealEntry.fromJson(Map<String, dynamic>.from(e)))
              .toList()
        : <MealEntry>[];

    if (isLegacy) {
      mealList = mealList.map((m) => m.copyWith(isCompleted: false)).toList();
    }

    final targetMap = json['targets'] as Map<String, dynamic>?;
    final targets = targetMap != null
        ? MacroTarget.fromJson(targetMap)
        : MacroTarget.defaultTarget();

    var baseCalories = (json['baseCalories'] as num?)?.toDouble() ?? 0.0;
    var baseProtein = (json['baseProtein'] as num?)?.toDouble() ?? 0.0;
    var baseCarbs = (json['baseCarbs'] as num?)?.toDouble() ?? 0.0;
    var baseFat = (json['baseFat'] as num?)?.toDouble() ?? 0.0;
    // Records written before the marker existed stored 300/25/40/15 as an
    // automatic starting amount on every day (nothing in the app let a user
    // enter these fields). Those exact numbers without the marker are that
    // placeholder and read as 0. With the marker, the numbers are taken as
    // written, so a value equal to the old default is kept.
    final hasMarker = json[baseAmountsVersionKey] != null;
    if (!hasMarker &&
        baseCalories == 300.0 &&
        baseProtein == 25.0 &&
        baseCarbs == 40.0 &&
        baseFat == 15.0) {
      baseCalories = baseProtein = baseCarbs = baseFat = 0.0;
    }

    return DailyNutrition(
      date:
          json['date'] as String? ??
          DateTime.now().toIso8601String().split('T')[0],
      targets: targets,
      meals: mealList,
      waterLiters: (json['waterLiters'] as num?)?.toDouble() ?? 2.0,
      baseCalories: baseCalories,
      baseProtein: baseProtein,
      baseCarbs: baseCarbs,
      baseFat: baseFat,
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
      baseAmountsVersionKey: baseAmountsVersion,
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
    int? baseUnknownCalorieItems,
    int? baseUnknownProteinItems,
    int? baseUnknownCarbItems,
    int? baseUnknownFatItems,
    int? baseItemCount,
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
      baseUnknownCalorieItems:
          baseUnknownCalorieItems ?? this.baseUnknownCalorieItems,
      baseUnknownProteinItems:
          baseUnknownProteinItems ?? this.baseUnknownProteinItems,
      baseUnknownCarbItems: baseUnknownCarbItems ?? this.baseUnknownCarbItems,
      baseUnknownFatItems: baseUnknownFatItems ?? this.baseUnknownFatItems,
      baseItemCount: baseItemCount ?? this.baseItemCount,
    );
  }
}
