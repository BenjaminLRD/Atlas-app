import '../data/local_storage.dart';
import '../models/activity_item.dart';
import '../models/friendship.dart';
import '../models/activity_post.dart';
import '../models/leaderboard_entry.dart';
import 'community/sample_community.dart';
import 'community/sample_world.dart';
import 'supabase/supabase_client.dart';

/// Central service managing social friendships, pending request approvals,
/// and community activity feed creation & retrieval.
class SocialService {
  static SocialService? _instance;
  final SupabaseClientManager _clientManager;

  List<Friendship>? _cachedFriendships;
  List<ActivityItem>? _cachedActivityFeed;

  SocialService({SupabaseClientManager? clientManager})
    : _clientManager = clientManager ?? SupabaseClientManager.instance;

  /// Reset singleton instance (useful for testing)
  static void resetInstance() {
    _instance = null;
  }

  /// Singleton instance getter
  static SocialService get instance {
    _instance ??= SocialService();
    return _instance!;
  }

  /// Default activity: the latest sample post of each default friend, so the
  /// feed agrees with profiles and rankings. Sample content only; nothing here
  /// is a real member's activity.
  static List<ActivityItem> _getDefaultActivityFeed() {
    final posts = SampleCommunity.posts();
    final items = <ActivityItem>[];
    for (final id in const ['usr_alex', 'usr_maya', 'usr_daniel']) {
      final post = posts.where((p) => p.userId == id).firstOrNull;
      if (post == null) continue;
      final caption = post.description.split(RegExp(r'(?<=[.!?])\s')).first;
      items.add(
        ActivityItem(
          id: 'act_${post.id}',
          userId: id,
          type: post.type == ActivityPostType.achievement
              ? 'achievement'
              : 'workout',
          title: '${post.userName} posted: ${post.title}',
          description: caption.length > 90
              ? '${caption.substring(0, 87)}...'
              : caption,
          createdAt: post.createdAt,
        ),
      );
    }
    items.sort((x, y) => y.createdAt.compareTo(x.createdAt));
    return items;
  }

