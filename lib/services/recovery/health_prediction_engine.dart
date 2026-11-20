import '../../models/daily_nutrition.dart';
import '../../models/health_metrics.dart';
import '../../models/recovery/recovery_report.dart';
import '../../models/workout_feedback.dart';
import '../../models/workout_history.dart';
import '../ai/ai_provider.dart';
import 'recovery_prediction_engine.dart';

/// Abstract contract for machine learning inference models (e.g. TFLite, CoreML, Onnx).
abstract class HealthMLModel {
  /// Runs forward pass on normalized feature vector [workoutRestHours, sleepHours, hrvMs, acwr, tsb, calories, protein]
  Future<double> predictReadinessScore(List<double> featureVector);
}

/// Default hybrid ML model utilizing domain biomechanics & physiological heuristics.
class RuleBasedHybridModel implements HealthMLModel {
  const RuleBasedHybridModel();

  @override
  Future<double> predictReadinessScore(List<double> featureVector) async {
    // Feature indices:
    // [0] = workoutRestHours / 48.0 (clamped 0-1)
    // [1] = sleepHours / 8.0 (clamped 0-1)
    // [2] = hrvMs / 80.0 (clamped 0-1)
    // [3] = acwr (1.0 = optimal)
    // [4] = proteinGrams / 120.0 (clamped 0-1)

    final rest = (featureVector.isNotEmpty ? featureVector[0] : 0.8).clamp(0.0, 1.0);
    final sleep = (featureVector.length > 1 ? featureVector[1] : 0.8).clamp(0.0, 1.0);
    final hrv = (featureVector.length > 2 ? featureVector[2] : 0.8).clamp(0.0, 1.0);
    final acwr = featureVector.length > 3 ? featureVector[3] : 1.0;
    final acwrScore = (acwr >= 0.8 && acwr <= 1.3) ? 1.0 : (acwr > 1.5 ? 0.3 : 0.7);
    final nutrition = (featureVector.length > 4 ? featureVector[4] : 0.8).clamp(0.0, 1.0);

    final score = (rest * 30.0) + (sleep * 25.0) + (hrv * 20.0) + (acwrScore * 15.0) + (nutrition * 10.0);
    return score.clamp(0.0, 100.0);
  }
}

/// Advanced Health Prediction Engine combining ML models, Biomechanical rules,
/// and AI reasoning. Prepared for future on-device TensorFlow Lite (.tflite) integration.
class HealthPredictionEngine {
  final RecoveryPredictionEngine _recoveryPredictionEngine;
  final HealthMLModel _mlModel;
  final AIProvider? aiProvider;

  HealthPredictionEngine({
    RecoveryPredictionEngine? recoveryPredictionEngine,
    HealthMLModel? mlModel,
    this.aiProvider,
  })  : _recoveryPredictionEngine = recoveryPredictionEngine ?? const RecoveryPredictionEngine(),
        _mlModel = mlModel ?? const RuleBasedHybridModel();

  /// Protein used when nothing is known about today's intake: a typical day,
  /// so the model neither rewards nor penalises missing data.
  static const double neutralProteinGrams = 100.0;

  /// Today's protein as a model input, with an explicit missing-value rule.
  /// No data, or foods whose protein is unknown, are imputed with
  /// [neutralProteinGrams]; unknown never becomes 0. The known amount still
  /// counts when it is already above that (it is a minimum, so it can only
  /// be higher in reality).
  static double proteinFeature(DailyNutrition? nutrition) {
    if (nutrition == null) return neutralProteinGrams;
    final totals = nutrition.totalsConsumed;
    if (totals.proteinComplete) return totals.protein;
    return totals.protein > neutralProteinGrams
        ? totals.protein
        : neutralProteinGrams;
  }

  /// Predicts athlete readiness and generates an explainable recovery report.
  Future<RecoveryReport> predictRecoveryAndReadiness({
    required String userId,
    required List<WorkoutHistory> workoutHistory,
    HealthMetrics? healthMetrics,
    DailyNutrition? todayNutrition,
    List<WorkoutFeedback>? feedbackHistory,
    DateTime? referenceDate,
  }) async {
    // 1. Run Core Physiological & Biomechanical Inference
    final report = _recoveryPredictionEngine.analyzeReadiness(
      userId: userId,
      workoutHistory: workoutHistory,
      healthMetrics: healthMetrics,
      todayNutrition: todayNutrition,
      feedbackHistory: feedbackHistory,
      referenceDate: referenceDate,
    );

    // 2. ML feature vector for model verification. The model only ever sees
    // real measurements: with no workout history, sleep or HRV there is nothing
    // to infer from, so it is skipped. No sleep, HRV or rest period is made up.
    // (Its output is not shown to the user; the report above is.)
    final sleepHours = healthMetrics?.sleepHours;
    final hrv = healthMetrics?.heartRateVariability;
    final canInfer =
        workoutHistory.isNotEmpty &&
        sleepHours != null &&
        sleepHours > 0 &&
        hrv != null &&
        hrv > 0;
    if (canInfer) {
      final restHours = (referenceDate ?? DateTime.now())
          .difference(workoutHistory.first.dateCompleted)
          .inHours
          .toDouble();
      final featureVector = [
        restHours / 48.0,
        sleepHours / 8.0,
        hrv / 80.0,
        report.acuteToChronicRatio,
        // Missing protein is imputed neutrally inside this input only.
        proteinFeature(todayNutrition) / 120.0,
      ];
      await _mlModel.predictReadinessScore(featureVector);
    }

    return report;
  }
}
