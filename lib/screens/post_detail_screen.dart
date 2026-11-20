import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/activity_post.dart';
import '../models/post_comment.dart';
import '../services/community/post_engagement.dart';
import '../services/saved_content_service.dart';
import '../services/community/post_media.dart';
import '../widgets/community/post_media_view.dart';
import '../widgets/community/community_avatar_helper.dart';
import '../widgets/community/cardio_post_card.dart';
import '../widgets/community/meal_post_card.dart';
import '../widgets/community/pr_post_card.dart';
import '../widgets/community/routine_post_card.dart';
import '../widgets/community/workout_post_card.dart';
import 'athlete_profile_screen.dart';

/// One post on its own page: media, caption, likes, comments and a comment
/// box. Sample posts are labelled and keep their likes and comments on this
/// device only (see [PostEngagement]).
class PostDetailScreen extends StatefulWidget {
  final ActivityPost post;

  /// Called with the latest post whenever the like or comments change, so the
  /// feed or profile that opened this page can stay in sync.
  final ValueChanged<ActivityPost>? onPostUpdated;

  const PostDetailScreen({super.key, required this.post, this.onPostUpdated});

  static Future<void> open(
    BuildContext context, {
    required ActivityPost post,
    ValueChanged<ActivityPost>? onPostUpdated,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PostDetailScreen(post: post, onPostUpdated: onPostUpdated),
      ),
    );
  }

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late ActivityPost _post;
  late List<PostComment> _comments;
  late bool _saved;
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _pageController = PageController();
  int _page = 0;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _comments = PostEngagement.localComments(_post);
    _saved = SavedContentService.instance.isSaved(_post.id);
    if (PostEngagement.isCloudPost(_post)) {
      PostEngagement.cloudComments(_post)
          .then((c) {
            if (mounted) setState(() => _comments = c);
          })
          .catchError((_) {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _publish() {
    final updated = _post.copyWith(
      commentsList: _comments,
      comments: _comments.length,
    );
    _post = updated;
    widget.onPostUpdated?.call(updated);
  }

  void _toggleLike() {
    final liked = !_post.isLiked;
    setState(() {
      _post = _post.copyWith(
        isLiked: liked,
        likes: (_post.likes + (liked ? 1 : -1)).clamp(0, 1 << 30),
      );
    });
    widget.onPostUpdated?.call(_post);
    PostEngagement.persistLike(_post).catchError((_) {
      if (!mounted) return;
      setState(() {
        _post = _post.copyWith(
          isLiked: !liked,
          likes: (_post.likes + (liked ? -1 : 1)).clamp(0, 1 << 30),
        );
      });
      widget.onPostUpdated?.call(_post);
    });
  }

  Future<void> _toggleSave() async {
    final saved = await SavedContentService.instance.toggleSave(_post);
    if (mounted) setState(() => _saved = saved);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final comment = await PostEngagement.addComment(_post, text);
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, comment];
        _sending = false;
      });
      _controller.clear();
      _publish();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your comment could not be posted.')),
      );
    }
  }

  void _openProfile(String userId, String name, String? avatar, String rank) {
    AthleteProfileScreen.open(
      context,
      userId: userId,
      name: CommunityAvatarHelper.displayNameFor(userId, name),
      avatarUrl: CommunityAvatarHelper.isShowcaseSelf(userId) ? null : avatar,
      rank: rank,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: const Text(
          'Post',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        backgroundColor: context.appSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: [
                      _author(),
                      const SizedBox(height: 12),
                      _media(),
                      _actions(),
                      const SizedBox(height: 10),
                      _caption(),
                      _richBody(),
                      const SizedBox(height: 20),
                      _commentsSection(),
                    ],
                  ),
                ),
                _inputBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _author() {
    final p = _post;
    return InkWell(
      key: const Key('post_detail_author'),
      onTap: () => _openProfile(p.userId, p.userName, p.userAvatar, p.userRank),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          CommunityAvatarHelper.buildAvatar(
            userId: p.userId,
            userName: p.userName,
            avatarUrl: p.userAvatar,
            radius: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      CommunityAvatarHelper.displayNameFor(
                        p.userId,
                        p.userName,
                      ),
                      style: AppTheme.headlineSm.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.appTextPrimary,
                      ),
                    ),
                    if (p.isSample)
                      Container(
                        key: const Key('post_detail_sample_badge'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: context.appTextSecondary),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'SAMPLE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        p.userRank,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${p.type.emoji} ${p.type.displayName} • ${p.timeAgo}',
                  style: AppTheme.bodySm.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _media() {
    final images = _post.images;
    if (images.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(
            children: [
              PageView.builder(
                key: const Key('post_detail_media'),
                controller: _pageController,
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final video = PostMedia.isVideo(_post) && i == 0;
                  final image = PostImage(
                    images[i],
                    borderRadius: 0,
                    width: double.infinity,
                    height: double.infinity,
                  );
                  if (!video) return image;
                  return GestureDetector(
                    key: const Key('post_detail_video'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => openPostVideo(context, _post),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        image,
                        const Center(child: VideoPlayBadge(size: 64)),
                      ],
                    ),
                  );
                },
              ),
              if (images.length > 1)
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < images.length; i++)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _page
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actions() {
    final liked = _post.isLiked;
    final likeColor = liked
        ? const Color(0xFFEF4444)
        : context.appTextSecondary;
    return Row(
      children: [
        InkWell(
          key: const Key('post_detail_like'),
          onTap: _toggleLike,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              children: [
                Icon(
                  liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: likeColor,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_post.likes}',
                  key: const Key('post_detail_like_count'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: likeColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                color: context.appTextSecondary,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                '${_comments.length}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: _toggleSave,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              children: [
                Icon(
                  _saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: _saved ? AppColors.primary : context.appTextSecondary,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  _saved ? 'Saved' : 'Save',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _saved
                        ? AppColors.primary
                        : context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _caption() {
    final p = _post;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (p.title.isNotEmpty)
          Text(
            p.title,
            style: AppTheme.headlineSm.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.appTextPrimary,
            ),
          ),
        if (p.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            p.description,
            style: AppTheme.bodySm.copyWith(
              fontSize: 13,
              height: 1.4,
              color: context.appTextPrimary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _richBody() {
    final Widget? body = switch (_post.type) {
      ActivityPostType.workout => WorkoutPostCard(post: _post),
      ActivityPostType.meal => MealPostCard(post: _post),
      ActivityPostType.achievement => PrPostCard(post: _post),
      ActivityPostType.routine => RoutinePostCard(post: _post),
      ActivityPostType.cardio => CardioPostCard(post: _post, large: true),
      _ => null,
    };
    if (body == null) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(top: 10), child: body);
  }

  Widget _commentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMMENTS (${_comments.length})',
          style: AppTheme.labelCaps.copyWith(
            fontSize: 11,
            color: context.appTextSecondary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        if (_comments.isEmpty)
          Container(
            key: const Key('post_detail_no_comments'),
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.appSurfaceVariant.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: context.appOutlineVariant.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              'No comments yet. Start the conversation.',
              textAlign: TextAlign.center,
              style: AppTheme.bodySm.copyWith(color: context.appTextSecondary),
            ),
          )
        else
          for (final c in _comments) _commentRow(c),
      ],
    );
  }

  Widget _commentRow(PostComment c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            key: Key('comment_avatar_${c.id}'),
            onTap: () =>
                _openProfile(c.userId, c.userName, c.userAvatar, c.userRank),
            child: CommunityAvatarHelper.buildAvatar(
              userId: c.userId,
              userName: c.userName,
              avatarUrl: c.userAvatar,
              radius: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: CommunityAvatarHelper.displayNameFor(
                          c.userId,
                          c.userName,
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: context.appTextPrimary,
                        ),
                      ),
                      TextSpan(
                        text: '  ${c.timeAgo}',
                        style: TextStyle(color: context.appTextSecondary),
                      ),
                    ],
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  c.text,
                  style: AppTheme.bodySm.copyWith(
                    fontSize: 13,
                    height: 1.35,
                    color: context.appTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: context.appSurface,
        border: Border(
          top: BorderSide(
            color: context.appOutlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('post_detail_comment_field'),
              controller: _controller,
              textCapitalization: TextCapitalization.sentences,
              minLines: 1,
              maxLines: 3,
              maxLength: 500,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Add a comment',
                counterText: '',
                isDense: true,
                filled: true,
                fillColor: context.appSurfaceVariant.withValues(alpha: 0.65),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          IconButton(
            key: const Key('post_detail_send'),
            tooltip: 'Send comment',
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.send_rounded, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
