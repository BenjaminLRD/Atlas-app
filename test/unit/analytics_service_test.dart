import 'package:flutter_test/flutter_test.dart';
import 'package:aizawl_gym/models/workout_history.dart';
import 'package:aizawl_gym/services/analytics_service.dart';
import 'package:aizawl_gym/utils/date_range_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DateRangeUtils Tests', () {
    test('startOfWeek returns Monday midnight', () {
      final wednesday = DateTime(2026, 8, 5); // Wednesday
      final monday = DateRangeUtils.startOfWeek(wednesday);

      expect(monday.year, equals(2026));
      expect(monday.month, equals(8));
      expect(monday.day, equals(3)); // August 3 is Monday
      expect(monday.weekday, equals(DateTime.monday));
    });

    test('endOfWeek returns Sunday end of day', () {
      final wednesday = DateTime(2026, 8, 5);
      final sunday = DateRangeUtils.endOfWeek(wednesday);

      expect(sunday.year, equals(2026));
      expect(sunday.month, equals(8));
      expect(sunday.day, equals(9)); // August 9 is Sunday
      expect(sunday.weekday, equals(DateTime.sunday));
    });

    test('isSameWeek returns true for dates in same Monday-Sunday week', () {
      final mon = DateTime(2026, 8, 3);
      final fri = DateTime(2026, 8, 7);
      final nextMon = DateTime(2026, 8, 10);

      expect(DateRangeUtils.isSameWeek(mon, fri), isTrue);
      expect(DateRangeUtils.isSameWeek(mon, nextMon), isFalse);
    });

    test('isSameMonth returns true for dates in same month and year', () {
      final d1 = DateTime(2026, 8, 1);
      final d2 = DateTime(2026, 8, 31);
      final d3 = DateTime(2026, 9, 1);

      expect(DateRangeUtils.isSameMonth(d1, d2), isTrue);
      expect(DateRangeUtils.isSameMonth(d1, d3), isFalse);
    });

    test('countActiveWeeks counts unique calendar weeks with workouts', () {
      final dates = [
        DateTime(2026, 8, 3), // Week 1 (Aug 3)
        DateTime(2026, 8, 5), // Week 1 (Aug 5)
        DateTime(2026, 8, 10), // Week 2 (Aug 10)
        DateTime(2026, 8, 24), // Week 4 (Aug 24)
      ];

      final count = DateRangeUtils.countActiveWeeks(dates);
      expect(count, equals(3));
    });
  });

  group('AnalyticsService Tests', () {
    late AnalyticsService analyticsService;
    final referenceNow = DateTime(2026, 8, 5, 12, 0); // Wednesday, Aug 5, 2026

    setUp(() {
      analyticsService = AnalyticsService.instance;
    });

    final sampleHistory = [
      WorkoutHistory(
        workoutName: 'Barbell Back Squats - Leg Day',
        dateCompleted: DateTime(2026, 8, 3, 10, 0), // Same week & month
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
        dateCompleted: DateTime(2026, 8, 5, 9, 0), // Same week & month
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
      WorkoutHistory(
        workoutName: 'Back & Biceps Pull',
        dateCompleted: DateTime(2026, 7, 20, 10, 0), // Previous month (July)
        durationSeconds: 3000,
        exercisesCompleted: 5,
        completionPercentage: 1.0,
        totalSets: 20,
        totalReps: 180,
        totalVolume: 8400.0,
        caloriesBurned: 340.0,
        personalRecords: ['Barbell Back Squats: 60.0 kg'],
        xpEarned: 380,
      ),
    ];

    test('calculateVolume computes lifetime, weekly, and monthly training volume', () {
      final volume = analyticsService.calculateVolume(sampleHistory, referenceNow);

      expect(volume.totalLifetimeVolume, equals(25000.0)); // 9600 + 7000 + 8400
      expect(volume.weeklyVolume, equals(16600.0)); // 9600 + 7000
      expect(volume.monthlyVolume, equals(16600.0)); // 9600 + 7000 (August only)
    });

    test('calculateConsistency computes workouts per active week and current streak', () {
      final consistency = analyticsService.calculateConsistency(sampleHistory, 5, referenceNow);

      expect(consistency.workoutsThisWeek, equals(2));
      expect(consistency.workoutsThisMonth, equals(2));
      expect(consistency.averageWorkoutsPerWeek, equals(1.5)); // 3 workouts / 2 active weeks = 1.5
      expect(consistency.currentStreak, equals(5));
    });

    test('calculateStrengthProgression compares earliest vs latest performance per exercise', () {
      final progressions = analyticsService.calculateStrengthProgression(sampleHistory);

      final squatProg = progressions.firstWhere((p) => p.exerciseName.contains('Squat'));
      expect(squatProg.earliestWeight, equals(60.0));
      expect(squatProg.latestWeight, equals(80.0));
      expect(squatProg.weightIncrease, equals(20.0));
      expect(squatProg.percentageImprovement, equals(33.3));
    });

    test('calculateMuscleGroupDistribution calculates balance using total sets per muscle group', () {
      final distribution = analyticsService.calculateMuscleGroupDistribution(sampleHistory);

      expect(distribution, contains('Legs'));
      expect(distribution, contains('Chest'));
      expect(distribution['Legs'], greaterThan(0.0));
      expect(distribution['Chest'], greaterThan(0.0));
    });

    test('calculatePersonalRecords detects highest weight, session volume, and max reps', () {
      final records = analyticsService.calculatePersonalRecords(sampleHistory);

      expect(records.maxWeightLifted, equals(85.0));
      expect(records.maxSingleSessionVolume, equals(9600.0));
      expect(records.maxRepsInSet, equals(180));
      expect(records.achievedRecords.length, equals(3));
    });
  });
}
