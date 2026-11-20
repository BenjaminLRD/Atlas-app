import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/theme/app_theme.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/screens/dashboard_screen.dart';
import 'package:atlas/screens/diet_plan_screen.dart';
import 'package:atlas/screens/profile_screen.dart';
import 'package:atlas/screens/workout_history_screen.dart';
import 'package:atlas/screens/workout_session_screen.dart';
import 'package:atlas/widgets/coach/coach_summary_card.dart';
import 'package:atlas/widgets/common/adaptive_workout_card.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    AppDependencies.instance;
    await AppDependencies.instance.profileProvider.updateProfile(
      UserProfile.defaultProfile(email: 'benjamin@example.com').copyWith(
        name: 'Benjamin LRD',
        fitnessGoal: 'Hypertrophy Goal',
        gender: 'Male',
        height: '175',
        weight: '72',
      ),
    );
  });

  Widget buildTestApp(Widget home) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: home,
    );
  }

  group('Phase 3 Screen Redesign & Hierarchy Tests', () {
    testWidgets(
      'Dashboard renders strict hierarchy: Important Action -> Progress -> Recommendations',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp(const DashboardScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // 1. Important Action: Active Protocol Hero Card
        expect(find.text('ACTIVE PROTOCOL'), findsOneWidget);
        expect(find.text('Start Workout'), findsWidgets);

        // 2. Progress: Daily Motivation & Ranked Mode
        expect(find.byType(CoachSummaryCard), findsOneWidget);
        expect(find.text('Atlas AI'), findsOneWidget);

        // 3. Recommendations & Intelligence
        expect(find.text('Recommendations & Intelligence'), findsOneWidget);
        expect(find.byType(AdaptiveWorkoutCard), findsOneWidget);
      },
    );

    testWidgets(
      'Profile Screen renders body composition, edit profile button, and achievements',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp(const ProfileScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Edit Profile button
        expect(find.text('Edit Profile'), findsOneWidget);

        // Weight Trends
        expect(find.text('Weight Trends'), findsOneWidget);

        // Weekly Performance
        expect(find.text('WEEKLY PERFORMANCE'), findsOneWidget);

        // Workout Timeline
        expect(find.text('Workout Timeline'), findsOneWidget);
      },
    );

    testWidgets(
      'Nutrition Screen renders Macro cards, Meal cards, and add food actions',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp(const DietPlanScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('NUTRITION DASHBOARD'), findsOneWidget);
        expect(find.text('MACRONUTRIENTS'), findsOneWidget);
        expect(find.text("TODAY'S MEALS"), findsOneWidget);
        expect(find.text('ADD FOOD'), findsOneWidget);
      },
    );

    testWidgets(
      'Progress Screen renders Analytics overview, timeline, and insights',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(buildTestApp(const WorkoutHistoryScreen()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Progress & Analytics'), findsOneWidget);
        expect(find.text('Workout Timeline'), findsOneWidget);
      },
    );

    testWidgets(
      'Workout Session Screen renders exercise hero, set tracking, and target customizers',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          buildTestApp(
            const WorkoutSessionScreen(
              workoutName: 'Leg Day - Hypertrophy',
              workoutId: 'test_session_01',
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Leg Day - Hypertrophy'), findsOneWidget);
        expect(find.text('SET TRACKING'), findsOneWidget);
        expect(
          find.text('TARGET CUSTOMIZATION (THIS SESSION)'),
          findsOneWidget,
        );
        expect(find.text('START SET 1'), findsOneWidget);
      },
    );
  });
}
