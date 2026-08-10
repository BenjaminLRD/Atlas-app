import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/models/fitness_context.dart';
import 'package:aizawl_gym/models/nutrition_progress.dart';
import 'package:aizawl_gym/models/nutrition_summary.dart';
import 'package:aizawl_gym/models/progress_summary.dart';
import 'package:aizawl_gym/models/recommendation.dart';
import 'package:aizawl_gym/models/user_goal.dart';
import 'package:aizawl_gym/models/user_profile.dart';
import 'package:aizawl_gym/models/user_progress.dart';
import 'package:aizawl_gym/models/workout_history.dart';
import 'package:aizawl_gym/providers/fitness_provider.dart';
import 'package:aizawl_gym/services/recommendation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    FitnessProvider.resetInstance();
  });

  group('FitnessContext Model Tests', () {
    test('initial FitnessContext has default empty structures', () {
      final ctx = FitnessContext.initial();

      expect(ctx.userGoal, isNull);
      expect(ctx.userProfile, isNull);
      expect(ctx.workoutHistory, isEmpty);
      expect(ctx.nutritionSummary.proteinGoalHitPercentage, equals(0.0));
      expect(ctx.progressSummary.totalWorkouts, equals(0));
      expect(ctx.userProgress.totalXP, equals(0));
      expect(ctx.nutritionProgress.currentNutritionStreak, equals(0));
    });

    test('toJson and fromJson work symmetrically', () {
      final now = DateTime(2026, 8, 7, 12, 0);
      final ctx = FitnessContext(
        userGoal: UserGoal.initial(),
        userProfile: UserProfile.defaultProfile(),
        workoutHistory: [
          WorkoutHistory(
            workoutName: 'Upper Body',
            dateCompleted: now,
            durationSeconds: 2700,
            exercisesCompleted: 4,
            completionPercentage: 100.0,
          ),
        ],
        nutritionSummary: NutritionSummary.empty(),
        progressSummary: ProgressSummary.zero(),
        userProgress: UserProgress.initial(),
        nutritionProgress: NutritionProgress.initial(),
        generatedAt: now,
      );

      final json = ctx.toJson();
      final restored = FitnessContext.fromJson(json);

      expect(restored.userGoal, isNotNull);
      expect(restored.userGoal!.id, equals('default_goal'));
      expect(restored.userProfile?.name, equals('Zothanmawia'));
      expect(restored.workoutHistory.length, equals(1));
      expect(restored.workoutHistory.first.workoutName, equals('Upper Body'));
    });

    test('copyWith updates specified fields', () {
      final initial = FitnessContext.initial();
      final updatedGoal = UserGoal.initial().copyWith(goalType: FitnessGoalType.fatLoss);
      final updated = initial.copyWith(userGoal: updatedGoal);

      expect(updated.userGoal, isNotNull);
      expect(updated.userGoal!.goalType, equals(FitnessGoalType.fatLoss));
      expect(updated.workoutHistory, isEmpty);
    });
  });

  group('Recommendation Model Tests', () {
    test('Recommendation serialization and isExpired property', () {
      final now = DateTime.now();
      final past = now.subtract(const Duration(hours: 2));
      final rec = Recommendation(
        id: 'rec_1',
        title: 'High Protein Intake',
        description: 'Aim for 160g protein daily',
        category: RecommendationCategory.nutrition,
        priority: RecommendationPriority.high,
        actionTitle: 'View Diet Plan',
        actionRoute: '/diet-plan',
        reasoning: 'Protein hit rate is low',
        metricTrigger: 'Protein: 45%',
        createdAt: now,
        expiresAt: past,
      );

      expect(rec.isExpired, isTrue);

      final json = rec.toJson();
      final restored = Recommendation.fromJson(json);

      expect(restored.id, equals('rec_1'));
      expect(restored.title, equals('High Protein Intake'));
      expect(restored.category, equals(RecommendationCategory.nutrition));
      expect(restored.priority, equals(RecommendationPriority.high));
      expect(restored.actionRoute, equals('/diet-plan'));
    });

    test('copyWith updates values accurately', () {
      final rec = Recommendation(
        id: 'rec_1',
        title: 'Title',
        description: 'Desc',
        category: RecommendationCategory.training,
        priority: RecommendationPriority.medium,
        actionTitle: 'Action',
        reasoning: 'Reason',
        createdAt: DateTime.now(),
      );

      final updated = rec.copyWith(isDismissed: true, priority: RecommendationPriority.high);

      expect(updated.isDismissed, isTrue);
      expect(updated.priority, equals(RecommendationPriority.high));
      expect(updated.title, equals('Title'));
    });
  });

  group('RuleBasedRecommendationEngine Rules Tests', () {
    const engine = RuleBasedRecommendationEngine();

    test('generates muscleGain goal recommendation', () {
      final ctx = FitnessContext.initial().copyWith(
        userGoal: UserGoal.initial().copyWith(
          goalType: FitnessGoalType.muscleGain,
          targetCalories: 2800.0,
          targetProtein: 150.0,
          currentWeight: 70.0,
          targetWeight: 75.0,
        ),
      );

      final recs = engine.generateRecommendations(ctx);

      expect(recs.any((r) => r.id == 'rec_goal_muscle_gain'), isTrue);
      final muscleRec = recs.firstWhere((r) => r.id == 'rec_goal_muscle_gain');
      expect(muscleRec.category, equals(RecommendationCategory.nutrition));
      expect(muscleRec.priority, equals(RecommendationPriority.high));
      expect(muscleRec.reasoning, contains('Muscle Gain'));
    });

    test('generates low protein hit rate recommendation when below 70%', () {
      final ctx = FitnessContext.initial().copyWith(
        nutritionSummary: NutritionSummary.empty().copyWith(
          proteinGoalHitPercentage: 45.0,
        ),
      );

      final recs = engine.generateRecommendations(ctx);

      expect(recs.any((r) => r.id == 'rec_nutrition_protein_boost'), isTrue);
      final boostRec = recs.firstWhere((r) => r.id == 'rec_nutrition_protein_boost');
      expect(boostRec.metricTrigger, contains('45%'));
    });

    test('generates active recovery recommendation for streaks >= 3', () {
      final ctx = FitnessContext.initial().copyWith(
        progressSummary: ProgressSummary.zero().copyWith(
          currentStreak: 4,
          totalWorkouts: 10,
        ),
      );

      final recs = engine.generateRecommendations(ctx);

      expect(recs.any((r) => r.id == 'rec_training_recovery_check'), isTrue);
      final rec = recs.firstWhere((r) => r.id == 'rec_training_recovery_check');
      expect(rec.category, equals(RecommendationCategory.recovery));
    });

    test('generates rank up recommendation when XP needed <= 150', () {
      final ctx = FitnessContext.initial().copyWith(
        userProgress: const UserProgress(
          totalXP: 650, // 100 XP needed to reach Bronze III (750 XP)
          completedWorkouts: 8,
          rankedUnlocked: true,
          currentRank: 'Bronze',
          currentDivision: 'IV',
          workoutStreak: 2,
          longestStreak: 4,
          lastWorkoutDate: null,
          totalWorkoutMinutes: 120,
          totalVolumeLifted: 5000.0,
          achievements: [],
        ),
      );

      final recs = engine.generateRecommendations(ctx);

      expect(recs.any((r) => r.id == 'rec_gamification_rank_up_close'), isTrue);
      final rankRec = recs.firstWhere((r) => r.id == 'rec_gamification_rank_up_close');
      expect(rankRec.reasoning, contains('100 XP remaining'));
    });

    test('RecommendationService filters out dismissed and duplicate recommendations', () {
      const service = RecommendationService();
      final ctx = FitnessContext.initial().copyWith(
        userGoal: UserGoal.initial().copyWith(goalType: FitnessGoalType.muscleGain),
      );

      final initialRecs = service.evaluateContext(ctx);
      expect(initialRecs, isNotEmpty);

      // Dismiss the first recommendation
      final dismissedFirst = initialRecs.first.copyWith(isDismissed: true);
      final filteredRecs = service.evaluateContext(
        ctx,
        existingRecommendations: [dismissedFirst],
      );

      expect(filteredRecs.any((r) => r.id == dismissedFirst.id), isFalse);
    });
  });

  group('FitnessProvider AI Coach Integration Tests', () {
    test('FitnessProvider builds context and exposes reactive recommendations', () async {
      final provider = FitnessProvider.instance;

      final ctx = provider.buildFitnessContext();
      expect(ctx, isNotNull);
      expect(ctx.generatedAt, isNotNull);

      final recs = provider.recommendations;
      expect(recs, isNotNull);
      expect(recs.isNotEmpty, isTrue);

      final firstRecId = recs.first.id;
      int notifyCount = 0;
      provider.addListener(() {
        notifyCount++;
      });

      provider.dismissRecommendation(firstRecId);

      expect(notifyCount, equals(1));
      expect(provider.recommendations.any((r) => r.id == firstRecId), isFalse);
    });
  });
}
