import '../models/recovery/readiness_inputs.dart';
import 'package:flutter/material.dart';
import '../models/activity_post.dart';
import '../models/badge.dart';
import '../models/coach_message.dart';
import '../models/consumed_food.dart';
import '../models/daily_nutrition.dart';
import '../models/digital_athlete.dart';
import '../models/fitness_context.dart';
import '../models/food_item.dart';
import '../models/food_scan_result.dart';
import '../models/health_metric.dart';
import '../models/health_metrics.dart';
import '../models/macro_target.dart';
import '../models/meal_entry.dart';
import '../models/nutrition_progress.dart';
import '../models/nutrition_summary.dart';
import '../models/progress_summary.dart';
import '../models/recommendation.dart';
import '../models/recovery_state.dart';
import '../models/sleep_record.dart';
import '../models/recovery_insight.dart';
import '../models/training_state.dart';
import '../models/user_goal.dart';
import '../models/user_profile.dart';
import '../models/user_progress.dart';
import '../models/workout_history.dart';
import '../services/community/sample_community.dart';

/// Weight trend data point for graph plotting
class WeightTrendPoint {
  final String label;
  final double weightKg;
  final DateTime date;

  const WeightTrendPoint({
    required this.label,
    required this.weightKg,
    required this.date,
  });
}

/// Weight summary metrics container
class WeightTrendSummary {
  final double currentKg;
  final double changeKg;
  final double lowestKg;
  final double highestKg;
  final List<WeightTrendPoint> points;

  const WeightTrendSummary({
    required this.currentKg,
    required this.changeKg,
    required this.lowestKg,
    required this.highestKg,
    required this.points,
  });
}

/// Centralized Showcase Data Provider generating rich, realistic demonstration data
/// for Atlas. All demo statistics, athlete twin records, workout histories,
/// nutrition meals, recovery telemetry, and weight trends originate here.
class ShowcaseDataProvider {
  static ShowcaseDataProvider? _instance;

  ShowcaseDataProvider();

  static ShowcaseDataProvider get instance =>
      _instance ??= ShowcaseDataProvider();

  static void resetInstance() {
    _instance = null;
  }

  // ──────────────────────────────────────────
  // 1. ATHLETE PROFILE DATA
  // ──────────────────────────────────────────

  UserProfile getShowcaseUserProfile() {
    return UserProfile(
      name: 'Alex Lalremruata',
      email: 'alex.rivera@atlasfit.ai',
      phone: '+1 (555) 382-9104',
      dob: '1998-05-14',
      gender: 'Male',
      height: '178',
      weight: '77.5',
      fitnessGoal: 'Hypertrophy & Strength',
      workoutExperience: 'Powerbuilder (Advanced)',
      preferredDays: const ['Monday', 'Tuesday', 'Thursday', 'Friday'],
      dietPreference: 'High Protein Non-Veg',
      massUnit: 'kg',
      lengthUnit: 'cm',
      subscription: 'Premium Pro',
      privacy: 'Public',
      notificationsEnabled: true,
      profilePic:
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
    );
  }

  // ──────────────────────────────────────────
  // 2. WORKOUT DATA (48 Workouts, 580k kg Volume, PRs, 7-day streak)
  // ──────────────────────────────────────────

