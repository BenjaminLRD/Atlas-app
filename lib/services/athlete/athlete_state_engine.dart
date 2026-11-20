import '../../models/digital_athlete.dart';
import '../../models/exercise_form_report.dart';

/// Central state coordinator continuously synchronizing the [DigitalAthlete] twin
/// across workout, nutrition, recovery, form analysis, and conversational telemetry.
class AthleteStateEngine {
  static AthleteStateEngine? _instance;
  static AthleteStateEngine get instance => _instance ??= AthleteStateEngine();

  final Map<String, DigitalAthlete> _athleteCache = {};

  /// Retrieves or initializes a DigitalAthlete profile for a given user
  DigitalAthlete getAthlete(String userId) {
    return _athleteCache.putIfAbsent(
      userId,
      () => DigitalAthlete.initial(userId),
    );
  }

  /// Sets or replaces athlete twin directly (useful for tests and hydration)
  void setAthlete(DigitalAthlete athlete) {
    _athleteCache[athlete.userId] = athlete;
  }

  /// 1. Update Athlete State After Workout Completion
  DigitalAthlete updateAfterWorkout({
    required String userId,
    required String workoutName,
    required String split,
    required double totalVolumeKg,
    required int durationMinutes,
    Map<String, double> liftPerformances =
        const {}, // e.g. {'Squat': 135.0, 'Bench Press': 102.5}
    double progressionRate = 0.03,
  }) {
    final current = getAthlete(userId);

    // Update 1RMs
    final updated1RM = Map<String, double>.from(
      current.strengthProfile.estimated1RM,
    );
    for (final entry in liftPerformances.entries) {
      if (entry.value > (updated1RM[entry.key] ?? 0.0)) {
        updated1RM[entry.key] = entry.value;
      }
    }

    final newStrengthProfile = current.strengthProfile.copyWith(
      estimated1RM: updated1RM,
      progressionVelocityPercentage:
          (current.strengthProfile.progressionVelocityPercentage * 0.8 +
          progressionRate * 100.0 * 0.2),
      totalStrengthVolumeKg:
          current.strengthProfile.totalStrengthVolumeKg + totalVolumeKg,
    );

    final newTrainingProfile = current.trainingProfile.copyWith(
      preferredSplit: split.isNotEmpty
          ? split
          : current.trainingProfile.preferredSplit,
      averageSessionMinutes:
          ((current.trainingProfile.averageSessionMinutes * 3 +
                      durationMinutes) /
                  4)
              .round(),
    );

    final newBehaviorProfile = current.behaviorProfile.copyWith(
      consistencyScore: (current.behaviorProfile.consistencyScore * 0.9 + 10.0)
          .clamp(50.0, 100.0),
      habitContinuityRate:
          (current.behaviorProfile.habitContinuityRate * 0.95 + 0.05).clamp(
            0.0,
            1.0,
          ),
    );

    final updatedAthlete = current.copyWith(
      strengthProfile: newStrengthProfile,
      trainingProfile: newTrainingProfile,
      behaviorProfile: newBehaviorProfile,
      updatedAt: DateTime.now(),
    );

    _athleteCache[userId] = updatedAthlete;
    return updatedAthlete;
  }

  /// 2. Update Athlete State After Nutrition Logging
  DigitalAthlete updateAfterNutrition({
    required String userId,
    required int caloriesConsumed,
    required double proteinGrams,
    required double carbsGrams,
    required double fatGrams,
    required double adherenceRate,
  }) {
    final current = getAthlete(userId);

    final newNutritionProfile = current.nutritionProfile.copyWith(
      dailyCalories:
          ((current.nutritionProfile.dailyCalories * 2 + caloriesConsumed) / 3)
              .round(),
      dailyProteinGrams:
          (current.nutritionProfile.dailyProteinGrams * 0.7 +
          proteinGrams * 0.3),
      dailyCarbsGrams:
          (current.nutritionProfile.dailyCarbsGrams * 0.7 + carbsGrams * 0.3),
      dailyFatGrams:
          (current.nutritionProfile.dailyFatGrams * 0.7 + fatGrams * 0.3),
      adherenceRate:
          (current.nutritionProfile.adherenceRate * 0.8 + adherenceRate * 0.2)
              .clamp(0.0, 1.0),
    );

    final updatedAthlete = current.copyWith(
      nutritionProfile: newNutritionProfile,
      updatedAt: DateTime.now(),
    );

    _athleteCache[userId] = updatedAthlete;
    return updatedAthlete;
  }

