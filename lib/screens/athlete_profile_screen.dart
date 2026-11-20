import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/activity_post.dart';
import '../models/athlete_profile.dart';
import '../services/community/profile_resolver.dart';
import '../services/community/sample_world.dart';
import '../services/growth_analytics_service.dart';
import '../services/social_graph_service.dart';
import '../services/community/post_media.dart';
import '../widgets/common/app_image.dart';
import '../widgets/community/post_media_view.dart';
import '../widgets/community/community_avatar_helper.dart';
import '../widgets/profile_picture.dart';
import 'edit_profile_screen.dart';
import 'new_challenge_screen.dart';
import 'post_detail_screen.dart';

/// Profile of one athlete: header with counts, highlights, and Posts, PRs and
/// About tabs.
///
/// Only information the athlete actually provided is shown. Sample athletes
/// are always labelled as demo content (see [AthleteProfile.isSample]).
/// Followers and following are not shown because no such data exists.
class AthleteProfileScreen extends StatefulWidget {
  final String userId;
  final String name;
  final String? avatarUrl;
  final String? rank;

  const AthleteProfileScreen({
    super.key,
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.rank,
  });

  static Future<void> open(
    BuildContext context, {
    required String userId,
    required String name,
    String? avatarUrl,
    String? rank,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AthleteProfileScreen(
          userId: userId,
          name: name,
          avatarUrl: avatarUrl,
          rank: rank,
        ),
      ),
    );
  }

  @override
  State<AthleteProfileScreen> createState() => _AthleteProfileScreenState();
}

enum _ProfileError { failed, notFound }

enum _Tab { posts, prs, about }

class _AthleteProfileScreenState extends State<AthleteProfileScreen> {
  AthleteProfile? _profile;
  _ProfileError? _error;
  List<ActivityPost> _posts = const [];
  bool _postsComplete = true;
  bool _postsLoading = true;
  bool _postsFailed = false;
  late bool _isFollowing;
  _Tab _tab = _Tab.posts;
  ActivityPostType? _typeFilter;

