/// The one Ranked ladder used everywhere a rank is shown:
/// Bronze → Silver → Gold → Platinum → Diamond → Champion, each with
/// divisions III → II → I (18 divisions).
///
/// Rank comes from Ranked points: one point per milestone level reached
/// (4 stats × 5 levels = 20 points). Each point moves you up one division;
/// Champion I needs 18 points. The server computes points from approved
/// milestones; the app only displays them.
class RankLadder {
  RankLadder._();

  static const List<String> tiers = [
    'Bronze',
    'Silver',
    'Gold',
    'Platinum',
    'Diamond',
    'Champion',
  ];
  static const List<String> divisions = ['III', 'II', 'I'];

  static int get divisionCount => tiers.length * divisions.length;

  /// Rank for [points]. Zero points is unranked.
  static RankPosition fromPoints(int points) {
    if (points <= 0) return const RankPosition.unranked();
    final index = (points - 1).clamp(0, divisionCount - 1);
    return RankPosition(
      index: index,
      tier: tiers[index ~/ divisions.length],
      division: divisions[index % divisions.length],
    );
  }

  /// Points needed to reach the division at [index].
  static int pointsForIndex(int index) => index + 1;

  /// Index of a tier name, or -1 (e.g. old saved names like "Elite").
  static int tierIndex(String tier) =>
      tiers.indexWhere((t) => t.toLowerCase() == tier.toLowerCase());

  /// The position for a saved tier and division (for example "Gold", "II"),
  /// or unranked when either is not on the ladder.
  static RankPosition parse(String tier, String division) {
    final t = tierIndex(tier.trim());
    final d = divisions.indexWhere(
      (x) => x.toLowerCase() == division.trim().toLowerCase(),
    );
    if (t < 0 || d < 0) return const RankPosition.unranked();
    final index = t * divisions.length + d;
    return RankPosition(index: index, tier: tiers[t], division: divisions[d]);
  }
}

/// A position on the [RankLadder].
class RankPosition {
  /// 0 = Bronze III … 17 = Champion I; -1 = unranked.
  final int index;
  final String tier;
  final String division;

  const RankPosition({
    required this.index,
    required this.tier,
    required this.division,
  });

  const RankPosition.unranked() : index = -1, tier = 'Unranked', division = '';

  bool get isRanked => index >= 0;

  /// Ranked points this position takes (0 when unranked).
  int get points => isRanked ? RankLadder.pointsForIndex(index) : 0;
  bool get isTop => index == RankLadder.divisionCount - 1;

  /// e.g. "Gold II" or "Unranked".
  String get title => isRanked ? '$tier $division' : 'Unranked';

  /// The next division, or null at the top.
  RankPosition? get next => isTop
      ? null
      : RankLadder.fromPoints(RankLadder.pointsForIndex(index + 1));

  @override
  bool operator ==(Object other) =>
      other is RankPosition && other.index == index;

  @override
  int get hashCode => index.hashCode;

  @override
  String toString() => title;
}
