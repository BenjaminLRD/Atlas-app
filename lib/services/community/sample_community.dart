import '../../data/local_storage.dart';
import '../../models/activity_post.dart';
import '../../models/athlete_profile.dart';
import '../../models/post_comment.dart';
import 'sample_media.dart';
import 'sample_world.dart';

/// Built-in sample community so a new account never sees an empty feed.
///
/// Everything here is demonstration content:
/// * every post carries [ActivityPost.isSample] and the UI labels it;
/// * sample ids are not server ids, so nothing here is ever sent to Supabase
///   (see `CommunityCloudRepository.isCloudId`);
/// * sample posts are never stored among the user's own posts
///   (`LocalStorage.saveCommunityPosts` drops them);
/// * the user's likes on sample posts live under their own storage key;
/// * the athletes, their posts, comments, likes, PRs and statistics all come
///   from `SampleWorld`, so a sample athlete named in a comment has a full
///   profile with their own posts behind it.
class SampleCommunity {
  const SampleCommunity._();

  static ActivityPostType _type(String raw) => ActivityPostType.values
      .firstWhere((t) => t.name == raw, orElse: () => ActivityPostType.workout);

  /// The sample posts, newest first, with the user's own likes applied.
  static List<ActivityPost> posts() {
    final liked = LocalStorage.getSampleLikedPostIds();
    final now = DateTime.now();
    final list = <ActivityPost>[];
    for (final s in SampleWorld.posts) {
      final author = SampleWorld.byKey(s.athlete);
      if (author == null) continue;
      final createdAt = now.subtract(Duration(hours: s.hoursAgo));
      final comments = <PostComment>[];
      for (var i = 0; i < s.comments.length; i++) {
        final c = s.comments[i];
        final who = SampleWorld.byKey(c.by);
        if (who == null) continue;
        var at = createdAt.add(Duration(minutes: c.minutesAfter));
        if (at.isAfter(now)) at = now;
        comments.add(
          PostComment(
            id: 'sc_${s.athlete}_${s.n}_$i',
            postId: s.id,
            userId: who.id,
            userName: who.name,
            userAvatar: who.avatar,
            userRank: who.rank,
            text: c.text,
            createdAt: at,
          ),
        );
      }
      final media = SampleMedia.forPost(s.id);
      final metadata = <String, dynamic>{
        ...s.meta,
        if (media?.videoAsset != null) 'videoAsset': media!.videoAsset,
        if (media?.videoLabel != null) 'videoTitle': media!.videoLabel,
        if (media != null) 'mediaCredit': media.credit,
      };
      final isLiked = liked.contains(s.id);
      final base = s.likedBy.length + s.extraLikes;
      list.add(
        ActivityPost(
          id: s.id,
          userId: author.id,
          userName: author.name,
          userAvatar: author.avatar,
          userRank: author.rank,
          type: _type(s.type),
          title: s.title,
          description: s.caption,
          images: media?.images ?? const [],
          metadata: metadata.isEmpty ? null : metadata,
          likes: isLiked ? base + 1 : base,
          commentsList: comments,
          savesCount: s.saves,
          createdAt: createdAt,
          isLiked: isLiked,
          isSample: true,
        ),
      );
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// All sample athletes.
  static List<SampleAthlete> athletes() => SampleWorld.athletes;

  /// User ids that belong to sample athletes.
  static Set<String> sampleUserIds() => {
    for (final a in SampleWorld.athletes) a.id,
  };

  static bool isSampleUser(String userId) => SampleWorld.byId(userId) != null;

  /// Names of the sample athletes who liked a sample post, for "liked by".
  static List<String> likedByNames(String postId) {
    for (final s in SampleWorld.posts) {
      if (s.id == postId) {
        return [
          for (final k in s.likedBy)
            if (SampleWorld.byKey(k) != null) SampleWorld.byKey(k)!.name,
        ];
      }
    }
    return const [];
  }

  static String _kg(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  static String _prValue(SamplePr p) {
    final e = p.exercise.toLowerCase();
    if (e.contains('(minutes)')) return '${_kg(p.kg)} min';
    if (e.contains('(seconds)')) return '${_kg(p.kg)} s';
    if (e.contains('(cm)')) return '${_kg(p.kg)} cm';
    if (e.contains('kg assist')) return '${_kg(p.kg)} kg assist x ${p.reps}';
    if (p.kg <= 0) return '${p.reps} reps';
    return '${_kg(p.kg)} kg x ${p.reps}';
  }

  /// The labelled demo profile for a sample athlete, or null for anyone else.
  static AthleteProfile? profileFor(String userId) {
    final a = SampleWorld.byId(userId);
    if (a == null) return null;
    final now = DateTime.now();
    final prs = [
      for (final p in a.prs)
        ProfilePr(
          p.exercise.replaceAll(RegExp(r' \([^)]*\)'), ''),
          _prValue(p),
          achievedAt: now.subtract(Duration(days: p.daysAgo)),
        ),
    ];
    return AthleteProfile(
      userId: a.id,
      displayName: a.name,
      username: a.username,
      avatarUrl: a.avatar,
      rankTitle: a.rank,
      bio: a.bio,
      fitness: [
        FitnessFact('Goal', a.goal),
        FitnessFact('Level', a.level),
        FitnessFact('Training style', a.style),
        FitnessFact('Schedule', a.schedule),
        if (prs.isNotEmpty)
          FitnessFact('Top PR', '${prs.first.exercise} ${prs.first.value}'),
      ],
      prs: prs,
      milestones: a.milestones,
      workoutCount: a.stats.totalWorkouts,
      streakDays: a.stats.streakDays,
      location: a.location,
      memberSince: a.memberSince,
      isSample: true,
      infoState: ProfileInfoState.demo,
    );
  }

  /// Sample posts written by one sample athlete, newest first.
  static List<ActivityPost> postsBy(String userId) =>
      posts().where((p) => p.userId == userId).toList();

  /// Records the user's like on a sample post, on this device only.
  static Future<void> setLiked(String postId, bool liked) =>
      LocalStorage.setSamplePostLiked(postId, liked);
}
