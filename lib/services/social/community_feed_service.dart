import '../../models/activity_post.dart';

/// Central Community Feed service managing multi-format posts, physical transformation journeys,
/// like engagements, and athlete conversations.
class CommunityFeedService {
  static CommunityFeedService? _instance;
  static CommunityFeedService get instance => _instance ??= CommunityFeedService();

  final List<ActivityPost> _posts = [
    ActivityPost(
      id: 'post_trans_1',
      userId: 'usr_alex',
      userName: 'Alex Carter',
      userAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      userRank: 'Legend 🔥',
      type: ActivityPostType.transformation,
      title: '12-Week Lean Bulk Journey',
      description: 'Consistent 5-day progressive overload split combined with high-protein clean nutrition. Gained 4.5kg while adding 22.5kg to my Bench Press!',
      images: const ['https://images.unsplash.com/photo-1574680096145-d05b474e2155?w=600'],
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      likes: 48,
      comments: 12,
      savesCount: 15,
      isLiked: false,
    ),
    ActivityPost(
      id: 'post_w_1',
      userId: 'usr_maya',
      userName: 'Maya Chen',
      userAvatar: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=150',
      userRank: 'Elite 👑',
      type: ActivityPostType.workout,
      title: 'Heavy Lower Body Hypertrophy',
      description: 'Crushed 6 exercises • 12,400 kg total volume. Squats felt explosive with low fatigue indicators.',
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      likes: 31,
      comments: 4,
      savesCount: 6,
      isLiked: true,
    ),
    ActivityPost(
      id: 'post_ach_1',
      userId: 'usr_daniel',
      userName: 'Daniel Kim',
      userAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
      userRank: 'Elite 👑',
      type: ActivityPostType.achievement,
      title: 'Unlocked: Century Club 🏆',
      description: 'Completed 100 structured training sessions on Atlas with an average form technique score of 91%!',
      createdAt: DateTime.now().subtract(const Duration(hours: 14)),
      likes: 56,
      comments: 9,
      savesCount: 8,
      isLiked: false,
    ),
  ];

  /// Retrieve current community feed.
  List<ActivityPost> getPosts() {
    return List.unmodifiable(_posts);
  }

  /// Create and share a physical transformation journey post.
  ActivityPost createTransformationPost({
    required String userId,
    required String userName,
    required String userAvatar,
    required String userRank,
    required String title,
    required String caption,
    required double beforeWeight,
    required double afterWeight,
    required String timeSpan,
    Map<String, double> strengthGains = const {},
    String? mediaUrl,
  }) {
    final weightDelta = afterWeight - beforeWeight;
    final deltaSign = weightDelta >= 0 ? '+' : '';
    final fullCaption = '$caption\n\n• Weight Change: $deltaSign${weightDelta.toStringAsFixed(1)} kg ($timeSpan)';

    final newPost = ActivityPost(
      id: 'post_trans_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      userRank: userRank,
      type: ActivityPostType.transformation,
      title: title,
      description: fullCaption,
      images: mediaUrl != null ? [mediaUrl] : const [],
      createdAt: DateTime.now(),
      likes: 0,
      comments: 0,
      savesCount: 0,
      isLiked: false,
    );

    _posts.insert(0, newPost);
    return newPost;
  }

  /// Toggles like state on a post and adjusts like count.
  ActivityPost? toggleLike(String postId) {
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return null;

    final current = _posts[idx];
    final isLikedNow = !current.isLiked;
    final newLikes = isLikedNow ? current.likes + 1 : (current.likes > 0 ? current.likes - 1 : 0);

    final updated = current.copyWith(
      isLiked: isLikedNow,
      likes: newLikes,
    );
    _posts[idx] = updated;
    return updated;
  }

  /// Adds a comment to a post and increments comment count.
  ActivityPost? addComment(String postId, String commentText) {
    final idx = _posts.indexWhere((p) => p.id == postId);
    if (idx == -1) return null;

    final current = _posts[idx];
    final updated = current.copyWith(
      comments: current.comments + 1,
    );
    _posts[idx] = updated;
    return updated;
  }
}
