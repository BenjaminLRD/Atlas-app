import '../../data/local_storage.dart';
import '../../models/activity_post.dart';
import '../../models/cardio_activity_data.dart';
import '../../models/cardio_route.dart';
import '../../providers/fitness_provider.dart';
import '../cardio/route_privacy.dart';
import 'community_cloud_repository.dart';

/// Turns a saved run or ride into a Community post.
///
/// The post is built only from the privacy-adjusted route: the athlete's own
/// saved route is never changed and the unmasked points never enter the post
/// metadata, which every signed-in member can read.
class CardioPostPublisher {
  const CardioPostPublisher._();

  /// Largest number of route points sent with a post.
  static const int maxRoutePoints = 120;

  /// Sharing is off in Showcase Mode: nothing the demo does is posted.
  static bool get canShare => !LocalStorage.isShowcaseModeEnabled();

  /// What others would see of [data]'s route under [mode].
  static MaskedRoute maskedRoute(
    CardioActivityData data,
    RoutePrivacyMode mode,
  ) => RoutePrivacy.apply(
    data.route,
    mode,
    seed: data.date.millisecondsSinceEpoch,
  );

  /// The post for [data]. Pure, so it can be tested without a backend.
  static ActivityPost buildDraft(
    CardioActivityData data, {
    required String caption,
    RoutePrivacyMode privacy = RoutePrivacyMode.hide200,
    String userId = 'usr_local',
    String userName = 'You',
    String? userAvatar,
    String userRank = 'Athlete',
    DateTime? now,
  }) {
    final masked = maskedRoute(data, privacy);
    final shared = Geo.downsample(masked.route, maxRoutePoints);
    final km = data.distanceKm;
    final title = km == null
        ? data.title
        : '${data.title} · ${km.toStringAsFixed(2)} km';
    return ActivityPost(
      id: 'post_${(now ?? DateTime.now()).millisecondsSinceEpoch}',
      userId: userId,
      userName: userName,
      userAvatar: userAvatar,
      userRank: userRank,
      type: ActivityPostType.cardio,
      title: title,
      description: caption.trim(),
      metadata: data.toPostMetadata(
        routeOverride: shared,
        routeMasked: masked.masked && masked.hasRoute,
        routeShared: masked.hasRoute || data.route.length < 2,
      ),
      createdAt: now ?? DateTime.now(),
    );
  }

  /// Publishes the activity as the signed-in athlete, or keeps it on this
  /// device when there is no account. Returns the published post.
  static Future<ActivityPost> publish(
    CardioActivityData data, {
    required String caption,
    RoutePrivacyMode privacy = RoutePrivacyMode.hide200,
  }) async {
    if (!canShare) {
      throw StateError('Sharing is off in Showcase Mode.');
    }
    final profile = LocalStorage.getUserProfile();
    final provider = FitnessProvider.instance;
    final draft = buildDraft(
      data,
      caption: caption,
      privacy: privacy,
      userId: provider.currentUser?.id ?? 'usr_local',
      userName: profile.name.isNotEmpty ? profile.name : 'You',
      userAvatar: profile.profilePic.isNotEmpty ? profile.profilePic : null,
      userRank: provider.fullRank,
    );
    if (CommunityCloudRepository.isActive) {
      return CommunityCloudRepository.instance.createPost(draft);
    }
    await LocalStorage.addCommunityPost(draft);
    return draft;
  }
}
