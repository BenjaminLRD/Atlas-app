import '../models/premium_feature.dart';
import '../models/subscription.dart';

/// Central permission evaluation manager determining feature access based on subscription tier.
class PremiumAccessManager {
  const PremiumAccessManager();

  /// Evaluates whether the given [subscription] has access to [feature].
  bool canAccessFeature(PremiumFeature feature, Subscription subscription) {
    if (subscription.isPremium) {
      return true;
    }
    // Free tier users do not have access to gated premium features
    return false;
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
    return const [];
  }
}
