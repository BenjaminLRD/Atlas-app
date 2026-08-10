/// Enumeration of premium features subject to subscription permissions.
enum PremiumFeature {
  aiCoach,
  adaptivePlanner,
  recoveryIntelligence,
  wearableSync,
  advancedAnalytics,
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
    }
  }

  String get title {
    switch (this) {
      case PremiumFeature.aiCoach:
        return 'AI Fitness Coach';
      case PremiumFeature.adaptivePlanner:
        return 'Adaptive Workout Planner';
      case PremiumFeature.recoveryIntelligence:
        return 'Recovery & Deload Intelligence';
      case PremiumFeature.wearableSync:
        return 'Wearable Health Sync';
      case PremiumFeature.advancedAnalytics:
        return 'Advanced Analytics & PRs';
    }
  }

  String get description {
    switch (this) {
      case PremiumFeature.aiCoach:
        return '24/7 personalized coaching, nutrition advice, and context-aware chat.';
      case PremiumFeature.adaptivePlanner:
        return 'Dynamic volume, intensity, and muscle recovery workout planner.';
      case PremiumFeature.recoveryIntelligence:
        return 'Algorithmic fatigue score tracking and automatic deload warnings.';
      case PremiumFeature.wearableSync:
        return 'Apple Health, Google Fit, Fitbit, and Garmin real-time sync.';
      case PremiumFeature.advancedAnalytics:
        return 'In-depth strength progression charts, 1RM estimation, and muscle distribution.';
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
    }
  }
}
