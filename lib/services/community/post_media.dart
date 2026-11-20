import '../../models/activity_post.dart';

/// Reads the media of a post: whether it is a video, where it plays from, its
/// poster image and its credit. One place, so the feed, the post page and
/// profile grids all agree and none shows a play button that leads nowhere.
class PostMedia {
  const PostMedia._();

  static bool _isLocalPath(String s) =>
      s.isNotEmpty && !s.startsWith('http') && !s.startsWith('assets/');

  /// Where the video plays from, or null when the post has no playable video:
  /// a bundled asset or web address in the post's metadata, or the local file
  /// a member attached to their own post.
  static String? videoSource(ActivityPost p) {
    final m = p.metadata;
    for (final key in const ['videoAsset', 'videoUrl']) {
      final v = m?[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    if (m?['isVideo'] == true && p.images.isNotEmpty) {
      final first = p.images.first;
      if (_isLocalPath(first)) return first;
    }
    return null;
  }

  static bool isVideo(ActivityPost p) => videoSource(p) != null;

  /// The picture to show before playing, or null when there is none (a video
  /// a member attached has no poster).
  static String? poster(ActivityPost p) {
    if (p.images.isEmpty) return null;
    final first = p.images.first;
    final src = videoSource(p);
    if (src != null && src == first) return null; // the video file itself
    return first;
  }

  static String title(ActivityPost p) {
    final t = p.metadata?['videoTitle'];
    return t is String && t.isNotEmpty ? t : p.title;
  }

  static String? credit(ActivityPost p) {
    final c = p.metadata?['mediaCredit'];
    return c is String && c.isNotEmpty ? c : null;
  }
}
