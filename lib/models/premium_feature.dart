/// Enumeration of premium features subject to Atlas subscription permissions.
enum PremiumFeature {
  aiCoach,
  adaptivePlanner,
  recoveryIntelligence,
  wearableSync,
  advancedAnalytics,
  unlimitedFoodScanning,
  exerciseFormAnalysis,
  recoveryPredictions,
  digitalAthleteInsights,
}

extension PremiumFeatureExtension on PremiumFeature {
  String get featureKey {
    switch (this) {
      case PremiumFeature.aiCoach:
        return 'ai_coach';
      case PremiumFeature.adaptivePlanner:
        return 'adaptive_planner';
      case PremiumFeature.recoveryIntelligence:
        return 'recovery_intelligence';
      case PremiumFeature.wearableSync:
        return 'wearable_sync';
      case PremiumFeature.advancedAnalytics:
        return 'advanced_analytics';
      case PremiumFeature.unlimitedFoodScanning:
        return 'unlimited_food_scanning';
      case PremiumFeature.exerciseFormAnalysis:
        return 'exercise_form_analysis';
      case PremiumFeature.recoveryPredictions:
        return 'recovery_predictions';
      case PremiumFeature.digitalAthleteInsights:
        return 'digital_athlete_insights';
    }
  }

  String get title {
    switch (this) {
      case PremiumFeature.aiCoach:
        return 'Unlimited Atlas AI Coach';
      case PremiumFeature.adaptivePlanner:
        return 'Adaptive Workout Autoregulation';
      case PremiumFeature.recoveryIntelligence:
        return 'Recovery & Deload Intelligence';
      case PremiumFeature.wearableSync:
        return 'Wearable Health Sync';
      case PremiumFeature.advancedAnalytics:
        return 'Advanced Strength Analytics & 1RM';
      case PremiumFeature.unlimitedFoodScanning:
        return 'Unlimited AI Food & Barcode Vision';
      case PremiumFeature.exerciseFormAnalysis:
        return 'Real-Time 33-pt Pose Form Coach';
      case PremiumFeature.recoveryPredictions:
        return '12-Week 1RM & Recovery Predictors';
      case PremiumFeature.digitalAthleteInsights:
        return 'Proactive Digital Athlete Insights';
    }
  }

  String get description {
    switch (this) {
      case PremiumFeature.aiCoach:
        return '24/7 unlimited context-aware conversational fitness coaching and tool execution.';
      case PremiumFeature.adaptivePlanner:
        return 'Fatigue-autoregulated training volume, RPE progression, and dynamic exercise regression.';
      case PremiumFeature.recoveryIntelligence:
        return 'Algorithmic HRV and CNS fatigue modeling with automated active recovery protocols.';
      case PremiumFeature.wearableSync:
        return 'Continuous Apple Health, Google Health Connect, and Garmin biometric sync.';
      case PremiumFeature.advancedAnalytics:
        return 'In-depth strength progression charts, 1RM trajectory modeling, and volume fatigue curves.';
      case PremiumFeature.unlimitedFoodScanning:
        return 'Snap unlimited meals and scan instant barcodes with AI macronutrient analysis.';
      case PremiumFeature.exerciseFormAnalysis:
        return 'On-device 33-point computer vision pose estimation with sub-second auditory feedback.';
      case PremiumFeature.recoveryPredictions:
        return 'Multi-week 1RM compound forecasts (Squat, Bench, Deadlift) and goal completion timelines.';
      case PremiumFeature.digitalAthleteInsights:
        return 'Weekly proactive AI insights synthesizing training volume, sleep, and biomechanics.';
    }
  }

  String get iconName {
    switch (this) {
      case PremiumFeature.aiCoach:
        return 'psychology_rounded';
      case PremiumFeature.adaptivePlanner:
        return 'auto_awesome_rounded';
      case PremiumFeature.recoveryIntelligence:
        return 'battery_charging_full_rounded';
      case PremiumFeature.wearableSync:
        return 'watch_rounded';
      case PremiumFeature.advancedAnalytics:
        return 'insights_rounded';
      case PremiumFeature.unlimitedFoodScanning:
        return 'qr_code_scanner_rounded';
      case PremiumFeature.exerciseFormAnalysis:
        return 'accessibility_new_rounded';
      case PremiumFeature.recoveryPredictions:
        return 'trending_up_rounded';
      case PremiumFeature.digitalAthleteInsights:
        return 'person_search_rounded';
    }
  }
}
