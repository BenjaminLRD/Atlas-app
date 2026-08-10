import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aizawl_gym/widgets/common/skeleton_card.dart';
import 'package:aizawl_gym/widgets/analytics/strength_progress_card.dart';
import 'package:aizawl_gym/widgets/progress/personal_records_section.dart';
import 'package:aizawl_gym/widgets/progress/insight_section.dart';
import 'package:aizawl_gym/widgets/progress/workout_timeline.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Skeleton Components Tests', () {
    testWidgets('SkeletonCard renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonCard(width: 100, height: 100),
          ),
        ),
      );

      expect(find.byType(SkeletonCard), findsOneWidget);
    });

    testWidgets('SkeletonAnalyticsCard renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonAnalyticsCard(),
          ),
        ),
      );

      expect(find.byType(SkeletonAnalyticsCard), findsOneWidget);
    });

    testWidgets('SkeletonChartCard renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonChartCard(),
          ),
        ),
      );

      expect(find.byType(SkeletonChartCard), findsOneWidget);
    });

    testWidgets('SkeletonTimelineCard renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonTimelineCard(),
          ),
        ),
      );

      expect(find.byType(SkeletonTimelineCard), findsOneWidget);
    });
  });

  group('Polished Empty State Widgets Tests', () {
    testWidgets('StrengthProgressCard displays polished empty state when topExercises is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StrengthProgressCard(topExercises: []),
          ),
        ),
      );

      expect(find.text('No Strength Logs Yet'), findsOneWidget);
      expect(find.text('Complete workouts to track exercise progression.'), findsOneWidget);
    });

    testWidgets('PersonalRecordsSection displays polished empty state when records is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PersonalRecordsSection(records: []),
          ),
        ),
      );

      expect(find.text('No Personal Records Yet'), findsOneWidget);
      expect(find.text('Set your first PR by completing workouts.'), findsOneWidget);
    });

    testWidgets('InsightSection displays polished empty state when insights is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InsightSection(insights: []),
          ),
        ),
      );

      expect(find.text('Analyzing Performance Data'), findsOneWidget);
      expect(find.text('Complete workouts to unlock personalized recommendations.'), findsOneWidget);
    });

    testWidgets('WorkoutTimeline displays polished empty state when history is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WorkoutTimeline(history: []),
          ),
        ),
      );

      expect(find.text('No Workout Journal Yet'), findsOneWidget);
      expect(find.text('Log your first session to build your history.'), findsOneWidget);
    });
  });
}
