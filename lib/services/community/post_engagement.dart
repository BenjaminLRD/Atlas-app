import '../../data/local_storage.dart';
import '../../models/activity_post.dart';
import '../../models/post_comment.dart';
import '../../providers/fitness_provider.dart';
import 'community_cloud_repository.dart';
import 'sample_community.dart';

/// Likes and comments for one post, shared by the feed card and the post page
/// so both keep sample and real content apart.
///
/// * Sample posts: kept on this device under their own keys, never sent to
///   the server and never written into the user's own posts.
/// * Server posts (signed in, UUID id): stored on Supabase under the user's
///   own account.
/// * The user's own local posts: stored on this device.
class PostEngagement {
  const PostEngagement._();

  static bool isCloudPost(ActivityPost post) =>
      !post.isSample &&
      CommunityCloudRepository.isActive &&
      CommunityCloudRepository.isCloudId(post.id);

  /// Comments known on this device: the post's own list plus any the user
  /// added locally.
  static List<PostComment> localComments(ActivityPost post) {
    final stored = LocalStorage.getCommentsForPost(post.id);
    if (stored.isEmpty) return List<PostComment>.from(post.commentsList);
    final seen = <String>{};
    return [
      for (final c in [...post.commentsList, ...stored])
        if (seen.add(c.id)) c,
    ];
  }

  static Future<List<PostComment>> cloudComments(ActivityPost post) =>
      CommunityCloudRepository.instance.fetchComments(post.id);

  /// Saves the like state carried by [updated]. For server posts this throws
  /// when the request fails so the caller can undo the change.
  static Future<void> persistLike(ActivityPost updated) async {
    if (updated.isSample) {
      await SampleCommunity.setLiked(updated.id, updated.isLiked);
    } else if (isCloudPost(updated)) {
      await CommunityCloudRepository.instance.setLiked(
        updated.id,
        updated.isLiked,
      );
    } else {
      await LocalStorage.updateCommunityPost(updated);
    }
  }

  /// Adds the user's comment. Throws for a server post that could not be
  /// saved.
  static Future<PostComment> addComment(ActivityPost post, String text) async {
    if (isCloudPost(post)) {
      return CommunityCloudRepository.instance.addComment(post.id, text);
    }
    final profile = LocalStorage.getUserProfile();
    final comment = PostComment(
      id: 'comm_${DateTime.now().microsecondsSinceEpoch}',
      postId: post.id,
      userId: FitnessProvider.instance.currentUser?.id ?? 'usr_local',
      userName: profile.name.isNotEmpty ? profile.name : 'You',
      userAvatar:
          profile.profilePic.isNotEmpty && !LocalStorage.isShowcaseModeEnabled()
          ? profile.profilePic
          : null,
      userRank: FitnessProvider.instance.fullRank,
      text: text,
      createdAt: DateTime.now(),
    );
    await LocalStorage.addCommentToPost(post.id, comment);
    return comment;
  }
}
