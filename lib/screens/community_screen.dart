import 'package:flutter/material.dart';
import '../services/community/community_cloud_repository.dart';
import '../services/community/sample_community.dart';
import '../app_theme.dart';
import '../data/local_storage.dart';
import '../models/activity_post.dart';
import '../models/social_profile.dart';
import '../providers/showcase_mode_provider.dart';
import '../services/achievement_service.dart';
import '../services/moderation_service.dart';
import '../services/social/community_insights_service.dart';
import '../services/social_graph_service.dart';
import '../widgets/common/app_card.dart';
import '../widgets/community/create_post_modal.dart';
import '../widgets/community/post_card.dart';
import '../widgets/community/challenges_tab.dart';
import '../widgets/community/rankings_tab.dart';

enum CommunityFeedFilter {
  all('All', null),
  trending('🔥 Trending', null),
  following('👥 Following', null),
  prs('🏆 PRs & Records', ActivityPostType.achievement),
  meals('🍱 Meal Prep', ActivityPostType.meal),
  workouts('🏋️ Workouts', ActivityPostType.workout),
  cardio('🏃 Run & Ride', ActivityPostType.cardio),
  programs('📋 Splits', ActivityPostType.routine),
  transformations('💪 Transformations', ActivityPostType.transformation);

  final String label;
  final ActivityPostType? targetType;
  const CommunityFeedFilter(this.label, this.targetType);
}