  static List<Friendship> _getDefaultFriendships() {
    final now = DateTime.now();
    return [
      Friendship(
        id: 'fs_1',
        requesterId: 'usr_alex',
        receiverId: 'usr_local',
        status: 'accepted',
        createdAt: now.subtract(const Duration(days: 10)),
      ),
      Friendship(
        id: 'fs_2',
        requesterId: 'usr_maya',
        receiverId: 'usr_local',
        status: 'accepted',
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      Friendship(
        id: 'fs_3',
        requesterId: 'usr_daniel',
        receiverId: 'usr_local',
        status: 'pending',
        createdAt: now.subtract(const Duration(hours: 4)),
      ),
    ];
  }

  /// Retrieve activity feed items sorted by creation date descending.
  Future<List<ActivityItem>> getActivityFeed({int limit = 50}) async {
    if (_cachedActivityFeed != null && _cachedActivityFeed!.isNotEmpty) {
      return List.unmodifiable(_cachedActivityFeed!);
    }

    try {
      final query = _clientManager.from('activity_feed');
      final rows = await query.select();
      if (rows.isNotEmpty) {
        final list = rows.map((r) => ActivityItem.fromJson(r)).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _cachedActivityFeed = list;
        return List.unmodifiable(list.take(limit).toList());
      }
    } catch (_) {}

    final defaults = _getDefaultActivityFeed();
    _cachedActivityFeed = List.from(defaults);
    return List.unmodifiable(defaults.take(limit).toList());
  }

  /// Create a new activity feed item.
  Future<void> createActivity(ActivityItem activity) async {
    final list = List<ActivityItem>.from(await getActivityFeed());
    list.insert(0, activity);
    _cachedActivityFeed = list;

    try {
      await _clientManager.from('activity_feed').insert(activity.toJson());
    } catch (_) {}
  }

  /// Toggle reaction on an activity feed item
  Future<void> toggleReaction(String activityId, String reactionKey) async {
    final list = List<ActivityItem>.from(await getActivityFeed());
    final index = list.indexWhere((a) => a.id == activityId);
    if (index != -1) {
      final current = list[index];
      final currentReactions = Map<String, int>.from(current.reactions);

      final isSameReaction = current.userReaction == reactionKey;
      if (isSameReaction) {
        currentReactions[reactionKey] =
            (currentReactions[reactionKey] ?? 1) - 1;
        list[index] = current.copyWith(
          reactions: currentReactions,
          userReaction: null,
        );
      } else {
        if (current.userReaction != null) {
          final old = current.userReaction!;
          currentReactions[old] = (currentReactions[old] ?? 1) - 1;
        }
        currentReactions[reactionKey] =
            (currentReactions[reactionKey] ?? 0) + 1;
        list[index] = current.copyWith(
          reactions: currentReactions,
          userReaction: reactionKey,
        );
      }
      _cachedActivityFeed = list;
    }
  }

  /// Add a comment count increment to an activity feed item
  Future<void> addComment(String activityId) async {
    final list = List<ActivityItem>.from(await getActivityFeed());
    final index = list.indexWhere((a) => a.id == activityId);
    if (index != -1) {
      list[index] = list[index].copyWith(
        commentsCount: list[index].commentsCount + 1,
      );
      _cachedActivityFeed = list;
    }
  }

  /// Get friendship records involving a user.
  Future<List<Friendship>> _getAllFriendships({
    String userId = 'usr_local',
  }) async {
    if (_cachedFriendships != null) {
      return List.unmodifiable(_cachedFriendships!);
    }

    try {
      final query = _clientManager.from('friendships');
      final rows = await query.select();
      if (rows.isNotEmpty) {
        final list = rows.map((r) => Friendship.fromJson(r)).toList();
        _cachedFriendships = list;
        return List.unmodifiable(list);
      }
    } catch (_) {}

    final defaults = _getDefaultFriendships();
    _cachedFriendships = List.from(defaults);
    return List.unmodifiable(defaults);
  }

  /// Get pending incoming friend requests for a user.
  Future<List<Friendship>> getPendingRequests({
    String userId = 'usr_local',
  }) async {
    final all = await _getAllFriendships(userId: userId);
    return all.where((f) => f.receiverId == userId && f.isPending).toList();
  }

  /// Get accepted friend profiles/entries.
  Future<List<LeaderboardEntry>> getFriends({
    String userId = 'usr_local',
  }) async {
    final all = await _getAllFriendships(userId: userId);
    final accepted = all
        .where(
          (f) =>
              f.isAccepted &&
              (f.requesterId == userId || f.receiverId == userId),
        )
        .toList();

    // Map friend IDs to sample profiles
    final friendIds = accepted
        .map((f) => f.requesterId == userId ? f.receiverId : f.requesterId)
        .toSet();

    // Friends are sample athletes from the shared sample world, so their
    // name, photo and rank agree with their profiles. Sample athletes have no
    // XP, so the XP field is 0 and is never displayed for them.
    final result = <LeaderboardEntry>[];
    for (final id in friendIds) {
      final a = SampleWorld.byId(id);
      if (a == null) continue;
      result.add(
        LeaderboardEntry(
          id: 'fs_entry_${a.key}',
          userId: a.id,
          displayName: a.name,
          avatarUrl: a.avatar,
          totalXP: 0,
          rankTitle: a.rank,
          division: '',
          country: '',
          updatedAt: DateTime.now(),
        ),
      );
    }
    return result;
  }

  /// Send a new friend request.
  Future<Friendship> sendFriendRequest({
    required String requesterId,
    required String receiverId,
  }) async {
    final friendships = List<Friendship>.from(
      await _getAllFriendships(userId: requesterId),
    );
    final newFriendship = Friendship(
      id: 'fs_${DateTime.now().millisecondsSinceEpoch}',
      requesterId: requesterId,
      receiverId: receiverId,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    friendships.add(newFriendship);
    _cachedFriendships = friendships;

    try {
      await _clientManager.from('friendships').insert(newFriendship.toJson());
    } catch (_) {}

    return newFriendship;
  }

  /// Accept an incoming friend request.
  Future<void> acceptFriendRequest({
    required String friendshipId,
    required String userId,
  }) async {
    final friendships = List<Friendship>.from(
      await _getAllFriendships(userId: userId),
    );
    final idx = friendships.indexWhere(
      (f) => f.id == friendshipId || f.requesterId == friendshipId,
    );
    if (idx != -1) {
      friendships[idx] = friendships[idx].copyWith(
        status: 'accepted',
        updatedAt: DateTime.now(),
      );
      _cachedFriendships = friendships;

      try {
        await _clientManager
            .from('friendships')
            .update(
              {
                'status': 'accepted',
                'updated_at': DateTime.now().toIso8601String(),
              },
              'id',
              friendships[idx].id,
            );
      } catch (_) {}
    }
  }

  /// Remove or decline a friend.
  Future<void> removeFriend({
    required String friendshipId,
    required String userId,
  }) async {
    final friendships = List<Friendship>.from(
      await _getAllFriendships(userId: userId),
    );
    friendships.removeWhere(
      (f) =>
          f.id == friendshipId ||
          f.requesterId == friendshipId ||
          f.receiverId == friendshipId,
    );
    _cachedFriendships = friendships;

    try {
      await _clientManager.from('friendships').delete('id', friendshipId);
    } catch (_) {}
  }

  /// Block a user and remove any active friendship.
  Future<void> blockUser({
    required String currentUserId,
    required String targetUserId,
  }) async {
    final blocked = LocalStorage.getBlockedUserIds();
    if (!blocked.contains(targetUserId)) {
      blocked.add(targetUserId);
      await LocalStorage.saveBlockedUserIds(blocked);
    }
    await removeFriend(friendshipId: targetUserId, userId: currentUserId);
  }

  /// Check whether a user is blocked.
  bool isUserBlocked(String userId) {
    return LocalStorage.getBlockedUserIds().contains(userId);
  }
}
