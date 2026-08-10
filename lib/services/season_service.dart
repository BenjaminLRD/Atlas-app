import '../models/fitness_season.dart';
import '../models/leaderboard_entry.dart';
import '../models/season_progress.dart';
import 'supabase/supabase_client.dart';

/// Central service managing seasonal competitive progression, seasonal XP accumulation,
/// and season leaderboards.
class SeasonService {
  static SeasonService? _instance;
  final SupabaseClientManager _clientManager;

  FitnessSeason? _cachedCurrentSeason;
  SeasonProgress? _cachedSeasonProgress;
  List<LeaderboardEntry>? _cachedSeasonLeaderboard;

  SeasonService({SupabaseClientManager? clientManager})
      : _clientManager = clientManager ?? SupabaseClientManager.instance;

  /// Reset singleton instance (useful for testing)
  static void resetInstance() {
    _instance = null;
  }

  /// Singleton instance getter
  static SeasonService get instance {
    _instance ??= SeasonService();
    return _instance!;
  }

  static FitnessSeason _getDefaultSeason() {
    final now = DateTime.now();
    return FitnessSeason(
      id: 'season_2026_q3',
      name: 'Season 3: Monsoon Mayhem',
      description: 'Push your limits this monsoon! Earn seasonal XP to unlock exclusive titles, badges, and gym gear.',
      startDate: now.subtract(const Duration(days: 15)),
      endDate: now.add(const Duration(days: 45)),
      rewardDescription: 'Top 3: Exclusive Gym Hoodie & Golden Trophy Badge • Top 10: Silver Badge • Top 25: Bronze Badge',
    );
  }

  static List<LeaderboardEntry> _getDefaultSeasonLeaderboard() {
    final now = DateTime.now();
    return [
      LeaderboardEntry(
        id: 's_entry_1',
        userId: 'usr_alex',
        displayName: 'Alex Carter',
        avatarUrl:
            'https://lh3.googleusercontent.com/aida-public/AB6AXuAe17WVT8Uj9wqSO561oYLks-4tk4O8kt7ZDLWnWiKhO9sc1vAkyPrEJHQr5H8o8jCDdRMP_8fO8wHG1K7dKWQ27WD3scUuT24ySyadqJpcQrRH5Veebc6g-Z2ivzuF-JZRFPwxQc5gKxxphIkoXPe_N2UeQ3XR9fR5O_6sz_2H4EV8iy7_3n5e0p8StfVZN1HzpbB3RdxwKHiBENcHovctQivOm9ZzyTKK-t8HgrCMZUZGdSZ9FRiHIA',
        totalXP: 14200,
        rankTitle: 'Season Leader',
        division: 'Division I',
        country: 'India',
        updatedAt: now,
      ),
      LeaderboardEntry(
        id: 's_entry_2',
        userId: 'usr_maya',
        displayName: 'Maya Chen',
        avatarUrl:
            'https://lh3.googleusercontent.com/aida-public/AB6AXuAf6_AjymJG_wOnAGeythvubzFwpd75IAjO3gZgI7zOFPMpxu0ZEKtYSSsYoaeO1kXX4_POG1YWtimfmalsmbE2-pj_7G1xKIRiCwe2MAorJhDbI7SYNK_YebTXO7DXmpZ60W9xpg5nbG7I1ZeSZeWx2RMlAgdnjeoXXEVSqGM7IloSx7Z4ZoNlMI2FzvZQzHT8LiWJX6DwuX37cgsfTavIwqos0cuDluKYXRPuvjdihl4p213lKlaEZA',
        totalXP: 11800,
        rankTitle: 'Season Contender',
        division: 'Division I',
        country: 'India',
        updatedAt: now,
      ),
      LeaderboardEntry(
        id: 's_entry_3',
        userId: 'usr_local',
        displayName: 'Lalramdina',
        avatarUrl: null,
        totalXP: 8400,
        rankTitle: 'Challenger',
        division: 'Division I',
        country: 'India',
        updatedAt: now,
      ),
    ];
  }

