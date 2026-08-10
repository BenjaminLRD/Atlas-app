import 'package:flutter_test/flutter_test.dart';
import 'package:aizawl_gym/models/streak_data.dart';
import 'package:aizawl_gym/models/weekly_challenge.dart';
import 'package:aizawl_gym/models/workout_history.dart';
import 'package:aizawl_gym/services/challenge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StreakData Tests', () {
    test('initial StreakData is zeroed', () {
      final streak = StreakData.initial();
      expect(streak.currentStreak, equals(0));
      expect(streak.longestStreak, equals(0));
      expect(streak.lastWorkoutDate, isNull);
    });

    test('first workout initializes streak to 1', () {
      final streak = StreakData.initial();
      final workoutDate = DateTime(2026, 8, 1, 10, 0);

      final updated = streak.updateWithWorkout(workoutDate);

      expect(updated.currentStreak, equals(1));
      expect(updated.longestStreak, equals(1));
      expect(updated.lastWorkoutDate, equals(workoutDate));
    });

    test('same day workout does not increase streak count', () {
      final date1 = DateTime(2026, 8, 1, 10, 0);
      final date2 = DateTime(2026, 8, 1, 18, 0);

      final streak1 = StreakData.initial().updateWithWorkout(date1);
      expect(streak1.currentStreak, equals(1));

      final streak2 = streak1.updateWithWorkout(date2);
      expect(streak2.currentStreak, equals(1));
      expect(streak2.longestStreak, equals(1));
      expect(streak2.lastWorkoutDate, equals(date2));
    });

    test('consecutive day workout increments streak count', () {
      final day1 = DateTime(2026, 8, 1, 10, 0);
      final day2 = DateTime(2026, 8, 2, 11, 0);

      final streak1 = StreakData.initial().updateWithWorkout(day1);
      final streak2 = streak1.updateWithWorkout(day2);

      expect(streak2.currentStreak, equals(2));
      expect(streak2.longestStreak, equals(2));
    });

    test('gap of more than 1 day resets current streak to 1 while preserving longest streak', () {
      final day1 = DateTime(2026, 8, 1, 10, 0);
      final day2 = DateTime(2026, 8, 2, 10, 0);
      final day3 = DateTime(2026, 8, 3, 10, 0);
      // Miss August 4, workout on August 5 (2 day gap)
      final day5 = DateTime(2026, 8, 5, 10, 0);

      var streak = StreakData.initial().updateWithWorkout(day1);
      streak = streak.updateWithWorkout(day2);
      streak = streak.updateWithWorkout(day3);

      expect(streak.currentStreak, equals(3));
      expect(streak.longestStreak, equals(3));

      // After gap
      final resetStreak = streak.updateWithWorkout(day5);

      expect(resetStreak.currentStreak, equals(1));
      expect(resetStreak.longestStreak, equals(3));
    });
  });

  group('WeeklyChallenge Model Tests', () {
    test('calculates progress percentage and formatted progress string correctly', () {
      const challenge = WeeklyChallenge(
        id: 'c1',
        title: 'Consistency Champion',
        description: 'Complete 5 workouts',
        category: 'Workouts',
        targetValue: 5.0,
        currentProgress: 3.0,
        xpReward: 500,
      );

      expect(challenge.progressPercentage, equals(0.6));
      expect(challenge.formattedProgress, equals('3 / 5'));
      expect(challenge.completed, isFalse);
    });

    test('formats volume challenge progress string with units', () {
      const challenge = WeeklyChallenge(
        id: 'c2',
        title: 'Volume Builder',
        description: 'Lift 10,000kg',
        category: 'Volume',
        targetValue: 10000.0,
        currentProgress: 6500.0,
        xpReward: 300,
      );

      expect(challenge.progressPercentage, equals(0.65));
      expect(challenge.formattedProgress, equals('6500 / 10000 kg'));
    });

    test('copyWith updates specified fields correctly', () {
      const challenge = WeeklyChallenge(
        id: 'c1',
        title: 'Title',
        description: 'Desc',
        category: 'Workouts',
        targetValue: 5.0,
        xpReward: 500,
      );

      final updated = challenge.copyWith(currentProgress: 5.0, completed: true);

      expect(updated.currentProgress, equals(5.0));
      expect(updated.completed, isTrue);
      expect(updated.title, equals('Title'));
    });
  });

  group('ChallengeService Tests', () {
    late ChallengeService challengeService;

    setUp(() {
      ChallengeService.resetInstance();
      challengeService = ChallengeService.instance;
    });

    test('initializes default placeholder weekly challenges', () {
      final challenges = challengeService.getChallenges();

      expect(challenges.length, equals(3));
      expect(challenges[0].title, equals('Consistency Champion'));
      expect(challenges[1].title, equals('Volume Builder'));
      expect(challenges[2].title, equals('Early Bird'));
    });

    test('updates challenge progress on workout completion', () async {
      final workout = WorkoutHistory(
        workoutName: 'Morning Leg Session',
        dateCompleted: DateTime(2026, 8, 4, 7, 30), // 7:30 AM (before 9 AM)
        durationSeconds: 3600,
        exercisesCompleted: 6, // 6 * 500 = 3000 volume
        completionPercentage: 1.0,
      );

      final completed = await challengeService.updateProgressOnWorkout(workout);
      final updatedChallenges = challengeService.getChallenges();

      final consistency = updatedChallenges.firstWhere((c) => c.id == 'weekly_consistency_5');
      final volume = updatedChallenges.firstWhere((c) => c.id == 'weekly_volume_10000');
      final earlyBird = updatedChallenges.firstWhere((c) => c.id == 'weekly_early_bird_3');

      expect(consistency.currentProgress, equals(1.0));
      expect(volume.currentProgress, equals(3000.0));
      expect(earlyBird.currentProgress, equals(1.0));
      expect(completed, isEmpty); // None reached target yet
    });
  });
}
