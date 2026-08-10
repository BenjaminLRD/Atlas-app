import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/models/brief_item.dart';
import 'package:aizawl_gym/models/daily_brief.dart';
import 'package:aizawl_gym/models/fitness_context.dart';
import 'package:aizawl_gym/models/nutrition_progress.dart';
import 'package:aizawl_gym/models/nutrition_summary.dart';
import 'package:aizawl_gym/models/progress_summary.dart';
import 'package:aizawl_gym/models/user_goal.dart';
import 'package:aizawl_gym/models/user_progress.dart';
import 'package:aizawl_gym/providers/fitness_provider.dart';
import 'package:aizawl_gym/services/ai/daily_brief_service.dart';
import 'package:aizawl_gym/widgets/coach/daily_brief_card.dart';
import 'package:aizawl_gym/screens/daily_brief_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    FitnessProvider.resetInstance();
  });

  group('BriefItem & DailyBrief Serialization Tests', () {
    test('BriefItem toJson & fromJson round-trip', () {
      const item = BriefItem(
        title: 'High Protein Hit',
        description: 'You hit 160g protein today!',
        category: 'NUTRITION',
        icon: 'restaurant',
        actionTitle: 'View Nutrition',
        actionRoute: 'open_nutrition',
      );

      final json = item.toJson();
      final restored = BriefItem.fromJson(json);

      expect(restored.title, equals(item.title));
      expect(restored.description, equals(item.description));
      expect(restored.category, equals(item.category));
      expect(restored.icon, equals(item.icon));
      expect(restored.actionTitle, equals(item.actionTitle));
      expect(restored.actionRoute, equals(item.actionRoute));
    });

    test('DailyBrief toJson & fromJson round-trip', () {
      final now = DateTime(2026, 8, 8, 3, 0);
      final brief = DailyBrief(
        id: 'brief_1',
        date: now,
        headline: 'Peak Performance!',
        summary: 'Keep up the workout streak.',
        focusArea: 'Strength & Training',
        items: const [
          BriefItem(
            title: 'Streak',
            description: '5 day streak',
            category: 'TRAINING',
            icon: 'fitness_center',
          ),
        ],
        priority: 1,
        createdAt: now,
        isRead: false,
        contextSummary: 'streak:5|protein:80',
      );

      final json = brief.toJson();
      final restored = DailyBrief.fromJson(json);

      expect(restored.id, equals(brief.id));
      expect(restored.headline, equals(brief.headline));
      expect(restored.summary, equals(brief.summary));
      expect(restored.focusArea, equals(brief.focusArea));
      expect(restored.items.length, equals(1));
      expect(restored.items.first.title, equals('Streak'));
      expect(restored.contextSummary, equals(brief.contextSummary));
    });
  });

  group('DailyBriefService Generation Rules Tests', () {
    const service = DailyBriefService();

    test('generates high streak training item and protein target item', () {
      final ctx = FitnessContext.initial().copyWith(
        userGoal: UserGoal.initial().copyWith(
          targetProtein: 160,
          targetCalories: 2400,
        ),
        progressSummary: ProgressSummary.zero().copyWith(
          currentStreak: 4,
          totalWorkouts: 10,
        ),
        nutritionSummary: NutritionSummary.empty().copyWith(
          proteinGoalHitPercentage: 85.0,
        ),
        nutritionProgress: NutritionProgress.initial().copyWith(
          currentNutritionStreak: 3,
        ),
      );

      final brief = service.generateBrief(ctx);

      expect(brief.headline, equals('Peak Training Momentum!'));
      expect(brief.focusArea, equals('Strength & Training'));
      expect(brief.items.isNotEmpty, isTrue);

      final trainingItem = brief.items.firstWhere((i) => i.category == 'TRAINING');
      expect(trainingItem.title, contains('High Workout Streak'));
      expect(trainingItem.description, contains('4-day workout streak'));

      final nutritionItem = brief.items.firstWhere((i) => i.category == 'NUTRITION');
      expect(nutritionItem.title, contains('Optimal Protein Adherence'));
      expect(nutritionItem.description, contains('85%'));
    });

    test('sorts items by priority order (TRAINING, NUTRITION, GOALS, GAMIFICATION)', () {
      final ctx = FitnessContext.initial().copyWith(
        userGoal: UserGoal.initial(),
        progressSummary: ProgressSummary.zero().copyWith(currentStreak: 3),
        userProgress: const UserProgress(
          totalXP: 500,
          completedWorkouts: 5,
          rankedUnlocked: true,
          currentRank: 'Silver',
          currentDivision: 'II',
          workoutStreak: 3,
          longestStreak: 5,
          lastWorkoutDate: null,
          totalWorkoutMinutes: 150,
          totalVolumeLifted: 8000.0,
          achievements: [],
        ),
      );

      final brief = service.generateBrief(ctx);
      final categories = brief.items.map((e) => e.category).toList();

      expect(categories.first, equals('TRAINING'));
      expect(categories[1], equals('NUTRITION'));
      expect(categories[2], equals('GOALS'));
      expect(categories[3], equals('GAMIFICATION'));
    });
  });

  group('FitnessProvider DailyBrief Integration Tests', () {
    test('provider exposes dailyBrief and responds to refreshDailyBrief', () async {
      final provider = FitnessProvider.instance;
      expect(provider.dailyBrief, isNotNull);

      final initialBrief = provider.dailyBrief!;
      expect(initialBrief.headline, isNotEmpty);

      provider.refreshDailyBrief();
      expect(provider.dailyBrief, isNotNull);
    });
  });

  group('DailyBrief UI Components Widget Tests', () {
    testWidgets('DailyBriefCard renders headline, focusArea, and button', (tester) async {
      final now = DateTime(2026, 8, 8);
      final testBrief = DailyBrief(
        id: 'b1',
        date: now,
        headline: 'Training Focus Today',
        summary: 'Complete your chest workout to maintain momentum.',
        focusArea: 'Strength & Training',
        items: const [
          BriefItem(
            title: 'Chest & Triceps',
            description: '4 sets of Bench Press',
            category: 'TRAINING',
            icon: 'fitness_center',
          ),
        ],
        createdAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyBriefCard(brief: testBrief),
          ),
        ),
      );

      expect(find.text('DAILY BRIEF'), findsOneWidget);
      expect(find.text('Training Focus Today'), findsOneWidget);
      expect(find.text('Strength & Training'), findsOneWidget);
      expect(find.text('VIEW DAILY BRIEF'), findsOneWidget);
    });

    testWidgets('DailyBriefScreen renders full daily advice sections', (tester) async {
      final now = DateTime(2026, 8, 8);
      final testBrief = DailyBrief(
        id: 'b2',
        date: now,
        headline: 'Nutritional Focus Today',
        summary: 'Ensure you reach 150g protein to support recovery.',
        focusArea: 'Nutritional Balance',
        items: const [
          BriefItem(
            title: 'Heavy Bench Press',
            description: 'Target 80kg today.',
            category: 'TRAINING',
            icon: 'fitness_center',
            actionTitle: 'View Routine',
            actionRoute: 'open_workout',
          ),
          BriefItem(
            title: 'Protein Intake',
            description: '150g protein target.',
            category: 'NUTRITION',
            icon: 'restaurant',
            actionTitle: 'Log Meals',
            actionRoute: 'open_nutrition',
          ),
        ],
        createdAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DailyBriefScreen(brief: testBrief),
        ),
      );

      expect(find.text('AI COACH BRIEF'), findsOneWidget);
      expect(find.text('Nutritional Focus Today'), findsOneWidget);
      expect(find.text('Training Advice'), findsOneWidget);
      expect(find.text('Nutrition Advice'), findsOneWidget);
      expect(find.text('Heavy Bench Press'), findsOneWidget);
      expect(find.text('Protein Intake'), findsOneWidget);
    });
  });
}