  List<WorkoutHistory> getShowcaseWorkoutHistory() {
    final now = DateTime.now();
    final List<WorkoutHistory> history = [];

    // Core recent landmark PR sessions
    history.add(
      WorkoutHistory(
        workoutName: 'Upper Push Power & Chest Builder',
        dateCompleted: now.subtract(const Duration(days: 1)),
        durationSeconds: 3480, // 58 mins
        exercisesCompleted: 5,
        completionPercentage: 100.0,
        totalSets: 18,
        totalReps: 144,
        totalVolume: 15400.0,
        caloriesBurned: 490.0,
        personalRecords: const [
          'Barbell Bench Press: 110.0 kg',
          'Incline Dumbbell Press: 38.0 kg',
        ],
        xpEarned: 380,
        formScore: 94.0,
        averageTechniqueScore: 92.5,
        readinessScore: 88.0,
        averageHR: 138,
        intensityScore: 88.0,
      ),
    );

    history.add(
      WorkoutHistory(
        workoutName: 'Pull Hypertrophy & Deadlift Peak',
        dateCompleted: now.subtract(const Duration(days: 2)),
        durationSeconds: 3660,
        exercisesCompleted: 6,
        completionPercentage: 100.0,
        totalSets: 20,
        totalReps: 160,
        totalVolume: 17200.0,
        caloriesBurned: 530.0,
        personalRecords: const [
          'Conventional Barbell Deadlift: 175.0 kg',
          'Weighted Pull-Up: +25.0 kg',
        ],
        xpEarned: 420,
        formScore: 91.0,
        averageTechniqueScore: 90.0,
        readinessScore: 85.0,
        averageHR: 146,
      ),
    );

    history.add(
      WorkoutHistory(
        workoutName: 'Leg Day Hypertrophy & Squat Focus',
        dateCompleted: now.subtract(const Duration(days: 4)),
        durationSeconds: 3780,
        exercisesCompleted: 5,
        completionPercentage: 100.0,
        totalSets: 19,
        totalReps: 152,
        totalVolume: 18800.0,
        caloriesBurned: 570.0,
        personalRecords: const ['Barbell Back Squat: 142.5 kg'],
        xpEarned: 450,
        formScore: 93.0,
        averageTechniqueScore: 92.0,
        readinessScore: 82.0,
        averageHR: 152,
      ),
    );

    history.add(
      WorkoutHistory(
        workoutName: 'Shoulders, Arms & Overhead Press',
        dateCompleted: now.subtract(const Duration(days: 5)),
        durationSeconds: 3120,
        exercisesCompleted: 6,
        completionPercentage: 100.0,
        totalSets: 18,
        totalReps: 180,
        totalVolume: 12400.0,
        caloriesBurned: 420.0,
        personalRecords: const ['Overhead Press: 72.5 kg'],
        xpEarned: 310,
        readinessScore: 86.0,
      ),
    );

    // Generate remaining 44 realistic workouts to reach 48 sessions and 580,000 kg volume
    final splits = [
      'Upper Push Power',
      'Pull Hypertrophy & Back',
      'Lower Body Squat & Hamstrings',
      'Upper Body Hypertrophy',
      'Posterior Chain & Core',
      'Shoulders & Arms Volume Blitz',
    ];

    double currentAccumulatedVolume =
        15400.0 + 17200.0 + 18800.0 + 12400.0; // 63,800 kg
    final targetRemainingVolume =
        580000.0 - currentAccumulatedVolume; // 516,200 kg
    final volumePerRemainingWorkout = targetRemainingVolume / 44.0;

    for (int i = 5; i <= 48; i++) {
      final daysAgo = 5 + ((i - 4) * 2);
      final splitName = splits[(i - 5) % splits.length];
      history.add(
        WorkoutHistory(
          workoutName: '$splitName #$i',
          dateCompleted: now.subtract(Duration(days: daysAgo)),
          durationSeconds: 3000 + ((i * 17) % 600),
          exercisesCompleted: 5,
          completionPercentage: 100.0,
          totalSets: 16 + (i % 4),
          totalReps: 140 + (i % 20),
          totalVolume: volumePerRemainingWorkout,
          caloriesBurned: 430.0 + (i % 80),
          personalRecords: const [],
          xpEarned: 280 + (i % 40),
          formScore: 90.0 + (i % 6),
          averageTechniqueScore: 89.0 + (i % 5),
          readinessScore: 80.0 + (i % 12),
          averageHR: 135 + (i % 15),
        ),
      );
    }

    return history;
  }

  UserProgress getShowcaseUserProgress() {
    return UserProgress(
      completedWorkouts: 48,
      totalXP: 14850,
      rankedUnlocked: true,
      currentRank: 'Gold',
      currentDivision: 'II',
      workoutStreak: 12,
      longestStreak: 30,
      totalWorkoutMinutes: 2880,
      totalVolumeLifted: 580000.0,
      achievements: getShowcaseBadges().map((b) => b.id).toList(),
      nutritionStreak: 14,
    );
  }

  // ──────────────────────────────────────────
  // 3. NUTRITION DATA (2,153 kcal, 142g Protein)
  // ──────────────────────────────────────────

