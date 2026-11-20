import 'dart:math';
import '../models/weight_goal.dart';

/// Single curated meal item in a generated daily transformation plan
class GeneratedMealPlanItem {
  final String mealType;
  final String title;
  final String description;
  final double calories;
  final double protein;
  final double carbs;
  final double fats;
  final List<String> ingredients;
  final String preparationTip;

  const GeneratedMealPlanItem({
    required this.mealType,
    required this.title,
    required this.description,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.ingredients,
    required this.preparationTip,
  });

  factory GeneratedMealPlanItem.fromJson(Map<String, dynamic> json) {
    return GeneratedMealPlanItem(
      mealType: json['mealType'] as String? ?? 'Meal',
      title: json['title'] as String? ?? 'Custom Meal',
      description: json['description'] as String? ?? '',
      calories: (json['calories'] as num?)?.toDouble() ?? 500.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 30.0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 50.0,
      fats: (json['fats'] as num?)?.toDouble() ?? 15.0,
      ingredients:
          (json['ingredients'] as List?)?.map((e) => e.toString()).toList() ??
          [],
      preparationTip: json['preparationTip'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mealType': mealType,
      'title': title,
      'description': description,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fats': fats,
      'ingredients': ingredients,
      'preparationTip': preparationTip,
    };
  }
}

/// Result object for progress-based calorie adaptation analysis
class WeightGoalAdaptationResult {
  final bool needsAdjustment;
  final double suggestedCalorieDelta;
  final String title;
  final String message;
  final String recommendation;
  final WeightGoal adjustedGoal;

  const WeightGoalAdaptationResult({
    required this.needsAdjustment,
    required this.suggestedCalorieDelta,
    required this.title,
    required this.message,
    required this.recommendation,
    required this.adjustedGoal,
  });
}

/// Service responsible for calculating personalized weight transformation targets,
/// macro distribution, daily meal schedule, and dynamic calorie adaptation.
class WeightGoalService {
  const WeightGoalService();

  /// Calculates baseline BMR via Mifflin-St Jeor equation:
  /// BMR = (10 * weight) + (6.25 * height) - (5 * age) + 5
  double calculateBMR({
    required double weightKg,
    required double heightCm,
    required int age,
  }) {
    return (10.0 * weightKg) + (6.25 * heightCm) - (5.0 * age) + 5.0;
  }

  /// Calculates TDEE given BMR and activity multiplier
  double calculateTDEE({
    required double bmr,
    String activityLevel = 'moderate',
  }) {
    double multiplier = 1.55; // default moderate
    switch (activityLevel.toLowerCase()) {
      case 'sedentary':
        multiplier = 1.2;
        break;
      case 'light':
        multiplier = 1.375;
        break;
      case 'moderate':
        multiplier = 1.55;
        break;
      case 'active':
        multiplier = 1.725;
        break;
      case 'veryactive':
      case 'very active':
        multiplier = 1.9;
        break;
    }
    return bmr * multiplier;
  }

