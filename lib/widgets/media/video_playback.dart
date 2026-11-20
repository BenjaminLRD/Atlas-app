import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../app_theme.dart';

/// Where a video comes from: a bundled asset, a web address, or a local file.
class VideoSource {
  final String location;
  const VideoSource(this.location);

  bool get isNetwork => location.startsWith('http');
  bool get isAsset => location.startsWith('assets/');
  bool get isFile => !isNetwork && !isAsset;
}

typedef VideoControllerFactory =
    VideoPlayerController Function(VideoSource source);

typedef VideoSurfaceBuilder =
    Widget Function(BuildContext context, VideoPlayerController controller);

/// Builds the real controller for a source. Tests replace [VideoPlayback.factory]
/// so no platform player is needed.
VideoPlayerController defaultVideoControllerFactory(VideoSource s) {
  if (s.isNetwork) {
    return VideoPlayerController.networkUrl(Uri.parse(s.location));
  }
  if (s.isAsset) return VideoPlayerController.asset(s.location);
  return VideoPlayerController.file(File(s.location));
}

/// Plays one video with real controls: play or pause, seek, mute, replay.
///
/// It loads only when it is shown, plays only this one video, pauses when the
/// app goes to the background, shows a loading state and a clear error with a
/// retry, and releases its player when removed.
class VideoPlayback extends StatefulWidget {
  /// Replaced in tests.
  static VideoControllerFactory factory = defaultVideoControllerFactory;

  /// How long to wait for the video to become ready.
  static Duration loadTimeout = const Duration(seconds: 20);

  final VideoSource source;
  final bool autoPlay;
  final bool looping;

  /// Draws the video picture. Tests replace it.
  final VideoSurfaceBuilder surfaceBuilder;

  /// Shown behind the loading spinner.
  final Widget? placeholder;

  const VideoPlayback({
    super.key,
    required this.source,
    this.autoPlay = true,
    this.looping = false,
    this.surfaceBuilder = surfaceDefault,
    this.placeholder,
  });

  static Widget surfaceDefault(BuildContext c, VideoPlayerController v) =>
      VideoPlayer(v);

  @override
  State<VideoPlayback> createState() => _VideoPlaybackState();
}

class _VideoPlaybackState extends State<VideoPlayback>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _failed = false;
  bool _muted = false;
  bool _dragging = false;
  double _dragValue = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final old = _controller;
    _controller = null;
    await old?.dispose();
    VideoPlayerController? c;
    try {
      c = VideoPlayback.factory(widget.source);
      await c.initialize().timeout(VideoPlayback.loadTimeout);
      if (!mounted) {
        await c.dispose();
        return;
      }
      await c.setLooping(widget.looping);
      await c.setVolume(_muted ? 0 : 1);
      c.addListener(_onTick);
      _controller = c;
      setState(() => _loading = false);
      if (widget.autoPlay) await c.play();
    } catch (_) {
      try {
        await c?.dispose();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _controller = null;
        _loading = false;
        _failed = true;
      });
    }
  }

  void _onTick() {
    final c = _controller;
    if (c == null || !mounted) return;
    if (c.value.hasError) {
      setState(() => _failed = true);
      return;
    }
    if (!_dragging) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _controller?.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final c = _controller;
    c?.removeListener(_onTick);
    c?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      final v = c.value;
      if (v.duration > Duration.zero && v.position >= v.duration) {
        await c.seekTo(Duration.zero);
      }
      await c.play();
    }
  }

  Future<void> _toggleMute() async {
    final c = _controller;
    setState(() => _muted = !_muted);
    await c?.setVolume(_muted ? 0 : 1);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return _error();
    final c = _controller;
    if (_loading || c == null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (widget.placeholder != null) widget.placeholder!,
          const Center(
            child: CircularProgressIndicator(
              key: Key('video_loading'),
              color: AppColors.primary,
            ),
          ),
        ],
      );
    }
    final v = c.value;
    final total = v.duration;
    final pos = v.position > total ? total : v.position;
    final maxMs = total.inMilliseconds <= 0
        ? 1.0
        : total.inMilliseconds.toDouble();
    final aspect = v.aspectRatio > 0 ? v.aspectRatio : 16 / 9;

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            key: const Key('video_surface'),
            behavior: HitTestBehavior.opaque,
            onTap: _togglePlay,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: aspect,
                    child: widget.surfaceBuilder(context, c),
                  ),
                ),
                if (!v.isPlaying)
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.55),
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Container(
          color: Colors.black,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Row(
            children: [
              IconButton(
                key: const Key('video_play_pause'),
                tooltip: v.isPlaying ? 'Pause' : 'Play',
                icon: Icon(
                  v.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                ),
                onPressed: _togglePlay,
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: AppColors.primary,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: AppColors.primary,
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    key: const Key('video_seek'),
                    min: 0,
                    max: maxMs,
                    value:
                        (_dragging ? _dragValue : pos.inMilliseconds.toDouble())
                            .clamp(0, maxMs),
                    onChangeStart: (_) => _dragging = true,
                    onChanged: (x) => setState(() => _dragValue = x),
                    onChangeEnd: (x) async {
                      _dragging = false;
                      await c.seekTo(Duration(milliseconds: x.round()));
                      if (mounted) setState(() {});
                    },
                  ),
                ),
              ),
              Text(
                '${_fmt(pos)} / ${_fmt(total)}',
                key: const Key('video_time'),
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              IconButton(
                key: const Key('video_mute'),
                tooltip: _muted ? 'Unmute' : 'Mute',
                icon: Icon(
                  _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                ),
                onPressed: _toggleMute,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _error() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_rounded,
              color: Colors.white54,
              size: 40,
            ),
            const SizedBox(height: 12),
            const Text(
              'This video could not be played',
              key: Key('video_error'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.source.isNetwork
                  ? 'Check your connection and try again.'
                  : 'The file is missing or in a format this phone cannot play.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('video_retry'),
              onPressed: _start,
              child: const Text('RETRY'),
            ),
          ],
        ),
      ),
    );
  }
}
