import 'analytics/analytics_service.dart';

/// Central service tracking community growth KPIs and social interactions.
class GrowthAnalyticsService {
  static GrowthAnalyticsService? _instance;

  int _referralsSent = 4;
  int _referralsConverted = 2;
  int _socialShares = 8;
  int _communityInteractions = 29;
  int _challengesJoined = 5;
  int _challengesWon = 3;

  /// Reset singleton instance (useful for testing)
  static void resetInstance() {
    _instance = null;
  }

  /// Singleton instance getter
  static GrowthAnalyticsService get instance {
    _instance ??= GrowthAnalyticsService();
    return _instance!;
  }

  void trackReferralSent() {
    _referralsSent++;
    AnalyticsService.instance.logEvent('referral_code_shared', parameters: {'total_sent': _referralsSent});
  }

  void trackReferralConverted() {
    _referralsConverted++;
    AnalyticsService.instance.logEvent('referral_converted', parameters: {'total_converted': _referralsConverted});
  }

  void trackSocialShare({String shareType = 'workout_card'}) {
    _socialShares++;
    AnalyticsService.instance.logEvent('social_content_shared', parameters: {'type': shareType});
  }

  void trackCommunityInteraction({String interactionType = 'like'}) {
    _communityInteractions++;
    AnalyticsService.instance.logEvent('community_interaction', parameters: {'type': interactionType});
  }

  void trackChallengeJoined() {
    _challengesJoined++;
    AnalyticsService.instance.logEvent('friend_challenge_joined');
  }

  void trackChallengeWon() {
    _challengesWon++;
    AnalyticsService.instance.logEvent('friend_challenge_won');
  }

  Map<String, int> getGrowthMetrics() {
    return {
      'referralsSent': _referralsSent,
      'referralsConverted': _referralsConverted,
      'socialShares': _socialShares,
      'communityInteractions': _communityInteractions,
      'challengesJoined': _challengesJoined,
      'challengesWon': _challengesWon,
    };
  }
}
