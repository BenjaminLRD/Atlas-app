import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/activity_post.dart';
import '../../models/post_comment.dart';
import '../cloud/cloud_session.dart';
import '../ranked/rank_ladder.dart';

/// Community feed, likes, comments, reports and blocks on Supabase.
///
/// Row Level Security hides blocked users' content and posts hidden by
/// moderation, so the app never filters those itself. Authors' names and
/// ranks come from `ranked_profiles`.
class CommunityCloudRepository {
  static CommunityCloudRepository? _instance;
  static CommunityCloudRepository get instance =>
      _instance ??= CommunityCloudRepository();
  static void setInstance(CommunityCloudRepository repo) => _instance = repo;

  /// True when the feed should come from the server.
  static bool get isActive =>
      CloudSession.isConfigured && CloudSession.userId != null;

  /// Most posts one profile page loads from the server. A profile that
  /// receives this many may have more.
  static const int profilePostLimit = 30;

  /// Server posts and comments have UUID ids; local ones do not.
  static bool isCloudId(String id) =>
      RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-').hasMatch(id);

  SupabaseClient get _client {
    final client = CloudSession.client;
    if (client == null) throw StateError('Community needs an account.');
    return client;
  }

  String get _uid => CloudSession.userId!;

  Future<Map<String, ({String name, String rank})>> _authors(
    Iterable<String> userIds,
  ) async {
    final ids = userIds.toSet().toList();
    if (ids.isEmpty) return const {};
    final rows = await _client
        .from('ranked_profiles')
        .select('user_id, display_name, points')
        .inFilter('user_id', ids);
    return {
      for (final r in rows)
        r['user_id'] as String: (
          name: (r['display_name'] as String?)?.isNotEmpty == true
              ? r['display_name'] as String
              : 'Athlete',
          rank: RankLadder.fromPoints(
            (r['points'] as num?)?.toInt() ?? 0,
          ).title,
        ),
    };
  }

  static ActivityPostType _type(String raw) => ActivityPostType.values
      .firstWhere((t) => t.name == raw, orElse: () => ActivityPostType.workout);

  /// Newest posts the viewer is allowed to see.
  Future<List<ActivityPost>> fetchFeed({int limit = 30}) async {
    final rows = await _client
        .from('community_posts')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return _hydrate(rows);
  }

  /// Posts by one member that the viewer is allowed to see.
  Future<List<ActivityPost>> fetchUserPosts(
    String userId, {
    int limit = profilePostLimit,
  }) async {
    final rows = await _client
        .from('community_posts')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return _hydrate(rows);
  }

  /// Public name and rank of a member, or null when they have no profile row.
  Future<({String name, String rank})?> fetchMember(String userId) async =>
      (await _authors([userId]))[userId];

  Future<List<ActivityPost>> _hydrate(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return const [];
    final authors = await _authors(rows.map((r) => r['user_id'] as String));
    final likedRows = await _client
        .from('community_likes')
        .select('post_id')
        .eq('user_id', _uid)
        .inFilter('post_id', rows.map((r) => r['id']).toList());
    final liked = likedRows.map((r) => r['post_id'] as String).toSet();

    return [
      for (final r in rows)
        ActivityPost(
          id: r['id'] as String,
          userId: r['user_id'] as String,
          userName: authors[r['user_id']]?.name ?? 'Athlete',
          userRank: authors[r['user_id']]?.rank ?? 'Unranked',
          type: _type(r['type'] as String),
          title: r['title'] as String? ?? '',
          description: r['description'] as String? ?? '',
          images: List<String>.from(r['images'] as List? ?? const []),
          metadata: Map<String, dynamic>.from(r['metadata'] as Map? ?? {}),
          likes: (r['likes_count'] as num?)?.toInt() ?? 0,
          comments: (r['comments_count'] as num?)?.toInt() ?? 0,
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
          isLiked: liked.contains(r['id']),
        ),
    ];
  }

  /// Publishes [draft] as the signed-in user, uploading [photo] if given.
  Future<ActivityPost> createPost(ActivityPost draft, {File? photo}) async {
    final images = <String>[];
    if (photo != null) {
      final ext = photo.path.split('.').last.toLowerCase();
      final path = '$_uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _client.storage.from('community-photos').upload(path, photo);
      images.add(_client.storage.from('community-photos').getPublicUrl(path));
    }
    final row = await _client
        .from('community_posts')
        .insert({
          'user_id': _uid,
          'type': draft.type.name,
          'title': draft.title,
          'description': draft.description,
          'images': images,
          'metadata': draft.metadata ?? const {},
        })
        .select()
        .single();
    final author = (await _authors([_uid]))[_uid];
    return draft.copyWith(
      id: row['id'] as String,
      userId: _uid,
      userName: author?.name ?? draft.userName,
      userRank: author?.rank ?? draft.userRank,
      images: images,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      likes: 0,
      isLiked: false,
    );
  }

  Future<void> setLiked(String postId, bool liked) async {
    if (liked) {
      await _client.from('community_likes').upsert({
        'post_id': postId,
        'user_id': _uid,
      }, onConflict: 'post_id,user_id');
    } else {
      await _client.from('community_likes').delete().match({
        'post_id': postId,
        'user_id': _uid,
      });
    }
  }

  Future<List<PostComment>> fetchComments(String postId) async {
    final rows = await _client
        .from('community_comments')
        .select()
        .eq('post_id', postId)
        .order('created_at');
    final authors = await _authors(rows.map((r) => r['user_id'] as String));
    return [
      for (final r in rows)
        PostComment(
          id: r['id'] as String,
          postId: postId,
          userId: r['user_id'] as String,
          userName: authors[r['user_id']]?.name ?? 'Athlete',
          userRank: authors[r['user_id']]?.rank ?? 'Unranked',
          text: r['body'] as String,
          createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        ),
    ];
  }

  Future<PostComment> addComment(String postId, String body) async {
    final row = await _client
        .from('community_comments')
        .insert({'post_id': postId, 'user_id': _uid, 'body': body})
        .select()
        .single();
    final author = (await _authors([_uid]))[_uid];
    return PostComment(
      id: row['id'] as String,
      postId: postId,
      userId: _uid,
      userName: author?.name ?? 'You',
      userRank: author?.rank ?? 'Unranked',
      text: body,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  /// Reports a post or comment. Repeat reports by the same person are
  /// ignored by the database.
  Future<void> report({
    String? postId,
    String? commentId,
    required String reason,
  }) async {
    try {
      await _client.from('content_reports').insert({
        'reporter_id': _uid,
        'post_id': postId,
        'comment_id': commentId,
        'reason': reason,
      });
    } on PostgrestException catch (e) {
      if (e.code != '23505') rethrow; // already reported
    }
  }

  Future<void> block(String userId) => _client.from('user_blocks').upsert({
    'blocker_id': _uid,
    'blocked_id': userId,
  }, onConflict: 'blocker_id,blocked_id');

  Future<void> unblock(String userId) => _client
      .from('user_blocks')
      .delete()
      .match({'blocker_id': _uid, 'blocked_id': userId});

  Future<void> deletePost(String postId) =>
      _client.from('community_posts').delete().eq('id', postId);
}
