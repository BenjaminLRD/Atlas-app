import '../data/local_storage.dart';

/// Service managing user following relationships, follow counts, and social graph state.
class SocialGraphService {
  static SocialGraphService? _instance;

  SocialGraphService();

  static SocialGraphService get instance {
    _instance ??= SocialGraphService();
    return _instance!;
  }

  static void resetInstance() {
    _instance = null;
  }

  /// Check whether the current user is following [targetUserId].
  bool isFollowing(String targetUserId) {
    final list = LocalStorage.getFollowingUserIds();
    return list.contains(targetUserId);
  }

  /// Follow a specific user.
  Future<void> followUser(String targetUserId) async {
    final list = LocalStorage.getFollowingUserIds();
    if (!list.contains(targetUserId)) {
      list.add(targetUserId);
      await LocalStorage.saveFollowingUserIds(list);
    }
  }

  /// Unfollow a specific user.
  Future<void> unfollowUser(String targetUserId) async {
    final list = LocalStorage.getFollowingUserIds();
    if (list.contains(targetUserId)) {
      list.remove(targetUserId);
      await LocalStorage.saveFollowingUserIds(list);
    }
  }

  /// Toggle follow status for [targetUserId] and return the new status.
  Future<bool> toggleFollow(String targetUserId) async {
    if (isFollowing(targetUserId)) {
      await unfollowUser(targetUserId);
      return false;
    } else {
      await followUser(targetUserId);
      return true;
    }
  }

  /// Get list of all followed user IDs.
  List<String> getFollowingUserIds() {
    return LocalStorage.getFollowingUserIds();
  }

  /// Get follower count for a user (combining simulated athlete baseline with local state).
  int getFollowersCount(String userId) {
    int baseline;
    switch (userId) {
      case 'usr_benjamin':
        baseline = 1420;
        break;
      case 'usr_alex':
        baseline = 980;
        break;
      case 'usr_maya':
        baseline = 840;
        break;
      case 'usr_daniel':
        baseline = 620;
        break;
      case 'usr_sarah':
        baseline = 510;
        break;
      default:
        baseline = 145;
    }
    return isFollowing(userId) ? baseline + 1 : baseline;
  }

  /// Get following count for a user.
  int getFollowingCount(String userId) {
    if (userId == 'usr_local' || userId.isEmpty) {
      return getFollowingUserIds().length;
    }
    switch (userId) {
      case 'usr_benjamin':
        return 180;
      case 'usr_alex':
        return 145;
      case 'usr_maya':
        return 210;
      default:
        return 95;
    }
  }
}
