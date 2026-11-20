/// One labelled fitness detail on a profile, for example "Goal: Muscle gain".
class FitnessFact {
  final String label;
  final String value;
  const FitnessFact(this.label, this.value);
}

/// A personal record shown on a profile, for example "Deadlift 140 kg x 3".
class ProfilePr {
  final String exercise;
  final String value;
  final DateTime? achievedAt;
  const ProfilePr(this.exercise, this.value, {this.achievedAt});
}

/// Why a profile does or does not show personal details.
enum ProfileInfoState {
  /// Built-in demo athlete: details are scripted and labelled.
  demo,

  /// The person using this device: shows what they entered themselves.
  own,

  /// A real member: their details are private to them, so none are shown.
  notShared,
}

/// What the profile screen shows about one athlete.
///
/// Every field is optional and is filled only from something the athlete
/// actually provided (or, for a sample athlete, from clearly labelled demo
/// content). Nothing is estimated: a missing field is simply not shown.
class AthleteProfile {
  final String userId;
  final String displayName;
  final String? username;

  /// Remote avatar, when one exists.
  final String? avatarUrl;

  /// Local picture file of the signed-in user (never of other people).
  final String? localAvatarPath;

  /// Rank title the athlete earned, when known.
  final String? rankTitle;

  /// Bio the athlete wrote, when they wrote one.
  final String? bio;

  /// Fitness details the athlete provided.
  final List<FitnessFact> fitness;

  /// Personal records (sample athletes only until real ones are shared).
  final List<ProfilePr> prs;

  /// Milestones the athlete reached (sample athletes only for now).
  final List<String> milestones;

  /// Workouts logged, current streak and badges unlocked. Null means there is
  /// no recorded data (shown as a dash), never zero-as-a-default.
  final int? workoutCount;
  final int? streakDays;
  final int? badgeCount;

  /// Location and membership line, when known.
  final String? location;
  final String? memberSince;

  /// Demo content, not a real member.
  final bool isSample;

  /// The person using this device.
  final bool isSelf;

  final ProfileInfoState infoState;

  const AthleteProfile({
    required this.userId,
    required this.displayName,
    this.username,
    this.avatarUrl,
    this.localAvatarPath,
    this.rankTitle,
    this.bio,
    this.fitness = const [],
    this.prs = const [],
    this.milestones = const [],
    this.workoutCount,
    this.streakDays,
    this.badgeCount,
    this.location,
    this.memberSince,
    this.isSample = false,
    this.isSelf = false,
    this.infoState = ProfileInfoState.notShared,
  });

  bool get hasBio => bio != null && bio!.trim().isNotEmpty;
  bool get hasFitness => fitness.isNotEmpty;
}
