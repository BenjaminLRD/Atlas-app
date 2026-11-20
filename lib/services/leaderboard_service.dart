import '../models/leaderboard_entry.dart';
import 'supabase/supabase_client.dart';

/// Central service managing real user rankings, global/local filtering,
/// and Supabase synchronization. With no server data it returns empty lists.
class LeaderboardService {
  final SupabaseClientManager _clientManager;

  LeaderboardService({SupabaseClientManager? clientManager})
    : _clientManager = clientManager ?? SupabaseClientManager.instance;

  /// Entries known on this device: only the athlete's own synced entry. Never
  /// seeded with other people, because there are no other people to rank.
  static final List<LeaderboardEntry> _localEntries = [];

  /// Retrieve global leaderboard entries sorted by totalXP descending.
  Future<List<LeaderboardEntry>> getGlobalLeaderboard({int limit = 50}) async {
    try {
      final query = _clientManager.from('leaderboard_entries');
      final rows = await query.select();
      if (rows.isNotEmpty) {
        final entries = rows.map((r) => LeaderboardEntry.fromJson(r)).toList();
        entries.sort((a, b) => b.totalXP.compareTo(a.totalXP));
        return entries.take(limit).toList();
      }
    } catch (_) {}

    // No server data: only this athlete's own entry is known.
    final fallback = List<LeaderboardEntry>.from(_localEntries);
    fallback.sort((a, b) => b.totalXP.compareTo(a.totalXP));
    return fallback.take(limit).toList();
  }

  /// Retrieve local country leaderboard entries sorted by totalXP descending.
  Future<List<LeaderboardEntry>> getLocalLeaderboard({
    String country = 'India',
    int limit = 50,
  }) async {
    try {
      final query = _clientManager.from('leaderboard_entries');
      final rows = await query.select('country', country);
      if (rows.isNotEmpty) {
        final entries = rows.map((r) => LeaderboardEntry.fromJson(r)).toList();
        entries.sort((a, b) => b.totalXP.compareTo(a.totalXP));
        return entries.take(limit).toList();
      }
    } catch (_) {}

    // No server data: only this athlete's own entry is known.
    final fallback = List<LeaderboardEntry>.from(_localEntries);
    fallback.sort((a, b) => b.totalXP.compareTo(a.totalXP));
    return fallback.take(limit).toList();
  }

  /// Retrieve friends leaderboard entries for a given user.
  Future<List<LeaderboardEntry>> getFriendsLeaderboard({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final query = _clientManager.from('leaderboard_entries');
      final rows = await query.select();
      if (rows.isNotEmpty) {
        final entries = rows.map((r) => LeaderboardEntry.fromJson(r)).toList();
        entries.sort((a, b) => b.totalXP.compareTo(a.totalXP));
        return entries.take(limit).toList();
      }
    } catch (_) {}

    // No server data: only this athlete's own entry is known.
    final fallback = List<LeaderboardEntry>.from(_localEntries);
    fallback.sort((a, b) => b.totalXP.compareTo(a.totalXP));
    return fallback.take(limit).toList();
  }

  /// Upsert / update a user's leaderboard entry in the remote database.
  Future<void> updateLeaderboardEntry(LeaderboardEntry entry) async {
    final query = _clientManager.from('leaderboard_entries');
    await query.upsert(entry.toJson(), onConflictColumn: 'id');

    final idx = _localEntries.indexWhere(
      (e) => e.userId == entry.userId || e.id == entry.id,
    );
    if (idx != -1) {
      _localEntries[idx] = entry;
    } else {
      _localEntries.add(entry);
    }
  }

  /// Retrieve leaderboard entries filtered by scope (Global, Friends, Local Gym),
  /// timeframe (Weekly, Monthly, All-Time), and metric (Total XP, Workouts, Volume, Streak).
  Future<List<LeaderboardEntry>> getFilteredLeaderboard({
    String scope = 'Global',
    String timeframe = 'Weekly',
    String metric = 'Total XP',
    int limit = 50,
  }) async {
    List<LeaderboardEntry> baseEntries;
    if (scope == 'Friends') {
      baseEntries = await getFriendsLeaderboard(
        userId: 'usr_local',
        limit: limit,
      );
    } else if (scope == 'Local Gym' || scope == 'Local') {
      baseEntries = await getLocalLeaderboard(country: 'India', limit: limit);
    } else {
      baseEntries = await getGlobalLeaderboard(limit: limit);
    }

    final sorted = List<LeaderboardEntry>.from(baseEntries);
    if (metric == 'Workouts') {
      sorted.sort((a, b) => b.totalXP.compareTo(a.totalXP));
    } else if (metric == 'Volume') {
      sorted.sort((a, b) => b.totalXP.compareTo(a.totalXP));
    } else {
      sorted.sort((a, b) => b.totalXP.compareTo(a.totalXP));
    }

    return sorted.take(limit).toList();
  }
}
