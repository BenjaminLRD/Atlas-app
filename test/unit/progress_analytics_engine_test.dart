import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/models/progress_analytics.dart';
import 'package:atlas/models/user_progress.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/models/workout_session.dart';
import 'package:atlas/services/achievement_service.dart';
import 'package:atlas/services/progress_analytics_engine.dart';

void main() {
  group('ProgressAnalyticsEngine - Zero State & Empty Handling', () {
    test(
      'generateAthleteReport returns clean empty report when history and sessions are empty',
      () {
        final report = ProgressAnalyticsEngine.instance.generateAthleteReport(
          sessions: const [],
          history: const [],
        );

        expect(report.currentSnapshot.totalVolume, equals(0.0));
        expect(report.currentSnapshot.completedWorkouts, equals(0));
        expect(report.currentSnapshot.totalSets, equals(0));
        expect(report.currentSnapshot.totalReps, equals(0));
        expect(report.currentSnapshot.muscleDistribution, isEmpty);
        expect(report.strengthProgressions, isEmpty);
        expect(report.volumeTrends, isEmpty);
        expect(report.muscleGrowthMetrics, isEmpty);
        expect(report.plateauInsights, isEmpty);
        expect(report.consistencyPercentage, equals(0.0));
        expect(report.recommendations, isNotEmpty);
        expect(
          report.recommendations.first,
          contains('Complete your first training session'),
        );
      },
    );

    test(
      'buildAICoachPromptContext generates clean zero-state prompt without fake baselines',
      () {
        final report = AthleteAnalyticsReport.empty();
        final promptContext = ProgressAnalyticsEngine.instance
            .buildAICoachPromptContext(report);

        expect(promptContext, contains('[ATHLETE PROGRESS CONTEXT]'));
        expect(
          promptContext,
          contains('Insufficient workout history recorded'),
        );
        expect(promptContext, isNot(contains('Squat: +15kg')));
      },
    );
  });

  group('ProgressAnalyticsEngine - Strength Progression & 1RM', () {
    test(
      'accurately calculates strength gains and Epley 1RM across sessions',
      () {
        final now = DateTime.now();

        final session1 = WorkoutSession(
          id: 'sess_1',
          workoutId: 'w_1',
          workoutName: 'Upper Body A',
          startTime: now.subtract(const Duration(days: 14)),
          endTime: now.subtract(const Duration(days: 14, hours: -1)),
          completedExercises: 1,
          totalVolume: 1280.0,
          caloriesBurned: 150.0,
          duration: const Duration(hours: 1),
          exercises: [
            WorkoutSessionExercise(
              id: 'ex_1',
              name: 'Barbell Bench Press',
              muscleGroup: 'Chest',
              sets: [
                WorkoutSessionSet(
                  setNumber: 1,
                  weight: 80.0,
                  reps: 8,
                  completed: true,
                ),
                WorkoutSessionSet(
                  setNumber: 2,
                  weight: 80.0,
                  reps: 8,
                  completed: true,
                ),
              ],
            ),
          ],
        );

        final session2 = WorkoutSession(
          id: 'sess_2',
          workoutId: 'w_1',
          workoutName: 'Upper Body B',
          startTime: now.subtract(const Duration(days: 7)),
          endTime: now.subtract(const Duration(days: 7, hours: -1)),
          completedExercises: 1,
          totalVolume: 540.0,
          caloriesBurned: 120.0,
          duration: const Duration(hours: 1),
          exercises: [
            WorkoutSessionExercise(
              id: 'ex_1',
              name: 'Barbell Bench Press',
              muscleGroup: 'Chest',
              sets: [
                WorkoutSessionSet(
                  setNumber: 1,
                  weight: 90.0,
                  reps: 6,
                  completed: true,
                ),
              ],
            ),
          ],
        );

        final session3 = WorkoutSession(
          id: 'sess_3',
          workoutId: 'w_1',
          workoutName: 'Upper Body C',
          startTime: now,
          endTime: now.add(const Duration(hours: 1)),
          completedExercises: 1,
          totalVolume: 500.0,
          caloriesBurned: 120.0,
          duration: const Duration(hours: 1),
          exercises: [
            WorkoutSessionExercise(
              id: 'ex_1',
              name: 'Barbell Bench Press',
              muscleGroup: 'Chest',
              sets: [
                WorkoutSessionSet(
                  setNumber: 1,
                  weight: 100.0,
                  reps: 5,
                  completed: true,
                ),
              ],
            ),
          ],
        );

        final report = ProgressAnalyticsEngine.instance.generateAthleteReport(
          sessions: [session1, session2, session3],
          history: const [],
        );

        expect(report.strengthProgressions, isNotEmpty);
        final bench = report.strengthProgressions.firstWhere(
          (s) => s.exerciseName == 'Barbell Bench Press',
        );

        expect(bench.startingWeight, equals(80.0));
        expect(bench.currentWeight, equals(100.0));
        expect(bench.improvement, equals(20.0));
        expect(bench.percentageImprovement, equals(25.0));
        // Epley 1RM for 100kg x 5 reps = 100 * (1 + 5/30) = 116.67kg
        expect(bench.estimatedOneRepMax, closeTo(116.67, 0.5));
      },
    );
  });

  group('ProgressAnalyticsEngine - Volume Trends & Muscle Growth', () {
    test(
      'calculates 4-week volume trends and week-over-week change percentage',
      () {
        final now = DateTime.now();

        final week1Workout = WorkoutHistory(
          workoutName: 'Pull Day',
          dateCompleted: now.subtract(const Duration(days: 21)),
          durationSeconds: 3600,
          exercisesCompleted: 5,
          completionPercentage: 100.0,
          totalVolume: 10000.0,
          totalSets: 20,
          totalReps: 160,
        );

        final week2Workout = WorkoutHistory(
          workoutName: 'Push Day',
          dateCompleted: now.subtract(const Duration(days: 14)),
          durationSeconds: 3600,
          exercisesCompleted: 5,
          completionPercentage: 100.0,
          totalVolume: 12000.0,
          totalSets: 20,
          totalReps: 160,
        );

        final week3Workout = WorkoutHistory(
          workoutName: 'Leg Day',
          dateCompleted: now.subtract(const Duration(days: 7)),
          durationSeconds: 3600,
          exercisesCompleted: 5,
          completionPercentage: 100.0,
          totalVolume: 15000.0,
          totalSets: 20,
          totalReps: 160,
        );

        final week4Workout = WorkoutHistory(
          workoutName: 'Full Body',
          dateCompleted: now,
          durationSeconds: 3600,
          exercisesCompleted: 5,
          completionPercentage: 100.0,
          totalVolume: 18000.0,
          totalSets: 20,
          totalReps: 160,
        );

        final report = ProgressAnalyticsEngine.instance.generateAthleteReport(
          sessions: const [],
          history: [week4Workout, week3Workout, week2Workout, week1Workout],
        );

        expect(report.volumeTrends, isNotEmpty);
        expect(report.volumeTrends.length, equals(4));

        // Latest week (Week 4) vs Week 3: (18000 - 15000) / 15000 * 100 = +20%
        final currentWeekPoint = report.volumeTrends.last;
        expect(currentWeekPoint.totalVolume, equals(18000.0));
        expect(currentWeekPoint.changePercentage, closeTo(20.0, 0.1));
      },
    );
  });

  group('ProgressAnalyticsEngine - Plateau Detection', () {
    test(
      'flags plateau when exercise load remains stalled for 3+ consecutive weeks',
      () {
        final now = DateTime.now();

        final sessionW1 = WorkoutSession(
          id: 's_p1',
          workoutId: 'w_ohp',
          workoutName: 'Overhead Press Day 1',
          startTime: now.subtract(const Duration(days: 22)),
          endTime: now.subtract(const Duration(days: 22, hours: -1)),
          completedExercises: 1,
          totalVolume: 300.0,
          caloriesBurned: 80.0,
          duration: const Duration(minutes: 45),
          exercises: [
            WorkoutSessionExercise(
              id: 'p_ex_1',
              name: 'Overhead Press',
              muscleGroup: 'Shoulders',
              sets: [
                WorkoutSessionSet(
                  setNumber: 1,
                  weight: 60.0,
                  reps: 5,
                  completed: true,
                ),
              ],
            ),
          ],
        );

        final sessionW2 = WorkoutSession(
          id: 's_p2',
          workoutId: 'w_ohp',
          workoutName: 'Overhead Press Day 2',
          startTime: now.subtract(const Duration(days: 15)),
          endTime: now.subtract(const Duration(days: 15, hours: -1)),
          completedExercises: 1,
          totalVolume: 300.0,
          caloriesBurned: 80.0,
          duration: const Duration(minutes: 45),
          exercises: [
            WorkoutSessionExercise(
              id: 'p_ex_1',
              name: 'Overhead Press',
              muscleGroup: 'Shoulders',
              sets: [
                WorkoutSessionSet(
                  setNumber: 1,
                  weight: 60.0,
                  reps: 5,
                  completed: true,
                ),
              ],
            ),
          ],
        );

        final sessionW3 = WorkoutSession(
          id: 's_p3',
          workoutId: 'w_ohp',
          workoutName: 'Overhead Press Day 3',
          startTime: now.subtract(const Duration(days: 8)),
          endTime: now.subtract(const Duration(days: 8, hours: -1)),
          completedExercises: 1,
          totalVolume: 300.0,
          caloriesBurned: 80.0,
          duration: const Duration(minutes: 45),
          exercises: [
            WorkoutSessionExercise(
              id: 'p_ex_1',
              name: 'Overhead Press',
              muscleGroup: 'Shoulders',
              sets: [
                WorkoutSessionSet(
                  setNumber: 1,
                  weight: 60.0,
                  reps: 5,
                  completed: true,
                ),
              ],
            ),
          ],
        );

        final sessionW4 = WorkoutSession(
          id: 's_p4',
          workoutId: 'w_ohp',
          workoutName: 'Overhead Press Day 4',
          startTime: now,
          endTime: now.add(const Duration(hours: 1)),
          completedExercises: 1,
          totalVolume: 300.0,
          caloriesBurned: 80.0,
          duration: const Duration(minutes: 45),
          exercises: [
            WorkoutSessionExercise(
              id: 'p_ex_1',
              name: 'Overhead Press',
              muscleGroup: 'Shoulders',
              sets: [
                WorkoutSessionSet(
                  setNumber: 1,
                  weight: 60.0,
                  reps: 5,
                  completed: true,
                ),
              ],
            ),
          ],
        );

        final report = ProgressAnalyticsEngine.instance.generateAthleteReport(
          sessions: [sessionW1, sessionW2, sessionW3, sessionW4],
          history: const [],
        );

        expect(report.plateauInsights, isNotEmpty);
        final ohpPlateau = report.plateauInsights.firstWhere(
          (p) => p.exerciseName == 'Overhead Press',
        );

        expect(ohpPlateau.stalledWeight, equals(60.0));
        expect(ohpPlateau.weeksStalled, greaterThanOrEqualTo(3));
        expect(ohpPlateau.recommendation, contains('Deload load by 10-15%'));
      },
    );
  });

  group('AchievementService - Real Analytics Integration', () {
    test(
      'unlocks 100kg Bench, 100k Volume, and +20kg strength increase badges from real report',
      () {
        final now = DateTime.now();

        final report = AthleteAnalyticsReport(
          currentSnapshot: ProgressSnapshot(
            date: now,
            bodyWeight: 75.0,
            totalVolume: 125000.0,
            workoutsCompleted: 15,
            averageIntensity: 8.0,
            muscleVolume: {'Chest': 60000.0, 'Back': 65000.0},
            prs: const [],
          ),
          strengthProgressions: [
            StrengthProgress(
              exerciseName: 'Barbell Bench Press',
              muscleGroup: 'Chest',
              previousWeight: 80.0,
              currentWeight: 105.0,
              improvement: 25.0,
              percentageIncrease: 31.25,
              estimatedOneRepMax: 120.0,
              lastLoggedDate: now,
              weightHistory: const [80.0, 90.0, 100.0, 105.0],
            ),
          ],
          muscleMetrics: const [],
          volumeTrends: const [],
          plateauInsights: const [],
          consistencyPercentage: 92.5,
          currentStreak: 10,
          longestStreak: 10,
          weeklyVolumeDeltaPercent: 15.0,
          aiCoachSummary: 'Keep progressing',
          generatedAt: now,
        );

        final initialProgress = UserProgress.initial().copyWith(
          completedWorkouts: 15,
          workoutStreak: 10,
        );

        final evalResult = AchievementService.evaluateAchievements(
          initialProgress,
          athleteAnalytics: report,
          hasNewPersonalRecord: true,
        );

        final unlockedIds = evalResult.newlyUnlockedBadges
            .map((b) => b.id)
            .toList();

        expect(unlockedIds, contains('first_workout'));
        expect(unlockedIds, contains('workouts_10'));
        expect(unlockedIds, contains('streak_7'));
        expect(unlockedIds, contains('streak_10'));
        expect(unlockedIds, contains('bench_100kg'));
        expect(unlockedIds, contains('volume_100k'));
        expect(unlockedIds, contains('strength_increase_20kg'));
        expect(unlockedIds, contains('consistency_90'));
        expect(unlockedIds, contains('personal_record'));
        expect(unlockedIds, isNot(contains('volume_500k')));
      },
    );
  });
}
