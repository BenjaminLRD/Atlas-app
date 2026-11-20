import '../data/local_storage.dart';
import '../models/referral.dart';
import '../models/reward_event.dart';
import '../models/notification_item.dart';
import '../services/reward_queue_service.dart';
import '../services/notification_service.dart';
import 'gamification/bonus_xp.dart';

/// Central service managing referral codes, code redemptions, and referral reward dispatches.
class ReferralService {
  static ReferralService? _instance;
  ReferralData? _cachedData;

  final XpAwarder? _awardXp;

  /// [awardXp] sends the XP to the athlete; by default the shared
  /// [BonusXp.awarder] is used, looked up each time it is needed.
  ReferralService({this._awardXp});

  Future<void> _award(int amount) => (_awardXp ?? BonusXp.awarder)(amount);

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

  /// Validate referral code format (e.g. ATLAS-XXXX)
  bool isValidCode(String code) {
    final trimmed = code.trim().toUpperCase();
    return trimmed.startsWith('ATLAS-') && trimmed.length >= 8;
  }

  /// Claims in progress, by account and code. The saved record below already
  /// stops a second tap, because it is written before anything is awaited;
  /// this keeps that true if the store ever becomes asynchronous.
  final Set<String> _claimsInProgress = {};

  /// Redeem/claim a friend's referral code upon joining.
  ///
  /// Each code can be claimed once per account: a repeat returns false and
  /// awards nothing. The claim is saved before the XP is awarded and taken
  /// back if awarding fails, so a failed claim can be tried again and a
  /// successful one never pays twice. (If the app dies between the save and
  /// the award, the code stays claimed without its XP rather than paying it
  /// twice.)
  ///
  /// Throws [XpIdentityException] when the signed-in account cannot be
  /// determined, and rethrows an award failure; in both cases nothing is
  /// claimed.
  Future<bool> claimReferralCode(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (!isValidCode(trimmed)) return false;

    final current = getReferralData();
    if (trimmed == current.referralCode) return false;

    final userId = BonusXp.currentUserId();
    final claimKey = '$userId|$trimmed';
    if (_claimsInProgress.contains(claimKey) ||
        LocalStorage.hasClaimedReferralCode(userId, trimmed)) {
      return false;
    }
    _claimsInProgress.add(claimKey);
    try {
      await LocalStorage.markReferralCodeClaimed(userId, trimmed);
      try {
        // Grant instant welcome referral bonus
        await _award(250);
      } catch (_) {
        await LocalStorage.unmarkReferralCodeClaimed(userId, trimmed);
        rethrow;
      }
      return _announceClaim();
    } finally {
      _claimsInProgress.remove(claimKey);
    }
  }

  bool _announceClaim() {
    RewardQueueService.instance.enqueue(
      RewardEvent.referralReward(
        referralId: 'claimed_${DateTime.now().millisecondsSinceEpoch}',
        title: 'WELCOME REFERRAL BONUS!',
        xpGained: 250,
      ),
    );

    NotificationService.instance.createNotification(
      NotificationItem.referralConverted(
        friendName: 'Atlas Ambassador',
        xpReward: 250,
      ),
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
      referredUserIds: [
        ...current.referredUserIds,
        'usr_${friendName.toLowerCase().replaceAll(' ', '_')}',
      ],
    );

    // Count the conversion only once the XP has been awarded: if awarding
    // fails, nothing is recorded and the conversion can be tried again.
    await _award(500);
    _cachedData = updated;

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
