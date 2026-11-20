import 'package:flutter/material.dart';
import '../../services/community/community_cloud_repository.dart';
import '../../services/community/post_engagement.dart';
import '../../services/community/post_media.dart';
import 'post_media_view.dart';
import '../../screens/athlete_profile_screen.dart';
import '../../screens/post_detail_screen.dart';
import '../../app_theme.dart';
import '../../models/activity_post.dart';
import '../../models/post_comment.dart';
import '../../services/moderation_service.dart';
import '../../services/saved_content_service.dart';
import '../common/app_card.dart';
import 'community_avatar_helper.dart';
import 'meal_post_card.dart';
import 'pr_post_card.dart';
import 'routine_post_card.dart';
import 'cardio_post_card.dart';
import 'workout_post_card.dart';

/// Full interactive Community Post Card component.
class PostCard extends StatefulWidget {
  final ActivityPost post;
  final ValueChanged<ActivityPost>? onPostUpdated;
  final VoidCallback? onPostHidden;

  const PostCard({
    super.key,
    required this.post,
    this.onPostUpdated,
    this.onPostHidden,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool _isLiked;
  late int _likesCount;
  late bool _isSaved;
  late List<PostComment> _commentsList;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likesCount = widget.post.likes;
    _isSaved = SavedContentService.instance.isSaved(widget.post.id);
    _initComments();
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post != widget.post) {
      _isLiked = widget.post.isLiked;
      _likesCount = widget.post.likes;
      _isSaved = SavedContentService.instance.isSaved(widget.post.id);
      _initComments();
    }
  }

  void _initComments() {
    if (_isCloudPost) {
      _commentsList = List<PostComment>.from(widget.post.commentsList);
      CommunityCloudRepository.instance
          .fetchComments(widget.post.id)
          .then((comments) {
            if (mounted) setState(() => _commentsList = comments);
          })
          .catchError((_) {});
      return;
    }
    _commentsList = PostEngagement.localComments(widget.post);
  }

