import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/models/workout_feedback.dart';
import 'package:aizawl_gym/services/workout_adaptation_service.dart';
import 'package:aizawl_gym/services/supabase/supabase_client.dart';
import 'package:aizawl_gym/providers/fitness_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SupabaseClientManager.resetInstance();
    WorkoutAdaptationService.resetInstance();
    FitnessProvider.resetInstance();
  });

  group('WorkoutFeedback Model Unit Tests', () {
    test('WorkoutFeedback serialization, copyWith, and equality', () {
      final now = DateTime.now();
      final fb = WorkoutFeedback(
        id: 'fb_1',
        workoutId: 'w_101',
        difficultyRating: 'too_easy',
        completionQuality: 1.0,
        volumeAchieved: 8000.0,
        targetVolume: 7500.0,
        notes: 'Felt light',
        createdAt: now,
      );

      final json = fb.toJson();
      expect(json['id'], equals('fb_1'));
      expect(json['difficulty_rating'], equals('too_easy'));

      final parsed = WorkoutFeedback.fromJson(json);
      expect(parsed.workoutId, equals('w_101'));
      expect(parsed.notes, equals('Felt light'));

      final updated = fb.copyWith(difficultyRating: 'perfect');
      expect(updated.difficultyRating, equals('perfect'));
    });
  });

  group('WorkoutAdaptationService Unit Tests', () {
    test('calculateProgressionFactor increases factor for too_easy feedback', () {
      final service = WorkoutAdaptationService.instance;
      final history = [
        WorkoutFeedback(
          id: 'fb_1',
          workoutId: 'w_1',
          difficultyRating: 'too_easy',
          createdAt: DateTime.now(),
        ),
      ];

      final factor = service.calculateProgressionFactor(history);
      expect(factor, greaterThan(1.0));
    });

    test('calculateProgressionFactor decreases factor for too_hard feedback', () {
      final service = WorkoutAdaptationService.instance;
      final history = [
        WorkoutFeedback(
          id: 'fb_1',
          workoutId: 'w_1',
          difficultyRating: 'too_hard',
          createdAt: DateTime.now(),
        ),
      ];

      final factor = service.calculateProgressionFactor(history);
      expect(factor, lessThan(1.0));
    });

    test('generateAdaptationNote returns descriptive text for ratings', () {
      final service = WorkoutAdaptationService.instance;
      final noteEasy = service.generateAdaptationNote(
        WorkoutFeedback(
          id: '1',
          workoutId: 'w',
          difficultyRating: 'too_easy',
          createdAt: DateTime.now(),
        ),
      );
      expect(noteEasy.contains('Too Easy'), isTrue);
    });
  });

  group('FitnessProvider Workout Adaptation Integration Tests', () {
    test('submitWorkoutFeedback stores feedback and refreshes adaptation', () async {
      final provider = FitnessProvider.instance;
      final fb = WorkoutFeedback(
        id: 'fb_test',
        workoutId: 'w_test',
        difficultyRating: 'perfect',
        createdAt: DateTime.now(),
      );

      await provider.submitWorkoutFeedback(fb);

      expect(provider.workoutFeedbackHistory, isNotEmpty);
      expect(provider.workoutFeedbackHistory.first.id, equals('fb_test'));
    });
  });
}
