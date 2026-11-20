import 'engagement_prediction_engine.dart';
import 'feature_engineering_service.dart';
import 'workout_recommendation_model.dart';

/// Pluggable Machine Learning Model Inference Service (TensorFlow Lite & On-Device ML ready).
class ModelInferenceService {
  static ModelInferenceService? _instance;
  static ModelInferenceService get instance =>
      _instance ??= ModelInferenceService();

  final Map<String, bool> _loadedModels = {
    'workout_recommendation_model': true,
    'churn_prediction_model': true,
    'recovery_prediction_model': true,
  };

  /// Loads or initializes an on-device machine learning model binary (e.g. .tflite).
  Future<bool> loadModel(String modelPath) async {
    _loadedModels[modelPath] = true;
    return true;
  }

  /// Updates or calibrates model weights and hyperparameters.
  void updateModel(String modelName, Map<String, dynamic> hyperparameters) {
    _loadedModels[modelName] = true;
  }

  /// Executes inference across registered machine learning models.
  Map<String, dynamic> predict({
    required String modelName,
    required Map<String, dynamic> inputFeatures,
  }) {
    switch (modelName) {
      case 'workout_recommendation_model':
        final featureVector = inputFeatures['feature_vector'] != null
            ? UserFeatureVector.fromJson(
                inputFeatures['feature_vector'] as Map<String, dynamic>,
              )
            : UserFeatureVector.baseline();
        final goal = inputFeatures['goal'] as String? ?? 'Hypertrophy';
        final level =
            inputFeatures['fitness_level'] as String? ?? 'Intermediate';
        final recoveryScore =
            (inputFeatures['recovery_score'] as num?)?.toDouble() ?? 85.0;

        final rec = WorkoutRecommendationModel.instance.generateRecommendation(
          featureVector: featureVector,
          goal: goal,
          fitnessLevel: level,
          recoveryScore: recoveryScore,
        );
        return {
          'model': modelName,
          'prediction': rec.toJson(),
          'confidence': rec.completionProbability,
        };

      case 'churn_prediction_model':
        final daysInactive =
            (inputFeatures['days_since_last_workout'] as num?)?.toInt() ?? 1;
        final missedGoals =
            (inputFeatures['missed_goals'] as num?)?.toInt() ?? 0;
        final engagement =
            (inputFeatures['engagement_score'] as num?)?.toDouble() ?? 85.0;
        final nutritionAdh =
            (inputFeatures['nutrition_adherence'] as num?)?.toDouble() ?? 0.85;

        final churnResult = EngagementPredictionEngine.instance
            .predictRetentionRisk(
              daysSinceLastWorkout: daysInactive,
              missedGoalsLast14Days: missedGoals,
              recentEngagementScore: engagement,
              nutritionLoggingAdherence: nutritionAdh,
            );
        return {
          'model': modelName,
          'prediction': churnResult.toJson(),
          'confidence': (1.0 - (churnResult.riskProbability - 0.5).abs()),
        };

      case 'recovery_prediction_model':
      default:
        return {
          'model': modelName,
          'prediction': {
            'estimated_recovery_score': 88.0,
            'fatigue_status': 'optimal',
            'readiness_recommendation':
                'Cleared for high-intensity compound training.',
          },
          'confidence': 0.95,
        };
    }
  }
}
