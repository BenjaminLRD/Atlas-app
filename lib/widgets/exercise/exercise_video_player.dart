import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app_theme.dart';
import '../../models/exercise.dart';
import '../../services/exercise/exercise_motion.dart';
import '../../services/exercise/exercise_thumbnails.dart';
import '../../services/exercise/exercise_videos.dart';
import 'exercise_motion_view.dart';

/// Form demonstration for one exercise.
///
/// Shows, in this order of preference:
/// 1. a drawn form animation (works offline; where the movement can be seen
///    from more than one side, the viewer can switch between the views),
/// 2. a verified YouTube demonstration, opened in the YouTube app or the
///    browser (nothing is downloaded or embedded from a source that cannot be
///    relied on),
/// 3. a plain-language statement that no demonstration exists, never a fake
///    or broken player.
///
/// The Animation / Video switch is always offered when there is an animation,
/// so an exercise without a verified video says so clearly instead of
/// silently hiding the option.
class ExerciseVideoPlayer extends StatefulWidget {
  final Exercise exercise;
  final double aspectRatio;

  /// Kept for existing callers; a YouTube video is never started on its own.
  final bool autoPlay;
  final bool showControls;
  final VoidCallback? onFullscreenToggle;

  /// Opens a link outside the app. Replaceable so tests need no platform.
  /// Returns false when nothing could open it.
  static Future<bool> Function(Uri uri) launcher = _launchExternally;

  /// Puts text on the clipboard (replaceable in tests).
  static Future<void> Function(String text) copier = _copyText;