  List<MealEntry> getShowcaseMeals() {
    final now = DateTime.now();
    return [
      MealEntry(
        id: 'meal_sc_1',
        name: 'Oatmeal with Whey & Berries',
        mealType: MealCategory.breakfast,
        timeLabel: '08:30 AM',
        date: DateTime(now.year, now.month, now.day, 8, 30),
        isCompleted: true,
        consumedFoods: [
          ConsumedFood(
            food: const FoodItem(
              id: 'food_oats',
              name: 'Oatmeal with Whey & Berries',
              calories: 485,
              protein: 36,
              carbohydrates: 64,
              fats: 9,
              servingSize: '1 bowl (300g)',
            ),
            quantity: 1.0,
            unit: 'serving',
          ),
        ],
      ),
      MealEntry(
        id: 'meal_sc_2',
        name: 'Grilled Chicken Breast & Jasmine Rice',
        mealType: MealCategory.lunch,
        timeLabel: '01:00 PM',
        date: DateTime(now.year, now.month, now.day, 13, 0),
        isCompleted: true,
        consumedFoods: [
          ConsumedFood(
            food: const FoodItem(
              id: 'food_chicken_rice',
              name: 'Grilled Chicken Breast & Jasmine Rice',
              calories: 680,
              protein: 48,
              carbohydrates: 82,
              fats: 14,
              servingSize: '1 plate (400g)',
            ),
            quantity: 1.0,
            unit: 'serving',
          ),
        ],
      ),
      MealEntry(
        id: 'meal_sc_3',
        name: 'Greek Yogurt & Almond Snack',
        mealType: MealCategory.snack,
        timeLabel: '04:30 PM',
        date: DateTime(now.year, now.month, now.day, 16, 30),
        isCompleted: true,
        consumedFoods: [
          ConsumedFood(
            food: const FoodItem(
              id: 'food_yogurt',
              name: 'Greek Yogurt & Almond Snack',
              calories: 348,
              protein: 22,
              carbohydrates: 24,
              fats: 16,
              servingSize: '1 cup (200g)',
            ),
            quantity: 1.0,
            unit: 'serving',
          ),
        ],
      ),
      MealEntry(
        id: 'meal_sc_4',
        name: 'Salmon Fillet with Sweet Potato',
        mealType: MealCategory.dinner,
        timeLabel: '07:45 PM',
        date: DateTime(now.year, now.month, now.day, 19, 45),
        isCompleted: true,
        consumedFoods: [
          ConsumedFood(
            food: const FoodItem(
              id: 'food_salmon',
              name: 'Salmon Fillet with Sweet Potato',
              calories: 640,
              protein: 36,
              carbohydrates: 68,
              fats: 24,
              servingSize: '1 portion (350g)',
            ),
            quantity: 1.0,
            unit: 'serving',
          ),
        ],
      ),
    ];
  }

  DailyNutrition getShowcaseDailyNutrition() {
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return DailyNutrition(
      date: todayStr,
      targets: const MacroTarget(
        calories: 2300.0,
        proteinGrams: 185.0,
        carbsGrams: 260.0,
        fatGrams: 65.0,
      ),
      meals: getShowcaseMeals(),
      waterLiters: 2.8,
      baseCalories: 0.0,
      baseProtein: 0.0,
      baseCarbs: 0.0,
      baseFat: 0.0,
    );
  }

  // ──────────────────────────────────────────
  // 4. SLEEP & RECOVERY DATA (Transparent Telemetry)
  // ──────────────────────────────────────────