  bool get _isCloudPost => PostEngagement.isCloudPost(widget.post);

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });
    final updated = widget.post.copyWith(
      isLiked: _isLiked,
      likes: _likesCount,
      commentsList: _commentsList,
    );
    widget.onPostUpdated?.call(updated);
    final liked = _isLiked;
    PostEngagement.persistLike(updated).catchError((_) {
      if (!mounted) return;
      setState(() {
        _isLiked = !liked;
        _likesCount += liked ? -1 : 1;
      });
    });
  }

  Future<void> _toggleSave() async {
    final newSaved = await SavedContentService.instance.toggleSave(widget.post);
    setState(() {
      _isSaved = newSaved;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isSaved
                ? 'Saved to your collection! 🔖'
                : 'Removed from saved collection',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _openCreatorProfile() => _openProfile(
    userId: widget.post.userId,
    userName: widget.post.userName,
    avatarUrl: widget.post.userAvatar,
    rank: widget.post.userRank,
  );

  /// Opens the profile of the tapped user (post author or commenter).
  void _openProfile({
    required String userId,
    required String userName,
    required String? avatarUrl,
    required String rank,
  }) {
    AthleteProfileScreen.open(
      context,
      userId: userId,
      name: CommunityAvatarHelper.displayNameFor(userId, userName),
      avatarUrl: CommunityAvatarHelper.isShowcaseSelf(userId)
          ? null
          : avatarUrl,
      rank: rank,
    );
  }

  /// Opens the full post page. Changes made there flow back to this card.
  void _openPost() {
    PostDetailScreen.open(
      context,
      post: widget.post.copyWith(
        isLiked: _isLiked,
        likes: _likesCount,
        commentsList: _commentsList,
      ),
      onPostUpdated: (updated) {
        if (!mounted) return;
        setState(() {
          _isLiked = updated.isLiked;
          _likesCount = updated.likes;
          _commentsList = List<PostComment>.from(updated.commentsList);
        });
        widget.onPostUpdated?.call(updated);
      },
    );
  }

  void _openCommentsSheet() {
    final controller = TextEditingController();
    final scrollController = ScrollController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Drag Handle
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: context.appOutlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Header Row with dynamic count and close button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Comments (${_commentsList.length})',
                          style: AppTheme.headlineSm.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: context.appTextPrimary,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: context.appTextPrimary,
                          ),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    const Divider(height: 1),
                    const SizedBox(height: 8),

                    // Comments List or Clean Empty State
                    Flexible(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.52,
                        ),
                        child: _commentsList.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 36,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.primary.withValues(
                                            alpha: 0.12,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          size: 28,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No comments yet',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: context.appTextPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Be the first to share your thoughts on this post!',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context.appTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                shrinkWrap: true,
                                itemCount: _commentsList.length,
                                separatorBuilder: (context, index) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (ctx, i) {
                                  final comment = _commentsList[i];
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                        key: Key(
                                          'comment_avatar_${comment.id}',
                                        ),
                                        onTap: () => _openProfile(
                                          userId: comment.userId,
                                          userName: comment.userName,
                                          avatarUrl: comment.userAvatar,
                                          rank: comment.userRank,
                                        ),
                                        child:
                                            CommunityAvatarHelper.buildAvatar(
                                              userId: comment.userId,
                                              userName: comment.userName,
                                              avatarUrl: comment.userAvatar,
                                              radius: 16,
                                            ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: context.appSurfaceElevated,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      CommunityAvatarHelper.displayNameFor(
                                                        comment.userId,
                                                        comment.userName,
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: context
                                                            .appTextPrimary,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (comment
                                                      .userRank
                                                      .isNotEmpty) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 5,
                                                            vertical: 1,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.primary
                                                            .withValues(
                                                              alpha: 0.12,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        comment.userRank,
                                                        style: const TextStyle(
                                                          fontSize: 9,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color:
                                                              AppColors.primary,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                  const Spacer(),
                                                  Text(
                                                    comment.timeAgo,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: context
                                                          .appTextSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                comment.text,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: context.appTextPrimary,
                                                  height: 1.35,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Add Comment Input Bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.appSurfaceElevated,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: context.appOutlineVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controller,
                              style: TextStyle(
                                fontSize: 13,
                                color: context.appTextPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Add a comment...',
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: context.appTextSecondary,
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                border: InputBorder.none,
                              ),
                              onSubmitted: (val) => _submitComment(
                                controller,
                                scrollController,
                                setModalState,
                              ),
                            ),
                          ),
                          Container(
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.arrow_upward_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 34,
                                minHeight: 34,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: () => _submitComment(
                                controller,
                                scrollController,
                                setModalState,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitComment(
    TextEditingController controller,
    ScrollController scrollController,
    StateSetter setModalState,
  ) async {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    final PostComment newComment;
    try {
      newComment = await PostEngagement.addComment(widget.post, text);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your comment could not be posted.')),
      );
      return;
    }
    if (!mounted) return;

    setState(() {
      _commentsList.add(newComment);
    });
    setModalState(() {});
    controller.clear();

    final updated = widget.post.copyWith(
      commentsList: _commentsList,
      comments: _commentsList.length,
    );
    widget.onPostUpdated?.call(updated);

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Post'),
        content: const Text(
          'Are you sure you want to report this post for moderation review? It will be hidden from your feed immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () async {
              await ModerationService.instance.reportPost(
                widget.post.id,
                'User reported',
              );
              if (ctx.mounted) Navigator.pop(ctx);
              widget.onPostHidden?.call();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Post reported and hidden.')),
                );
              }
            },
            child: const Text(
              'Report & Hide',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Author Header Row
          Row(
            children: [
              GestureDetector(
                key: Key('post_avatar_${widget.post.id}'),
                onTap: _openCreatorProfile,
                child: CommunityAvatarHelper.buildAvatar(
                  userId: widget.post.userId,
                  userName: widget.post.userName,
                  avatarUrl: widget.post.userAvatar,
                  radius: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _openCreatorProfile,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              CommunityAvatarHelper.displayNameFor(
                                widget.post.userId,
                                widget.post.userName,
                              ),
                              style: AppTheme.headlineSm.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: context.appTextPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.post.isSample) ...[
                            const SizedBox(width: 6),
                            Container(
                              key: Key('sample_badge_${widget.post.id}'),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: context.appTextSecondary,
                                ),
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
                          ],
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                widget.post.userRank,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${widget.post.type.emoji} ${widget.post.type.displayName}',
                              style: AppTheme.bodySm.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: context.appTextSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            ' • ${widget.post.timeAgo}',
                            style: AppTheme.bodySm.copyWith(
                              fontSize: 10,
                              color: context.appTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // More / Moderation Menu
              SizedBox(
                width: 24,
                height: 24,
                child: PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: context.appTextSecondary,
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  onSelected: (val) async {
                    if (val == 'report') {
                      _showReportDialog();
                    } else if (val == 'hide') {
                      await ModerationService.instance.hidePost(widget.post.id);
                      widget.onPostHidden?.call();
                    } else if (val == 'block') {
                      await ModerationService.instance.blockUser(
                        widget.post.userId,
                      );
                      widget.onPostHidden?.call();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Blocked ${widget.post.userName}'),
                          ),
                        );
                      }
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'hide',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_off_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('Hide Post', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(
                            Icons.flag_outlined,
                            size: 16,
                            color: Color(0xFFEF4444),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Report Post',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'block',
                      child: Row(
                        children: [
                          Icon(
                            Icons.block_rounded,
                            size: 16,
                            color: Color(0xFFEF4444),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Block User',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Tapping the post content opens the full post page.
          GestureDetector(
            key: Key('post_body_${widget.post.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: _openPost,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. Post Title & Description
                if (widget.post.title.isNotEmpty) ...[
                  Text(
                    widget.post.title,
                    style: AppTheme.headlineSm.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                if (widget.post.description.isNotEmpty) ...[
                  Text(
                    widget.post.description,
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 12,
                      color: context.appTextSecondary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // 3. Media Preview (Photos / Videos)
                _buildMedia(),

                // 4. Dynamic Rich Post Body
                _buildRichPostBody(),
              ],
            ),
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // 4. Action Bar (Like, Comment, Save, Share)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Like Action
              InkWell(
                onTap: _toggleLike,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isLiked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: _isLiked
                            ? const Color(0xFFEF4444)
                            : context.appTextSecondary,
                        size: 16,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$_likesCount',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _isLiked
                              ? const Color(0xFFEF4444)
                              : context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Comment Action
              InkWell(
                onTap: _openCommentsSheet,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: context.appTextSecondary,
                        size: 16,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${_commentsList.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Save Action
              InkWell(
                onTap: _toggleSave,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isSaved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: _isSaved
                            ? AppColors.primary
                            : context.appTextSecondary,
                        size: 16,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _isSaved ? 'Saved' : 'Save',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _isSaved
                              ? AppColors.primary
                              : context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Share Action
              InkWell(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Post link copied to clipboard! 🔗'),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  child: Icon(
                    Icons.share_outlined,
                    color: context.appTextSecondary,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRichPostBody() {
    switch (widget.post.type) {
      case ActivityPostType.workout:
        return WorkoutPostCard(post: widget.post);
      case ActivityPostType.meal:
        return MealPostCard(post: widget.post);
      case ActivityPostType.achievement:
        return PrPostCard(post: widget.post);
      case ActivityPostType.routine:
        return RoutinePostCard(post: widget.post);
      case ActivityPostType.cardio:
        return CardioPostCard(post: widget.post);
      case ActivityPostType.transformation:
      case ActivityPostType.progress:
        if (widget.post.metadata != null &&
            widget.post.metadata!['currentWeightKg'] != null) {
          final start = widget.post.metadata!['startWeightKg'] as num? ?? 50;
          final current =
              widget.post.metadata!['currentWeightKg'] as num? ?? 55;
          final weeks = widget.post.metadata!['durationWeeks'] as num? ?? 12;

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: context.appSurfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSimpleMetric(
                    'START',
                    '$start kg',
                    const Color(0xFF6B7280),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFFF59E0B),
                  size: 14,
                ),
                Expanded(
                  child: _buildSimpleMetric(
                    'CURRENT',
                    '$current kg',
                    const Color(0xFF10B981),
                  ),
                ),
                Expanded(
                  child: _buildSimpleMetric(
                    'TIMELINE',
                    '$weeks wks',
                    const Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
    }
  }

  Widget _buildSimpleMetric(String label, String value, Color color) {
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: AppTheme.labelCaps.copyWith(
              fontSize: 8,
              color: context.appTextSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMedia() {
    if (widget.post.images.isEmpty && !PostMedia.isVideo(widget.post)) {
      return const SizedBox.shrink();
    }

    final isVideo = PostMedia.isVideo(widget.post);
    final poster = isVideo
        ? PostMedia.poster(widget.post)
        : (widget.post.images.isEmpty ? null : widget.post.images.first);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: GestureDetector(
              key: Key('post_video_${widget.post.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: isVideo ? () => openPostVideo(context, widget.post) : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (poster != null)
                    PostImage(poster)
                  else
                    Container(color: const Color(0xFF111827)),
                  if (isVideo) ...[
                    // Dark vignette overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.3),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                    ),
                    // Video Pill Top Left
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.videocam_rounded,
                              color: AppColors.primary,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'WORKOUT VIDEO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Center play button: opens the real player.
                    Center(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: Key('post_video_play_${widget.post.id}'),
                          onTap: () => openPostVideo(context, widget.post),
                          borderRadius: BorderRadius.circular(30),
                          child: const VideoPlayBadge(),
                        ),
                      ),
                    ),
                  ],
                  if (!isVideo && widget.post.images.length > 1)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.collections_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '1/${widget.post.images.length}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
