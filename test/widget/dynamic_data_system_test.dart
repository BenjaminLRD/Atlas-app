import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/providers/showcase_mode_provider.dart';
import 'package:atlas/providers/showcase_data_provider.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/widgets/common/daily_motivation_card.dart';
import 'package:atlas/widgets/common/readiness_card.dart';
import 'package:atlas/widgets/dashboard/weight_trends_card.dart';
import 'package:atlas/widgets/dashboard/dashboard_achievements_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Dynamic Data System Widget Tests (Fresh User vs Showcase Mode)', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await LocalStorage.init();
      AppDependencies.reset();
      ShowcaseModeProvider.resetInstance();
      ShowcaseDataProvider.resetInstance();
      FitnessProvider.resetInstance();
    });

    testWidgets('1. DailyMotivationCard renders onboarding quote for fresh user and Kai Greene quote for showcase mode',
        (tester) async {
      // 1. Fresh user
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DailyMotivationCard(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('“Every day is a fresh start.”'), findsOneWidget);
      expect(find.text('— Unknown'), findsOneWidget);
      expect(
        find.text(
          'Complete your profile to get personalized insights and motivation.',
        ),
        findsOneWidget,
      );

      // 2. Enable Showcase Mode
      await ShowcaseModeProvider.instance.enableShowcaseMode();
      await tester.pumpAndSettle();

      expect(find.text('“Discipline today, strength tomorrow.”'), findsOneWidget);
      expect(find.text('— Kai Greene'), findsOneWidget);
      expect(
        find.text(
          'Stay consistent with your training and nutrition. You\'ve got this!',
        ),
        findsOneWidget,
      );
    });

    testWidgets('2. ReadinessCard renders "-" and empty state when null, and "GOOD" 76% when state is provided',
        (tester) async {
      // 1. Fresh user (null state)
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReadinessCard(state: null),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('-'), findsNWidgets(3)); // status badge, readiness, fatigue
      expect(find.text('No readiness data yet'), findsOneWidget);
      expect(
        find.text(
          'Complete workouts and track recovery to see personalized insights.',
        ),
        findsOneWidget,
      );

      // 2. Showcase state
      final showcaseState = ShowcaseDataProvider.instance.getShowcaseTrainingState();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReadinessCard(state: showcaseState),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('GOOD'), findsOneWidget);
      expect(find.text('76%'), findsOneWidget);
      expect(find.text('28%'), findsOneWidget);
      expect(
        find.text(
          'Good readiness! Your body is primed for a productive training session.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('3. WeightTrendsCard renders empty state for fresh user and 72.4kg graph for showcase mode',
        (tester) async {
      // 1. Fresh user
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WeightTrendsCard(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Weight Trends'), findsOneWidget);
      expect(find.text('No data available'), findsOneWidget);
      expect(
        find.text('Start tracking your weight to see trends over time.'),
        findsOneWidget,
      );
      expect(find.text('-'), findsNWidgets(4)); // CURRENT, CHANGE, LOWEST, HIGHEST

      // 2. Enable Showcase Mode
      await ShowcaseModeProvider.instance.enableShowcaseMode();
      await tester.pumpAndSettle();

      expect(find.text('72.4 kg'), findsOneWidget);
      expect(find.text('↓ 1.2 kg'), findsOneWidget);
      expect(find.text('68.7 kg'), findsOneWidget);
      expect(find.text('75.1 kg'), findsOneWidget);
      expect(find.text('No data available'), findsNothing);
    });

    testWidgets('4. DashboardAchievementsCard renders "Keep it up!" for fresh user and "Great job! 🔥" for showcase mode',
        (tester) async {
      // 1. Fresh user
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardAchievementsCard(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Keep it up!'), findsOneWidget);
      expect(
        find.text(
          'Complete your first workout to see personalized achievements here.',
        ),
        findsOneWidget,
      );

      // 2. Enable Showcase Mode
      await ShowcaseModeProvider.instance.enableShowcaseMode();
      await tester.pumpAndSettle();

      expect(find.text('Great job! 🔥'), findsOneWidget);
      expect(
        find.text(
          'You\'ve hit 7 day streak milestone! Keep pushing toward your goals.',
        ),
        findsOneWidget,
      );
    });
  });
}
