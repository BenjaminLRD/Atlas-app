import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../data/local_storage.dart';
import '../../data/profile_provider.dart';
import '../common/app_image.dart';
import '../profile_picture.dart';

/// Helper utility providing deterministic, realistic fitness profile avatars
/// for community users, leaderboard athletes, and challenge participants.
class CommunityAvatarHelper {
  static const List<String> defaultAvatars = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80', // Alex Carter
    'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=200&auto=format&fit=crop&q=80', // Maya Chen
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80', // Daniel Kim
    'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=200&auto=format&fit=crop&q=80', // Sophia Martinez
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&auto=format&fit=crop&q=80', // Liam O'Connor
    'https://images.unsplash.com/photo-1568602471122-7832951cc4c5?w=200&auto=format&fit=crop&q=80', // David R.
    'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200&auto=format&fit=crop&q=80', // Elena V.
    'https://images.unsplash.com/photo-1522075469751-3a6694fb2f61?w=200&auto=format&fit=crop&q=80', // Marcus K.
    'https://images.unsplash.com/photo-1567013127542-490d757e51fc?w=200&auto=format&fit=crop&q=80', // Coach Zuala
    'https://images.unsplash.com/photo-1548690312-e3b507d8c110?w=200&auto=format&fit=crop&q=80', // Jenny Ralte
  ];

  /// Mapping of known usernames / IDs to dedicated avatar URLs
  static final Map<String, String> _knownUserAvatars = {
    'usr_alex': defaultAvatars[0],
    'alex carter': defaultAvatars[0],
    'alex_carter': defaultAvatars[0],
    'usr_maya': defaultAvatars[1],
    'maya chen': defaultAvatars[1],
    'maya_chen': defaultAvatars[1],
    'usr_daniel': defaultAvatars[2],
    'daniel kim': defaultAvatars[2],
    'daniel_kim': defaultAvatars[2],
    'usr_sophia': defaultAvatars[3],
    'sophia martinez': defaultAvatars[3],
    'sophia_martinez': defaultAvatars[3],
    'usr_liam': defaultAvatars[4],
    'liam o\'connor': defaultAvatars[4],
    'liam o’connor': defaultAvatars[4],
    'liam_fitness': defaultAvatars[4],
    'creator_zuala': defaultAvatars[8],
    'coach zuala': defaultAvatars[8],
    'creator_jenny': defaultAvatars[9],
    'jenny ralte': defaultAvatars[9],
    'usr_local': defaultAvatars[5],
    'alex lalremruata': defaultAvatars[5],
    'alex rivera': defaultAvatars[5],
    'you': defaultAvatars[5],
  };

  /// User ids that mean "the person using the app" in Showcase Mode data.
  static const Set<String> _showcaseSelfIds = {
    'usr_local',
    'usr_showcase_athlete',
  };

  /// True when [userId] is the current user AND Showcase Mode is on. Other
  /// community users never match, so they keep their simulated identity.
  static bool isShowcaseSelf(String? userId) =>
      userId != null &&
      LocalStorage.isShowcaseModeEnabled() &&
      _showcaseSelfIds.contains(userId);

  /// The name to show for a community user: `YOU` for the current user in
  /// Showcase Mode, otherwise [name] unchanged.
  static String displayNameFor(String? userId, String name) =>
      isShowcaseSelf(userId) ? ProfileProvider.showcaseSelfLabel : name;

  /// Returns a clean avatar URL for the given user, falling back to a deterministic avatar.
  static String getAvatarForUser({
    String? userId,
    String? userName,
    String? currentAvatar,
  }) {
    if (currentAvatar != null && currentAvatar.trim().isNotEmpty) {
      return currentAvatar.trim();
    }
    if (userId != null && _knownUserAvatars.containsKey(userId.toLowerCase())) {
      return _knownUserAvatars[userId.toLowerCase()]!;
    }
    if (userName != null &&
        _knownUserAvatars.containsKey(userName.toLowerCase())) {
      return _knownUserAvatars[userName.toLowerCase()]!;
    }
    final key = userId ?? userName ?? 'athlete';
    final hash = key.codeUnits.fold(0, (prev, elem) => prev + elem);
    return defaultAvatars[hash.abs() % defaultAvatars.length];
  }

  /// Builds a consistent, circular avatar widget with subtle border and fallback.
  static Widget buildAvatar({
    String? userId,
    String? userName,
    String? avatarUrl,
    double radius = 20.0,
    Color? borderColor,
    double borderWidth = 1.5,
  }) {
    if (isShowcaseSelf(userId)) {
      // Generic avatar for the current user in Showcase Mode.
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? AppColors.primary.withValues(alpha: 0.3),
            width: borderWidth,
          ),
        ),
        child: ProfileImage(
          path: null,
          size: radius * 2 - borderWidth * 2,
          iconSize: radius,
        ),
      );
    }
    final effectiveUrl = getAvatarForUser(
      userId: userId,
      userName: userName,
      currentAvatar: avatarUrl,
    );

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor ?? AppColors.primary.withValues(alpha: 0.3),
          width: borderWidth,
        ),
      ),
      child: AppImage.avatar(
        imageUrl: effectiveUrl,
        radius: radius,
        name: userName ?? 'Athlete',
      ),
    );
  }
}