  List<SleepRecord> getShowcaseSleepHistory() {
    final now = DateTime.now();
    return [
      // Last night (0 days ago)
      SleepRecord.fromTimes(
        id: 'sleep_showcase_0',
        userId: 'usr_showcase_athlete',
        date: now,
        bedtime: DateTime(now.year, now.month, now.day - 1, 23, 18),
        wakeTime: DateTime(now.year, now.month, now.day, 7, 0),
        quality: SleepQuality.good,
        consistency: SleepConsistency.good,
        source: HealthDataSource.showcase,
        restingHeartRate: 58.0,
        hrv: 62.0,
        notes: 'Felt well-rested and ready for upper body push session.',
      ),
      // 1 day ago
      SleepRecord.fromTimes(
        id: 'sleep_showcase_1',
        userId: 'usr_showcase_athlete',
        date: now.subtract(const Duration(days: 1)),
        bedtime: DateTime(now.year, now.month, now.day - 2, 23, 0),
        wakeTime: DateTime(now.year, now.month, now.day - 1, 7, 14),
        quality: SleepQuality.excellent,
        consistency: SleepConsistency.optimal,
        source: HealthDataSource.showcase,
        restingHeartRate: 56.0,
        hrv: 68.0,
      ),
      // 2 days ago
      SleepRecord.fromTimes(
        id: 'sleep_showcase_2',
        userId: 'usr_showcase_athlete',
        date: now.subtract(const Duration(days: 2)),
        bedtime: DateTime(now.year, now.month, now.day - 3, 23, 15),
        wakeTime: DateTime(now.year, now.month, now.day - 2, 7, 10),
        quality: SleepQuality.good,
        consistency: SleepConsistency.good,
        source: HealthDataSource.showcase,
        restingHeartRate: 59.0,
        hrv: 61.0,
      ),
      // 3 days ago
      SleepRecord.fromTimes(
        id: 'sleep_showcase_3',
        userId: 'usr_showcase_athlete',
        date: now.subtract(const Duration(days: 3)),
        bedtime: DateTime(now.year, now.month, now.day - 4, 23, 40),
        wakeTime: DateTime(now.year, now.month, now.day - 3, 7, 11),
        quality: SleepQuality.good,
        consistency: SleepConsistency.fair,
        source: HealthDataSource.showcase,
        restingHeartRate: 60.0,
        hrv: 59.0,
      ),
      // 4 days ago
      SleepRecord.fromTimes(
        id: 'sleep_showcase_4',
        userId: 'usr_showcase_athlete',
        date: now.subtract(const Duration(days: 4)),
        bedtime: DateTime(now.year, now.month, now.day - 5, 23, 10),
        wakeTime: DateTime(now.year, now.month, now.day - 4, 7, 12),
        quality: SleepQuality.excellent,
        consistency: SleepConsistency.optimal,
        source: HealthDataSource.showcase,
        restingHeartRate: 57.0,
        hrv: 65.0,
      ),
      // 5 days ago
      SleepRecord.fromTimes(
        id: 'sleep_showcase_5',
        userId: 'usr_showcase_athlete',
        date: now.subtract(const Duration(days: 5)),
        bedtime: DateTime(now.year, now.month, now.day - 6, 0, 15),
        wakeTime: DateTime(now.year, now.month, now.day - 5, 7, 3),
        quality: SleepQuality.fair,
        consistency: SleepConsistency.fair,
        source: HealthDataSource.showcase,
        restingHeartRate: 63.0,
        hrv: 54.0,
      ),
      // 6 days ago
      SleepRecord.fromTimes(
        id: 'sleep_showcase_6',
        userId: 'usr_showcase_athlete',
        date: now.subtract(const Duration(days: 6)),
        bedtime: DateTime(now.year, now.month, now.day - 7, 23, 30),
        wakeTime: DateTime(now.year, now.month, now.day - 6, 6, 42),
        quality: SleepQuality.good,
        consistency: SleepConsistency.good,
        source: HealthDataSource.showcase,
        restingHeartRate: 59.0,
        hrv: 60.0,
      ),
    ];
  }

  SleepRecord getShowcaseLatestSleep() {
    return getShowcaseSleepHistory().first;
  }

  RecoveryInsight getShowcaseRecoveryInsight() {
    return RecoveryInsight(
      status: RecoveryStatus.good,
      interpretation:
          'Your sleep duration was close to your goal and your resting heart rate is slightly below your recent average. Your planned workout looks reasonable today.',
      reasoningBullets: const [
        '7h 42m sleep (close to 8h goal)',
        'Good sleep consistency',
        'Resting HR near baseline (58 bpm)',
        'HRV is stable / elevated (62 ms)',
      ],
      latestSleep: getShowcaseLatestSleep(),
      restingHeartRate: 58.0,
      rhrDiffFromBaseline: -3.0,
      hrv: 62.0,
      hrvPercentDiffFromBaseline: 8.0,
      source: HealthDataSource.showcase,
      hasSufficientData: true,
      isEstimated: true,
      generatedAt: DateTime.now(),
    );
  }

  TrainingState getShowcaseTrainingState() {
    final now = DateTime.now();
    return TrainingState(
      // Demonstration content: shown as measured on purpose.
      inputs: const ReadinessInputs(
        hasSleep: true,
        hasHrv: true,
        hasRestingHeartRate: true,
        hasWorkoutHistory: true,
      ),
      id: 'ts_showcase',
      fatigueScore: 28,
      readinessScore: 76,
      trainingLoad: 145.0,
      weeklyVolume: 63800.0,
      recommendedIntensity: 'heavy_training',
      recommendation:
          'Good readiness! Your body is primed for a productive training session.',
      lastUpdated: now,
    );
  }