  /// Computes complete [WeightGoal] domain model with scientific targets
  WeightGoal createWeightGoal({
    required String userId,
    required double currentWeight,
    required double targetWeight,
    required int targetWeeks,
    required WeightGoalType type,
    required DietPreference diet,
    required MealFrequency mealsPerDay,
    BudgetTier budget = BudgetTier.medium,
    int age = 25,
    double heightCm = 175.0,
    String activityLevel = 'moderate',
  }) {
    final bmr = calculateBMR(
      weightKg: currentWeight,
      heightCm: heightCm,
      age: age,
    );
    final tdee = calculateTDEE(bmr: bmr, activityLevel: activityLevel);

    final safeWeeks = max(targetWeeks, 4);
    final weightDeltaKg = targetWeight - currentWeight;
    final weeklyRateKg = weightDeltaKg / safeWeeks;

    double dailySurplusOrDeficit = 0.0;
    double proteinMultiplier = 2.0; // g per kg of target weight

    switch (type) {
      case WeightGoalType.gain:
        // Safe caloric surplus for lean bulk: +300 to +500 kcal
        dailySurplusOrDeficit = (weeklyRateKg.abs() * 7700 / 7).clamp(
          300.0,
          550.0,
        );
        proteinMultiplier = 2.0;
        break;

      case WeightGoalType.lose:
        // Safe caloric deficit: -350 to -550 kcal
        dailySurplusOrDeficit = -(weeklyRateKg.abs() * 7700 / 7).clamp(
          350.0,
          550.0,
        );
        proteinMultiplier = 2.2; // higher protein to preserve lean muscle
        break;

      case WeightGoalType.maintain:
        dailySurplusOrDeficit = 0.0;
        proteinMultiplier = 1.8;
        break;

      case WeightGoalType.recomposition:
        dailySurplusOrDeficit = 50.0; // slight surplus / near maintenance
        proteinMultiplier = 2.2;
        break;
    }

    final targetCalories = (tdee + dailySurplusOrDeficit).roundToDouble();

    // 1. Protein: 1.6 - 2.2 g/kg (4 kcal/g)
    final proteinGrams = (targetWeight * proteinMultiplier).roundToDouble();
    final proteinCalories = proteinGrams * 4.0;

    // 2. Fats: 25% - 30% of total calories (9 kcal/g)
    final fatCalories = targetCalories * 0.25;
    final fatGrams = (fatCalories / 9.0).roundToDouble();

    // 3. Carbohydrates: Remaining calories (4 kcal/g)
    final remainingCalories = targetCalories - proteinCalories - fatCalories;
    final carbsGrams = max(50.0, remainingCalories / 4.0).roundToDouble();

    final now = DateTime.now();

    return WeightGoal(
      id: 'wg_${now.millisecondsSinceEpoch}',
      userId: userId,
      currentWeight: currentWeight,
      targetWeight: targetWeight,
      targetWeeks: safeWeeks,
      type: type,
      diet: diet,
      mealsPerDay: mealsPerDay,
      budget: budget,
      dailyCalorieTarget: targetCalories,
      proteinGrams: proteinGrams,
      carbsGrams: carbsGrams,
      fatGrams: fatGrams,
      expectedWeeklyRateKg: weeklyRateKg.abs(),
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Generates a structured daily meal plan breakdown based on the user's [WeightGoal]
  List<GeneratedMealPlanItem> generateMealPlan(WeightGoal goal) {
    final totalCalories = goal.dailyCalorieTarget;
    final totalProtein = goal.proteinGrams;
    final totalCarbs = goal.carbsGrams;
    final totalFat = goal.fatGrams;

    final count = goal.mealsPerDay.count;

    if (count == 3) {
      // 3 Meals Split: 35% Breakfast, 40% Lunch, 25% Dinner
      return [
        _buildMeal(
          mealType: 'Breakfast',
          diet: goal.diet,
          budget: goal.budget,
          calPercent: 0.35,
          totalCalories: totalCalories,
          totalProtein: totalProtein,
          totalCarbs: totalCarbs,
          totalFat: totalFat,
          breakfastIndex: 0,
        ),
        _buildMeal(
          mealType: 'Lunch',
          diet: goal.diet,
          budget: goal.budget,
          calPercent: 0.40,
          totalCalories: totalCalories,
          totalProtein: totalProtein,
          totalCarbs: totalCarbs,
          totalFat: totalFat,
          lunchIndex: 0,
        ),
        _buildMeal(
          mealType: 'Dinner',
          diet: goal.diet,
          budget: goal.budget,
          calPercent: 0.25,
          totalCalories: totalCalories,
          totalProtein: totalProtein,
          totalCarbs: totalCarbs,
          totalFat: totalFat,
          dinnerIndex: 0,
        ),
      ];
    } else if (count == 4) {
      // 4 Meals Split: 30% Breakfast, 35% Lunch, 15% High-Protein Snack, 20% Dinner
      return [
        _buildMeal(
          mealType: 'Breakfast',
          diet: goal.diet,
          budget: goal.budget,
          calPercent: 0.30,
          totalCalories: totalCalories,
          totalProtein: totalProtein,
          totalCarbs: totalCarbs,
          totalFat: totalFat,
          breakfastIndex: 0,
        ),
        _buildMeal(
          mealType: 'Lunch',
          diet: goal.diet,
          budget: goal.budget,
          calPercent: 0.35,
          totalCalories: totalCalories,
          totalProtein: totalProtein,
          totalCarbs: totalCarbs,
          totalFat: totalFat,
          lunchIndex: 0,
        ),
        _buildMeal(
          mealType: 'Snack / Pre-Workout',
          diet: goal.diet,
          budget: goal.budget,
          calPercent: 0.15,
          totalCalories: totalCalories,
          totalProtein: totalProtein,
          totalCarbs: totalCarbs,
          totalFat: totalFat,
          snackIndex: 0,
        ),
        _buildMeal(
          mealType: 'Dinner',
          diet: goal.diet,
          budget: goal.budget,
          calPercent: 0.20,
          totalCalories: totalCalories,
          totalProtein: totalProtein,
          totalCarbs: totalCarbs,
          totalFat: totalFat,
          dinnerIndex: 0,
        ),
      ];
    } else {
      // 5 Meals Split: 25% Breakfast, 30% Lunch, 15% Afternoon Snack, 20% Dinner, 10% Post-Workout Shake
      return [
        _buildMeal(
          mealType: 'Breakfast',
          diet: goal.diet,
          budget: goal.budget,
          calPercent: 0.25,
          totalCalories: totalCalories,
          totalProtein: totalProtein,
          totalCarbs: totalCarbs,
          totalFat: totalFat,
          breakfastIndex: 0,
        ),
        _buildMeal(
          mealType: 'Lunch',
          diet: goal.diet,
          budget: goal.budget,
          calPercent: 0.30,
          totalCalories: totalCalories,
          totalProtein: totalProtein,
          totalCarbs: totalCarbs,
          totalFat: totalFat,
          lunchIndex: 0,
        ),
        _buildMeal(
          mealType: 'Afternoon Snack',
          diet: goal.diet,
          budget: goal.budget,
          calPercent: 0.15,
          totalCalories: totalCalories,
          totalProtein: totalProtein,
          totalCarbs: totalCarbs,
          totalFat: totalFat,
          snackIndex: 0,
        ),
        _buildMeal(
          mealType: 'Dinner',
          diet: goal.diet,
          budget: goal.budget,
          calPercent: 0.20,
          totalCalories: totalCalories,
          totalProtein: totalProtein,
          totalCarbs: totalCarbs,
          totalFat: totalFat,
          dinnerIndex: 0,
        ),
        _buildMeal(
          mealType: 'Post-Workout / Night Snack',
          diet: goal.diet,
          budget: goal.budget,
          calPercent: 0.10,
          totalCalories: totalCalories,
          totalProtein: totalProtein,
          totalCarbs: totalCarbs,
          totalFat: totalFat,
          snackIndex: 1,
        ),
      ];
    }
  }

  /// Analyzes actual weigh-in progress against the goal timeline and provides adaptive calorie feedback
  WeightGoalAdaptationResult analyzeProgressAndAdapt({
    required WeightGoal goal,
    required double currentLoggedWeight,
    required int weeksLogged,
  }) {
    if (weeksLogged <= 0) {
      return WeightGoalAdaptationResult(
        needsAdjustment: false,
        suggestedCalorieDelta: 0,
        title: 'Plan On Track',
        message:
            'Your weight goal program is newly active. Continue following daily targets!',
        recommendation:
            'Log weigh-ins weekly to allow the AI engine to calibrate adjustments.',
        adjustedGoal: goal,
      );
    }

    final totalChange = (currentLoggedWeight - goal.currentWeight).abs();
    final actualWeeklyRate = totalChange / weeksLogged;
    final expectedWeeklyRate = goal.expectedWeeklyRateKg;

    if (goal.isWeightGain) {
      if (currentLoggedWeight <=
          goal.currentWeight + (expectedWeeklyRate * weeksLogged * 0.5)) {
        // Gain is too slow (e.g. +0.1kg/wk vs +0.5kg/wk) -> Increase surplus
        const delta = 200.0;
        final newCalories = goal.dailyCalorieTarget + delta;
        final newCarbs = goal.carbsGrams + (delta / 4.0);
        final updatedGoal = goal.copyWith(
          dailyCalorieTarget: newCalories,
          carbsGrams: newCarbs,
          updatedAt: DateTime.now(),
        );

        return WeightGoalAdaptationResult(
          needsAdjustment: true,
          suggestedCalorieDelta: delta,
          title: 'Weight Gain Below Target Pace',
          message:
              'Your actual gain rate (${actualWeeklyRate.toStringAsFixed(2)} kg/wk) is slower than your target (${expectedWeeklyRate.toStringAsFixed(2)} kg/wk).',
          recommendation:
              'We recommend increasing daily intake by +200 kcal (approx. 50g additional complex carbs or healthy fats).',
          adjustedGoal: updatedGoal,
        );
      } else if (actualWeeklyRate > expectedWeeklyRate * 1.8 &&
          expectedWeeklyRate > 0.2) {
        // Gain is too fast (excess fat accumulation risk) -> Modulate surplus
        const delta = -150.0;
        final newCalories = max(1800.0, goal.dailyCalorieTarget + delta);
        final newCarbs = max(100.0, goal.carbsGrams + (delta / 4.0));
        final updatedGoal = goal.copyWith(
          dailyCalorieTarget: newCalories,
          carbsGrams: newCarbs,
          updatedAt: DateTime.now(),
        );

        return WeightGoalAdaptationResult(
          needsAdjustment: true,
          suggestedCalorieDelta: delta,
          title: 'Weight Gain Ahead of Target Pace',
          message:
              'Your weight is increasing at ${actualWeeklyRate.toStringAsFixed(2)} kg/wk (expected: ${expectedWeeklyRate.toStringAsFixed(2)} kg/wk).',
          recommendation:
              'Modulate daily calories by -150 kcal to ensure clean muscular hypertrophy rather than excess adipose storage.',
          adjustedGoal: updatedGoal,
        );
      }
    }

    return WeightGoalAdaptationResult(
      needsAdjustment: false,
      suggestedCalorieDelta: 0,
      title: 'Progress Optimal',
      message:
          'You are gaining at ${actualWeeklyRate.toStringAsFixed(2)} kg/wk, perfectly matching your 6-month transformation curve.',
      recommendation:
          'Maintain your current daily macronutrient targets and consistent resistance training.',
      adjustedGoal: goal,
    );
  }

  // --- Internal Meal Generator Helper ---
  GeneratedMealPlanItem _buildMeal({
    required String mealType,
    required DietPreference diet,
    required BudgetTier budget,
    required double calPercent,
    required double totalCalories,
    required double totalProtein,
    required double totalCarbs,
    required double totalFat,
    int breakfastIndex = 0,
    int lunchIndex = 0,
    int snackIndex = 0,
    int dinnerIndex = 0,
  }) {
    final mealCals = (totalCalories * calPercent).roundToDouble();
    final mealProtein = (totalProtein * calPercent).roundToDouble();
    final mealCarbs = (totalCarbs * calPercent).roundToDouble();
    final mealFat = (totalFat * calPercent).roundToDouble();

    if (mealType.toLowerCase().contains('breakfast')) {
      if (diet == DietPreference.vegetarian || diet == DietPreference.vegan) {
        return GeneratedMealPlanItem(
          mealType: mealType,
          title: 'Power Oats & Peanut Butter Bowl',
          description:
              'Rolled oats cooked in almond/soy milk with ripe banana, peanut butter, chia seeds & vegan protein.',
          calories: mealCals,
          protein: mealProtein,
          carbs: mealCarbs,
          fats: mealFat,
          ingredients: [
            '100g Rolled Oats',
            '1 Large Banana',
            '30g Peanut Butter',
            '1 Scoop Plant Protein',
            '200ml Soy Milk',
          ],
          preparationTip:
              'Blend in honey or cinnamon for antioxidant-rich natural flavor.',
        );
      } else {
        return GeneratedMealPlanItem(
          mealType: mealType,
          title: 'Eggs, Toast & Oats Mass Breakfast',
          description:
              'Whole eggs with egg whites on seeded sourdough toast alongside hearty honey-banana oatmeal.',
          calories: mealCals,
          protein: mealProtein,
          carbs: mealCarbs,
          fats: mealFat,
          ingredients: [
            '3 Whole Eggs',
            '2 Egg Whites',
            '2 Slices Sourdough Bread',
            '60g Oats',
            '1 Banana',
          ],
          preparationTip:
              'Cook eggs in olive oil and season with black pepper and turmeric.',
        );
      }
    } else if (mealType.toLowerCase().contains('lunch')) {
      if (diet == DietPreference.vegetarian) {
        return GeneratedMealPlanItem(
          mealType: mealType,
          title: 'Paneer Bhurji & Basmati Rice Bowl',
          description:
              'High-protein spiced cottage cheese sautéed with bell peppers, onions, alongside steamed basmati rice & dal.',
          calories: mealCals,
          protein: mealProtein,
          carbs: mealCarbs,
          fats: mealFat,
          ingredients: [
            '150g Low-Fat Paneer',
            '1.5 Cups Basmati Rice',
            '1 Cup Yellow Lentils',
            'Mixed Vegetables',
          ],
          preparationTip:
              'Pair with cucumber raita for healthy gut probiotics.',
        );
      } else if (diet == DietPreference.vegan) {
        return GeneratedMealPlanItem(
          mealType: mealType,
          title: 'Tofu, Chickpeas & Quinoa Super Bowl',
          description:
              'Crispy pan-seared firm tofu with seasoned roasted chickpeas, quinoa, avocado slices & sesame dressing.',
          calories: mealCals,
          protein: mealProtein,
          carbs: mealCarbs,
          fats: mealFat,
          ingredients: [
            '180g Firm Tofu',
            '1 Cup Cooked Chickpeas',
            '1 Cup Quinoa',
            '1/2 Avocado',
            'Broccoli',
          ],
          preparationTip:
              'Press tofu for 15 minutes before cooking for maximum crispiness.',
        );
      } else {
        return GeneratedMealPlanItem(
          mealType: mealType,
          title: 'Chicken Breast Curry with Jasmine Rice',
          description:
              'Tender chicken breast simmered in fragrant tomato-ginger curry with steamed jasmine rice & steamed greens.',
          calories: mealCals,
          protein: mealProtein,
          carbs: mealCarbs,
          fats: mealFat,
          ingredients: [
            '200g Chicken Breast',
            '1.5 Cups Jasmine Rice',
            '1 Cup Steamed Broccoli',
            'Curry Gravy',
          ],
          preparationTip:
              'Batch cook chicken for 3 days to keep your meal routine effortless.',
        );
      }
    } else if (mealType.toLowerCase().contains('snack')) {
      if (diet == DietPreference.vegan) {
        return GeneratedMealPlanItem(
          mealType: mealType,
          title: 'High-Calorie Vegan Smoothie',
          description:
              'Dense mass shake with plant protein, oat powder, almond butter, dates & banana.',
          calories: mealCals,
          protein: mealProtein,
          carbs: mealCarbs,
          fats: mealFat,
          ingredients: [
            '1 Scoop Pea/Rice Protein',
            '50g Oat Powder',
            '2 Medjool Dates',
            '25g Almond Butter',
          ],
          preparationTip:
              'Add 1 tbsp cacao powder for natural dark chocolate flavor.',
        );
      } else {
        return GeneratedMealPlanItem(
          mealType: mealType,
          title: 'Whey Protein & Greek Yogurt Parfait',
          description:
              'Thick Greek yogurt layered with whey protein isolate, mixed berries, almonds & granola.',
          calories: mealCals,
          protein: mealProtein,
          carbs: mealCarbs,
          fats: mealFat,
          ingredients: [
            '200g Greek Yogurt',
            '1 Scoop Whey Protein',
            '40g Granola',
            '20g Raw Almonds',
            'Berries',
          ],
          preparationTip:
              'Ideal 60-90 minutes before your workout for sustained glycogen release.',
        );
      }
    } else {
      // Dinner
      if (diet == DietPreference.vegetarian) {
        return GeneratedMealPlanItem(
          mealType: mealType,
          title: 'Soya Chunks & Mixed Dal Curry',
          description:
              'Ultra high-protein soya chunks cooked with kidney beans, brown rice & roasted sweet potato.',
          calories: mealCals,
          protein: mealProtein,
          carbs: mealCarbs,
          fats: mealFat,
          ingredients: [
            '60g Soya Chunks',
            '1 Cup Kidney Beans (Rajma)',
            '1 Cup Brown Rice',
            '1 Sweet Potato',
          ],
          preparationTip:
              'Boil soya chunks in salted water and squeeze thoroughly before sautéing.',
        );
      } else if (diet == DietPreference.vegan) {
        return GeneratedMealPlanItem(
          mealType: mealType,
          title: 'Lentil Dahl & Roasted Sweet Potato',
          description:
              'Hearty red lentil dahl seasoned with cumin and coriander, served with roasted sweet potatoes & kale.',
          calories: mealCals,
          protein: mealProtein,
          carbs: mealCarbs,
          fats: mealFat,
          ingredients: [
            '1.5 Cups Red Lentils',
            '200g Sweet Potato',
            '1 Cup Sautéed Kale',
            'Olive Oil',
          ],
          preparationTip:
              'Lentils provide complete amino acid profiles when combined with grains.',
        );
      } else {
        return GeneratedMealPlanItem(
          mealType: mealType,
          title: 'Grilled Salmon or Lean Beef with Potatoes',
          description:
              'Wild-caught salmon fillet or lean minced beef with roasted sweet potato wedges & asparagus.',
          calories: mealCals,
          protein: mealProtein,
          carbs: mealCarbs,
          fats: mealFat,
          ingredients: [
            '180g Salmon / Lean Beef',
            '200g Sweet Potato',
            '1 Cup Grilled Asparagus',
            'Olive Oil',
          ],
          preparationTip:
              'Rich in Omega-3 fatty acids to accelerate joint and muscular recovery overnight.',
        );
      }
    }
  }
}
