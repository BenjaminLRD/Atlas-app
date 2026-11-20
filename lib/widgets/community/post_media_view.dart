import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../models/activity_post.dart';
import '../../screens/video_player_screen.dart';
import '../../services/community/post_media.dart';
import '../common/app_image.dart';

/// A post picture that understands bundled assets as well as web addresses.
class PostImage extends StatelessWidget {
  final String source;
  final double borderRadius;
  final BoxFit fit;
  final double? width;
  final double? height;

  const PostImage(
    this.source, {
    super.key,
    this.borderRadius = 12,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (source.startsWith('assets/')) {
      return AppImage(
        assetPath: source,
        fit: fit,
        borderRadius: borderRadius,
        width: width,
        height: height,
        fallbackIcon: Icons.image_not_supported_outlined,
      );
    }
    return AppImage(
      imageUrl: source,
      fit: fit,
      borderRadius: borderRadius,
      width: width,
      height: height,
      fallbackIcon: Icons.image_not_supported_outlined,
    );
  }
}

/// Opens the full-screen player for a video post.
Future<void> openPostVideo(BuildContext context, ActivityPost post) {
  final src = PostMedia.videoSource(post);
  if (src == null) return Future.value();
  return VideoPlayerScreen.open(
    context,
    location: src,
    title: PostMedia.title(post),
    credit: PostMedia.credit(post),
  );
}

/// The round play button drawn over a video's poster. Tapping the poster (or
/// the button) plays the video.
class VideoPlayBadge extends StatelessWidget {
  final double size;
  const VideoPlayBadge({super.key, this.size = 52});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.65),
        border: Border.all(color: AppColors.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: size * 0.65,
      ),
    );
  }
}
