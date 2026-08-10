import '../models/referral.dart';
import '../models/reward_event.dart';
import '../models/notification_item.dart';
import '../services/reward_queue_service.dart';
import '../services/notification_service.dart';
import '../providers/fitness_provider.dart';

/// Central service managing referral codes, code redemptions, and referral reward dispatches.
class ReferralService {
  static ReferralService? _instance;
  ReferralData? _cachedData;

  /// Reset singleton instance (useful for testing)
  static void resetInstance() {
    _instance = null;
  }

  /// Singleton instance getter
  static ReferralService get instance {
    _instance ??= ReferralService();
    return _instance!;
  }

  /// Get current user's referral system details
  ReferralData getReferralData({String userId = 'usr_local'}) {
    _cachedData ??= ReferralData.initial(userId: userId);
    return _cachedData!;
  }

  /// Validate referral code format (e.g. AIRZAWL-XXXX)
  bool isValidCode(String code) {
    final trimmed = code.trim().toUpperCase();
    return trimmed.startsWith('AIRZAWL-') && trimmed.length >= 10;
  }

  /// Redeem/claim a friend's referral code upon joining
  Future<bool> claimReferralCode(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (!isValidCode(trimmed)) return false;

    final current = getReferralData();
    if (trimmed == current.referralCode) return false;

    // Grant instant welcome referral bonus
    await FitnessProvider.instance.addXP(250);
    RewardQueueService.instance.enqueue(
      RewardEvent.referralReward(
        referralId: 'claimed_${DateTime.now().millisecondsSinceEpoch}',
        title: 'WELCOME REFERRAL BONUS!',
        xpGained: 250,
      ),
    );

    NotificationService.instance.createNotification(
      NotificationItem.referralConverted(friendName: 'Aizawl Ambassador', xpReward: 250),
    );

    return true;
  }

  /// Trigger a referral conversion event when a referred friend joins/completes milestone
  Future<void> simulateReferralConversion(String friendName) async {
    final current = getReferralData();
    final updated = current.copyWith(
      totalReferredCount: current.totalReferredCount + 1,
      convertedCount: current.convertedCount + 1,
      totalXpEarned: current.totalXpEarned + 500,
      referredUserIds: [...current.referredUserIds, 'usr_${friendName.toLowerCase().replaceAll(' ', '_')}'],
    );
    _cachedData = updated;

    await FitnessProvider.instance.addXP(500);

    RewardQueueService.instance.enqueue(
      RewardEvent.referralReward(
        referralId: 'conv_${DateTime.now().millisecondsSinceEpoch}',
        title: 'REFERRAL CONVERTED!',
        xpGained: 500,
        data: {'amount': 500, 'source': 'Referred $friendName'},
      ),
    );

    NotificationService.instance.createNotification(
      NotificationItem.referralConverted(friendName: friendName, xpReward: 500),
    );
  }
}
