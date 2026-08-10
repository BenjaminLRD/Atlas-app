import 'package:flutter_test/flutter_test.dart';
import 'package:aizawl_gym/models/fitness_insight.dart';
import 'package:aizawl_gym/models/progress_summary.dart';
import 'package:aizawl_gym/services/insight_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FitnessInsight Model Tests', () {
    test('FitnessInsight.fromJson and toJson round trip', () {
      final insight = FitnessInsight(
        id: 'insight_1',
        title: 'Volume Growth',
        description: 'Your weekly training volume increased 18%.',
        category: 'performance',
        priority: 'high',
        icon: 'trending_up',
        createdAt: DateTime(2026, 8, 5, 12, 0),
        suggestedAction: 'Keep up the progressive overload.',
        metricSummary: '18,500 kg volume',
        actionType: 'view_analytics',
      );

      final jsonMap = insight.toJson();
      final roundTrip = FitnessInsight.fromJson(jsonMap);

      expect(roundTrip.id, equals('insight_1'));
      expect(roundTrip.title, equals('Volume Growth'));
      expect(roundTrip.category, equals('performance'));
      expect(roundTrip.priority, equals('high'));
    });

    test('FitnessInsight.copyWith updates specified fields', () {
      final insight = FitnessInsight(
        id: 'insight_1',
        title: 'Original Title',
        description: 'Original Description',
        category: 'consistency',
        createdAt: DateTime(2026, 8, 5),
      );

      final updated = insight.copyWith(
        title: 'Updated Title',
        priority: 'high',
      );

      expect(updated.title, equals('Updated Title'));
      expect(updated.category, equals('consistency'));
      expect(updated.priority, equals('high'));
    });
  });

  group('InsightService Engine Tests', () {
    late InsightService service;

    setUp(() {
      service = InsightService.instance;
    });

    test('generateInsights produces rule-based insights from ProgressSummary', () {
      final summary = ProgressSummary(
        totalWorkouts: 10,
        totalVolume: 50000.0,
        totalTrainingMinutes: 450,
        currentRank: 'Gold I',
        currentXP: 2500,
        currentStreak: 5,
        longestStreak: 8,
        weeklyVolume: 15000.0,
        monthlyVolume: 40000.0,
        weeklyVolumeChangePercent: 18.0,
        monthlyVolumeChangePercent: 22.0,
        weeklyWorkoutChange: 2,
        strengthGrowthPercent: 25.0,
        consistencyScore: 85.0,
        personalRecords: const [],
        topExercises: const [
          TopExercise(
            exerciseName: 'Barbell Bench Press',
            muscleGroup: 'Chest',
            sessionsCompleted: 6,
            maxWeight: 85.0,
            totalVolume: 12000.0,
            percentageImprovement: 25.0,
          ),
        ],
        muscleGroupDistribution: const {
          'Legs': 15.0,
          'Chest': 35.0,
          'Back': 30.0,
          'Arms': 20.0,
        },
        lastUpdated: DateTime(2026, 8, 5),
      );

      final insights = service.generateInsights(
        summary,
        neededXP: 340,
        nextRankTitle: 'Gold II',
        nowOverride: DateTime(2026, 8, 5),
      );

      expect(insights, isNotEmpty);

      final hasVolumeInsight = insights.any((i) => i.category == 'performance' && i.title.contains('Volume'));
      final hasStreakInsight = insights.any((i) => i.category == 'consistency' && i.description.contains('5 day streak'));
      final hasBalanceInsight = insights.any((i) => i.category == 'balance');
      final hasRankInsight = insights.any((i) => i.category == 'motivation' && i.description.contains('340 XP'));
      final hasStrengthInsight = insights.any((i) => i.category == 'strength' && i.description.contains('Bench Press'));

      expect(hasVolumeInsight, isTrue);
      expect(hasStreakInsight, isTrue);
      expect(hasBalanceInsight, isTrue);
      expect(hasRankInsight, isTrue);
      expect(hasStrengthInsight, isTrue);
    });
  });
}