  /// 3. Update Athlete State After Recovery & Wearable Sync
  DigitalAthlete updateAfterRecovery({
    required String userId,
    required double sleepHours,
    required double hrvScore,
    required int restingHeartRate,
    required double recoveryScore,
  }) {
    final current = getAthlete(userId);

    final newRecoveryProfile = current.recoveryProfile.copyWith(
      averageRecoveryScore:
          (current.recoveryProfile.averageRecoveryScore * 0.7 +
          recoveryScore * 0.3),
      sleepDurationHours:
          (current.recoveryProfile.sleepDurationHours * 0.7 + sleepHours * 0.3),
      hrvAverage: (current.recoveryProfile.hrvAverage * 0.7 + hrvScore * 0.3),
      restingHeartRate:
          ((current.recoveryProfile.restingHeartRate * 2 + restingHeartRate) /
                  3)
              .round(),
    );

    final updatedAthlete = current.copyWith(
      recoveryProfile: newRecoveryProfile,
      updatedAt: DateTime.now(),
    );

    _athleteCache[userId] = updatedAthlete;
    return updatedAthlete;
  }

  /// 4. Update Athlete State After Biomechanical Form Analysis
  DigitalAthlete updateAfterFormAnalysis({
    required String userId,
    required ExerciseFormReport formReport,
  }) {
    final current = getAthlete(userId);

    final updatedFormAverages = Map<String, double>.from(
      current.formScoreAverages,
    );
    final prevScore = updatedFormAverages[formReport.exerciseName] ?? 80.0;
    updatedFormAverages[formReport.exerciseName] =
        (prevScore * 0.6 + formReport.score.overallScore * 0.4);

    final updatedWeaknesses = List<String>.from(current.biomechanicsWeaknesses);
    for (final issue in formReport.detectedIssues) {
      final weaknessText = '${formReport.exerciseName}: ${issue.problem}';
      if (!updatedWeaknesses.contains(weaknessText)) {
        updatedWeaknesses.add(weaknessText);
      }
    }

    final updatedAthlete = current.copyWith(
      formScoreAverages: updatedFormAverages,
      biomechanicsWeaknesses: updatedWeaknesses,
      updatedAt: DateTime.now(),
    );

    _athleteCache[userId] = updatedAthlete;
    return updatedAthlete;
  }

  /// 5. Update Athlete State After AI Conversation & Explicit Feedback
  DigitalAthlete updateAfterAiConversation({
    required String userId,
    String? trainingPersonality,
    String? preferredSplit,
    String? preferredWorkoutTime,
    String? missedSessionTrigger,
  }) {
    final current = getAthlete(userId);

    final newTraining = current.trainingProfile.copyWith(
      trainingPersonality:
          trainingPersonality ?? current.trainingProfile.trainingPersonality,
      preferredSplit: preferredSplit ?? current.trainingProfile.preferredSplit,
    );

    final newBehavior = current.behaviorProfile.copyWith(
      preferredWorkoutTime:
          preferredWorkoutTime ?? current.behaviorProfile.preferredWorkoutTime,
      missedSessionTrigger:
          missedSessionTrigger ?? current.behaviorProfile.missedSessionTrigger,
    );

    final updatedAthlete = current.copyWith(
      trainingProfile: newTraining,
      behaviorProfile: newBehavior,
      updatedAt: DateTime.now(),
    );

    _athleteCache[userId] = updatedAthlete;
    return updatedAthlete;
  }

  /// Detects the athlete's optimal circadian training window based on recovery and habits
  String detectCircadianOptimalWindow(String userId) {
    final athlete = getAthlete(userId);
    final pref = athlete.behaviorProfile.preferredWorkoutTime.toLowerCase();
    final rec = athlete.recoveryProfile.averageRecoveryScore;

    if (pref == 'morning') {
      return rec >= 80
          ? 'Morning Peak (06:30 - 08:30)'
          : 'Late Morning (09:30 - 11:30)';
    } else if (pref == 'afternoon') {
      return 'Afternoon Power Peak (14:00 - 16:30)';
    } else {
      return 'Evening Hypertrophy Window (17:30 - 19:30)';
    }
  }

  /// Synthesizes high-priority personalized training and recovery recommendations
  List<String> synthesizePersonalizedRecommendations(String userId) {
    final athlete = getAthlete(userId);
    final recs = <String>[];

    // 1. Recovery analysis
    if (athlete.recoveryProfile.averageRecoveryScore < 60) {
      recs.add(
        'CNS fatigue elevated. Recommend 20% volume deload or active mobility session.',
      );
    } else if (athlete.recoveryProfile.averageRecoveryScore >= 85) {
      recs.add(
        'Optimal autonomic readiness. Prime state for compound overload (+2.5% load).',
      );
    }

    // 2. Nutrition check
    if (athlete.nutritionProfile.adherenceRate < 0.8) {
      recs.add(
        'Protein adherence is below 80%. Prioritize 40g post-workout protein.',
      );
    }

    // 3. Biomechanical feedback
    if (athlete.biomechanicsWeaknesses.isNotEmpty) {
      recs.add('Focus technique cue: ${athlete.biomechanicsWeaknesses.first}');
    }

    return recs;
  }
}
