import '../data/local_storage.dart';
import 'community/community_cloud_repository.dart';
import '../models/activity_post.dart';

/// Moderation, reporting, and safety service for the Community Hub.
class ModerationService {
  static ModerationService? _instance;

  ModerationService();

  static ModerationService get instance {
    _instance ??= ModerationService();
    return _instance!;
  }

  static void resetInstance() {
    _instance = null;
  }

  /// Submit a safety / content report for a post.
  Future<void> reportPost(String postId, String reason) async {
    // Hide it here right away; the server hides it for everyone after three
    // reports and queues it for review.
    await hidePost(postId);
    if (CommunityCloudRepository.isActive &&
        CommunityCloudRepository.isCloudId(postId)) {
      await CommunityCloudRepository.instance.report(
        postId: postId,
        reason: reason,
      );
    }
  }

  /// Report a comment for review.
  Future<void> reportComment(String commentId, String reason) async {
    if (CommunityCloudRepository.isActive &&
        CommunityCloudRepository.isCloudId(commentId)) {
      await CommunityCloudRepository.instance.report(
        commentId: commentId,
        reason: reason,
      );
    }
  }

  /// Block a user and prevent their content from appearing in feeds.
  Future<void> blockUser(String userId) async {
    final list = LocalStorage.getBlockedUserIds();
    if (!list.contains(userId)) {
      list.add(userId);
      await LocalStorage.saveBlockedUserIds(list);
    }
    // Sample athletes exist only on this device; the server knows no such id.
    if (CommunityCloudRepository.isActive &&
        CommunityCloudRepository.isCloudId(userId)) {
      await CommunityCloudRepository.instance.block(userId);
    }
  }

  /// Unblock a user.
  Future<void> unblockUser(String userId) async {
    final list = LocalStorage.getBlockedUserIds();
    if (list.contains(userId)) {
      list.remove(userId);
      await LocalStorage.saveBlockedUserIds(list);
    }
    if (CommunityCloudRepository.isActive &&
        CommunityCloudRepository.isCloudId(userId)) {
      await CommunityCloudRepository.instance.unblock(userId);
    }
  }

  /// Check if user is blocked.
  bool isUserBlocked(String userId) {
    return LocalStorage.getBlockedUserIds().contains(userId);
  }

  /// Hide a specific post.
  Future<void> hidePost(String postId) async {
    final list = LocalStorage.getHiddenPostIds();
    if (!list.contains(postId)) {
      list.add(postId);
      await LocalStorage.saveHiddenPostIds(list);
    }
  }

  /// Check if post is hidden.
  bool isPostHidden(String postId) {
    return LocalStorage.getHiddenPostIds().contains(postId);
  }

  /// Filter out blocked user posts and hidden posts from a feed list.
  List<ActivityPost> filterModeratedPosts(List<ActivityPost> posts) {
    final blockedUsers = LocalStorage.getBlockedUserIds().toSet();
    final hiddenPosts = LocalStorage.getHiddenPostIds().toSet();

    return posts.where((post) {
      if (blockedUsers.contains(post.userId)) return false;
      if (hiddenPosts.contains(post.id)) return false;
      return true;
    }).toList();
  }
}
