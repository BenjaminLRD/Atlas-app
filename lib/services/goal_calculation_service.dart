import '../models/user_goal.dart';

/// Calculation result bundle containing derived BMR, TDEE, target calories, and macro split
class CalculatedTargets {
  final double bmr;
  final double tdee;
  final double targetCalories;
  final double targetProtein;
  final double targetCarbohydrates;
  final double targetFats;

  const CalculatedTargets({
    required this.bmr,
    required this.tdee,
    required this.targetCalories,
    required this.targetProtein,
    required this.targetCarbohydrates,
    required this.targetFats,
  });

  @override
  String toString() {
    return 'CalculatedTargets(BMR: ${bmr.toStringAsFixed(0)}, TDEE: ${tdee.toStringAsFixed(0)}, Calories: ${targetCalories.toStringAsFixed(0)}kcal, Protein: ${targetProtein.toStringAsFixed(1)}g, Carbs: ${targetCarbohydrates.toStringAsFixed(1)}g, Fats: ${targetFats.toStringAsFixed(1)}g)';
  }
}

/// Service responsible for calculating BMR, TDEE, target calories,
/// and macro allocations based on user biometrics, activity level, and fitness goals.
class GoalCalculationService {
  const GoalCalculationService();

  /// Activity level multipliers for TDEE calculation
  static double getActivityMultiplier(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary:
        return 1.2;
      case ActivityLevel.light:
        return 1.375;
      case ActivityLevel.moderate:
        return 1.55;
      case ActivityLevel.active:
        return 1.725;
      case ActivityLevel.veryActive:
        return 1.9;
    }
  }

  /// Calculates BMR using the Mifflin-St Jeor equation baseline:
  /// BMR = 10 * weight(kg) + 6.25 * height(cm) - 5 * age + 5
  double calculateBMR({
    required double weight,
    required double height,
    required int age,
  }) {
    return (10.0 * weight) + (6.25 * height) - (5.0 * age) + 5.0;
  }

  /// Calculates TDEE from BMR and ActivityLevel
  double calculateTDEE({
    required double bmr,
    required ActivityLevel activityLevel,
  }) {
    return bmr * getActivityMultiplier(activityLevel);
  }

  /// Calculates personalized calorie and macro targets
  CalculatedTargets calculateTargets({
    required int age,
    required double height,
    required double weight,
    required ActivityLevel activityLevel,
    required FitnessGoalType goalType,
  }) {
    final double bmr = calculateBMR(weight: weight, height: height, age: age);
    final double tdee = calculateTDEE(bmr: bmr, activityLevel: activityLevel);

    double calorieAdjustment = 0.0;
    double proteinPerKg = 1.8;
    double fatCalorieRatio = 0.25;

    switch (goalType) {
      case FitnessGoalType.muscleGain:
        calorieAdjustment = 400.0;
        proteinPerKg = 2.0;
        fatCalorieRatio = 0.25;
        break;

      case FitnessGoalType.fatLoss:
        calorieAdjustment = -400.0;
        proteinPerKg = 2.2;
        fatCalorieRatio = 0.25;
        break;

      case FitnessGoalType.maintenance:
        calorieAdjustment = 0.0;
        proteinPerKg = 1.8;
        fatCalorieRatio = 0.25;
        break;

      case FitnessGoalType.strength:
        calorieAdjustment = 250.0;
        proteinPerKg = 2.0;
        fatCalorieRatio = 0.25;
        break;

      case FitnessGoalType.endurance:
        calorieAdjustment = 0.0;
        proteinPerKg = 1.6;
        fatCalorieRatio = 0.20; // Higher carb allocation for endurance
        break;
    }

    final double targetCalories = (tdee + calorieAdjustment).clamp(1200.0, 6000.0);
    final double targetProtein = (weight * proteinPerKg).clamp(40.0, 350.0);
    final double targetFats = ((targetCalories * fatCalorieRatio) / 9.0).clamp(30.0, 200.0);

    final double proteinCalories = targetProtein * 4.0;
    final double fatCalories = targetFats * 9.0;
    final double remainingCalories = targetCalories - proteinCalories - fatCalories;
    final double targetCarbohydrates = (remainingCalories / 4.0).clamp(50.0, 800.0);

    return CalculatedTargets(
      bmr: bmr,
      tdee: tdee,
      targetCalories: targetCalories,
      targetProtein: targetProtein,
      targetCarbohydrates: targetCarbohydrates,
      targetFats: targetFats,
    );
  }

  /// Helper method to create a new UserGoal with auto-calculated targets
  UserGoal generateUserGoal({
    required String id,
    required FitnessGoalType goalType,
    required FitnessLevel fitnessLevel,
    required ActivityLevel activityLevel,
    required int age,
    required double height,
    required double currentWeight,
    required double targetWeight,
  }) {
    final targets = calculateTargets(
      age: age,
      height: height,
      weight: currentWeight,
      activityLevel: activityLevel,
      goalType: goalType,
    );

    final now = DateTime.now();

    return UserGoal(
      id: id,
      goalType: goalType,
      fitnessLevel: fitnessLevel,
      activityLevel: activityLevel,
      age: age,
      height: height,
      currentWeight: currentWeight,
      targetWeight: targetWeight,
      targetCalories: targets.targetCalories,
      targetProtein: targets.targetProtein,
      targetCarbohydrates: targets.targetCarbohydrates,
      targetFats: targets.targetFats,
      createdDate: now,
      updatedDate: now,
    );
  }
}