  HealthMetrics getShowcaseHealthMetrics() {
    return HealthMetrics(
      id: 'metric_showcase_athlete',
      userId: 'usr_showcase_athlete',
      sleepHours: 7.8, // 7h 48m
      heartRateVariability: 76.0,
      restingHeartRate: 52.0,
      recoveryScore: 88,
      steps: 8420,
      stressLevel: 18.0,
      caloriesBurned: 540.0,
      activeMinutes: 65,
      bloodOxygen: 99.0,
      heartRateAverage: 62.0,
    );
  }

  RecoveryState getShowcaseRecoveryState() {
    final now = DateTime.now();
    return RecoveryState(
      // Demonstration content: shown as measured on purpose.
      inputs: const ReadinessInputs(
        hasSleep: true,
        hasHrv: true,
        hasRestingHeartRate: true,
        hasWorkoutHistory: true,
      ),
      id: 'rec_showcase',
      lastUpdated: now,
      recoveryScore: 88,
      fatigueLevel: FatigueLevel.low,
      recommendation: RecoveryRecommendation.trainNormal,
      isDeloadRecommended: false,
    );
  }

  // ──────────────────────────────────────────
  // 5. PROGRESS & 6-MONTH WEIGHT TRENDS (DEC -> MAY)
  // ──────────────────────────────────────────

  WeightTrendSummary getShowcaseWeightTrendSummary() {
    final now = DateTime.now();
    final points = [
      WeightTrendPoint(
        label: 'DEC',
        weightKg: 68.7,
        date: now.subtract(const Duration(days: 150)),
      ),
      WeightTrendPoint(
        label: 'JAN',
        weightKg: 72.0,
        date: now.subtract(const Duration(days: 120)),
      ),
      WeightTrendPoint(
        label: 'FEB',
        weightKg: 71.8,
        date: now.subtract(const Duration(days: 90)),
      ),
      WeightTrendPoint(
        label: 'MAR',
        weightKg: 70.5,
        date: now.subtract(const Duration(days: 60)),
      ),
      WeightTrendPoint(
        label: 'APR',
        weightKg: 68.7,
        date: now.subtract(const Duration(days: 30)),
      ),
      WeightTrendPoint(label: 'MAY', weightKg: 72.4, date: now),
    ];

    return WeightTrendSummary(
      currentKg: 72.4,
      changeKg: -1.2,
      lowestKg: 68.7,
      highestKg: 75.1,
      points: points,
    );
  }

  // ──────────────────────────────────────────
  // 6. ACHIEVEMENTS & BADGES
  // ──────────────────────────────────────────

  List<AchievementBadge> getShowcaseBadges() {
    final now = DateTime.now();
    return [
      AchievementBadge(
        id: 'badge_streak_7',
        title: '7-Day Streak Master 🔥',
        description:
            'You have hit the 7 day streak milestone! Keep pushing toward your goals.',
        iconCodePoint: Icons.local_fire_department_rounded.codePoint,
        category: 'Consistency',
        rarity: 'Epic',
        earnedDate: now.subtract(const Duration(days: 1)),
      ),
      AchievementBadge(
        id: 'badge_bench_110',
        title: 'Century+ Club (110kg Bench)',
        description: 'Benched 110kg with verified pause lockout.',
        iconCodePoint: Icons.fitness_center_rounded.codePoint,
        category: 'Strength',
        rarity: 'Epic',
        earnedDate: now.subtract(const Duration(days: 1)),
      ),
      AchievementBadge(
        id: 'badge_volume_500k',
        title: 'Half Million Club',
        description: 'Accumulated over 500,000 kg lifetime mechanical volume.',
        iconCodePoint: Icons.military_tech_rounded.codePoint,
        category: 'Volume',
        rarity: 'Legendary',
        earnedDate: now.subtract(const Duration(days: 2)),
      ),
      AchievementBadge(
        id: 'badge_clean_eater',
        title: 'Nutrition Master',
        description: 'Hit daily protein and macro targets 25 days in a month.',
        iconCodePoint: Icons.restaurant_rounded.codePoint,
        category: 'Nutrition',
        rarity: 'Rare',
        earnedDate: now.subtract(const Duration(days: 1)),
      ),
    ];
  }

  // ──────────────────────────────────────────
  // 7. AI COACH CONVERSATIONS & MEMORY
  // ──────────────────────────────────────────

