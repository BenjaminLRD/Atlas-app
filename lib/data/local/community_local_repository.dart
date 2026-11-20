import '../../models/activity_post.dart';
import '../local_storage.dart';

/// Production offline-first local repository for community posts, reactions, and feed caching.
class CommunityLocalRepository {
  List<ActivityPost> getCommunityFeed() {
    return LocalStorage.getCommunityPosts();
  }

  Future<void> saveCommunityPosts(List<ActivityPost> posts) async {
    await LocalStorage.saveCommunityPosts(posts);
  }

  Future<void> createPost(
    ActivityPost post, {
    String userId = 'usr_local_01',
  }) async {
    final current = LocalStorage.getCommunityPosts();
    current.insert(0, post);
    await LocalStorage.saveCommunityPosts(current);
  }
}
