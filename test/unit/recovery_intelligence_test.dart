import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/models/health_metrics.dart';
import 'package:aizawl_gym/models/recovery_state.dart';
import 'package:aizawl_gym/models/training_state.dart';
import 'package:aizawl_gym/models/workout_feedback.dart';
import 'package:aizawl_gym/services/recovery_intelligence_service.dart';
import 'package:aizawl_gym/services/supabase/supabase_client.dart';
import 'package:aizawl_gym/providers/fitness_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SupabaseClientManager.resetInstance();
    RecoveryIntelligenceService.resetInstance();
    FitnessProvider.resetInstance();
  });

  group('RecoveryState Model Unit Tests', () {
    test('RecoveryState serialization, copyWith, and equality', () {
      final now = DateTime.now();
      final state = RecoveryState(
        id: 'rec_1',
        recoveryScore: 85,
        fatigueLevel: FatigueLevel.low,
        trainingStress: 25.0,
        sleepQuality: 0.9,
        recoveryTrend: 'improving',
        recommendation: RecoveryRecommendation.trainNormal,
        isDeloadRecommended: false,
        lastUpdated: now,
      );

      final json = state.toJson();
      expect(json['id'], equals('rec_1'));
      expect(json['recovery_score'], equals(85));
      expect(json['fatigue_level'], equals('low'));

      final parsed = RecoveryState.fromJson(json);
      expect(parsed.recoveryScore, equals(85));
      expect(parsed.fatigueLevel, equals(FatigueLevel.low));

      final updated = state.copyWith(recoveryScore: 90);
      expect(updated.recoveryScore, equals(90));
    });
  });

  group('RecoveryIntelligenceService Unit Tests', () {
    test('High sleep + low fatigue produces high recovery score', () {
      final service = RecoveryIntelligenceService.instance;
      final health = HealthMetrics(
        id: 'h_1',
        date: DateTime.now(),
        steps: 8000,
        sleepHours: 8.5,
        heartRateAverage: 60.0,
      );

      final state = service.analyzeRecoveryState(
        healthMetrics: health,
        customRecoveryScore: 85,
      );

      expect(state.recoveryScore, greaterThanOrEqualTo(85));
      expect(state.fatigueLevel, equals(FatigueLevel.low));
    });

    test('Low sleep + hard feedback increases fatigue level', () {
      final service = RecoveryIntelligenceService.instance;
      final health = HealthMetrics(
        id: 'h_bad_sleep',
        date: DateTime.now(),
        steps: 12000,
        sleepHours: 5.0,
        heartRateAverage: 78.0,
      );

      final feedback = List.generate(
        3,
        (i) => WorkoutFeedback(
          id: 'fb_$i',
          workoutId: 'w_$i',
          difficultyRating: 'too_hard',
          createdAt: DateTime.now(),
        ),
      );

      final state = service.analyzeRecoveryState(
        healthMetrics: health,
        feedbackHistory: feedback,
        customRecoveryScore: 50,
      );

      expect(state.fatigueLevel == FatigueLevel.high || state.fatigueLevel == FatigueLevel.critical, isTrue);
    });

    test('Fatigue > 75 & readiness < 45 triggers deload recommendation', () {
      final service = RecoveryIntelligenceService.instance;
      final trainingState = TrainingState(
        id: 'ts_exhausted',
        fatigueScore: 80,
        readinessScore: 40,
        recommendation: 'Rest recommended',
        lastUpdated: DateTime.now(),
      );

      final state = service.analyzeRecoveryState(
        trainingState: trainingState,
      );

      expect(state.isDeloadRecommended, isTrue);
      expect(state.recommendation, equals(RecoveryRecommendation.deloadWeek));
    });
  });

  group('FitnessProvider Recovery Intelligence Integration Tests', () {
    test('refreshRecoveryIntelligence updates recoveryState and buildFitnessContext contains recovery data', () async {
      final provider = FitnessProvider.instance;
      await provider.refreshRecoveryIntelligence();

      expect(provider.recoveryState, isNotNull);
      expect(provider.recoveryState!.recoveryScore, greaterThan(0));

      final ctx = provider.buildFitnessContext();
      expect(ctx.recoveryState, isNotNull);
      expect(ctx.recoveryState!.recoveryScore, equals(provider.recoveryState!.recoveryScore));
    });
  });
}
