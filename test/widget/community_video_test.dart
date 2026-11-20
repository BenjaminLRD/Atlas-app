import 'dart:io';
import 'dart:typed_data';

import '../mocks/fake_video.dart';

import 'package:atlas/app_theme.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/activity_post.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/providers/showcase_mode_provider.dart';
import 'package:atlas/screens/athlete_profile_screen.dart';
import 'package:atlas/screens/post_detail_screen.dart';
import 'package:atlas/screens/video_player_screen.dart';
import 'package:atlas/services/community/post_media.dart';
import 'package:atlas/services/community/sample_community.dart';
import 'package:atlas/services/community/sample_media.dart';
import 'package:atlas/services/moderation_service.dart';
import 'package:atlas/services/saved_content_service.dart';
import 'package:atlas/services/showcase_mode_service.dart';
import 'package:atlas/services/social_graph_service.dart';
import 'package:atlas/widgets/community/post_card.dart';
import 'package:atlas/widgets/media/video_playback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(412, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme, home: home));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

ActivityPost _videoPost() =>
    SampleCommunity.posts().firstWhere((p) => PostMedia.isVideo(p));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<FakeVideo> made;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    AppDependencies.reset();
    FitnessProvider.resetInstance();
    SocialGraphService.resetInstance();
    SavedContentService.resetInstance();
    ModerationService.resetInstance();
    ShowcaseModeService.resetInstance();
    await ShowcaseModeProvider.instance.disableShowcaseMode();
    made = [];
    VideoPlayback.factory = (_) {
      final c = FakeVideo();
      made.add(c);
      return c;
    };
    VideoPlayback.loadTimeout = const Duration(seconds: 20);
  });

  tearDown(() {
    VideoPlayback.factory = defaultVideoControllerFactory;
    VideoPlayback.loadTimeout = const Duration(seconds: 20);
  });

  group('the player', () {
    Widget screen() => VideoPlayerScreen(
      source: const VideoSource('assets/community/videos/squat.webm'),
      title: 'Squat demonstration',
      credit: 'Credit line',
      surfaceBuilder: fakeVideoSurface,
    );

    testWidgets('loads, plays, pauses and resumes', (tester) async {
      await _pump(tester, screen());
      expect(find.byKey(const Key('fake_surface')), findsOneWidget);
      expect(made.single.value.isPlaying, isTrue); // autoplay
      expect(find.text('Squat demonstration'), findsOneWidget);
      expect(find.byKey(const Key('video_credit')), findsOneWidget);

      await tester.tap(find.byKey(const Key('video_play_pause')));
      await tester.pump();
      expect(made.single.value.isPlaying, isFalse);
      await tester.tap(find.byKey(const Key('video_play_pause')));
      await tester.pump();
      expect(made.single.value.isPlaying, isTrue);
    });

    testWidgets('tapping the picture toggles playback', (tester) async {
      await _pump(tester, screen());
      await tester.tap(find.byKey(const Key('video_surface')));
      await tester.pump();
      expect(made.single.value.isPlaying, isFalse);
    });

    testWidgets('seeking moves to the chosen time', (tester) async {
      await _pump(tester, screen());
      final slider = tester.widget<Slider>(find.byKey(const Key('video_seek')));
      slider.onChangeStart!(0);
      slider.onChanged!(5000);
      slider.onChangeEnd!(5000);
      await tester.pump();
      expect(made.single.seeks.last, const Duration(milliseconds: 5000));
      expect(find.text('00:05 / 00:10'), findsOneWidget);
    });

    testWidgets('mute and unmute change the volume', (tester) async {
      await _pump(tester, screen());
      expect(made.single.volume, 1);
      await tester.tap(find.byKey(const Key('video_mute')));
      await tester.pump();
      expect(made.single.volume, 0);
      expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
      await tester.tap(find.byKey(const Key('video_mute')));
      await tester.pump();
      expect(made.single.volume, 1);
    });

    testWidgets('playing again after the end restarts from the beginning', (
      tester,
    ) async {
      await _pump(tester, screen());
      final c = made.single;
      c.value = c.value.copyWith(
        position: const Duration(seconds: 10),
        isPlaying: false,
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('video_play_pause')));
      await tester.pump();
      expect(c.seeks.last, Duration.zero);
      expect(c.value.isPlaying, isTrue);
    });

    testWidgets('close leaves the page and releases the player', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => VideoPlayerScreen.open(
                context,
                location: 'assets/community/videos/squat.webm',
                title: 'Squat',
                surfaceBuilder: fakeVideoSurface,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(VideoPlayerScreen), findsOneWidget);
      await tester.tap(find.byKey(const Key('video_close')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(VideoPlayerScreen), findsNothing);
      expect(made.single.disposedCalled, isTrue);
    });

    testWidgets('a video that cannot open shows an error and can be retried', (
      tester,
    ) async {
      var attempt = 0;
      VideoPlayback.factory = (_) {
        final c = FakeVideo(failInit: attempt++ == 0);
        made.add(c);
        return c;
      };
      await _pump(tester, screen());
      expect(find.byKey(const Key('video_error')), findsOneWidget);
      expect(find.byKey(const Key('video_retry')), findsOneWidget);
      expect(find.byKey(const Key('fake_surface')), findsNothing);

      await tester.tap(find.byKey(const Key('video_retry')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('video_error')), findsNothing);
      expect(find.byKey(const Key('fake_surface')), findsOneWidget);
      expect(made.length, 2);
    });

    testWidgets('a video that never loads times out into the error state', (
      tester,
    ) async {
      VideoPlayback.loadTimeout = const Duration(milliseconds: 50);
      VideoPlayback.factory = (_) {
        final c = FakeVideo(hang: true);
        made.add(c);
        return c;
      };
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.darkTheme, home: screen()),
      );
      await tester.pump();
      expect(find.byKey(const Key('video_loading')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();
      expect(find.byKey(const Key('video_error')), findsOneWidget);
      await tester.pump(const Duration(days: 2)); // let the fake finish
    });

    testWidgets('a missing file is an error, not a crash', (tester) async {
      VideoPlayback.factory = (_) => FakeVideo(failInit: true);
      await _pump(
        tester,
        VideoPlayerScreen(
          source: const VideoSource('/no/such/file.mp4'),
          title: 'Missing',
          surfaceBuilder: fakeVideoSurface,
        ),
      );
      expect(find.byKey(const Key('video_error')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('video posts', () {
    testWidgets('tapping a video post in the feed plays it', (tester) async {
      final post = _videoPost();
      VideoPlayback.factory = (_) {
        final c = FakeVideo();
        made.add(c);
        return c;
      };
      await _pump(
        tester,
        Scaffold(
          body: SingleChildScrollView(child: PostCard(post: post)),
        ),
      );
      expect(find.text('WORKOUT VIDEO'), findsOneWidget);
      await tester.tap(find.byKey(Key('post_video_play_${post.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final screen = tester.widget<VideoPlayerScreen>(
        find.byType(VideoPlayerScreen),
      );
      expect(screen.source.location, PostMedia.videoSource(post));
      expect(screen.source.isAsset, isTrue);
      expect(screen.credit, isNotNull);
    });

    testWidgets('tapping the picture itself also plays it', (tester) async {
      final post = _videoPost();
      await _pump(
        tester,
        Scaffold(
          body: SingleChildScrollView(child: PostCard(post: post)),
        ),
      );
      await tester.tapAt(
        tester.getCenter(find.byKey(Key('post_video_${post.id}'))) +
            const Offset(60, 40),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(VideoPlayerScreen), findsOneWidget);
    });

    testWidgets('the post page plays the video too', (tester) async {
      final post = _videoPost();
      await _pump(tester, PostDetailScreen(post: post));
      await tester.tap(find.byKey(const Key('post_detail_video')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(VideoPlayerScreen), findsOneWidget);
    });

    testWidgets('profile grids mark video posts', (tester) async {
      final post = _videoPost();
      await _pump(
        tester,
        AthleteProfileScreen(userId: post.userId, name: post.userName),
      );
      expect(
        find.descendant(
          of: find.byKey(Key('profile_post_${post.id}')),
          matching: find.byIcon(Icons.videocam_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a photo post has no play button', (tester) async {
      final post = SampleCommunity.posts().firstWhere(
        (p) => !PostMedia.isVideo(p) && p.images.isNotEmpty,
      );
      await _pump(
        tester,
        Scaffold(
          body: SingleChildScrollView(child: PostCard(post: post)),
        ),
      );
      expect(find.byKey(Key('post_video_play_${post.id}')), findsNothing);
      expect(find.text('WORKOUT VIDEO'), findsNothing);
    });

    testWidgets(
      'a post flagged as video with no file shows no fake play button',
      (tester) async {
        final post = ActivityPost(
          id: 'x',
          userId: 'u',
          userName: 'U',
          type: ActivityPostType.workout,
          title: 'Flag only',
          description: '',
          images: const ['assets/community/photos/sp_alex_2.jpg'],
          metadata: const {'isVideo': true},
          createdAt: DateTime.now(),
        );
        expect(PostMedia.isVideo(post), isFalse);
        await _pump(
          tester,
          Scaffold(
            body: SingleChildScrollView(child: PostCard(post: post)),
          ),
        );
        expect(find.byKey(const Key('post_video_play_x')), findsNothing);
      },
    );

    testWidgets('a video attached to your own post plays from its file', (
      tester,
    ) async {
      final post = ActivityPost(
        id: 'mine',
        userId: 'usr_local',
        userName: 'Me',
        type: ActivityPostType.workout,
        title: 'My clip',
        description: '',
        images: const ['/data/user/0/atlas/cache/clip.mp4'],
        metadata: const {'isVideo': true},
        createdAt: DateTime.now(),
      );
      expect(PostMedia.videoSource(post), '/data/user/0/atlas/cache/clip.mp4');
      expect(PostMedia.poster(post), isNull);
      await _pump(
        tester,
        Scaffold(
          body: SingleChildScrollView(child: PostCard(post: post)),
        ),
      );
      expect(find.byKey(const Key('post_video_play_mine')), findsOneWidget);
    });

    testWidgets('Showcase Mode plays the same videos', (tester) async {
      await ShowcaseModeProvider.instance.enableShowcaseMode();
      final showcase = ShowcaseModeService.instance
          .getShowcaseCommunityPosts()
          .firstWhere(PostMedia.isVideo);
      await _pump(
        tester,
        Scaffold(
          body: SingleChildScrollView(child: PostCard(post: showcase)),
        ),
      );
      await tester.tap(find.byKey(Key('post_video_play_${showcase.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(VideoPlayerScreen), findsOneWidget);
      expect(showcase.id, _videoPost().id);
      await ShowcaseModeProvider.instance.disableShowcaseMode();
    });
  });

  group('the bundled sample media', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    test('every referenced file exists and is listed as an asset folder', () {
      expect(pubspec, contains('assets/community/photos/'));
      expect(pubspec, contains('assets/community/videos/'));
      for (final e in SampleMedia.all.entries) {
        for (final img in e.value.images) {
          expect(File(img).existsSync(), isTrue, reason: '${e.key}: $img');
        }
        final v = e.value.videoAsset;
        if (v != null) {
          expect(File(v).existsSync(), isTrue, reason: '${e.key}: $v');
        }
        expect(e.value.credit, contains('Wikimedia Commons'));
      }
    });

    test('every video post has a playable asset and a poster', () {
      final videos = SampleCommunity.posts().where(PostMedia.isVideo).toList();
      expect(videos.length, greaterThanOrEqualTo(12));
      for (final p in videos) {
        final src = PostMedia.videoSource(p)!;
        expect(File(src).existsSync(), isTrue, reason: p.id);
        expect(src.endsWith('.mp4'), isTrue, reason: 'MP4 plays on iOS too');
        expect(PostMedia.poster(p), isNotNull, reason: p.id);
        expect(p.metadata!['mediaCredit'], isNotNull);
      }
    });

    test('no photo or video is used by more than one post', () {
      final images = <String>[];
      final videos = <String>[];
      for (final e in SampleMedia.all.values) {
        images.addAll(e.images);
        if (e.videoAsset != null) videos.add(e.videoAsset!);
      }
      expect(images.toSet().length, images.length);
      expect(videos.toSet().length, videos.length);
      expect(images.length, greaterThanOrEqualTo(40));
    });

    test('every bundled file is used, and nothing is missing', () {
      final used = <String>{};
      for (final e in SampleMedia.all.values) {
        used.addAll(e.images);
        if (e.videoAsset != null) used.add(e.videoAsset!);
      }
      for (final f in used) {
        expect(File(f).existsSync(), isTrue, reason: 'missing $f');
      }
      final onDisk = [
        ...Directory('assets/community/photos').listSync(),
        ...Directory('assets/community/videos').listSync(),
      ].whereType<File>().map((f) => f.path.replaceAll(r'\', '/')).toSet();
      expect(onDisk.difference(used), isEmpty, reason: 'unused files bundled');
    });

    test('videos are short H.264 MP4 files', () {
      for (final e in SampleMedia.all.values.where((e) => e.videoAsset != null)) {
        final bytes = File(e.videoAsset!).readAsBytesSync();
        // ftyp box right at the start identifies an MP4 container.
        expect(String.fromCharCodes(bytes.sublist(4, 8)), 'ftyp', reason: e.videoAsset);
        final text = String.fromCharCodes(bytes);
        expect(text.contains('avc1'), isTrue, reason: '${e.videoAsset} is not H.264');
        // Movie header: version, flags, times, then timescale and duration.
        final i = text.indexOf('mvhd');
        final data = ByteData.sublistView(Uint8List.fromList(bytes));
        final v = bytes[i + 4];
        final timescale = data.getUint32(i + 4 + 4 + (v == 1 ? 16 : 8));
        final duration = v == 1
            ? data.getUint64(i + 4 + 4 + 20)
            : data.getUint32(i + 4 + 4 + 12);
        final seconds = duration / timescale;
        expect(seconds, inInclusiveRange(4.0, 15.0), reason: e.videoAsset);
        expect(bytes.length, lessThan(1500 * 1024), reason: e.videoAsset);
      }
    });

    test('the audit record lists every media post', () {
      final doc = File('docs/SAMPLE_MEDIA_AUDIT.md').readAsStringSync();
      for (final id in SampleMedia.all.keys) {
        expect(doc.contains(id), isTrue, reason: '$id missing from audit');
      }
    });

    test('media belongs only to sample posts', () {
      final ids = SampleCommunity.posts().map((p) => p.id).toSet();
      expect(SampleMedia.all.keys.every(ids.contains), isTrue);
      expect(SampleCommunity.posts().every((p) => p.isSample), isTrue);
    });

    test('files are small enough to keep the app light', () {
      final total = Directory('assets/community')
          .listSync(recursive: true)
          .whereType<File>()
          .fold<int>(0, (a, f) => a + f.lengthSync());
      expect(total, lessThan(16 * 1024 * 1024));
      for (final f in Directory(
        'assets/community/photos',
      ).listSync().whereType<File>()) {
        expect(f.lengthSync(), lessThan(260 * 1024), reason: f.path);
      }
      for (final f in Directory(
        'assets/community/videos',
      ).listSync().whereType<File>()) {
        expect(f.lengthSync(), lessThan(2 * 1024 * 1024), reason: f.path);
      }
    });

    test('no sample post depends on the network for its picture', () {
      for (final p in SampleCommunity.posts()) {
        for (final i in p.images) {
          expect(i.startsWith('assets/'), isTrue, reason: '${p.id} $i');
        }
      }
    });

    test('showcase and community serve the same media', () {
      expect(
        ShowcaseModeService.instance
            .getShowcaseCommunityPosts()
            .map(
              (p) => '${p.id}|${p.images.join()}|${PostMedia.videoSource(p)}',
            )
            .toList(),
        SampleCommunity.posts()
            .map(
              (p) => '${p.id}|${p.images.join()}|${PostMedia.videoSource(p)}',
            )
            .toList(),
      );
    });
  });
}
