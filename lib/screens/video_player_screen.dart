import 'package:flutter/material.dart';

import '../widgets/media/video_playback.dart';

/// Full-screen video: black page, close button, title, and the shared player
/// with play or pause, seek and mute.
class VideoPlayerScreen extends StatelessWidget {
  final VideoSource source;
  final String title;
  final String? credit;
  final VideoSurfaceBuilder? surfaceBuilder;

  const VideoPlayerScreen({
    super.key,
    required this.source,
    required this.title,
    this.credit,
    this.surfaceBuilder,
  });

  static Future<void> open(
    BuildContext context, {
    required String location,
    required String title,
    String? credit,
    VideoSurfaceBuilder? surfaceBuilder,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => VideoPlayerScreen(
          source: VideoSource(location),
          title: title,
          credit: credit,
          surfaceBuilder: surfaceBuilder,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          key: const Key('video_close'),
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: VideoPlayback(
                source: source,
                surfaceBuilder: surfaceBuilder ?? VideoPlayback.surfaceDefault,
              ),
            ),
            if (credit != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  credit!,
                  key: const Key('video_credit'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