/// Upgraded Social Fitness Hub with 4 Tabs: Feed, Rankings, Challenges, Badges.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CommunityFeedFilter _selectedFilter = CommunityFeedFilter.all;

  List<ActivityPost> _allPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    ShowcaseModeProvider.instance.addListener(_onShowcaseChanged);
    _loadData();
  }

  @override
  void dispose() {
    ShowcaseModeProvider.instance.removeListener(_onShowcaseChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onShowcaseChanged() {
    if (mounted) {
      _loadData();
    }
  }

  void _loadData() {
    final isShowcase = ShowcaseModeProvider.instance.isShowcaseModeEnabled;
    final userPosts = LocalStorage.getCommunityPosts();

    // The user's own posts first, then the labelled sample community, so a
    // new account never sees an empty feed. Sample posts stay flagged and are
    // never mixed into the user's own records.
    final combined = [...userPosts, ...SampleCommunity.posts()];

    // Deduplicate by ID
    final seen = <String>{};
    final uniquePosts = combined.where((p) => seen.add(p.id)).toList();
    final filtered = ModerationService.instance.filterModeratedPosts(
      uniquePosts,
    );

    setState(() {
      _allPosts = filtered;
      _isLoading = false;
    });

    if (!isShowcase && CommunityCloudRepository.isActive) {
      _loadCloudFeed();
    }
  }

  /// Real community feed for signed-in users.
  Future<void> _loadCloudFeed() async {
    try {
      final posts = await CommunityCloudRepository.instance.fetchFeed();
      if (!mounted) return;
      setState(() {
        _allPosts = ModerationService.instance.filterModeratedPosts([
          ...posts,
          ...SampleCommunity.posts(),
        ]);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load the community feed. Pull to refresh.'),
        ),
      );
    }
  }

  List<ActivityPost> get _displayedPosts {
    final followingIds = SocialGraphService.instance
        .getFollowingUserIds()
        .toSet();

    switch (_selectedFilter) {
      case CommunityFeedFilter.all:
        return _allPosts;
      case CommunityFeedFilter.trending:
        final list = List<ActivityPost>.from(_allPosts);
        list.sort(
          (a, b) => (b.likes + b.comments * 2 + b.savesCount * 3).compareTo(
            a.likes + a.comments * 2 + a.savesCount * 3,
          ),
        );
        return list;
      case CommunityFeedFilter.following:
        return _allPosts
            .where(
              (p) => followingIds.contains(p.userId) || p.userId == 'usr_local',
            )
            .toList();
      case CommunityFeedFilter.prs:
      case CommunityFeedFilter.meals:
      case CommunityFeedFilter.workouts:
      case CommunityFeedFilter.cardio:
      case CommunityFeedFilter.programs:
      case CommunityFeedFilter.transformations:
        return _allPosts
            .where((p) => p.type == _selectedFilter.targetType)
            .toList();
    }
  }

  void _openCreatePost() {
    CreatePostModal.show(
      context,
      onPostCreated: (newPost) {
        setState(() {
          _allPosts.insert(0, newPost);
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: const Text(
          'Community Hub',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        backgroundColor: context.appSurface,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: context.appTextSecondary,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
          tabs: const [
            Tab(text: 'Feed', icon: Icon(Icons.dynamic_feed_rounded, size: 18)),
            Tab(
              text: 'Rankings',
              icon: Icon(Icons.leaderboard_rounded, size: 18),
            ),
            Tab(
              text: 'Challenges',
              icon: Icon(Icons.emoji_events_rounded, size: 18),
            ),
            Tab(
              text: 'Badges',
              icon: Icon(Icons.military_tech_rounded, size: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.primary,
              size: 24,
            ),
            tooltip: 'Create Post',
            onPressed: _openCreatePost,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFeedTab(),
                _buildRankingsTab(),
                _buildChallengesTab(),
                _buildAchievementsTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreatePost,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text(
          'CREATE POST',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: COMMUNITY FEED
  // -------------------------------------------------------------
  Widget _buildFeedTab() {
    final posts = _displayedPosts;
    final isShowcase = ShowcaseModeProvider.instance.isShowcaseModeEnabled;
    final insight = isShowcase
        ? CommunityInsightsService.instance.generateCommunityMilestoneSummary()
        : 'Welcome to the Atlas Community! Posts marked SAMPLE are demo content, not real members.';

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: CustomScrollView(
        slivers: [
          // AI Community Insight Banner
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.insights_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      insight,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.appTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Filter Chips
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: CommunityFeedFilter.values.map((filter) {
                    final isSelected = filter == _selectedFilter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter.label),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : context.appTextPrimary,
                        ),
                        backgroundColor: context.appSurfaceVariant,
                        onSelected: (val) {
                          if (val) setState(() => _selectedFilter = filter);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // Posts List or Clean Empty State
          if (posts.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.12),
                        ),
                        child: const Icon(
                          Icons.dynamic_feed_outlined,
                          size: 48,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No posts yet',
                        style: AppTheme.headlineSm.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: context.appTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Follow the community and share your first workout, meal, or fitness win.',
                        textAlign: TextAlign.center,
                        style: AppTheme.bodySm.copyWith(
                          color: context.appTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _openCreatePost,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('SHARE POST'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((ctx, i) {
                  final post = posts[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PostCard(
                      key: ValueKey(post.id),
                      post: post,
                      onPostUpdated: (updated) {
                        setState(() {
                          final idx = _allPosts.indexWhere(
                            (p) => p.id == updated.id,
                          );
                          if (idx != -1) _allPosts[idx] = updated;
                        });
                      },
                      onPostHidden: () => _loadData(),
                    ),
                  );
                }, childCount: posts.length),
              ),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: RANKINGS (real week and sample leaderboard, see RankingsTab)
  // -------------------------------------------------------------
  Widget _buildRankingsTab() {
    return RankingsTab(
      startOnSample: ShowcaseModeProvider.instance.isShowcaseModeEnabled,
    );
  }

  // -------------------------------------------------------------
  // TAB 3: CHALLENGES (your own, see ChallengesTab)
  // -------------------------------------------------------------
  Widget _buildChallengesTab() => const ChallengesTab();

  // -------------------------------------------------------------
  // TAB 4: ACHIEVEMENTS & BADGES
  // -------------------------------------------------------------
  Widget _buildAchievementsTab() {
    final achievements = AchievementService.getAllAchievements();
    final isShowcase = ShowcaseModeProvider.instance.isShowcaseModeEnabled;
    final rank = isShowcase
        ? SocialAthleteRank.ironWarrior
        : SocialAthleteRank.beginner;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Rank Card
          AppCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.2),
                  child: Text(rank.icon, style: const TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rank.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isShowcase
                            ? 'Rank Tier 3 • 8,450 XP Earned'
                            : 'Rank Tier 1 • 0 XP Earned',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: isShowcase ? 0.56 : 0.0,
                          minHeight: 6,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isShowcase
                            ? '6,550 XP to Elite 👑'
                            : '1,000 XP to Rising Athlete ⚡',
                        style: TextStyle(
                          fontSize: 10,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'UNLOCKED BADGES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 10),

          // Badges Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: achievements.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.6,
            ),
            itemBuilder: (context, index) {
              final ach = achievements[index];
              return AppCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(ach.iconData, color: AppColors.primary, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            ach.title,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            ach.rarity,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFFFD700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
