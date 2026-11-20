import '../../models/social_profile.dart';

/// Supported competitive leaderboard ranking categories.
enum LeaderboardCategory {
  weeklyXp('Weekly XP', '⚡'),
  workoutConsistency('Consistency & Streaks', '🔥'),
  totalVolume('Total Volume Lifted', '🏋️'),
  strengthGains('Strength Gains', '💪'),
  challengePoints('Challenge Points', '🏆');

  final String title;
  final String icon;
  const LeaderboardCategory(this.title, this.icon);
}

/// Ranked leaderboard entry with real calculated position.
class RankedAthleteEntry {
  final int rank;
  final SocialProfile profile;
  final String metricValue;
  final double numericScore;

  const RankedAthleteEntry({
    required this.rank,
    required this.profile,
    required this.metricValue,
    required this.numericScore,
  });
}

/// Service computing competitive leaderboard rankings from real athlete activity without synthetic padding.
class SocialLeaderboardService {
  static SocialLeaderboardService? _instance;
  static SocialLeaderboardService get instance =>
      _instance ??= SocialLeaderboardService();

  /// Default baseline athlete profiles representing the local fitness community.

  /// Computes leaderboard rankings for a set of athlete profiles based on the selected category.
  List<RankedAthleteEntry> computeRankings({
    required LeaderboardCategory category,
    List<SocialProfile>? profiles,
    SocialProfile? currentAthlete,
  }) {
    final list = List<SocialProfile>.from(profiles ?? const <SocialProfile>[]);
    if (currentAthlete != null &&
        !list.any((p) => p.userId == currentAthlete.userId)) {
      list.add(currentAthlete);
    }

    switch (category) {
      case LeaderboardCategory.weeklyXp:
        list.sort((a, b) => b.totalXp.compareTo(a.totalXp));
        return list.asMap().entries.map((e) {
          final p = e.value;
          return RankedAthleteEntry(
            rank: e.key + 1,
            profile: p,
            metricValue: '${p.totalXp} XP',
            numericScore: p.totalXp.toDouble(),
          );
        }).toList();

      case LeaderboardCategory.workoutConsistency:
        list.sort((a, b) {
          final streakComp = b.currentStreakDays.compareTo(a.currentStreakDays);
          if (streakComp != 0) return streakComp;
          return b.workoutsCompleted.compareTo(a.workoutsCompleted);
        });
        return list.asMap().entries.map((e) {
          final p = e.value;
          return RankedAthleteEntry(
            rank: e.key + 1,
            profile: p,
            metricValue:
                '${p.currentStreakDays} day streak (${p.workoutsCompleted} sessions)',
            numericScore: p.currentStreakDays.toDouble(),
          );
        }).toList();

      case LeaderboardCategory.totalVolume:
        list.sort((a, b) => b.totalVolumeKg.compareTo(a.totalVolumeKg));
        return list.asMap().entries.map((e) {
          final p = e.value;
          final tonStr = (p.totalVolumeKg / 1000).toStringAsFixed(1);
          return RankedAthleteEntry(
            rank: e.key + 1,
            profile: p,
            metricValue: '$tonStr tons lifted',
            numericScore: p.totalVolumeKg,
          );
        }).toList();

      case LeaderboardCategory.strengthGains:
        list.sort((a, b) {
          final scoreA =
              a.totalVolumeKg /
              (a.workoutsCompleted > 0 ? a.workoutsCompleted : 1);
          final scoreB =
              b.totalVolumeKg /
              (b.workoutsCompleted > 0 ? b.workoutsCompleted : 1);
          return scoreB.compareTo(scoreA);
        });
        return list.asMap().entries.map((e) {
          final p = e.value;
          final avgVol = p.workoutsCompleted > 0
              ? (p.totalVolumeKg / p.workoutsCompleted).round()
              : 0;
          return RankedAthleteEntry(
            rank: e.key + 1,
            profile: p,
            metricValue: '$avgVol kg avg/session',
            numericScore: avgVol.toDouble(),
          );
        }).toList();

      case LeaderboardCategory.challengePoints:
        list.sort((a, b) {
          final ptsA = a.achievements.length * 200 + a.totalXp ~/ 10;
          final ptsB = b.achievements.length * 200 + b.totalXp ~/ 10;
          return ptsB.compareTo(ptsA);
        });
        return list.asMap().entries.map((e) {
          final p = e.value;
          final pts = p.achievements.length * 200 + p.totalXp ~/ 10;
          return RankedAthleteEntry(
            rank: e.key + 1,
            profile: p,
            metricValue: '$pts pts (${p.achievements.length} badges)',
            numericScore: pts.toDouble(),
          );
        }).toList();
    }
  }
}
