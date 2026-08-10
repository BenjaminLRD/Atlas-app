import '../models/leaderboard_user.dart';

/// Leaderboard Data Service providing mock datasets for Global, Friends, and Local scopes.
/// Built with a clean service interface so it can be swapped with a real API or cloud database.
class LeaderboardService {
  /// Retrieve leaderboard users based on tab index: 0 = Global, 1 = Friends, 2 = Local
  List<LeaderboardUser> getLeaderboard({
    required int tabIndex,
    required String userRank,
    required int userXP,
    String? userAvatarUrl,
  }) {
    switch (tabIndex) {
      case 1:
        return _getFriendsLeaderboard(userRank, userXP, userAvatarUrl);
      case 2:
        return _getLocalLeaderboard(userRank, userXP, userAvatarUrl);
      case 0:
      default:
        return _getGlobalLeaderboard(userRank, userXP, userAvatarUrl);
    }
  }

  /// Global Leaderboard Dataset
  List<LeaderboardUser> _getGlobalLeaderboard(
    String userRank,
    int userXP,
    String? userAvatarUrl,
  ) {
    return [
      const LeaderboardUser(
        rankPosition: 1,
        name: 'Alex Carter',
        rankTitle: 'Elite I',
        xp: 52400,
        imageUrl:
            'https://lh3.googleusercontent.com/aida-public/AB6AXuAe17WVT8Uj9wqSO561oYLks-4tk4O8kt7ZDLWnWiKhO9sc1vAkyPrEJHQr5H8o8jCDdRMP_8fO8wHG1K7dKWQ27WD3scUuT24ySyadqJpcQrRH5Veebc6g-Z2ivzuF-JZRFPwxQc5gKxxphIkoXPe_N2UeQ3XR9fR5O_6sz_2H4EV8iy7_3n5e0p8StfVZN1HzpbB3RdxwKHiBENcHovctQivOm9ZzyTKK-t8HgrCMZUZGdSZ9FRiHIA',
      ),
      const LeaderboardUser(
        rankPosition: 2,
        name: 'Maya Chen',
        rankTitle: 'Diamond II',
        xp: 31200,
        imageUrl:
            'https://lh3.googleusercontent.com/aida-public/AB6AXuAf6_AjymJG_wOnAGeythvubzFwpd75IAjO3gZgI7zOFPMpxu0ZEKtYSSsYoaeO1kXX4_POG1YWtimfmalsmbE2-pj_7G1xKIRiCwe2MAorJhDbI7SYNK_YebTXO7DXmpZ60W9xpg5nbG7I1ZeSZeWx2RMlAgdnjeoXXEVSqGM7IloSx7Z4ZoNlMI2FzvZQzHT8LiWJX6DwuX37cgsfTavIwqos0cuDluKYXRPuvjdihl4p213lKlaEZA',
      ),
      const LeaderboardUser(
        rankPosition: 3,
        name: 'Daniel Kim',
        rankTitle: 'Diamond III',
        xp: 28700,
        imageUrl:
            'https://lh3.googleusercontent.com/aida-public/AB6AXuAi9oBX0mp3E4ZfZXXvRfRfZvcajEtSFWt8yleyU4BavUKjvWQ5g4yhbpSwRFE0gZZQDp_cwkJbb43sRxx_gTEmZJLHbW_n_l3KJF5jbz5khSJj-xNDXkbIfBC7kcdpGWSaFhlzF43JhGHdTWwcq6f19hf_UAnp0jK7eWQLFQVY2W6ATlBGRrmUcEPPfzlCNvsdNvvoljmV9TALS1hEM3jdN5_77NNJ4AQazBntOOEvoDNfXH-l_OvlqQ',
      ),
      const LeaderboardUser(
        rankPosition: 4,
        name: 'Emma Johnson',
        rankTitle: 'Platinum II',
        xp: 24100,
      ),
      const LeaderboardUser(
        rankPosition: 5,
        name: "Liam O'Connor",
        rankTitle: 'Platinum I',
        xp: 22600,
      ),
      LeaderboardUser(
        rankPosition: 247,
        name: 'You',
        rankTitle: userRank,
        xp: userXP,
        imageUrl: userAvatarUrl,
        isCurrentUser: true,
      ),
    ];
  }

  /// Friends Leaderboard Dataset
  List<LeaderboardUser> _getFriendsLeaderboard(
    String userRank,
    int userXP,
    String? userAvatarUrl,
  ) {
    return [
      const LeaderboardUser(
        rankPosition: 1,
        name: 'Aman Raj',
        rankTitle: 'Silver I',
        xp: 2400,
      ),
      LeaderboardUser(
        rankPosition: 2,
        name: 'You',
        rankTitle: userRank,
        xp: userXP,
        imageUrl: userAvatarUrl,
        isCurrentUser: true,
      ),
      const LeaderboardUser(
        rankPosition: 3,
        name: 'Vikram Das',
        rankTitle: 'Bronze II',
        xp: 450,
      ),
      const LeaderboardUser(
        rankPosition: 4,
        name: 'Riya Patel',
        rankTitle: 'Bronze I',
        xp: 320,
      ),
      const LeaderboardUser(
        rankPosition: 5,
        name: 'Siddharth Iyer',
        rankTitle: 'Unranked',
        xp: 0,
      ),
    ];
  }

  /// Local Leaderboard Dataset
  List<LeaderboardUser> _getLocalLeaderboard(
    String userRank,
    int userXP,
    String? userAvatarUrl,
  ) {
    return [
      const LeaderboardUser(
        rankPosition: 1,
        name: 'Rohan Mehta',
        rankTitle: 'Diamond II',
        xp: 18700,
      ),
      const LeaderboardUser(
        rankPosition: 2,
        name: 'Ananya Singh',
        rankTitle: 'Platinum I',
        xp: 15400,
      ),
      const LeaderboardUser(
        rankPosition: 3,
        name: 'Arjun Verma',
        rankTitle: 'Gold I',
        xp: 12200,
      ),
      const LeaderboardUser(
        rankPosition: 4,
        name: 'Neha Sharma',
        rankTitle: 'Gold II',
        xp: 9800,
      ),
      const LeaderboardUser(
        rankPosition: 5,
        name: 'Kabir Malhotra',
        rankTitle: 'Silver I',
        xp: 8100,
      ),
      LeaderboardUser(
        rankPosition: 247,
        name: 'You',
        rankTitle: userRank,
        xp: userXP,
        imageUrl: userAvatarUrl,
        isCurrentUser: true,
      ),
    ];
  }
}
