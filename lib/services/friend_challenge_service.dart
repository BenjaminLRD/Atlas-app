import '../models/friend_challenge.dart';
import '../models/reward_event.dart';
import '../models/notification_item.dart';
import '../services/reward_queue_service.dart';
import '../services/notification_service.dart';
import '../providers/fitness_provider.dart';

/// Central service managing 1v1 and group Friend Challenges.
class FriendChallengeService {
  static FriendChallengeService? _instance;
  List<FriendChallenge>? _cachedChallenges;

  /// Reset singleton instance (useful for testing)
  static void resetInstance() {
    _instance = null;
  }

  /// Singleton instance getter
  static FriendChallengeService get instance {
    _instance ??= FriendChallengeService();
    return _instance!;
  }

  static List<FriendChallenge> _getDefaultChallenges() {
    return [
      FriendChallenge(
        id: 'fc_1',
        creatorId: 'usr_alex',
        creatorName: 'Alex Carter',
        opponentId: 'usr_local',
        opponentName: 'You',
        type: ChallengeType.volumeShowdown,
        status: ChallengeStatus.active,
        title: 'Leg Volume Showdown',
        description: 'First to lift 15,000 kg total volume',
        creatorProgress: 11200.0,
        opponentProgress: 9500.0,
        targetGoal: 15000.0,
        xpReward: 750,
      ),
      FriendChallenge(
        id: 'fc_2',
        creatorId: 'usr_local',
        creatorName: 'You',
        opponentId: 'usr_maya',
        opponentName: 'Maya Chen',
        type: ChallengeType.streakSprint,
        status: ChallengeStatus.invited,
        title: '7-Day Streak Sprint',
        description: 'Complete at least 1 workout daily for 7 consecutive days',
        creatorProgress: 3.0,
        opponentProgress: 2.0,
        targetGoal: 7.0,
        xpReward: 500,
      ),
    ];
  }

  /// Get active and pending friend challenges
  List<FriendChallenge> getChallenges() {
    _cachedChallenges ??= _getDefaultChallenges();
    return List.unmodifiable(_cachedChallenges!);
  }

  /// Create and send a new 1v1 challenge to a friend
  FriendChallenge createChallenge({
    required String opponentId,
    required String opponentName,
    required ChallengeType type,
    required String title,
    required double targetGoal,
    int xpReward = 500,
  }) {
    final newChallenge = FriendChallenge(
      id: 'fc_${DateTime.now().millisecondsSinceEpoch}',
      creatorId: 'usr_local',
      creatorName: 'You',
      opponentId: opponentId,
      opponentName: opponentName,
      type: type,
      status: ChallengeStatus.active,
      title: title,
      description: 'First to reach ${targetGoal.toInt()} goal!',
      creatorProgress: 0.0,
      opponentProgress: 0.0,
      targetGoal: targetGoal,
      xpReward: xpReward,
    );

    final list = List<FriendChallenge>.from(getChallenges());
    list.insert(0, newChallenge);
    _cachedChallenges = list;

    NotificationService.instance.createNotification(
      NotificationItem.challengeReceived(fromUserName: opponentName, challengeTitle: title),
    );

    return newChallenge;
  }

  /// Accept an incoming challenge invitation
  void acceptChallenge(String challengeId) {
    final list = List<FriendChallenge>.from(getChallenges());
    final index = list.indexWhere((c) => c.id == challengeId);
    if (index != -1) {
      list[index] = list[index].copyWith(status: ChallengeStatus.active);
      _cachedChallenges = list;
    }
  }

  /// Decline an incoming challenge invitation
  void declineChallenge(String challengeId) {
    final list = List<FriendChallenge>.from(getChallenges());
    final index = list.indexWhere((c) => c.id == challengeId);
    if (index != -1) {
      list[index] = list[index].copyWith(status: ChallengeStatus.declined);
      _cachedChallenges = list;
    }
  }

  /// Update challenge progress based on completed workout metrics
  void updateProgressOnWorkout({required double volumeLifted, int sessionsIncrement = 1}) {
    final list = List<FriendChallenge>.from(getChallenges());
    for (int i = 0; i < list.length; i++) {
      final challenge = list[i];
      if (challenge.status != ChallengeStatus.active) continue;

      double addition = 0.0;
      if (challenge.type == ChallengeType.volumeShowdown) {
        addition = volumeLifted;
      } else if (challenge.type == ChallengeType.workoutCount || challenge.type == ChallengeType.streakSprint) {
        addition = sessionsIncrement.toDouble();
      } else if (challenge.type == ChallengeType.xpRace) {
        addition = 150.0;
      }

      final updatedProgress = challenge.creatorProgress + addition;
      if (updatedProgress >= challenge.targetGoal && challenge.winnerId == null) {
        // Victory achieved!
        list[i] = challenge.copyWith(
          creatorProgress: updatedProgress,
          status: ChallengeStatus.completed,
          winnerId: 'usr_local',
        );

        FitnessProvider.instance.addXP(challenge.xpReward);
        RewardQueueService.instance.enqueue(
          RewardEvent.friendChallenge(
            challengeId: challenge.id,
            title: 'CHALLENGE VICTORY!',
            xpGained: challenge.xpReward,
            data: {'amount': challenge.xpReward, 'source': 'Defeated ${challenge.opponentName}'},
          ),
        );
      } else {
        list[i] = challenge.copyWith(creatorProgress: updatedProgress);
      }
    }
    _cachedChallenges = list;
  }
}
