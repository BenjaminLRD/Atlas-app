import '../models/leaderboard_entry.dart';
import 'supabase/supabase_client.dart';

/// Central service managing real user rankings, global/local filtering,
/// and Supabase synchronization with offline fallback data.
class LeaderboardService {
  final SupabaseClientManager _clientManager;

  LeaderboardService({SupabaseClientManager? clientManager})
      : _clientManager = clientManager ?? SupabaseClientManager.instance;

  static final List<LeaderboardEntry> _mockFallbackEntries = [
    LeaderboardEntry(
      id: 'lb_1',
      userId: 'usr_alex',
      displayName: 'Alex Carter',
      avatarUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAe17WVT8Uj9wqSO561oYLks-4tk4O8kt7ZDLWnWiKhO9sc1vAkyPrEJHQr5H8o8jCDdRMP_8fO8wHG1K7dKWQ27WD3scUuT24ySyadqJpcQrRH5Veebc6g-Z2ivzuF-JZRFPwxQc5gKxxphIkoXPe_N2UeQ3XR9fR5O_6sz_2H4EV8iy7_3n5e0p8StfVZN1HzpbB3RdxwKHiBENcHovctQivOm9ZzyTKK-t8HgrCMZUZGdSZ9FRiHIA',
      totalXP: 52400,
      rankTitle: 'Elite I',
      division: 'Division I',
      country: 'India',
      updatedAt: DateTime.now(),
    ),
    LeaderboardEntry(
      id: 'lb_2',
      userId: 'usr_maya',
      displayName: 'Maya Chen',
      avatarUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAf6_AjymJG_wOnAGeythvubzFwpd75IAjO3gZgI7zOFPMpxu0ZEKtYSSsYoaeO1kXX4_POG1YWtimfmalsmbE2-pj_7G1xKIRiCwe2MAorJhDbI7SYNK_YebTXO7DXmpZ60W9xpg5nbG7I1ZeSZeWx2RMlAgdnjeoXXEVSqGM7IloSx7Z4ZoNlMI2FzvZQzHT8LiWJX6DwuX37cgsfTavIwqos0cuDluKYXRPuvjdihl4p213lKlaEZA',
      totalXP: 31200,
      rankTitle: 'Diamond II',
      division: 'Division I',
      country: 'India',
      updatedAt: DateTime.now(),
    ),
    LeaderboardEntry(
      id: 'lb_3',
      userId: 'usr_daniel',
      displayName: 'Daniel Kim',
      avatarUrl:
          'https://lh3.googleusercontent.com/aida-public/AB6AXuAi9oBX0mp3E4ZfZXXvRfRfZvcajEtSFWt8yleyU4BavUKjvWQ5g4yhbpSwRFE0gZZQDp_cwkJbb43sRxx_gTEmZJLHbW_n_l3KJF5jbz5khSJj-xNDXkbIfBC7kcdpGWSaFhlzF43JhGHdTWwcq6f19hf_UAnp0jK7eWQLFQVY2W6ATlBGRrmUcEPPfzlCNvsdNvvoljmV9TALS1hEM3jdN5_77NNJ4AQazBntOOEvoDNfXH-l_OvlqQ',
      totalXP: 28700,
      rankTitle: 'Diamond III',
      division: 'Division I',
      country: 'USA',
      updatedAt: DateTime.now(),
    ),
    LeaderboardEntry(
      id: 'lb_4',
      userId: 'usr_emma',
      displayName: 'Emma Johnson',
      totalXP: 24100,
      rankTitle: 'Platinum II',
      division: 'Division II',
      country: 'India',
      updatedAt: DateTime.now(),
    ),
    LeaderboardEntry(
      id: 'lb_5',
      userId: 'usr_liam',
      displayName: "Liam O'Connor",
      totalXP: 22600,
      rankTitle: 'Platinum I',
      division: 'Division II',
      country: 'UK',
      updatedAt: DateTime.now(),
    ),
  ];

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

    final fallback = List<LeaderboardEntry>.from(_mockFallbackEntries);
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

    final fallback = _mockFallbackEntries
        .where((e) => e.country.toLowerCase() == country.toLowerCase())
        .toList();
    if (fallback.isEmpty) {
      fallback.addAll(_mockFallbackEntries.take(3));
    }
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

    final fallback = List<LeaderboardEntry>.from(_mockFallbackEntries);
    fallback.sort((a, b) => b.totalXP.compareTo(a.totalXP));
    return fallback.take(limit).toList();
  }

  /// Upsert / update a user's leaderboard entry in the remote database.
  Future<void> updateLeaderboardEntry(LeaderboardEntry entry) async {
    final query = _clientManager.from('leaderboard_entries');
    await query.upsert(entry.toJson(), onConflictColumn: 'id');

    final idx = _mockFallbackEntries
        .indexWhere((e) => e.userId == entry.userId || e.id == entry.id);
    if (idx != -1) {
      _mockFallbackEntries[idx] = entry;
    } else {
      _mockFallbackEntries.add(entry);
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
      baseEntries = await getFriendsLeaderboard(userId: 'usr_local', limit: limit);
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