  List<CoachMessage> getShowcaseAIConversations() {
    final now = DateTime.now();
    return [
      CoachMessage(
        id: 'msg_sc_1',
        role: CoachRole.user,
        content:
            'Should I push for a new bench press PR today or take a lighter session?',
        timestamp: now.subtract(const Duration(days: 1, hours: 2)),
      ),
      CoachMessage(
        id: 'msg_sc_2',
        role: CoachRole.assistant,
        content:
            'Your CNS Readiness score is 76/100 and HRV is resting at 76ms with 7h 48m of quality sleep. You are in optimal condition to attempt your 110 kg Bench Press working set today. Warm up progressively with 3 ramp-up sets and ensure 3-minute rest intervals between maximal efforts.',
        timestamp: now.subtract(const Duration(days: 1, hours: 1, minutes: 59)),
      ),
      CoachMessage(
        id: 'msg_sc_3',
        role: CoachRole.user,
        content:
            'What should my post-workout meal look like to maximize hypertrophy?',
        timestamp: now.subtract(const Duration(hours: 4)),
      ),
      CoachMessage(
        id: 'msg_sc_4',
        role: CoachRole.assistant,
        content:
            'You are currently at 142g protein out of your 160g target for today. Target 25-30g of protein paired with 40-50g of complex carbs. A salmon fillet with sweet potato or whey isolate with oats will close your daily macro goal cleanly.',
        timestamp: now.subtract(const Duration(hours: 3, minutes: 58)),
      ),
    ];
  }

  List<Recommendation> getShowcaseRecommendations() {
    final now = DateTime.now();
    return [
      Recommendation(
        id: 'rec_1',
        title: 'Optimal Push Day Window',
        description: 'Readiness 76/100 • Progressive Overload Primed',
        category: RecommendationCategory.training,
        actionTitle: 'Start Push Session',
        reasoning:
            'HRV and sleep architecture (7h 48m) are primed for chest hypertrophy.',
        createdAt: now,
      ),
      Recommendation(
        id: 'rec_2',
        title: 'Macro Target: 2,153 kcal (142g / 160g Protein)',
        description:
            '18g Protein remaining to complete daily muscle synthesis target',
        category: RecommendationCategory.nutrition,
        actionTitle: 'Log Evening Meal',
        reasoning:
            'On track to hit clean caloric target for lean muscle growth.',
        createdAt: now,
      ),
    ];
  }

  /// Showcase Mode uses the same sample community as normal Community: one
  /// dataset, labelled as sample, kept on this device (see [SampleCommunity]).
  List<ActivityPost> getShowcaseCommunityPosts() {
    return SampleCommunity.posts();
  }

  FoodScanResult getShowcaseFoodScan() {
    return FoodScanResult(
      scanType: FoodScanType.aiVision,
      food: const FoodItem(
        id: 'scan_food_1',
        name: 'Grilled Herb Chicken Bowl with Quinoa',
        calories: 540,
        protein: 46.5,
        carbohydrates: 52.0,
        fats: 14.0,
        servingSize: '1 bowl',
      ),
      confidence: 'High',
      estimatedQuantity: 330.0,
      estimatedUnit: 'g',
      notes:
          'Detected lean grilled chicken breast (~180g), cooked organic quinoa (~150g), and roasted mixed greens with olive oil dressing.',
    );
  }

