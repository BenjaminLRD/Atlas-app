import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/models/health_metrics.dart';
import 'package:aizawl_gym/models/training_state.dart';
import 'package:aizawl_gym/models/workout_history.dart';
import 'package:aizawl_gym/services/training_intelligence_service.dart';
import 'package:aizawl_gym/services/supabase/supabase_client.dart';
import 'package:aizawl_gym/providers/fitness_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SupabaseClientManager.resetInstance();
    TrainingIntelligenceService.resetInstance();
    FitnessProvider.resetInstance();
  });

  group('TrainingState Model Unit Tests', () {
    test('TrainingState serialization, copyWith, and equality', () {
      final now = DateTime.now();
      final state = TrainingState(
        id: 'ts_1',
        fatigueScore: 40,
        readinessScore: 75,
        trainingLoad: 140.0,
        weeklyVolume: 18000.0,
        recommendedIntensity: 'moderate_training',
        recommendation: 'Good readiness',
        lastUpdated: now,
      );

      final json = state.toJson();
      expect(json['id'], equals('ts_1'));
      expect(json['fatigue_score'], equals(40));
      expect(json['readiness_score'], equals(75));

      final parsed = TrainingState.fromJson(json);
      expect(parsed.id, equals('ts_1'));
      expect(parsed.recommendedIntensity, equals('moderate_training'));

      final updated = state.copyWith(readinessScore: 85);
      expect(updated.readinessScore, equals(85));
    });
  });

  group('TrainingIntelligenceService Unit Tests', () {
    test('analyzeTrainingState calculates high readiness for well-rested state', () {
      final service = TrainingIntelligenceService.instance;
      final workouts = <WorkoutHistory>[];
      final health = HealthMetrics(
        id: 'h_1',
        date: DateTime.now(),
        steps: 8000,
        sleepHours: 8.0,
        heartRateAverage: 62.0,
      );

      final state = service.analyzeTrainingState(
        workouts: workouts,
        healthMetrics: health,
        recoveryScore: 90,
      );

      expect(state.readinessScore, greaterThanOrEqualTo(80));
      expect(state.recommendedIntensity, equals('heavy_training'));
    });

    test('analyzeTrainingState calculates higher fatigue when workout volume is high', () {
      final service = TrainingIntelligenceService.instance;
      final now = DateTime.now();

      final workouts = List.generate(
        6,
        (i) => WorkoutHistory(
          workoutName: 'Volume Session $i',
          dateCompleted: now.subtract(Duration(days: i)),
          durationSeconds: 3600,
          exercisesCompleted: 8,
          completionPercentage: 1.0,
          totalVolume: 6000.0,
        ),
      );

      final state = service.analyzeTrainingState(
        workouts: workouts,
        recoveryScore: 50,
      );

      expect(state.fatigueScore, greaterThan(30));
    });
  });

  group('FitnessProvider Training Intelligence Integration Tests', () {
    test('refreshTrainingIntelligence updates provider trainingState', () async {
      final provider = FitnessProvider.instance;
      await provider.refreshTrainingIntelligence();

      expect(provider.trainingState, isNotNull);
      expect(provider.trainingState!.readinessScore, greaterThanOrEqualTo(0));
    });

    test('saveWorkoutCompletion triggers training intelligence refresh', () async {
      final provider = FitnessProvider.instance;
      await provider.refreshTrainingIntelligence();

      final workout = WorkoutHistory(
        workoutName: 'Intense Leg Press',
        dateCompleted: DateTime.now(),
        durationSeconds: 3600,
        exercisesCompleted: 6,
        completionPercentage: 1.0,
        totalVolume: 7500.0,
        caloriesBurned: 450.0,
        xpEarned: 200,
      );

      await provider.saveWorkoutCompletion(workout);

      expect(provider.trainingState, isNotNull);
    });
  });
}
