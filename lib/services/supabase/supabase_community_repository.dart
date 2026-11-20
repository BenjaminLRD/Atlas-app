import '../../data/local_storage.dart';
import '../../models/activity_post.dart';
import 'database_models.dart';
import 'supabase_client.dart';

/// Cloud-first, local-fallback repository for community posts, reactions, and feed.
class SupabaseCommunityRepository {
  final SupabaseClientManager _clientManager;

  SupabaseCommunityRepository({SupabaseClientManager? clientManager})
    : _clientManager = clientManager ?? SupabaseClientManager.instance;

  /// Retrieves community feed: tries Supabase first, falls back to local feed cache.
  Future<List<ActivityPost>> getCommunityFeed() async {
    try {
      final rows = await _clientManager
          .from(SupabaseTableNames.communityPosts)
          .select();

      if (rows.isNotEmpty) {
        final list = rows.map((r) {
          final typeName = r['post_type'] as String? ?? 'workout';
          final type = ActivityPostType.values.firstWhere(
            (t) => t.name == typeName,
            orElse: () => ActivityPostType.workout,
          );
          return ActivityPost(
            id: r['id'] as String,
            userId: r['user_id'] as String,
            userName: r['author_name'] as String? ?? 'Athlete',
            userAvatar: r['author_avatar'] as String?,
            userRank: r['author_rank'] as String? ?? 'Athlete',
            type: type,
            title: r['caption'] as String? ?? '',
            description: r['caption'] as String? ?? '',
            images: r['media_url'] != null ? [r['media_url'] as String] : [],
            metadata: (r['metrics_payload'] as Map?) != null
                ? Map<String, dynamic>.from(r['metrics_payload'] as Map)
                : null,
            likes: (r['likes_count'] as num?)?.toInt() ?? 0,
            comments: (r['comments_count'] as num?)?.toInt() ?? 0,
            createdAt: r['created_at'] != null
                ? DateTime.parse(r['created_at'] as String)
                : DateTime.now(),
          );
        }).toList();

        // Sort descending by creation date
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        await LocalStorage.saveCommunityPosts(list);
        return list;
      }
    } catch (_) {
      // Offline fallback
    }
    return LocalStorage.getCommunityPosts();
  }

  /// Creates new community post: saves to local feed, then uploads to Supabase.
  Future<void> createPost(ActivityPost post) async {
    // 1. Local Cache
    final current = LocalStorage.getCommunityPosts();
    current.insert(0, post);
    await LocalStorage.saveCommunityPosts(current);

    // 2. Cloud Sync
    final payload = SupabaseModelMappers.activityPostToTable(post);
    await _clientManager
        .from(SupabaseTableNames.communityPosts)
        .insert(payload);
  }
}