  static Future<bool> _launchExternally(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<void> _copyText(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  const ExerciseVideoPlayer({
    super.key,
    required this.exercise,
    this.aspectRatio = 16 / 9,
    this.autoPlay = false,
    this.showControls = true,
    this.onFullscreenToggle,
  });

  @override
  State<ExerciseVideoPlayer> createState() => _ExerciseVideoPlayerState();
}

enum _Mode { animation, video }

/// Where the "watch on YouTube" action is.
enum _VideoState { idle, opening, failed }

class _ExerciseVideoPlayerState extends State<ExerciseVideoPlayer> {
  late _Mode _mode;

  MotionView? _view;
  _VideoState _videoState = _VideoState.idle;

  /// The demonstration for the chosen viewpoint (the default one until the
  /// viewer switches, and again if the chosen one does not exist).
  MotionDef? get _motion {
    final id = widget.exercise.id;
    final wanted = _view;
    if (wanted != null) {
      final m = ExerciseMotions.forIdView(id, wanted);
      if (m != null) return m;
    }
    return ExerciseMotions.forId(id);
  }

  List<MotionDef> get _views => ExerciseMotions.viewsFor(widget.exercise.id);

  @override
  void didUpdateWidget(ExerciseVideoPlayer old) {
    super.didUpdateWidget(old);
    if (old.exercise.id != widget.exercise.id) _view = null;
  }

  /// The verified YouTube demonstration for this exercise, if there is one.
  ExerciseVideo? get _video => ExerciseVideos.forExercise(widget.exercise.id);

  bool get _hasVideo => _video != null;

  bool get _hasAnimation => _motion != null;

  @override
  void initState() {
    super.initState();
    _mode = _hasAnimation ? _Mode.animation : _Mode.video;
  }

  void _openFullscreen(BuildContext context) {
    if (widget.onFullscreenToggle != null) {
      widget.onFullscreenToggle!();
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 24,
          ),
          backgroundColor: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ExerciseVideoPlayer(
                  exercise: widget.exercise,
                  aspectRatio: 16 / 10,
                  autoPlay: true,
                  showControls: false,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    // The switch is offered whenever there is an animation, so a missing
    // video is stated plainly instead of the option vanishing.
    final both = _hasAnimation;
    final showingAnimation = _hasAnimation && _mode == _Mode.animation;
    final showingVideo = _hasAnimation ? _mode == _Mode.video : _hasVideo;

    final badgeText = showingAnimation
        ? 'FORM ANIMATION'
        : (showingVideo
              ? (_hasVideo ? 'YOUTUBE DEMO' : 'NO VIDEO YET')
              : 'VISUAL CUES');
    final badgeIcon = showingAnimation
        ? Icons.animation_rounded
        : (showingVideo
              ? Icons.ondemand_video_rounded
              : widget.exercise.categoryIcon);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? AppColors.primaryContainer.withValues(alpha: 0.3)
              : Colors.black12,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. The demonstration itself.
            Positioned.fill(
              child: _visual(context, showingAnimation, showingVideo),
            ),

            // 3. Top badges.
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(badgeIcon, color: AppColors.primary, size: 13),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              badgeText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTheme.labelCaps.copyWith(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.showControls) ...[
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(
                        Icons.fullscreen_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      constraints: const BoxConstraints(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.5),
                        padding: const EdgeInsets.all(5),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _openFullscreen(context),
                    ),
                  ],
                ],
              ),
            ),
            // 4. Switch between the viewpoints that exist for this exercise.
            if (showingAnimation && _views.length > 1)
              Positioned(
                top: 40,
                right: 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final m in _views) ...[
                      if (m != _views.first) const SizedBox(width: 4),
                      _viewChip(m.view),
                    ],
                  ],
                ),
              ),
            // 5. Switch between the animation and the real video.
            if (both)
              Positioned(
                top: 40,
                left: 10,
                child: Row(
                  children: [
                    _modeChip(
                      'Animation',
                      _Mode.animation,
                      const Key('form_mode_animation'),
                    ),
                    const SizedBox(width: 4),
                    _modeChip(
                      'Video',
                      _Mode.video,
                      const Key('form_mode_video'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _viewChip(MotionView view) {
    final on = (_motion?.view ?? MotionView.side) == view;
    final label = switch (view) {
      MotionView.side => 'Side View',
      MotionView.front => 'Front View',
      MotionView.top => 'Top View',
    };
    return Semantics(
      button: true,
      selected: on,
      label: label,
      child: GestureDetector(
        key: Key('view_toggle_${view.name}'),
        onTap: () => setState(() => _view = view),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: on
                ? AppColors.primary
                : Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24, width: 0.8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: on ? Colors.black : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeChip(String label, _Mode mode, Key key) {
    final on = _mode == mode;
    return GestureDetector(
      key: key,
      onTap: () => setState(() => _mode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: on ? AppColors.primary : Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24, width: 0.8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: on ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }

  Future<void> _openVideo(ExerciseVideo video) async {
    if (_videoState == _VideoState.opening) return;
    setState(() => _videoState = _VideoState.opening);
    var opened = false;
    try {
      opened = await ExerciseVideoPlayer.launcher(video.watchUri);
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    setState(
      () => _videoState = opened ? _VideoState.idle : _VideoState.failed,
    );
  }

  Future<void> _copyLink(ExerciseVideo video) async {
    await ExerciseVideoPlayer.copier(video.watchUri.toString());
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('Link copied'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _visual(BuildContext context, bool animation, bool video) {
    if (animation) {
      return ExerciseMotionView(motion: _motion!);
    }
    if (video) {
      return _videoPanel(context);
    }
    return _placeholder(context);
  }

  /// The Video view: the exercise's own illustration behind a clear, honest
  /// action. It never pretends to be a player. A video is only offered when a
  /// verified one exists; otherwise the panel says there is none.
  Widget _videoPanel(BuildContext context) {
    final video = _video;
    final asset = ExerciseThumbnails.assetFor(widget.exercise.id);
    final failed = _videoState == _VideoState.failed;
    final opening = _videoState == _VideoState.opening;

    final Widget body;
    if (video == null) {
      final reason = ExerciseVideos.unavailableReason(widget.exercise.id);
      body = Column(
        key: const Key('video_unavailable'),
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.videocam_off_outlined,
            color: Colors.white70,
            size: 30,
          ),
          const SizedBox(height: 8),
          const Text(
            'No video available yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            reason == null
                ? 'We have not verified a demonstration video for this '
                      'exercise, so none is linked. The animation shows the '
                      'form.'
                : '$reason The animation shows the form where one exists.',
            textAlign: TextAlign.center,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            video.title,
            key: const Key('video_title'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'by ${video.channel} · on YouTube',
            key: const Key('video_channel'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60, fontSize: 10),
          ),
          const SizedBox(height: 10),
          if (failed) ...[
            const Text(
              'Could not open YouTube. Check your connection, or copy the '
              'link and open it yourself.',
              key: Key('video_open_failed'),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Color(0xFFFBBF24), fontSize: 11),
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              ElevatedButton.icon(
                key: const Key('exercise_video_play'),
                onPressed: opening ? null : () => _openVideo(video),
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(failed ? 'Try again' : 'Watch on YouTube'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              if (failed)
                OutlinedButton.icon(
                  key: const Key('exercise_video_copy'),
                  onPressed: () => _copyLink(video),
                  icon: const Icon(Icons.link_rounded, size: 16),
                  label: const Text('Copy link'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    minimumSize: const Size(0, 38),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          if (!failed)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Opens in the YouTube app or your browser. Needs internet.',
                style: TextStyle(color: Colors.white54, fontSize: 9.5),
              ),
            ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: const Color(0xFF0F1417)),
        if (asset != null)
          Opacity(
            opacity: 0.22,
            child: Image.asset(
              asset,
              fit: BoxFit.cover,
              errorBuilder: (context, e, s) => const SizedBox.shrink(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 72, 14, 10),
          child: Center(child: SingleChildScrollView(child: body)),
        ),
      ],
    );
  }

  Widget _placeholder(BuildContext context) {
    final isDark = context.isDarkMode;
    final categoryIcon = widget.exercise.categoryIcon;
    final targetSummary = widget.exercise.targetMuscles.isNotEmpty
        ? widget.exercise.targetMuscles.take(3).join(' • ')
        : widget.exercise.muscleGroup;
    final reason = ExerciseMotions.unavailableReason(widget.exercise.id);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF1E293B), Color(0xFF0F172A)]
              : const [Color(0xFFF1F5F9), Color(0xFFE2E8F0)],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? AppColors.primaryContainer.withValues(alpha: 0.15)
                        : Colors.white,
                    border: Border.all(
                      color: AppColors.primaryContainer.withValues(
                        alpha: isDark ? 0.4 : 0.6,
                      ),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    categoryIcon,
                    size: 20,
                    color: isDark ? AppColors.primary : const Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.exercise.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTheme.headlineMd.copyWith(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  targetSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppTheme.bodySm.copyWith(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.65)
                        : const Color(0xFF475569),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  child: Text(
                    'No form demonstration yet',
                    key: const Key('no_demonstration'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.labelCaps.copyWith(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white70 : Colors.black87,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (reason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    reason,
                    key: const Key('no_demonstration_reason'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : const Color(0xFF475569),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                if (!_hasVideo) ...[
                  Text(
                    'No external video is available either.',
                    key: const Key('no_video_note'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  'Atlas provides: ✓ Instructions  ✓ Muscles  ✓ Mistakes  ✓ Tips',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodySm.copyWith(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.primary : const Color(0xFF0F766E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
