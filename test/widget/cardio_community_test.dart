import 'package:atlas/app_theme.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/activity_post.dart';
import 'package:atlas/models/cardio_activity_data.dart';
import 'package:atlas/models/cardio_route.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/screens/athlete_profile_screen.dart';
import 'package:atlas/screens/cardio_activity_screen.dart';
import 'package:atlas/screens/community_screen.dart';
import 'package:atlas/screens/post_detail_screen.dart';
import 'package:atlas/services/cardio/route_privacy.dart';
import 'package:atlas/services/community/cardio_post_publisher.dart';
import 'package:atlas/services/community/community_cloud_repository.dart';
import 'package:atlas/services/community/post_engagement.dart';
import 'package:atlas/services/community/sample_community.dart';
import 'package:atlas/services/community/sample_world.dart';
import 'package:atlas/services/moderation_service.dart';
import 'package:atlas/services/saved_content_service.dart';
import 'package:atlas/providers/showcase_mode_provider.dart';
import 'package:atlas/services/social_graph_service.dart';
import 'package:atlas/widgets/community/post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<RoutePoint> _route() => [
  for (var i = 0; i < 60; i++)
    RoutePoint(23.7271 + i * 0.0002, 92.7176 + (i.isEven ? 0.0003 : 0.0), 0),
];

ActivityPost _realRun({bool withRoute = true, bool calories = true}) {
  final data = CardioActivityData(
    kind: CardioKind.running,
    title: 'Morning Run',
    date: DateTime.now().subtract(const Duration(hours: 2)),
    distanceKm: 10.35,
    durationSeconds: 52 * 60 + 12,
    avgSpeedKmh: 10.35 / (3132 / 3600),
    avgPaceSecPerKm: 3132 / 10.35,
    calories: calories ? 640 : null,
    route: withRoute ? _route() : const [],
  );
  return ActivityPost(
    id: 'real_run_1',
    userId: 'usr_local',
    userName: 'Me',
    type: ActivityPostType.cardio,
    title: 'Morning Run',
    description: 'Felt strong today.',
    metadata: data.toPostMetadata(),
    createdAt: data.date,
  );
}

ActivityPost _realRide() {
  final data = CardioActivityData(
    kind: CardioKind.cycling,
    title: 'Evening Ride',
    date: DateTime.now().subtract(const Duration(hours: 5)),
    distanceKm: 32.05,
    durationSeconds: 5400,
    avgSpeedKmh: 32.05 / 1.5,
    calories: 900,
    route: _route(),
  );
  return ActivityPost(
    id: 'real_ride_1',
    userId: 'usr_local',
    userName: 'Me',
    type: ActivityPostType.cardio,
    title: 'Evening Ride',
    description: '',
    metadata: data.toPostMetadata(),
    createdAt: data.date,
  );
}

ActivityPost _samplePost({CardioKind? kind}) =>
    SampleCommunity.posts().firstWhere(
      (p) =>
          p.type == ActivityPostType.cardio &&
          (kind == null || p.metadata!['activity'] == kind.key),
    );