  /// Get the active competitive season.
  Future<FitnessSeason> getCurrentSeason() async {
    if (_cachedCurrentSeason != null) {
      return _cachedCurrentSeason!;
    }

    try {
      final query = _clientManager.from('seasons');
      final rows = await query.select();
      if (rows.isNotEmpty) {
        final list = rows.map((r) => FitnessSeason.fromJson(r)).toList();
        final active = list.firstWhere(
          (s) => s.isActive,
          orElse: () => list.first,
        );
        _cachedCurrentSeason = active;
        return active;
      }
    } catch (_) {}

    final defaultSeason = _getDefaultSeason();
    _cachedCurrentSeason = defaultSeason;
    return defaultSeason;
  }

  /// Get season leaderboard entries sorted by seasonXP descending.
  Future<List<LeaderboardEntry>> getSeasonLeaderboard(String seasonId) async {
    if (_cachedSeasonLeaderboard != null && _cachedSeasonLeaderboard!.isNotEmpty) {
      return List.unmodifiable(_cachedSeasonLeaderboard!);
    }

    try {
      final query = _clientManager.from('season_progress');
      final rows = await query.select('season_id', seasonId);
      if (rows.isNotEmpty) {
        final entries = rows.map((r) {
          final xp = r['season_xp'] as int? ?? 0;
          return LeaderboardEntry(
            id: r['id'] as String? ?? '',
            userId: r['user_id'] as String? ?? '',
            displayName: r['display_name'] as String? ?? 'Gym Member',
            avatarUrl: r['avatar_url'] as String?,
            totalXP: xp,
            rankTitle: 'Season Competitor',
            division: 'Division I',
            country: 'India',
            updatedAt: DateTime.now(),
          );
        }).toList();
        entries.sort((a, b) => b.totalXP.compareTo(a.totalXP));
        _cachedSeasonLeaderboard = entries;
        return List.unmodifiable(entries);
      }
    } catch (_) {}

    final defaults = _getDefaultSeasonLeaderboard();
    _cachedSeasonLeaderboard = List.from(defaults);
    return List.unmodifiable(defaults);
  }

  /// Get a user's season progress record.
  Future<SeasonProgress> getSeasonProgress({
    required String seasonId,
    required String userId,
  }) async {
    if (_cachedSeasonProgress != null &&
        _cachedSeasonProgress!.seasonId == seasonId &&
        _cachedSeasonProgress!.userId == userId) {
      return _cachedSeasonProgress!;
    }

    try {
      final query = _clientManager.from('season_progress');
      final rows = await query.select();
      final userRow = rows.firstWhere(
        (r) => r['season_id'] == seasonId && r['user_id'] == userId,
        orElse: () => <String, dynamic>{},
      );

      if (userRow.isNotEmpty) {
        final prog = SeasonProgress.fromJson(userRow);
        _cachedSeasonProgress = prog;
        return prog;
      }
    } catch (_) {}

    final initial = SeasonProgress(
      id: 'sp_${seasonId}_$userId',
      seasonId: seasonId,
      userId: userId,
      seasonXP: 8400,
      updatedAt: DateTime.now(),
    );
    _cachedSeasonProgress = initial;
    return initial;
  }

  /// Add seasonal XP to a user's season progress record.
  Future<SeasonProgress> addSeasonXP({
    required String seasonId,
    required String userId,
    required int amount,
  }) async {
    final current = await getSeasonProgress(seasonId: seasonId, userId: userId);
    final updated = current.copyWith(
      seasonXP: current.seasonXP + amount,
      updatedAt: DateTime.now(),
    );

    _cachedSeasonProgress = updated;

    // Update season leaderboard cache
    if (_cachedSeasonLeaderboard != null) {
      final idx = _cachedSeasonLeaderboard!.indexWhere((e) => e.userId == userId || e.id == updated.id);
      if (idx != -1) {
        _cachedSeasonLeaderboard![idx] = _cachedSeasonLeaderboard![idx].copyWith(
          totalXP: updated.seasonXP,
          updatedAt: DateTime.now(),
        );
      } else {
        _cachedSeasonLeaderboard!.add(LeaderboardEntry(
          id: updated.id,
          userId: userId,
          displayName: 'Lalramdina',
          totalXP: updated.seasonXP,
          rankTitle: 'Season Competitor',
          division: 'Division I',
          country: 'India',
          updatedAt: DateTime.now(),
        ));
      }
      _cachedSeasonLeaderboard!.sort((a, b) => b.totalXP.compareTo(a.totalXP));
    }

    try {
      await _clientManager.from('season_progress').upsert(updated.toJson());
    } catch (_) {}

    return updated;
  }
}