  FitnessContext getShowcaseFitnessContext() {
    final now = DateTime.now();
    return FitnessContext(
      userProfile: getShowcaseUserProfile(),
      userGoal: UserGoal(
        id: 'goal_showcase',
        goalType: FitnessGoalType.muscleGain,
        fitnessLevel: FitnessLevel.intermediate,
        activityLevel: ActivityLevel.moderate,
        age: 26,
        height: 178.0,
        currentWeight: 72.4,
        targetWeight: 76.0,
        targetCalories: 2300.0,
        targetProtein: 160.0,
        targetCarbohydrates: 260.0,
        targetFats: 65.0,
        createdDate: now.subtract(const Duration(days: 30)),
        updatedDate: now,
      ),
      workoutHistory: getShowcaseWorkoutHistory(),
      nutritionSummary: const NutritionSummary(
        totalCaloriesConsumed: 2153.0,
        averageDailyCalories: 2300.0,
        averageProtein: 142.0,
        proteinGoalHitPercentage: 92.0,
      ),
      userProgress: getShowcaseUserProgress(),
      progressSummary: ProgressSummary(
        totalWorkouts: 48,
        totalVolume: 580000.0,
        totalTrainingMinutes: 2880,
        currentRank: 'Gold',
        currentXP: 14850,
        currentStreak: 7,
        longestStreak: 30,
        weeklyVolume: 63800.0,
        monthlyVolume: 198200.0,
        weeklyVolumeChangePercent: 8.5,
        monthlyVolumeChangePercent: 14.2,
        weeklyWorkoutChange: 1,
        strengthGrowthPercent: 12.0,
        consistencyScore: 92.0,
        personalRecords: [
          PersonalRecord(
            id: 'pr_bench',
            exerciseName: 'Barbell Bench Press',
            muscleGroup: 'Chest',
            recordType: 'Weight PR',
            value: 110.0,
            previousValue: 105.0,
            improvementPercentage: 4.8,
            achievedDate: now.subtract(const Duration(days: 1)),
          ),
          PersonalRecord(
            id: 'pr_deadlift',
            exerciseName: 'Barbell Deadlift',
            muscleGroup: 'Back',
            recordType: 'Weight PR',
            value: 175.0,
            previousValue: 170.0,
            improvementPercentage: 2.9,
            achievedDate: now.subtract(const Duration(days: 2)),
          ),
        ],
        topExercises: const [],
        muscleGroupDistribution: const {
          'Chest': 28.0,
          'Back': 28.0,
          'Legs': 30.0,
          'Arms': 14.0,
        },
        lastUpdated: now,
      ),
      nutritionProgress: const NutritionProgress(
        currentNutritionStreak: 14,
        longestNutritionStreak: 25,
        totalMealsCompleted: 142,
        totalProteinGoalsAchieved: 26,
      ),
      todayHealthMetric: HealthMetric.sample(),
      recoveryState: getShowcaseRecoveryState(),
      generatedAt: now,
    );
  }

  DigitalAthlete getShowcaseDigitalAthlete() {
    return DigitalAthlete(
      userId: 'usr_showcase_athlete',
      physicalProfile: const PhysicalProfile(
        age: 26,
        weightKg: 77.5,
        heightCm: 178.0,
        gender: 'male',
        bodyFatPercentage: 13.8,
      ),
      strengthProfile: const StrengthProfile(
        estimated1RM: {
          'Squat': 142.5,
          'Bench Press': 110.0,
          'Deadlift': 175.0,
          'Overhead Press': 72.5,
        },
        strengthLevel: 'Advanced',
        progressionVelocityPercentage: 4.2,
        totalStrengthVolumeKg: 580000.0,
      ),
      trainingProfile: const TrainingProfile(
        preferredSplit: 'Upper / Lower',
        weeklyFrequency: 4,
        averageSessionMinutes: 58,
        trainingPersonality: 'Methodical Powerbuilder',
        favoriteExercises: [
          'Barbell Bench Press',
          'Barbell Back Squat',
          'Barbell Deadlift',
          'Weighted Pull-Up',
        ],
      ),
      recoveryProfile: const RecoveryProfile(
        averageRecoveryScore: 88.0,
        sleepDurationHours: 7.8,
        hrvAverage: 76.0,
        restingHeartRate: 52,
        fatigueSensitivity: 'low',
      ),
      nutritionProfile: const NutritionProfile(
        dailyCalories: 2650,
        dailyProteinGrams: 185.0,
        dailyCarbsGrams: 238.0,
        dailyFatGrams: 65.0,
        adherenceRate: 0.96,
        dietaryPreference: 'high_protein',
      ),
      behaviorProfile: const BehaviorProfile(
        consistencyScore: 94.0,
        preferredWorkoutTime: 'evening',
        missedSessionTrigger: 'accumulated_fatigue',
        habitContinuityRate: 0.95,
      ),
      goalProfile: const GoalProfile(
        primaryGoal: 'hypertrophy',
        targetWeightKg: 76.0,
        targetStrengthMilestones: {
          'Squat': 155.0,
          'Bench Press': 120.0,
          'Deadlift': 190.0,
        },
      ),
      biomechanicsWeaknesses: const [
        'Squat: Slight forward torso lean on 90%+ 1RM attempts',
      ],
      formScoreAverages: const {
        'Squat': 92.0,
        'Bench Press': 96.0,
        'Deadlift': 91.0,
      },
      updatedAt: DateTime.now(),
    );
  }
}
