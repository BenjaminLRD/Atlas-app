import 'package:flutter_test/flutter_test.dart';
import 'package:aizawl_gym/models/progress_summary.dart';
import 'package:aizawl_gym/models/streak_data.dart';
import 'package:aizawl_gym/models/user_progress.dart';
import 'package:aizawl_gym/models/workout_history.dart';
import 'package:aizawl_gym/services/progress_summary_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProgressSummary Model Tests', () {
    test('ProgressSummary.zero initializes correct defaults', () {
      final summary = ProgressSummary.zero();

      expect(summary.totalWorkouts, equals(0));
      expect(summary.totalVolume, equals(0.0));
      expect(summary.currentRank, equals('Iron I'));
      expect(summary.currentStreak, equals(0));
      expect(summary.personalRecords, isEmpty);
      expect(summary.muscleGroupDistribution, isNotEmpty);
    });

    test('ProgressSummary.fromJson and toJson round trip', () {
      final summary = ProgressSummary(
        totalWorkouts: 12,
        totalVolume: 45000.0,
        totalTrainingMinutes: 540,
        currentRank: 'Gold I',
        currentXP: 2400,
        currentStreak: 4,
        longestStreak: 7,
        weeklyVolume: 12000.0,
        monthlyVolume: 35000.0,
        weeklyVolumeChangePercent: 15.0,
        monthlyVolumeChangePercent: 20.0,
        weeklyWorkoutChange: 1,
        strengthGrowthPercent: 25.0,
        consistencyScore: 85.0,
        personalRecords: const [
          PersonalRecord(
            id: 'pr_squat_100',
            exerciseName: 'Barbell Back Squat',
            recordType: 'Heaviest Lift',
            value: 100.0,
            previousValue: 90.0,
            improvementPercentage: 11.1,
          ),
        ],
        topExercises: const [
          TopExercise(
            exerciseName: 'Barbell Back Squat',
            muscleGroup: 'Legs',
            sessionsCompleted: 8,
            maxWeight: 100.0,
            totalVolume: 24000.0,
            percentageImprovement: 25.0,
          ),
        ],
        muscleGroupDistribution: const {'Legs': 40.0, 'Chest': 30.0, 'Back': 30.0},
        lastUpdated: DateTime(2026, 8, 4, 12, 0),
      );

      final jsonMap = summary.toJson();
      final roundTrip = ProgressSummary.fromJson(jsonMap);

      expect(roundTrip.totalWorkouts, equals(12));
      expect(roundTrip.currentRank, equals('Gold I'));
      expect(roundTrip.personalRecords.first.exerciseName, equals('Barbell Back Squat'));
      expect(roundTrip.topExercises.first.maxWeight, equals(100.0));
    });
  });

  group('ProgressSummaryService Tests', () {
    late ProgressSummaryService service;
    final now = DateTime(2026, 8, 5, 12, 0); // Wednesday, Aug 5, 2026

    setUp(() {
      service = ProgressSummaryService.instance;
    });

    final mockHistory = [
      WorkoutHistory(
        workoutName: 'Barbell Back Squats - Leg Day',
        dateCompleted: DateTime(2026, 8, 3, 10, 0),
        durationSeconds: 3600,
        exercisesCompleted: 4,
        completionPercentage: 1.0,
        totalSets: 16,
        totalReps: 160,
        totalVolume: 9600.0,
        caloriesBurned: 390.0,
        personalRecords: ['Barbell Back Squats: 80.0 kg'],
        xpEarned: 400,
      ),
      WorkoutHistory(
        workoutName: 'Chest & Triceps Push',
        dateCompleted: DateTime(2026, 8, 5, 9, 0),
        durationSeconds: 2700,
        exercisesCompleted: 4,
        completionPercentage: 1.0,
        totalSets: 14,
        totalReps: 140,
        totalVolume: 7000.0,
        caloriesBurned: 300.0,
        personalRecords: ['Barbell Bench Press: 85.0 kg'],
        xpEarned: 350,
      ),
    ];

    final mockProgress = UserProgress.initial().copyWith(
      totalXP: 1850,
      currentRank: 'Gold',
      currentDivision: 'II',
      completedWorkouts: 2,
      workoutStreak: 3,
      longestStreak: 5,
      rankedUnlocked: true,
    );

    final mockStreak = StreakData(
      currentStreak: 3,
      longestStreak: 5,
      lastWorkoutDate: DateTime(2026, 8, 5),
    );

    test('generateSummary correctly aggregates all required metrics', () {
      final summary = service.generateSummary(
        history: mockHistory,
        userProgress: mockProgress,
        streakData: mockStreak,
        nowOverride: now,
      );

      // Core
      expect(summary.totalWorkouts, equals(2));
      expect(summary.totalVolume, equals(16600.0));
      expect(summary.totalTrainingMinutes, equals(105)); // (3600 + 2700) / 60
      expect(summary.currentRank, equals('Gold II'));
      expect(summary.currentXP, equals(1850));
      expect(summary.currentStreak, equals(3));
      expect(summary.longestStreak, equals(5));

      // Analytics
      expect(summary.weeklyVolume, equals(16600.0));
      expect(summary.monthlyVolume, equals(16600.0));

      // Comparison
      expect(summary.consistencyScore, greaterThan(0.0));

      // Collections
      expect(summary.personalRecords, isNotEmpty);
      expect(summary.topExercises, isNotEmpty);

      // Distribution
      expect(summary.muscleGroupDistribution, contains('Legs'));
      expect(summary.muscleGroupDistribution, contains('Chest'));

      // Metadata
      expect(summary.lastUpdated, equals(now));
    });
  });
}
