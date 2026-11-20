import '../models/premium_feature.dart';
import '../models/subscription.dart';

/// Central permission and usage evaluation manager determining feature access
/// and daily usage quotas based on subscription tier.
class PremiumAccessManager {
  static const int freeDailyAiMessageLimit = 3;
  static const int freeDailyFoodScanLimit = 3;

  // In-memory usage counter: userId -> { 'ai_messages': count, 'food_scans': count }
  static final Map<String, Map<String, int>> _dailyUsageTracker = {};
  static DateTime _lastUsageReset = DateTime.now();

  const PremiumAccessManager();

  static void resetUsageForTesting() {
    _dailyUsageTracker.clear();
    _lastUsageReset = DateTime.now();
  }

  /// Evaluates whether the given [subscription] has access to [feature].
  bool canAccessFeature(PremiumFeature feature, Subscription subscription) {
    if (subscription.isPremium) {
      return true;
    }

    // Certain basic features allow limited free usage handled via quotas
    if (feature == PremiumFeature.aiCoach ||
        feature == PremiumFeature.unlimitedFoodScanning) {
      return true; // Subject to daily quota check
    }

    // Strictly premium features are locked for Free tier
    return false;
  }

  /// Checks if the user has remaining daily quota for a given action.
  bool hasRemainingQuota({
    required String userId,
    required String actionKey, // e.g. 'ai_message' or 'food_scan'
    required Subscription subscription,
  }) {
    if (subscription.isPremium) return true; // Unlimited for Pro / Elite

    _checkAndResetDailyUsage();
    final userUsage = _dailyUsageTracker[userId] ?? {};
    final currentCount = userUsage[actionKey] ?? 0;

    if (actionKey == 'ai_message') {
      return currentCount < freeDailyAiMessageLimit;
    } else if (actionKey == 'food_scan') {
      return currentCount < freeDailyFoodScanLimit;
    }

    return false;
  }

  /// Increments daily usage for a quota-restricted feature.
  void recordUsage({required String userId, required String actionKey}) {
    _checkAndResetDailyUsage();
    _dailyUsageTracker.putIfAbsent(userId, () => {});
    _dailyUsageTracker[userId]![actionKey] =
        (_dailyUsageTracker[userId]![actionKey] ?? 0) + 1;
  }

  /// Returns current usage stats for display in UI.
  Map<String, int> getDailyUsage(String userId) {
    _checkAndResetDailyUsage();
    return Map.unmodifiable(_dailyUsageTracker[userId] ?? {});
  }

  /// Returns list of all features currently subject to premium gating.
  List<PremiumFeature> getGatedFeatures() {
    return PremiumFeature.values;
  }

  /// Returns list of unlocked features for the active [subscription].
  List<PremiumFeature> getUnlockedFeatures(Subscription subscription) {
    if (subscription.isPremium) {
      return PremiumFeature.values;
    }
    return [PremiumFeature.aiCoach, PremiumFeature.unlimitedFoodScanning];
  }

  void _checkAndResetDailyUsage() {
    final now = DateTime.now();
    if (now.day != _lastUsageReset.day ||
        now.month != _lastUsageReset.month ||
        now.year != _lastUsageReset.year) {
      _dailyUsageTracker.clear();
      _lastUsageReset = now;
    }
  }
}
