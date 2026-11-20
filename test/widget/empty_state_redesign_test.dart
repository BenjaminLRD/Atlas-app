import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/theme/app_theme.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/screens/workout_history_screen.dart';
import 'package:atlas/screens/diet_plan_screen.dart';
import 'package:atlas/widgets/common/app_empty_state.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    AppDependencies.instance;
    await AppDependencies.instance.profileProvider.updateProfile(
      UserProfile.defaultProfile(
        email: 'benjamin@example.com',
      ).copyWith(name: 'Benjamin LRD', fitnessGoal: 'Hypertrophy Goal'),
    );
  });

  Widget buildTestApp(Widget home) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: Scaffold(body: home),
    );
  }

  group('Phase 4 Empty State Redesign Tests', () {
    testWidgets(
      'AppEmptyState.startJourney renders title, subtitle, 4 unlock checklist items, and CTA button',
      (tester) async {
        bool buttonTapped = false;

        await tester.pumpWidget(
          buildTestApp(
            AppEmptyState.startJourney(
              onStartWorkout: () => buttonTapped = true,
            ),
          ),
        );
        await tester.pump();

        // Title & Subtitle
        expect(find.text('Start your journey'), findsOneWidget);
        expect(
          find.text('Complete your first workout to unlock:'),
          findsOneWidget,
        );

        // Checklist unlocks
        expect(find.text('Performance analytics'), findsOneWidget);
        expect(find.text('XP progression'), findsOneWidget);
        expect(find.text('Achievements'), findsOneWidget);
        expect(find.text('AI recommendations'), findsOneWidget);

        // Action button
        final buttonFinder = find.text('Start Workout');
        expect(buttonFinder, findsOneWidget);
        await tester.tap(buttonFinder);
        expect(buttonTapped, isTrue);
      },
    );

    testWidgets(
      'AppEmptyState.noNutrition renders title, checklist items, and CTA',
      (tester) async {
        bool actionTapped = false;

        await tester.pumpWidget(
          buildTestApp(
            AppEmptyState.noNutrition(onAddFood: () => actionTapped = true),
          ),
        );
        await tester.pump();

        expect(find.text('No meals tracked today.'), findsOneWidget);
        expect(
          find.text('Log your first meal today to track calories and macronutrients.'),
          findsOneWidget,
        );
        expect(find.text('Calorie deficit & surplus balance'), findsOneWidget);
        expect(
          find.text('Macronutrient breakdown (Protein, Carbs, Fats)'),
          findsOneWidget,
        );
        expect(
          find.text('Nutrition consistency & meal streaks'),
          findsOneWidget,
        );

        final buttonFinder = find.text('Log First Meal');
        expect(buttonFinder, findsOneWidget);
        await tester.tap(buttonFinder);
        expect(actionTapped, isTrue);
      },
    );

    testWidgets(
      'AppEmptyState.noAchievements renders title, checklist items, and CTA',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(AppEmptyState.noAchievements(onStartWorkout: () {})),
        );
        await tester.pump();

        expect(find.text('Unlock Your Potential'), findsOneWidget);
        expect(
          find.text(
            'Complete workouts and hit consistency milestones to unlock:',
          ),
          findsOneWidget,
        );
        expect(find.text('Milestone & Consistency badges'), findsOneWidget);
        expect(find.text('Profile showcase rank & flair'), findsOneWidget);
        expect(find.text('Leaderboard XP multipliers'), findsOneWidget);
        expect(find.text('Start Workout'), findsOneWidget);
      },
    );

    testWidgets(
      'AppEmptyState.noChat renders title, checklist items, and CTA',
      (tester) async {
        await tester.pumpWidget(
          buildTestApp(AppEmptyState.noChat(onStartChat: () {})),
        );
        await tester.pump();

        expect(find.text('Start chatting with your coach.'), findsOneWidget);
        expect(
          find.text('Ask your AI coach for personalized workouts, nutrition plans, and form advice.'),
          findsOneWidget,
        );
        expect(
          find.text('Instant workout form tips & tutorials'),
          findsOneWidget,
        );
        expect(find.text('Start Conversation'), findsOneWidget);
      },
    );

    testWidgets(
      'WorkoutHistoryScreen shows Start your journey empty state when 0 sessions logged',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: const WorkoutHistoryScreen(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Start your journey'), findsWidgets);
        expect(
          find.text('Complete your first workout to unlock:'),
          findsOneWidget,
        );
        expect(find.text('Performance analytics'), findsOneWidget);
        expect(find.text('XP progression'), findsOneWidget);
        expect(find.text('Achievements'), findsOneWidget);
        expect(find.text('AI recommendations'), findsOneWidget);
        expect(find.text('Start Workout'), findsOneWidget);
      },
    );

    testWidgets(
      'DietPlanScreen renders Nutrition Dashboard structure with modern empty state readiness',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.lightTheme, home: const DietPlanScreen()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('NUTRITION DASHBOARD'), findsOneWidget);
        expect(find.text('MACRONUTRIENTS'), findsOneWidget);
        expect(find.text("TODAY'S MEALS"), findsOneWidget);
      },
    );
  });
}
