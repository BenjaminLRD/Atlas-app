import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/activity_item.dart';
import '../models/friendship.dart';
import '../models/leaderboard_entry.dart';
import '../providers/fitness_provider.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/app_image.dart';
import '../widgets/social/referral_card.dart';
import '../widgets/social/friend_challenge_card.dart';
import '../widgets/social/community_event_card.dart';
import '../screens/public_profile_screen.dart';
import '../services/social_service.dart';
import '../services/growth_analytics_service.dart';

/// Screen dedicated to social activity sharing, friend connections, and request management.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  int _selectedTab = 0; // 0: Feed, 1: Friends, 2: Requests
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FitnessProvider.instance.loadFriends();
      FitnessProvider.instance.loadActivityFeed();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FitnessProvider.instance,
      builder: (context, _) {
        final provider = FitnessProvider.instance;
        final friends = provider.friends;
        final requests = provider.friendRequests;
        final feed = provider.activityFeed;

        return Scaffold(
          backgroundColor: context.appBackground,
          body: SafeArea(
            child: Column(
              children: [
                AppHeader.standard(
                  title: 'Community & Friends',
                  subtitle: '${friends.length} Friends • ${requests.length} Requests',
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: _buildSearchBar(context),
                ),
                _buildTabSelector(context, pendingCount: requests.length),
                const SizedBox(height: 8),
                Expanded(
                  child: IndexedStack(
                    index: _selectedTab,
                    children: [
                      _buildActivityFeedTab(context, feed: feed, provider: provider),
                      _buildFriendsTab(context, friends: friends, searchQuery: _searchQuery, provider: provider),
                      _buildRequestsTab(context, requests: requests, provider: provider),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final isDark = context.isDarkMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val.trim()),
        style: TextStyle(fontSize: 13, color: context.appTextPrimary),
        decoration: InputDecoration(
          icon: Icon(Icons.search_rounded, size: 20, color: context.appTextSecondary),
          border: InputBorder.none,
          hintText: 'Search gym members by name...',
          hintStyle: TextStyle(fontSize: 13, color: context.appTextSecondary),
        ),
      ),
    );
  }

  Widget _buildTabSelector(BuildContext context, {required int pendingCount}) {
    final isDark = context.isDarkMode;
    final tabs = ['Activity Feed', 'Friends', 'Requests ($pendingCount)'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.4) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final idx = entry.key;
          final label = entry.value;
          final isSelected = _selectedTab == idx;

          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = idx),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? context.appTextPrimary : context.appTextSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActivityFeedTab(
    BuildContext context, {
    required List<ActivityItem> feed,
    required FitnessProvider provider,
  }) {
    return RefreshIndicator(
      onRefresh: () => provider.loadActivityFeed(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 1. Active Gym Community Event Banner
            const CommunityEventCard(),
            const SizedBox(height: 14),

            // 2. 1v1 Friend Challenge Card
            const FriendChallengeCard(),
            const SizedBox(height: 14),

            // 3. Referral Program Card
            const ReferralCard(),
            const SizedBox(height: 16),

            // 4. Activity Feed Items Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'COMMUNITY ACTIVITY',
                  style: AppTheme.headlineMd.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  '${feed.length} Updates',
                  style: AppTheme.bodySm.copyWith(fontSize: 11, color: context.appTextSecondary),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (feed.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'No activity updates yet.',
                  style: TextStyle(color: context.appTextSecondary, fontSize: 13),
                ),
              )
            else
              ...feed.map((item) => _buildActivityCard(context, item)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(BuildContext context, ActivityItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildActivityIcon(item.type),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.appTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.appTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatTimeAgo(item.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(height: 1, color: context.appOutlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 8),

            // Activity Reactions Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _buildReactionButton(context, item, 'like', '👍', item.reactions['like'] ?? 0),
                    const SizedBox(width: 6),
                    _buildReactionButton(context, item, 'fire', '🔥', item.reactions['fire'] ?? 0),
                    const SizedBox(width: 6),
                    _buildReactionButton(context, item, 'respect', '💪', item.reactions['respect'] ?? 0),
                    const SizedBox(width: 6),
                    _buildReactionButton(context, item, 'legendary', '🏆', item.reactions['legendary'] ?? 0),
                  ],
                ),

                // Comment Action Button
                GestureDetector(
                  onTap: () {
                    SocialService.instance.addComment(item.id);
                    GrowthAnalyticsService.instance.trackCommunityInteraction(interactionType: 'comment');
                    setState(() {});
                  },
                  child: Row(
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 14, color: context.appTextSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${item.commentsCount}',
                        style: AppTheme.bodySm.copyWith(fontSize: 11, color: context.appTextSecondary, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionButton(BuildContext context, ActivityItem item, String key, String emoji, int count) {
    final isSelected = item.userReaction == key;

    return GestureDetector(
      onTap: () async {
        await SocialService.instance.toggleReaction(item.id, key);
        GrowthAnalyticsService.instance.trackCommunityInteraction(interactionType: key);
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.2) : context.appSurfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: AppColors.primary, width: 1) : null,
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: AppTheme.bodySm.copyWith(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected ? AppColors.primary : context.appTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityIcon(String type) {
    IconData icon;
    Color color;

    switch (type.toLowerCase()) {
      case 'workout':
        icon = Icons.fitness_center_rounded;
        color = AppColors.primaryContainer;
        break;
      case 'rank_up':
        icon = Icons.military_tech_rounded;
        color = Colors.amber;
        break;
      case 'achievement':
        icon = Icons.emoji_events_rounded;
        color = Colors.purple;
        break;
      case 'challenge':
      default:
        icon = Icons.flag_rounded;
        color = Colors.blue;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  // --- TAB 2: FRIENDS LIST ---
  Widget _buildFriendsTab(
    BuildContext context, {
    required List<LeaderboardEntry> friends,
    required String searchQuery,
    required FitnessProvider provider,
  }) {
    final filtered = searchQuery.isEmpty
        ? friends
        : friends
            .where((f) => f.displayName.toLowerCase().contains(searchQuery.toLowerCase()))
            .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_outlined, color: context.appTextSecondary, size: 40),
            const SizedBox(height: 8),
            Text(
              searchQuery.isEmpty ? 'No friends added yet.' : 'No members found matching "$searchQuery"',
              style: TextStyle(color: context.appTextSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final friend = filtered[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => PublicProfileScreen.showModal(context, friend),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  AppImage.avatar(
                    imageUrl: friend.avatarUrl,
                    name: friend.displayName,
                    radius: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friend.displayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.appTextPrimary,
                          ),
                        ),
                        Text(
                          '${friend.rankTitle} • ${friend.totalXP} XP',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- TAB 3: PENDING REQUESTS ---
  Widget _buildRequestsTab(
    BuildContext context, {
    required List<Friendship> requests,
    required FitnessProvider provider,
  }) {
    if (requests.isEmpty) {
      return Center(
        child: Text(
          'No pending friend requests.',
          style: TextStyle(color: context.appTextSecondary, fontSize: 13),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                AppImage.avatar(
                  name: 'Gym Member',
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Friend Request',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.appTextPrimary,
                        ),
                      ),
                      Text(
                        'Wants to connect with you',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => provider.acceptFriendRequest(req.id),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Accept', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
