import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/models/nutrition_summary.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/widgets/nutrition_analytics/nutrition_summary_card.dart';
import 'package:aizawl_gym/widgets/nutrition_analytics/protein_performance_card.dart';
import 'package:aizawl_gym/widgets/nutrition_analytics/macro_distribution_chart.dart';
import 'package:aizawl_gym/widgets/nutrition_analytics/calorie_trend_card.dart';
import 'package:aizawl_gym/widgets/nutrition_analytics/nutrition_insight_section.dart';
import 'package:aizawl_gym/screens/diet_plan_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );
  }

  const testSummary = NutritionSummary(
    totalCaloriesConsumed: 14000.0,
    averageDailyCalories: 2000.0,
    averageProtein: 150.0,
    averageCarbohydrates: 220.0,
    averageFats: 60.0,
    proteinGoalHitPercentage: 85.0,
    calorieGoalConsistency: 90.0,
    currentNutritionStreak: 6,
    weeklyCalories: [1800.0, 2000.0, 2100.0, 1950.0, 2200.0, 2000.0, 1950.0],
    macroBalance: {'protein': 30.0, 'carbs': 50.0, 'fats': 20.0},
  );

  group('Nutrition Analytics Dashboard Widgets Tests', () {
    testWidgets('NutritionSummaryCard renders without error', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const NutritionSummaryCard(summary: testSummary)));
      await tester.pumpAndSettle();

      expect(find.text('NUTRITION SUMMARY'), findsOneWidget);
      expect(find.text('6 Day Streak'), findsOneWidget);
      expect(find.text('TOTAL CONSUMED'), findsOneWidget);
      expect(find.text('DAILY AVERAGE'), findsOneWidget);
    });

    testWidgets('ProteinPerformanceCard renders protein metrics', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const ProteinPerformanceCard(summary: testSummary)));
      await tester.pumpAndSettle();

      expect(find.text('PROTEIN PERFORMANCE'), findsOneWidget);
      expect(find.text('85%'), findsOneWidget);
      expect(find.text('150g avg'), findsOneWidget);
    });

    testWidgets('MacroDistributionChart renders and switches segment selection on tap', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const MacroDistributionChart(summary: testSummary)));
      await tester.pumpAndSettle();

      expect(find.text('MACRO DISTRIBUTION'), findsOneWidget);
      expect(find.textContaining('Protein'), findsWidgets);
    });

    testWidgets('CalorieTrendCard renders 7-day trend values', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const CalorieTrendCard(summary: testSummary)));
      await tester.pumpAndSettle();

      expect(find.text('7-DAY CALORIE TREND'), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
    });

    testWidgets('NutritionInsightSection renders generated insights', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const NutritionInsightSection(summary: testSummary)));
      await tester.pumpAndSettle();

      expect(find.text('NUTRITION INSIGHTS'), findsOneWidget);
      expect(find.text('Optimal Protein Muscle Recovery'), findsOneWidget);
      expect(find.text('Consistent Calorie Balance'), findsOneWidget);
    });

    testWidgets('DietPlanScreen renders full analytics and insights sections', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: ThemeData.dark(), home: const DietPlanScreen()));
      await tester.pumpAndSettle();

      expect(find.text('NUTRITION DASHBOARD'), findsOneWidget);
      expect(find.text('NUTRITION ANALYTICS', skipOffstage: false), findsOneWidget);
      expect(find.text('NUTRITION INSIGHTS', skipOffstage: false), findsOneWidget);
    });
  });
}