  @override
  void initState() {
    super.initState();
    _isFollowing = SocialGraphService.instance.isFollowing(widget.userId);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _postsLoading = true;
      _postsFailed = false;
      _error = null;
    });
    final AthleteProfile profile;
    try {
      profile = await ProfileResolver.resolve(
        userId: widget.userId,
        name: widget.name,
        avatarUrl: widget.avatarUrl,
        rank: widget.rank,
      );
    } on ProfileNotFound {
      if (mounted) setState(() => _error = _ProfileError.notFound);
      return;
    } catch (_) {
      if (mounted) setState(() => _error = _ProfileError.failed);
      return;
    }
    if (!mounted) return;
    setState(() => _profile = profile);
    try {
      final result = await ProfileResolver.postsFor(profile);
      if (!mounted) return;
      setState(() {
        _posts = result.posts;
        _postsComplete = result.complete;
        _postsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _postsLoading = false;
        _postsFailed = true;
      });
    }
  }

  Future<void> _toggleFollow() async {
    final status = await SocialGraphService.instance.toggleFollow(
      widget.userId,
    );
    GrowthAnalyticsService.instance.trackCommunityInteraction(
      interactionType: 'follow_toggle',
    );
    if (!mounted) return;
    setState(() => _isFollowing = status);
    final name = _profile?.displayName ?? widget.name;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(status ? 'Following $name' : 'Unfollowed $name'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Sample athletes only. Challenges between real people need backend
  /// support and are not offered yet.
  Future<void> _challenge() async {
    final name = _profile?.displayName ?? widget.name;
    final key = SampleWorld.byId(widget.userId)?.key;
    if (key == null) return;
    final id = await NewChallengeScreen.open(context, opponentKey: key);
    if (id != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Challenge started with $name (sample).')),
      );
    }
  }

  void _openPost(ActivityPost post) {
    PostDetailScreen.open(
      context,
      post: post,
      onPostUpdated: (updated) {
        if (!mounted) return;
        setState(() {
          _posts = [for (final p in _posts) p.id == updated.id ? updated : p];
        });
      },
    );
  }

  void _goTo(_Tab tab, {ActivityPostType? filter}) {
    setState(() {
      _tab = tab;
      _typeFilter = filter;
    });
  }

  bool _hasPostsOfType(ActivityPostType type) =>
      _posts.any((p) => p.type == type);

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: Text(
          profile?.username ?? 'Profile',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: context.appSurface,
        elevation: 0,
      ),
      body: _error != null
          ? _errorView(_error!)
          : profile == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    children: [
                      _header(profile),
                      const SizedBox(height: 12),
                      _actions(profile),
                      ..._highlights(profile),
                      const SizedBox(height: 8),
                      _tabBar(profile),
                      const SizedBox(height: 12),
                      _tabBody(profile),
                      if (profile.isSample) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Sample athlete. Demo content, not a real member.',
                          key: const Key('sample_profile_note'),
                          textAlign: TextAlign.center,
                          style: AppTheme.bodySm.copyWith(
                            color: context.appTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _errorView(_ProfileError error) {
    final failed = error == _ProfileError.failed;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              failed ? Icons.wifi_off_rounded : Icons.person_off_rounded,
              size: 44,
              color: context.appTextSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              failed
                  ? 'Could not load this profile'
                  : 'This account is not available',
              key: Key(failed ? 'profile_load_failed' : 'profile_not_found'),
              textAlign: TextAlign.center,
              style: AppTheme.headlineSm.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              failed
                  ? 'Check your connection and try again.'
                  : 'It may have been deleted, or it was never created here.',
              textAlign: TextAlign.center,
              style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
            ),
            if (failed) ...[
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('RETRY')),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- header
  Widget _header(AthleteProfile profile) {
    final accent = context.appPrimary;
    final postsReady = !_postsLoading && !_postsFailed;
    final postsValue = postsReady
        ? '${_posts.length}${_postsComplete ? '' : '+'}'
        : '--';
    final counts = <Widget>[
      _count('POSTS', postsValue, key: const Key('profile_posts_count')),
      if (profile.isSample) ...[
        _count('PRS', '${profile.prs.length}'),
        _count('WORKOUTS', '${profile.workoutCount ?? '--'}'),
      ] else if (profile.isSelf) ...[
        _count(
          'WORKOUTS',
          profile.workoutCount?.toString() ?? '--',
          key: const Key('profile_workouts_count'),
        ),
        _count(
          'DAY STREAK',
          profile.streakDays?.toString() ?? '--',
          key: const Key('profile_streak_count'),
        ),
      ],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _avatar(profile, accent),
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [for (final c in counts) Flexible(child: c)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          profile.displayName,
          style: AppTheme.headlineLg.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: context.appTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (profile.rankTitle != null)
              _pill(profile.rankTitle!, context.appTextPrimary),
            if (profile.isSample)
              _pill(
                'SAMPLE ATHLETE',
                context.appTextSecondary,
                outlined: true,
                key: const Key('sample_profile_badge'),
              ),
          ],
        ),
        if (profile.hasBio) ...[
          const SizedBox(height: 8),
          Text(
            profile.bio!,
            style: AppTheme.bodySm.copyWith(
              color: context.appTextPrimary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _count(String label, String value, {Key? key}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          key: key,
          style: AppTheme.headlineSm.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.appTextPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          style: AppTheme.labelCaps.copyWith(
            fontSize: 10,
            color: context.appTextSecondary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  Widget _avatar(AthleteProfile profile, Color accent) {
    const radius = 40.0;
    if (profile.isSample) {
      return CommunityAvatarHelper.buildAvatar(
        userId: profile.userId,
        userName: profile.displayName,
        avatarUrl: profile.avatarUrl,
        radius: radius,
        borderWidth: 2,
        borderColor: accent.withValues(alpha: 0.7),
      );
    }
    final picture = profile.isSelf
        ? ProfileImage(
            path: profile.localAvatarPath,
            size: radius * 2,
            iconSize: radius * 0.8,
          )
        : AppImage.avatar(
            imageUrl: profile.avatarUrl,
            radius: radius,
            name: profile.displayName,
          );
    return Container(
      width: radius * 2 + 4,
      height: radius * 2 + 4,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent.withValues(alpha: 0.7), width: 2),
      ),
      alignment: Alignment.center,
      child: ClipOval(child: picture),
    );
  }

  // ------------------------------------------------------------ actions
  Widget _actions(AthleteProfile profile) {
    if (profile.isSelf) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const EditProfileScreen(),
              ),
            );
            if (mounted) _load();
          },
          icon: const Icon(Icons.edit_rounded, size: 16),
          label: const Text('EDIT PROFILE'),
          style: _outlinedStyle(),
        ),
      );
    }
    final follow = ElevatedButton.icon(
      onPressed: _toggleFollow,
      icon: Icon(
        _isFollowing ? Icons.check_rounded : Icons.person_add_alt_1_rounded,
        size: 16,
      ),
      label: Text(_isFollowing ? 'FOLLOWING' : 'FOLLOW'),
      style: _primaryStyle(_isFollowing),
    );
    if (!profile.isSample) {
      return SizedBox(width: double.infinity, child: follow);
    }
    return Row(
      children: [
        Expanded(child: follow),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _challenge,
            icon: const Icon(
              Icons.emoji_events_rounded,
              size: 16,
              color: Color(0xFFF59E0B),
            ),
            label: const Text('CHALLENGE'),
            style: _outlinedStyle(),
          ),
        ),
      ],
    );
  }

  ButtonStyle _primaryStyle(bool muted) => ElevatedButton.styleFrom(
    elevation: 0,
    backgroundColor: muted ? context.appSurfaceVariant : AppColors.primary,
    foregroundColor: muted ? context.appTextPrimary : Colors.white,
    minimumSize: const Size(0, 48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );

  ButtonStyle _outlinedStyle() => OutlinedButton.styleFrom(
    foregroundColor: context.appTextPrimary,
    minimumSize: const Size(0, 48),
    side: BorderSide(color: context.appOutlineVariant.withValues(alpha: 0.7)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );

  // --------------------------------------------------------- highlights
  /// In-profile shortcuts. Each lands on a tab or a filtered posts grid, and
  /// only appears when there is something to show.
  List<Widget> _highlights(AthleteProfile profile) {
    final items = <_Highlight>[
      if (profile.prs.isNotEmpty)
        _Highlight(
          'hl_prs',
          Icons.emoji_events_rounded,
          'PRs',
          () => _goTo(_Tab.prs),
        ),
      if (profile.isSelf && (profile.streakDays ?? 0) > 0)
        _Highlight(
          'hl_streak',
          Icons.local_fire_department_rounded,
          'Streak',
          () => _goTo(_Tab.about),
        ),
      if (profile.isSelf && (profile.badgeCount ?? 0) > 0)
        _Highlight(
          'hl_badges',
          Icons.military_tech_rounded,
          'Badges',
          () => _goTo(_Tab.about),
        ),
      if (profile.isSample && profile.milestones.isNotEmpty)
        _Highlight(
          'hl_milestones',
          Icons.flag_rounded,
          'Milestones',
          () => _goTo(_Tab.about),
        ),
      if (_hasPostsOfType(ActivityPostType.meal))
        _Highlight(
          'hl_meals',
          Icons.restaurant_rounded,
          'Meals',
          () => _goTo(_Tab.posts, filter: ActivityPostType.meal),
        ),
      if (_hasPostsOfType(ActivityPostType.routine))
        _Highlight(
          'hl_routines',
          Icons.list_alt_rounded,
          'Routines',
          () => _goTo(_Tab.posts, filter: ActivityPostType.routine),
        ),
    ];
    if (items.isEmpty) return const [];
    return [
      const SizedBox(height: 16),
      SizedBox(
        height: 78,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (_, i) {
            final h = items[i];
            return GestureDetector(
              key: Key(h.key),
              onTap: h.onTap,
              child: SizedBox(
                width: 62,
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: context.appPrimary.withValues(alpha: 0.8),
                          width: 1.5,
                        ),
                        color: context.appSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      child: Icon(h.icon, color: context.appPrimary, size: 22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      h.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 11,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  // --------------------------------------------------------------- tabs
  List<_Tab> _tabsFor(AthleteProfile profile) => [
    _Tab.posts,
    if (profile.prs.isNotEmpty || profile.isSelf) _Tab.prs,
    _Tab.about,
  ];

  Widget _tabBar(AthleteProfile profile) {
    final tabs = _tabsFor(profile);
    final current = tabs.contains(_tab) ? _tab : _Tab.posts;
    String label(_Tab t) => switch (t) {
      _Tab.posts => 'POSTS',
      _Tab.prs => 'PRS',
      _Tab.about => 'ABOUT',
    };
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: context.appOutlineVariant.withValues(alpha: 0.3),
          ),
          bottom: BorderSide(
            color: context.appOutlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          for (final t in tabs)
            Expanded(
              child: InkWell(
                key: Key('profile_tab_${t.name}'),
                onTap: () => _goTo(t),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: t == current
                            ? context.appPrimary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    label(t),
                    textAlign: TextAlign.center,
                    style: AppTheme.labelCaps.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: t == current
                          ? context.appPrimary
                          : context.appTextSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tabBody(AthleteProfile profile) {
    final tabs = _tabsFor(profile);
    final current = tabs.contains(_tab) ? _tab : _Tab.posts;
    return switch (current) {
      _Tab.posts => _postsTab(),
      _Tab.prs => _prsTab(profile),
      _Tab.about => _aboutTab(profile),
    };
  }

  // -------------------------------------------------------------- posts
  Widget _postsTab() {
    if (_postsLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_postsFailed) {
      return _panel(
        child: Column(
          children: [
            Text(
              'Could not load posts.',
              style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
            ),
            TextButton(onPressed: _load, child: const Text('RETRY')),
          ],
        ),
      );
    }
    if (_posts.isEmpty) {
      return _panel(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'No posts yet.',
            key: const Key('profile_no_posts'),
            style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
          ),
        ),
      );
    }
    final shown = _typeFilter == null
        ? _posts
        : _posts.where((p) => p.type == _typeFilter).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_typeFilter != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InputChip(
              key: const Key('profile_filter_chip'),
              label: Text('Showing: ${_typeFilter!.displayName}'),
              onDeleted: () => setState(() => _typeFilter = null),
            ),
          ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: shown.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
          ),
          itemBuilder: (_, i) => _tile(shown[i]),
        ),
      ],
    );
  }

  Widget _tile(ActivityPost post) {
    final hasImage = post.images.isNotEmpty;
    return GestureDetector(
      key: Key('profile_post_${post.id}'),
      onTap: () => _openPost(post),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: hasImage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  PostImage(post.images.first),
                  if (PostMedia.isVideo(post))
                    const Positioned(
                      top: 6,
                      right: 6,
                      child: Icon(
                        Icons.videocam_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                ],
              )
            : Container(
                padding: const EdgeInsets.all(8),
                color: context.appSurfaceVariant.withValues(alpha: 0.65),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(post.type.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 4),
                    Text(
                      post.title.isNotEmpty
                          ? post.title
                          : post.type.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: context.appTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  // ---------------------------------------------------------------- PRs
  String _ago(DateTime? d) {
    if (d == null) return '';
    final days = DateTime.now().difference(d).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 30) return '$days days ago';
    final months = days ~/ 30;
    return months == 1 ? '1 month ago' : '$months months ago';
  }

  Widget _prsTab(AthleteProfile profile) {
    if (profile.prs.isEmpty) {
      return _panel(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'No personal records yet. They appear here when a workout sets one.',
            key: const Key('profile_no_prs'),
            textAlign: TextAlign.center,
            style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final pr in profile.prs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _panel(
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    size: 20,
                    color: Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      pr.exercise,
                      style: AppTheme.bodySm.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (pr.value.isNotEmpty || pr.achievedAt != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (pr.value.isNotEmpty)
                          Text(
                            pr.value,
                            style: AppTheme.bodySm.copyWith(
                              color: context.appPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        if (pr.achievedAt != null)
                          Text(
                            _ago(pr.achievedAt),
                            style: AppTheme.bodySm.copyWith(
                              color: context.appTextSecondary,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------------- about
  Widget _aboutTab(AthleteProfile profile) {
    if (!profile.isSample &&
        !profile.isSelf &&
        profile.infoState == ProfileInfoState.notShared) {
      return _panel(
        child: Text(
          "This member hasn't shared a bio or fitness details. Their posts are in the Posts tab.",
          key: const Key('profile_not_shared'),
          style: AppTheme.bodySm.copyWith(
            color: context.appTextSecondary,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      );
    }
    final facts = <FitnessFact>[
      ...profile.fitness,
      if (profile.location != null) FitnessFact('Location', profile.location!),
      if (profile.memberSince != null)
        FitnessFact('Member', profile.memberSince!),
      if (profile.isSelf) ...[
        if (profile.workoutCount != null)
          FitnessFact('Workouts logged', '${profile.workoutCount}'),
        if (profile.streakDays != null)
          FitnessFact('Current streak', '${profile.streakDays} days'),
        if (profile.badgeCount != null)
          FitnessFact('Badges unlocked', '${profile.badgeCount}'),
      ],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!profile.hasBio && profile.isSelf)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _panel(
              child: Text(
                'Add a short bio in Edit profile so others know who you are.',
                key: const Key('profile_add_bio'),
                style: AppTheme.bodySm.copyWith(
                  color: context.appTextSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        if (facts.isNotEmpty) _panel(child: _factList(facts)),
        if (profile.milestones.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionHeader('MILESTONES'),
          const SizedBox(height: 8),
          _panel(
            child: Column(
              children: [
                for (final m in profile.milestones)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.flag_rounded,
                          size: 16,
                          color: context.appPrimary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            m,
                            style: AppTheme.bodySm.copyWith(
                              color: context.appTextPrimary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (profile.isSelf) ...[
          const SizedBox(height: 16),
          Text(
            'Other members currently see only your name, rank and posts.',
            key: const Key('profile_visibility_note'),
            style: AppTheme.bodySm.copyWith(
              color: context.appTextSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _factList(List<FitnessFact> facts) {
    return Column(
      children: [
        for (var i = 0; i < facts.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                facts[i].label,
                style: AppTheme.bodySm.copyWith(
                  color: context.appTextSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  facts[i].value,
                  textAlign: TextAlign.end,
                  style: AppTheme.bodySm.copyWith(
                    color: context.appTextPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ------------------------------------------------------------ helpers
  Widget _panel({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(12),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: context.appSurfaceVariant.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.appOutlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: child,
    );
  }

  Widget _pill(String text, Color color, {bool outlined = false, Key? key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: outlined
            ? null
            : context.appSurfaceVariant.withValues(alpha: 0.8),
        border: outlined ? Border.all(color: color) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: AppTheme.bodySm.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: AppTheme.labelCaps.copyWith(
          fontSize: 11,
          color: context.appTextSecondary,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _Highlight {
  final String key;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Highlight(this.key, this.icon, this.label, this.onTap);
}