Future<void> _pump(WidgetTester tester, Widget child, {Size? size}) async {
  tester.view.physicalSize = size ?? const Size(412, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    AppDependencies.reset();
    FitnessProvider.resetInstance();
    SocialGraphService.resetInstance();
    SavedContentService.resetInstance();
    ModerationService.resetInstance();
  });

  group('sample runs and rides', () {
    test('are part of the shared sample world, by the existing athletes', () {
      final cardio = SampleCommunity.posts()
          .where((p) => p.type == ActivityPostType.cardio)
          .toList();
      expect(cardio.length, greaterThanOrEqualTo(8));
      final kinds = {for (final p in cardio) p.metadata!['activity']};
      expect(kinds, {'running', 'cycling'});
      final athleteIds = SampleWorld.athletes.map((a) => a.id).toSet();
      expect(athleteIds.length, 11);
      expect(cardio.every((p) => athleteIds.contains(p.userId)), isTrue);
      expect(cardio.map((p) => p.userId).toSet().length, greaterThan(4));
      expect(
        cardio.map((p) => p.description).toSet().length,
        cardio.length,
        reason: 'captions are unique',
      );
    });

    test('every sample activity is labelled and its figures agree', () {
      for (final p in SampleCommunity.posts().where(
        (p) => p.type == ActivityPostType.cardio,
      )) {
        final m = p.metadata!;
        expect(p.isSample, isTrue, reason: p.id);
        expect(m['sampleRoute'], isTrue, reason: p.id);
        final d = CardioActivityData.fromPost(p)!;
        expect(d.isSample, isTrue);
        final route = d.route;
        expect(route.length, greaterThan(40), reason: p.id);
        // Distance is the length of the drawn route.
        expect(
          d.distanceKm!,
          closeTo(Geo.routeLengthM(route) / 1000, d.distanceKm! * 0.02),
          reason: p.id,
        );
        // Speed, pace and duration agree with the distance.
        final hours = d.durationSeconds! / 3600;
        expect(d.avgSpeedKmh!, closeTo(d.distanceKm! / hours, 0.05));
        expect(d.avgPaceSecPerKm!, closeTo(3600 / d.avgSpeedKmh!, 1));
        // Believable ranges for the activity.
        if (d.kind == CardioKind.running) {
          expect(d.avgSpeedKmh, inInclusiveRange(7, 15), reason: p.id);
        } else {
          expect(d.avgSpeedKmh, inInclusiveRange(14, 30), reason: p.id);
        }
        // Calories are present only when estimated, never zero.
        if (d.calories != null) {
          expect(d.calories, greaterThan(50));
          expect(d.caloriesEstimated, isTrue);
        }
        expect(CommunityCloudRepository.isCloudId(p.id), isFalse);
      }
    });

    test(
      'some activities have no calorie figure rather than a made-up one',
      () {
        final cardio = SampleCommunity.posts()
            .where((p) => p.type == ActivityPostType.cardio)
            .map((p) => CardioActivityData.fromPost(p)!)
            .toList();
        expect(cardio.any((d) => d.calories == null), isTrue);
        expect(cardio.any((d) => d.calories != null), isTrue);
      },
    );

    test('sample interactions never reach the backend', () async {
      final p = _samplePost();
      expect(PostEngagement.isCloudPost(p), isFalse);
      await PostEngagement.persistLike(p.copyWith(isLiked: true, likes: 5));
      // Not stored among the user's own posts.
      expect(LocalStorage.getCommunityPosts(), isEmpty);
      expect(LocalStorage.getSampleLikedPostIds(), contains(p.id));
    });
  });

  group('the activity card', () {
    for (final size in const [Size(320, 900), Size(360, 900), Size(412, 900)]) {
      testWidgets('a real run fits ${size.width.toInt()} dp', (tester) async {
        await _pump(tester, PostCard(post: _realRun()), size: size);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('cardio_card_real_run_1')), findsOneWidget);
      });

      testWidgets('a sample ride fits ${size.width.toInt()} dp', (
        tester,
      ) async {
        await _pump(
          tester,
          PostCard(post: _samplePost(kind: CardioKind.cycling)),
          size: size,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a real run shows its own figures and no sample labels', (
      tester,
    ) async {
      await _pump(tester, PostCard(post: _realRun()));
      expect(find.text('RUNNING'), findsOneWidget);
      expect(find.text('10.35 km'), findsOneWidget);
      expect(find.text('52:12'), findsOneWidget);
      expect(find.text('5:03 /km'), findsOneWidget);
      expect(find.text('640 kcal (est.)'), findsOneWidget);
      expect(find.text('Felt strong today.'), findsOneWidget);
      expect(find.byKey(const Key('cardio_sample_label')), findsNothing);
      expect(find.byKey(const Key('sample_route_badge')), findsNothing);
      expect(find.byKey(const Key('route_canvas')), findsOneWidget);
    });

    testWidgets('a ride shows speed, not pace', (tester) async {
      await _pump(tester, PostCard(post: _realRide()));
      expect(find.text('CYCLING'), findsOneWidget);
      expect(find.text('Speed'), findsOneWidget);
      expect(find.text('Pace'), findsNothing);
      expect(find.text('21.4 km/h'), findsOneWidget);
    });

    testWidgets('unknown calories are left out, not shown as zero', (
      tester,
    ) async {
      await _pump(tester, PostCard(post: _realRun(calories: false)));
      expect(find.byKey(const Key('card_calories')), findsNothing);
      expect(find.textContaining('0 kcal'), findsNothing);
    });

    testWidgets('a run without a route says so instead of drawing one', (
      tester,
    ) async {
      await _pump(tester, PostCard(post: _realRun(withRoute: false)));
      expect(find.byKey(const Key('route_canvas')), findsNothing);
      expect(find.text('No GPS route'), findsOneWidget);
      expect(find.text('10.35 km'), findsOneWidget);
    });

    testWidgets('a sample activity and its route are labelled', (tester) async {
      final p = _samplePost(kind: CardioKind.running);
      await _pump(tester, PostCard(post: p));
      expect(find.byKey(const Key('cardio_sample_label')), findsOneWidget);
      expect(find.byKey(const Key('sample_route_badge')), findsOneWidget);
      expect(find.byKey(Key('sample_badge_${p.id}')), findsOneWidget);
    });
  });

  group('opening the activity', () {
    testWidgets('the route preview opens the full activity with a large map', (
      tester,
    ) async {
      await _pump(tester, PostCard(post: _realRun()));
      await tester.tap(find.byKey(const Key('cardio_route_preview')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail_map')), findsOneWidget);
      expect(find.text('Morning Run'), findsWidgets);
      expect(find.text('10.35'), findsOneWidget);
      expect(find.byKey(const Key('detail_sample_note')), findsNothing);
    });

    testWidgets('a sample activity says its route is not a real recording', (
      tester,
    ) async {
      await _pump(tester, PostCard(post: _samplePost()));
      await tester.tap(find.byKey(const Key('cardio_route_preview')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail_sample_note')), findsOneWidget);
      expect(find.byKey(const Key('sample_route_badge')), findsOneWidget);
    });

    testWidgets('tapping the card opens the post page with all statistics', (
      tester,
    ) async {
      await _pump(tester, PostCard(post: _realRun()));
      await tester.tap(find.text('Morning Run'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PostDetailScreen), findsOneWidget);
      expect(find.byKey(const Key('cardio_route_large')), findsOneWidget);
      expect(find.byKey(const Key('stat_rate')), findsOneWidget);
      expect(find.byKey(const Key('stat_calories')), findsOneWidget);
    });
  });

  group('existing post interactions still work', () {
    testWidgets('liking and unliking a sample activity', (tester) async {
      final p = _samplePost();
      await _pump(tester, PostCard(post: p));
      final base = p.likes;
      await tester.tap(find.byIcon(Icons.favorite_border_rounded).first);
      await tester.pump();
      expect(find.text('${base + 1}'), findsWidgets);
      await tester.tap(find.byIcon(Icons.favorite_rounded).first);
      await tester.pump();
      expect(find.text('$base'), findsWidgets);
    });

    testWidgets('the athlete avatar opens their profile', (tester) async {
      final p = _samplePost();
      await _pump(tester, PostCard(post: p));
      await tester.tap(find.byKey(Key('post_avatar_${p.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AthleteProfileScreen), findsOneWidget);
    });

    testWidgets('the comments button opens the sample comments', (
      tester,
    ) async {
      final p = SampleCommunity.posts().firstWhere(
        (p) => p.type == ActivityPostType.cardio && p.comments > 0,
      );
      await _pump(tester, PostCard(post: p));
      await tester.tap(find.byIcon(Icons.chat_bubble_outline_rounded).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(p.commentsList.first.text), findsOneWidget);
    });
  });

  group('the Community feed', () {
    testWidgets('offers a Run & Ride filter that shows only those posts', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.darkTheme, home: const CommunityScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final chip = find.text('🏃 Run & Ride');
      expect(chip, findsWidgets);
      await tester.ensureVisible(chip.first);
      await tester.pump();
      await tester.tap(chip.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(PostCard), findsWidgets);
      expect(find.textContaining('SAMPLE ACTIVITY'), findsWidgets);
      expect(find.text('WORKOUT COMPLETED'), findsNothing);
    });
  });

  group('Showcase Mode', () {
    testWidgets('shows the sample activities in the cardio hub, labelled', (
      tester,
    ) async {
      await ShowcaseModeProvider.instance.enableShowcaseMode();
      addTearDown(ShowcaseModeProvider.instance.disableShowcaseMode);
      tester.view.physicalSize = const Size(412, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const CardioActivityScreen(),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('sample_activities_header')), findsOneWidget);
      expect(find.textContaining('SAMPLE ACTIVITIES'), findsOneWidget);
      // Open a sample activity: same detail view as a real one.
      final p = SampleCommunity.posts().firstWhere(
        (p) => p.type == ActivityPostType.cardio,
      );
      await tester.tap(find.byKey(Key('sample_activity_${p.id}')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail_map')), findsOneWidget);
      expect(find.byKey(const Key('detail_sample_note')), findsOneWidget);
    });

    test('sharing a real activity is not possible in Showcase', () async {
      await ShowcaseModeProvider.instance.enableShowcaseMode();
      addTearDown(ShowcaseModeProvider.instance.disableShowcaseMode);
      expect(CardioPostPublisher.canShare, isFalse);
      final data = CardioActivityData.fromPost(_realRun())!;
      expect(
        () => CardioPostPublisher.publish(
          data,
          caption: '',
          privacy: RoutePrivacyMode.hide200,
        ),
        throwsStateError,
      );
      expect(LocalStorage.getCommunityPosts(), isEmpty);
    });
  });

  group('sharing a real activity', () {
    test('the post carries the real figures, not the sample flag', () {
      final data = CardioActivityData.fromPost(_realRun())!;
      final draft = CardioPostPublisher.buildDraft(
        data,
        caption: '  Great morning  ',
        privacy: RoutePrivacyMode.none,
        now: DateTime(2026, 11, 16, 8),
      );
      expect(draft.type, ActivityPostType.cardio);
      expect(draft.isSample, isFalse);
      expect(draft.description, 'Great morning');
      final m = draft.metadata!;
      expect(m['activity'], 'running');
      expect(m['distanceKm'], 10.35);
      expect(m['durationSeconds'], 3132);
      expect(m['calories'], 640);
      expect(m['caloriesEstimated'], isTrue);
      expect(m.containsKey('sampleRoute'), isFalse);
      expect((m['route'] as List).length, 60);
      expect(CardioActivityData.fromPost(draft)!.isSample, isFalse);
    });

    test('unknown calories are not put in the post', () {
      final data = CardioActivityData.fromPost(_realRun(calories: false))!;
      final draft = CardioPostPublisher.buildDraft(
        data,
        caption: '',
        privacy: RoutePrivacyMode.none,
      );
      expect(draft.metadata!.containsKey('calories'), isFalse);
    });

    test('hiding the start and end trims the shared route', () {
      final long = [
        for (var i = 0; i <= 300; i++) RoutePoint(23.7 + i * 0.0001, 92.7),
      ];
      final data = CardioActivityData(
        kind: CardioKind.running,
        title: 'Run',
        date: DateTime(2026, 11, 16),
        distanceKm: 3.3,
        durationSeconds: 1200,
        route: long,
      );
      final full = CardioPostPublisher.buildDraft(
        data,
        caption: '',
        privacy: RoutePrivacyMode.none,
      );
      final hidden = CardioPostPublisher.buildDraft(
        data,
        caption: '',
        privacy: RoutePrivacyMode.hide200,
      );
      final hiddenFirst = (hidden.metadata!['route'] as List).first as List;
      final gap = Geo.distanceM(
        long.first.lat,
        long.first.lng,
        (hiddenFirst[0] as num).toDouble(),
        (hiddenFirst[1] as num).toDouble(),
      );
      expect(gap, greaterThanOrEqualTo(195), reason: 'the start is hidden');
      expect(
        (full.metadata!['route'] as List).length,
        lessThanOrEqualTo(CardioPostPublisher.maxRoutePoints),
      );
    });
  });
}
