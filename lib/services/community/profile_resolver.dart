import '../../data/local_storage.dart';
import '../../data/profile_provider.dart';
import '../../models/activity_post.dart';
import '../../models/athlete_profile.dart';
import '../../providers/fitness_provider.dart';
import '../../widgets/community/community_avatar_helper.dart';
import '../cloud/cloud_session.dart';
import 'community_cloud_repository.dart';
import 'sample_community.dart';

/// The profile could not be loaded (for example no connection). Retrying may
/// work, so callers should offer a retry rather than show an empty page.
class ProfileLoadFailure implements Exception {
  const ProfileLoadFailure();
}

/// No account is known for the tapped name or avatar.
class ProfileNotFound implements Exception {
  const ProfileNotFound();
}

/// Builds a profile only from what is actually known about the athlete.
///
/// * Sample athletes: labelled demo content.
/// * The signed-in user: what they entered in their own profile.
/// * Other real members: their public name and earned rank. Their bio and
///   fitness details are private to them (the server never shares them), so
///   they are not shown and never guessed.
class ProfileResolver {
  const ProfileResolver._();

  static bool isSelfId(String userId) {
    if (userId.isEmpty) return false;
    return userId == 'usr_local' ||
        userId == 'usr_local_01' ||
        (LocalStorage.isShowcaseModeEnabled() &&
            userId == 'usr_showcase_athlete') ||
        userId == CloudSession.userId ||
        userId == FitnessProvider.instance.currentUser?.id;
  }

  /// [name], [avatarUrl] and [rank] come from the post or comment the user
  /// tapped and are used when nothing better is known.
  static Future<AthleteProfile> resolve({
    required String userId,
    required String name,
    String? avatarUrl,
    String? rank,
  }) async {
    final sample = SampleCommunity.profileFor(userId);
    if (sample != null) return sample;

    if (isSelfId(userId)) return _self(userId, name, rank);

    final isServerId = CommunityCloudRepository.isCloudId(userId);
    // An id that is neither a sample athlete, you, nor a server account, with
    // no name to go on, points at nothing.
    if (userId.isEmpty || (!isServerId && name.trim().isEmpty)) {
      throw const ProfileNotFound();
    }

    var displayName = name;
    var rankTitle = rank;
    if (isServerId && CommunityCloudRepository.isActive) {
      try {
        final member = await CommunityCloudRepository.instance.fetchMember(
          userId,
        );
        if (member != null) {
          displayName = member.name;
          rankTitle = member.rank;
        }
      } catch (_) {
        throw const ProfileLoadFailure();
      }
    }
    return AthleteProfile(
      userId: userId,
      displayName: displayName.isEmpty ? 'Athlete' : displayName,
      avatarUrl: avatarUrl,
      rankTitle: (rankTitle ?? '').trim().isEmpty ? null : rankTitle,
      infoState: ProfileInfoState.notShared,
    );
  }

  static AthleteProfile _self(String userId, String name, String? rank) {
    final p = LocalStorage.getUserProfile();
    final showcase = CommunityAvatarHelper.isShowcaseSelf(userId);
    final shownName = showcase
        ? ProfileProvider.showcaseSelfLabel
        : (p.name.trim().isNotEmpty
              ? p.name.trim()
              : (name.isNotEmpty ? name : 'You'));
    final bio = p.bio.trim();
    final stats = _ownStats();
    return AthleteProfile(
      userId: userId,
      displayName: shownName,
      workoutCount: stats.workouts,
      streakDays: stats.streak,
      badgeCount: stats.badges,
      prs: stats.prs,
      localAvatarPath: showcase || p.profilePic.trim().isEmpty
          ? null
          : p.profilePic.trim(),
      rankTitle: (rank ?? '').trim().isEmpty ? null : rank,
      bio: bio.isEmpty || showcase ? null : bio,
      fitness: showcase
          ? const []
          : [
              if (p.fitnessGoal.trim().isNotEmpty)
                FitnessFact('Goal', p.fitnessGoal.trim()),
              if (p.workoutExperience.trim().isNotEmpty)
                FitnessFact('Level', p.workoutExperience.trim()),
            ],
      isSelf: true,
      infoState: ProfileInfoState.own,
    );
  }

  /// Your own recorded activity. Anything with no record is null (a dash on
  /// screen); nothing is estimated or defaulted.
  static ({int? workouts, int? streak, int? badges, List<ProfilePr> prs})
  _ownStats() {
    try {
      final fp = FitnessProvider.instance;
      final history = [...fp.workoutHistory]
        ..sort((a, b) => b.dateCompleted.compareTo(a.dateCompleted));
      final seen = <String>{};
      final prs = <ProfilePr>[];
      for (final w in history) {
        for (final text in w.personalRecords) {
          if (text.trim().isEmpty || !seen.add(text)) continue;
          prs.add(ProfilePr(text, '', achievedAt: w.dateCompleted));
          if (prs.length >= 30) break;
        }
        if (prs.length >= 30) break;
      }
      final badges = fp.userProgress.achievements.length;
      return (
        workouts: history.isEmpty ? null : history.length,
        streak: history.isEmpty ? null : fp.workoutStreak,
        badges: badges == 0 ? null : badges,
        prs: prs,
      );
    } catch (_) {
      return (workouts: null, streak: null, badges: null, prs: const []);
    }
  }

  /// The athlete's own posts, newest first. [complete] is false when the list
  /// may be missing posts (the server page limit was reached, or loading some
  /// of them failed), so callers must not present its length as a total.
  static Future<({List<ActivityPost> posts, bool complete})> postsFor(
    AthleteProfile profile,
  ) async {
    var complete = true;
    List<ActivityPost> list;
    if (profile.isSample) {
      list = SampleCommunity.postsBy(profile.userId);
    } else if (profile.isSelf) {
      list = [
        for (final p in LocalStorage.getCommunityPosts())
          if (!p.isSample && isSelfId(p.userId)) p,
      ];
      final uid = CloudSession.userId;
      if (CommunityCloudRepository.isActive && uid != null) {
        try {
          final mine = await CommunityCloudRepository.instance.fetchUserPosts(
            uid,
          );
          final seen = list.map((p) => p.id).toSet();
          list = [...list, ...mine.where((p) => seen.add(p.id))];
          if (mine.length >= CommunityCloudRepository.profilePostLimit) {
            complete = false;
          }
        } catch (_) {
          complete = false;
        }
      }
    } else if (CommunityCloudRepository.isActive &&
        CommunityCloudRepository.isCloudId(profile.userId)) {
      list = await CommunityCloudRepository.instance.fetchUserPosts(
        profile.userId,
      );
      complete = list.length < CommunityCloudRepository.profilePostLimit;
    } else {
      list = const [];
    }
    final sorted = List<ActivityPost>.from(list)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return (posts: sorted, complete: complete);
  }
}
