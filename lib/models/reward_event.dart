import '../models/badge.dart';
import '../widgets/common/rank_up_dialog.dart';

/// Enum representing the category of post-workout and gamification rewards
enum RewardType {
  rankUp,
  achievement,
  xpBonus,
  // Future extension types
  dailyQuest,
  weeklyChallenge,
  seasonalReward,
  battlePass,
  referralReward,
  friendChallenge,
}

/// Model class for a single reward event queued in the reward pipeline
class RewardEvent {
  /// Unique identifier used for queue ordering and deduplication
  final String id;

  /// The type of reward event
  final RewardType type;

  /// Display title of the reward
  final String title;

  /// Payload data associated with the reward (e.g. RankUpDetails, AchievementBadge)
  final dynamic data;

  /// Priority of presentation (Higher priority rewards are presented first)
  final int priority;

  /// Timestamp when the reward event was generated
  final DateTime timestamp;

  RewardEvent({
    required this.id,
    required this.type,
    required this.title,
    this.data,
    this.priority = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Convert RewardEvent to a JSON-encodable map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'priority': priority,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  // --- Factory constructors for standard system rewards ---

  /// Create a Rank Up reward event (Priority 100)
  factory RewardEvent.rankUp(RankUpDetails details) {
    return RewardEvent(
      id: 'rank_up_${details.newRank}',
      type: RewardType.rankUp,
      title: 'Rank Up: ${details.newRank}',
      data: details,
      priority: 100,
    );
  }

  /// Create an Achievement unlock reward event (Priority 80)
  factory RewardEvent.achievement(AchievementBadge badge) {
    return RewardEvent(
      id: 'achievement_${badge.id}',
      type: RewardType.achievement,
      title: 'Achievement Unlocked: ${badge.title}',
      data: badge,
      priority: 80,
    );
  }

  /// Create an XP Bonus reward event (Priority 50)
  factory RewardEvent.xpBonus({
    required int amount,
    required String source,
    String? customId,
  }) {
    return RewardEvent(
      id: customId ?? 'xp_bonus_${source}_${DateTime.now().millisecondsSinceEpoch}',
      type: RewardType.xpBonus,
      title: '+$amount XP Bonus',
      data: {'amount': amount, 'source': source},
      priority: 50,
    );
  }

  // --- Architecture preparation factories for future expansions ---

  /// Create a Daily Quest completion reward event (Priority 60)
  factory RewardEvent.dailyQuest({
    required String questId,
    required String title,
    dynamic data,
  }) {
    return RewardEvent(
      id: 'daily_quest_$questId',
      type: RewardType.dailyQuest,
      title: title,
      data: data,
      priority: 60,
    );
  }

  /// Create a Weekly Challenge reward event (Priority 70)
  factory RewardEvent.weeklyChallenge({
    required String challengeId,
    required String title,
    dynamic data,
  }) {
    return RewardEvent(
      id: 'weekly_challenge_$challengeId',
      type: RewardType.weeklyChallenge,
      title: title,
      data: data,
      priority: 70,
    );
  }

  /// Create a Seasonal Reward event (Priority 75)
  factory RewardEvent.seasonalReward({
    required String rewardId,
    required String title,
    dynamic data,
  }) {
    return RewardEvent(
      id: 'seasonal_reward_$rewardId',
      type: RewardType.seasonalReward,
      title: title,
      data: data,
      priority: 75,
    );
  }

  /// Create a Battle Pass progression reward event (Priority 65)
  factory RewardEvent.battlePass({
    required String tierId,
    required String title,
    dynamic data,
  }) {
    return RewardEvent(
      id: 'battle_pass_$tierId',
      type: RewardType.battlePass,
      title: title,
      data: data,
      priority: 65,
    );
  }

  /// Create a Referral Reward event (Priority 72)
  factory RewardEvent.referralReward({
    required String referralId,
    required String title,
    required int xpGained,
    dynamic data,
  }) {
    return RewardEvent(
      id: 'referral_reward_$referralId',
      type: RewardType.referralReward,
      title: title,
      data: data ?? {'amount': xpGained, 'source': 'Referral Bonus'},
      priority: 72,
    );
  }

  /// Create a Friend Challenge victory reward event (Priority 85)
  factory RewardEvent.friendChallenge({
    required String challengeId,
    required String title,
    required int xpGained,
    dynamic data,
  }) {
    return RewardEvent(
      id: 'friend_challenge_$challengeId',
      type: RewardType.friendChallenge,
      title: title,
      data: data ?? {'amount': xpGained, 'source': 'Challenge Victory'},
      priority: 85,
    );
  }

  @override
  String toString() => 'RewardEvent(id: $id, type: ${type.name}, priority: $priority, title: $title)';
}
