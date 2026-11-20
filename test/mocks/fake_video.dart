// ignore_for_file: must_call_super
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// A stand-in for the platform player: records what it is asked to do.
class FakeVideo extends VideoPlayerController {
  FakeVideo({this.failInit = false, this.hang = false})
    : super.networkUrl(Uri.parse('https://example.com/fake.webm'));

  final bool failInit;
  final bool hang;
  bool disposedCalled = false;
  double volume = 1;
  final seeks = <Duration>[];

  @override
  Future<void> initialize() async {
    if (hang) await Future<void>.delayed(const Duration(days: 1));
    if (failInit) throw Exception('cannot open');
    value = value.copyWith(
      isInitialized: true,
      duration: const Duration(seconds: 10),
      size: const Size(720, 1280),
    );
  }

  @override
  Future<void> play() async => value = value.copyWith(isPlaying: true);

  @override
  Future<void> pause() async => value = value.copyWith(isPlaying: false);

  @override
  Future<void> seekTo(Duration position) async {
    seeks.add(position);
    value = value.copyWith(position: position);
  }

  @override
  Future<void> setVolume(double v) async => volume = v;

  @override
  Future<void> setLooping(bool looping) async {}

  // The real dispose talks to the platform player, which does not exist in
  // tests.
  @override
  Future<void> dispose() async => disposedCalled = true;
}

Widget fakeVideoSurface(BuildContext c, VideoPlayerController v) =>
    const SizedBox.expand(key: Key('fake_surface'));
