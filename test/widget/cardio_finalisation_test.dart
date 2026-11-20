import 'dart:convert';
import 'dart:math' as math;

import 'package:atlas/app_theme.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/activity_post.dart';
import 'package:atlas/models/activity_record.dart';
import 'package:atlas/models/cardio_activity_data.dart';
import 'package:atlas/models/cardio_route.dart';
import 'package:atlas/models/post_comment.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/providers/showcase_mode_provider.dart';
import 'package:atlas/screens/cardio_activity_screen.dart';
import 'package:atlas/screens/cardio_history_screen.dart';
import 'package:atlas/screens/post_detail_screen.dart';
import 'package:atlas/services/cardio/cardio_journal.dart';
import 'package:atlas/services/cardio/route_privacy.dart';
import 'package:atlas/services/cloud/cloud_session.dart';
import 'package:atlas/services/community/cardio_post_publisher.dart';
import 'package:atlas/services/community/community_cloud_repository.dart';
import 'package:atlas/services/community/sample_community.dart';
import 'package:atlas/widgets/cardio/geo_map_view.dart';
import 'package:atlas/widgets/cardio/route_privacy_picker.dart';
import 'package:atlas/widgets/community/post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _lat0 = 23.7271;
const _lng0 = 92.7176;

List<RoutePoint> _outAndBack() {
  final pts = <RoutePoint>[];
  for (var i = 0; i <= 200; i++) {
    pts.add(RoutePoint(_lat0 + (i * 10) / 111195, _lng0, i * 1000));
  }
  for (var i = 200; i >= 0; i--) {
    pts.add(RoutePoint(_lat0 + (i * 10) / 111195, _lng0 + 0.0003, 0));
  }
  return pts;
}

double _fromHome(RoutePoint p) => Geo.distanceM(_lat0, _lng0, p.lat, p.lng);

/// Tiles that never load: the test environment answers every request with an
/// error, like a phone with no connection.
class _FailTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates c, TileLayer options) =>
      NetworkImage('http://tiles.invalid/${c.z}/${c.x}/${c.y}.png');
}

/// A transparent 1x1 tile that always loads.
class _OkTiles extends TileProvider {
  static final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_png);
}

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

CardioSession _session(
  String id,
  DateTime at, {
  String category = 'Running',
  double km = 5,
  int secs = 1800,
  bool route = true,
  bool completed = true,
  bool kcalKnown = true,
}) => CardioSession(
  id: id,
  exerciseId: 'x',
  exerciseName: category == 'Cycling' ? 'Outdoor Ride' : 'Outdoor Run',
  category: category,
  durationSeconds: secs,
  distanceKm: km,
  caloriesBurned: kcalKnown ? 320 : 0,
  caloriesKnown: kcalKnown,
  startTime: at,
  isCompleted: completed,
  route: route ? _outAndBack().take(40).toList() : const [],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    AppDependencies.reset();
    FitnessProvider.resetInstance();
  });

  group('map and fallback', () {
    testWidgets('with tiles it shows a real map, the route and attribution', (
      tester,
    ) async {
      await _pump(
        tester,
        GeoMapView(
          key: const Key('m'),
          route: _outAndBack(),
          height: 260,
          tileProvider: _OkTiles(),
        ),
      );
      expect(find.byKey(const Key('geo_map')), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(PolylineLayer), findsOneWidget);
      expect(find.byType(MarkerLayer), findsOneWidget);
      expect(find.byType(RichAttributionWidget), findsOneWidget);
      expect(find.byKey(const Key('map_fallback_note')), findsNothing);
      expect(MapConfig.attribution, contains('OpenStreetMap'));
      expect(MapConfig.userAgent, isNotEmpty);
    });

    testWidgets('no API key is embedded in the tile address', (tester) async {
      expect(MapConfig.tileUrl, isNot(contains('key=')));
      expect(MapConfig.tileUrl, isNot(contains('apikey')));
      expect(MapConfig.tileUrl, isNot(contains('access_token')));
    });

    testWidgets('a live position is shown over the route', (tester) async {
      final r = _outAndBack().take(30).toList();
      await _pump(
        tester,
        GeoMapView(
          route: r,
          current: r.last,
          follow: true,
          tileProvider: _OkTiles(),
        ),
      );
      expect(find.byKey(const Key('geo_map')), findsOneWidget);
    });

    testWidgets('a single position still shows a map, not an error', (
      tester,
    ) async {
      await _pump(
        tester,
        GeoMapView(
          route: const [],
          current: const RoutePoint(_lat0, _lng0),
          tileProvider: _OkTiles(),
        ),
      );
      expect(find.byKey(const Key('geo_map')), findsOneWidget);
    });

    testWidgets('when tiles cannot load the plain route is shown instead', (
      tester,
    ) async {
      // The test environment has no network: every tile request fails.
      await _pump(
        tester,
        GeoMapView(
          key: const Key('m'),
          route: _outAndBack(),
          height: 300,
          tileProvider: _FailTiles(),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byKey(const Key('map_fallback_note')).evaluate().isNotEmpty) {
          break;
        }
      }
      while (tester.takeException() != null) {}
      expect(find.byKey(const Key('map_fallback_note')), findsOneWidget);
      expect(find.textContaining('Map unavailable'), findsOneWidget);
      expect(find.byKey(const Key('route_canvas')), findsOneWidget);
      expect(find.byKey(const Key('geo_map')), findsNothing);
    });

    testWidgets('Retry tries the map again', (tester) async {
      await _pump(
        tester,
        GeoMapView(
          route: _outAndBack(),
          height: 300,
          tileProvider: _FailTiles(),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byKey(const Key('map_retry')).evaluate().isNotEmpty) break;
      }
      while (tester.takeException() != null) {}
      await tester.tap(find.byKey(const Key('map_retry')));
      await tester.pump();
      expect(find.byKey(const Key('geo_map')), findsOneWidget);
      expect(find.byKey(const Key('map_fallback_note')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      while (tester.takeException() != null) {}
    });

    testWidgets('without tiles available the route drawing is used directly', (
      tester,
    ) async {
      // Under flutter test there is no network and no tile provider injected.
      await _pump(tester, GeoMapView(route: _outAndBack(), isSample: true));
      expect(find.byKey(const Key('geo_map')), findsNothing);
      expect(find.byKey(const Key('route_canvas')), findsOneWidget);
      expect(find.byKey(const Key('sample_route_badge')), findsOneWidget);
    });

    testWidgets('an empty route says so', (tester) async {
      await _pump(
        tester,
        const GeoMapView(route: [], emptyMessage: 'Nothing here'),
      );
      expect(find.text('Nothing here'), findsOneWidget);
    });
  });

  group('privacy picker', () {
    CardioActivityData data(List<RoutePoint> r) => CardioActivityData(
      kind: CardioKind.running,
      title: 'Run',
      date: DateTime(2026, 11, 16, 7),
      distanceKm: 4,
      durationSeconds: 1500,
      route: r,
    );

    testWidgets('explains each choice and previews what others see', (
      tester,
    ) async {
      var mode = RoutePrivacyMode.hide200;
      await _pump(
        tester,
        StatefulBuilder(
          builder: (ctx, set) => RoutePrivacyPicker(
            data: data(_outAndBack()),
            mode: mode,
            onChanged: (m) => set(() => mode = m),
          ),
        ),
      );
      expect(find.byKey(const Key('privacy_preview')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('privacy_explanation'))).data,
        contains('200 m'),
      );
      await tester.tap(find.byKey(const Key('privacy_hide500')));
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const Key('privacy_explanation'))).data,
        contains('500 m'),
      );
      await tester.tap(find.byKey(const Key('privacy_none')));
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const Key('privacy_explanation'))).data,
        contains('home'),
      );
      await tester.tap(find.byKey(const Key('privacy_noRoute')));
      await tester.pump();
      expect(find.text('No route will be shared'), findsOneWidget);
    });

    testWidgets('a short route says it cannot be hidden safely', (
      tester,
    ) async {
      final short = [
        for (var i = 0; i <= 30; i++)
          RoutePoint(_lat0 + (i * 10) / 111195, _lng0),
      ];
      await _pump(
        tester,
        RoutePrivacyPicker(
          data: data(short),
          mode: RoutePrivacyMode.hide200,
          onChanged: (_) {},
        ),
      );
      expect(find.textContaining('Too short to hide safely'), findsOneWidget);
    });

    testWidgets('a shared post says its route is hidden, or not shared', (
      tester,
    ) async {
      final masked = CardioPostPublisher.buildDraft(
        data(_outAndBack()),
        caption: '',
        privacy: RoutePrivacyMode.hide200,
      );
      await _pump(tester, PostCard(post: masked));
      expect(find.byKey(const Key('route_canvas')), findsOneWidget);
      final none = CardioPostPublisher.buildDraft(
        data(_outAndBack()),
        caption: '',
        privacy: RoutePrivacyMode.noRoute,
      );
      await _pump(tester, PostCard(post: none));
      expect(find.text('Route not shared'), findsOneWidget);
    });
  });

  group('cardio history', () {
    final base = DateTime(2026, 11, 10, 7, 30);

    testWidgets('lists runs and rides, newest first, with the main figures', (
      tester,
    ) async {
      await _pump(
        tester,
        SizedBox(
          height: 900,
          child: CardioHistoryScreen(
            showcase: false,
            sessions: [
              _session('a', base),
              _session(
                'b',
                base.add(const Duration(days: 2)),
                category: 'Cycling',
                km: 24,
                secs: 3000,
              ),
            ],
          ),
        ),
        size: const Size(412, 1000),
      );
      final ids = tester
          .widgetList<InkWell>(
            find.byWidgetPredicate(
              (w) =>
                  w is InkWell &&
                  w.key.toString().contains('history_') &&
                  !w.key.toString().contains('filter'),
            ),
          )
          .map((w) => w.key.toString())
          .toList();
      expect(ids.first, contains("history_b"));
      expect(
        tester.widget<Text>(find.byKey(const Key('history_kind_a'))).data,
        'Running',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('history_kind_b'))).data,
        'Cycling',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('history_date_a'))).data,
        'Tue 10 Nov 2026, 07:30',
      );
      final run = tester
          .widget<Text>(find.byKey(const Key('history_stats_a')))
          .data!;
      expect(run, contains('5.00 km'));
      expect(run, contains('30:00'));
      expect(run, contains('6:00 /km'));
      expect(run, contains('320 kcal (est.)'));
      final ride = tester
          .widget<Text>(find.byKey(const Key('history_stats_b')))
          .data!;
      expect(ride, contains('24.00 km'));
      expect(ride, contains('28.8 km/h'));
      expect(find.byKey(const Key('history_route_a')), findsOneWidget);
    });

    testWidgets('unknown calories and a missing route are not invented', (
      tester,
    ) async {
      await _pump(
        tester,
        SizedBox(
          height: 900,
          child: CardioHistoryScreen(
            showcase: false,
            sessions: [_session('a', base, route: false, kcalKnown: false)],
          ),
        ),
        size: const Size(412, 1000),
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('history_stats_a'))).data,
        isNot(contains('kcal')),
      );
      expect(find.byKey(const Key('history_route_a')), findsNothing);
      expect(find.byKey(const Key('history_noroute_a')), findsOneWidget);
    });

    testWidgets('filters between running and cycling', (tester) async {
      await _pump(
        tester,
        SizedBox(
          height: 900,
          child: CardioHistoryScreen(
            showcase: false,
            sessions: [
              _session('a', base),
              _session(
                'b',
                base.add(const Duration(days: 1)),
                category: 'Cycling',
              ),
            ],
          ),
        ),
        size: const Size(412, 1000),
      );
      await tester.tap(find.byKey(const Key('hist_filter_running')));
      await tester.pump();
      expect(find.byKey(const Key('history_a')), findsOneWidget);
      expect(find.byKey(const Key('history_b')), findsNothing);
      await tester.tap(find.byKey(const Key('hist_filter_cycling')));
      await tester.pump();
      expect(find.byKey(const Key('history_b')), findsOneWidget);
      expect(find.byKey(const Key('history_a')), findsNothing);
      await tester.tap(find.byKey(const Key('hist_filter_all')));
      await tester.pump();
      expect(find.byKey(const Key('history_a')), findsOneWidget);
      expect(find.byKey(const Key('history_b')), findsOneWidget);
    });

    testWidgets('duplicates, unfinished and non-GPS sessions are left out', (
      tester,
    ) async {
      await _pump(
        tester,
        SizedBox(
          height: 900,
          child: CardioHistoryScreen(
            showcase: false,
            sessions: [
              _session('a', base),
              _session('a', base), // same id twice
              _session('u', base, completed: false),
              _session('row', base, category: 'Rowing'),
            ],
          ),
        ),
        size: const Size(412, 1000),
      );
      expect(find.byKey(const Key('history_a')), findsOneWidget);
      expect(find.byKey(const Key('history_u')), findsNothing);
      expect(find.byKey(const Key('history_row')), findsNothing);
    });

    testWidgets('tapping an entry opens the full activity with its route', (
      tester,
    ) async {
      await _pump(
        tester,
        SizedBox(
          height: 900,
          child: CardioHistoryScreen(
            showcase: false,
            sessions: [_session('a', base)],
          ),
        ),
        size: const Size(412, 1000),
      );
      await tester.tap(find.byKey(const Key('history_a')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('detail_map')), findsOneWidget);
      expect(find.byKey(const Key('stat_rate')), findsOneWidget);
    });

    testWidgets('an empty history explains itself', (tester) async {
      await _pump(
        tester,
        const SizedBox(
          height: 600,
          child: CardioHistoryScreen(showcase: false, sessions: []),
        ),
        size: const Size(412, 700),
      );
      expect(find.byKey(const Key('history_empty')), findsOneWidget);
    });

    testWidgets('Showcase shows labelled sample activities, never your own', (
      tester,
    ) async {
      await LocalStorage.saveCardioSession(_session('mine', base));
      await _pump(
        tester,
        const SizedBox(height: 900, child: CardioHistoryScreen(showcase: true)),
        size: const Size(412, 1000),
      );
      expect(find.byKey(const Key('history_sample_note')), findsOneWidget);
      expect(find.byKey(const Key('history_mine')), findsNothing);
      expect(find.text('SAMPLE'), findsWidgets);
    });

    for (final size in const [Size(320, 700), Size(360, 700), Size(412, 700)]) {
      testWidgets('fits ${size.width.toInt()} dp', (tester) async {
        await _pump(
          tester,
          SizedBox(
            height: 650,
            child: CardioHistoryScreen(
              showcase: false,
              sessions: [
                _session('a', base, km: 12.34, secs: 4000),
                _session('b', base, category: 'Cycling', km: 40, secs: 5400),
              ],
            ),
          ),
          size: size,
        );
        final ex = tester.takeException();
        if (ex != null) fail(ex is FlutterError ? ex.toStringDeep() : '$ex');
      });
    }
  });

  simulatedPublishing();

  group('recovering an unfinished session', () {
    String snapshotJson() => jsonEncode(
      CardioSnapshot(
        kind: CardioKind.running,
        startedAt: DateTime(2026, 11, 16, 7),
        activeMs: 25 * 60 * 1000,
        pausedMs: 0,
        paused: false,
        distanceM: 4200,
        route: _outAndBack().take(60).toList(),
        savedAt: DateTime(2026, 11, 16, 7, 26),
      ).toJson(),
    );

    testWidgets('offers to save it, and saving stores one session', (
      tester,
    ) async {
      await LocalStorage.saveCardioJournalJson(snapshotJson());
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
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('recover_text')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('recover_text'))).data,
        contains('4.20 km'),
      );
      await tester.tap(find.byKey(const Key('recover_save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final saved = LocalStorage.getCardioSessions();
      expect(saved.length, 1);
      expect(saved.single.category, 'Running');
      expect(saved.single.distanceKm, closeTo(4.2, 0.01));
      expect(saved.single.route, isNotEmpty);
      expect(LocalStorage.getCardioJournalJson(), isNull);
    });

    testWidgets('discarding saves nothing and clears the copy', (tester) async {
      await LocalStorage.saveCardioJournalJson(snapshotJson());
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
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const Key('recover_discard')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(LocalStorage.getCardioSessions(), isEmpty);
      expect(LocalStorage.getCardioJournalJson(), isNull);
    });

    testWidgets('a copy with almost nothing in it is dropped quietly', (
      tester,
    ) async {
      await LocalStorage.saveCardioJournalJson(
        jsonEncode(
          CardioSnapshot(
            kind: CardioKind.cycling,
            startedAt: DateTime(2026, 11, 16, 7),
            activeMs: 4000,
            pausedMs: 0,
            paused: false,
            distanceM: 3,
            route: const [],
            savedAt: DateTime(2026, 11, 16, 7, 1),
          ).toJson(),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const CardioActivityScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('recover_text')), findsNothing);
      expect(LocalStorage.getCardioJournalJson(), isNull);
    });

    testWidgets('Showcase never offers a recovery of real data', (
      tester,
    ) async {
      await LocalStorage.saveCardioJournalJson(snapshotJson());
      await ShowcaseModeProvider.instance.enableShowcaseMode();
      addTearDown(ShowcaseModeProvider.instance.disableShowcaseMode);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const CardioActivityScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('recover_text')), findsNothing);
    });
  });
}

// ---------------------------------------------------------------------------
// Publishing, against a SIMULATED server. This stands in for Supabase and its
// row-level security rules; it is not the real backend.
// ---------------------------------------------------------------------------

class _SimServer extends CommunityCloudRepository {
  _SimServer(this.viewer);

  /// The signed-in member making the call.
  String viewer;
  final List<Map<String, dynamic>> rows = [];
  final Set<String> likes = {};
  final List<PostComment> comments = [];
  final Set<String> blocks = {};
  int creates = 0;
  int n = 0;

  Map<String, dynamic> _json(Map<String, dynamic>? m) =>
      jsonDecode(jsonEncode(m ?? {})) as Map<String, dynamic>;

  @override
  Future<ActivityPost> createPost(ActivityPost draft, {dynamic photo}) async {
    creates++;
    final id = '00000000-0000-4000-8000-${(++n).toString().padLeft(12, '0')}';
    rows.add({
      'id': id,
      'user_id': viewer, // RLS: you can only post as yourself
      'type': draft.type.name,
      'title': draft.title,
      'description': draft.description,
      'metadata': _json(draft.metadata), // JSONB round trip
      'hidden': false,
    });
    return draft.copyWith(id: id, userId: viewer);
  }

  ActivityPost _post(Map<String, dynamic> r) => ActivityPost(
    id: r['id'] as String,
    userId: r['user_id'] as String,
    userName: 'Member',
    type: ActivityPostType.values.firstWhere((t) => t.name == r['type']),
    title: r['title'] as String,
    description: r['description'] as String,
    metadata: r['metadata'] as Map<String, dynamic>,
    createdAt: DateTime(2026, 11, 16, 8),
  );

  @override
  Future<List<ActivityPost>> fetchFeed({int limit = 30}) async => [
    for (final r in rows)
      // RLS "Visible posts": your own, or not hidden and not blocked.
      if (r['user_id'] == viewer ||
          (r['hidden'] != true && !blocks.contains('$viewer|${r['user_id']}')))
        _post(r),
  ];

  @override
  Future<void> setLiked(String postId, bool liked) async {
    final k = '$postId|$viewer';
    liked ? likes.add(k) : likes.remove(k);
  }

  @override
  Future<List<PostComment>> fetchComments(String postId) async => [
    for (final c in comments)
      if (c.postId == postId) c,
  ];

  @override
  Future<PostComment> addComment(String postId, String body) async {
    final c = PostComment(
      id: 'c${comments.length}',
      postId: postId,
      userId: viewer,
      userName: 'Member',
      userRank: 'Bronze',
      text: body,
      createdAt: DateTime(2026, 11, 16, 9),
    );
    comments.add(c);
    return c;
  }

  @override
  Future<void> deletePost(String postId) async {
    // RLS "Authors delete posts": only your own rows are deleted.
    rows.removeWhere((r) => r['id'] == postId && r['user_id'] == viewer);
  }
}

void simulatedPublishing() {
  group('publishing (SIMULATED server)', () {
    late _SimServer server;

    setUp(() {
      server = _SimServer('author');
      CloudSession.debugUserIdOverride = () => server.viewer;
      CommunityCloudRepository.setInstance(server);
    });

    tearDown(() {
      CloudSession.debugUserIdOverride = null;
      CommunityCloudRepository.setInstance(CommunityCloudRepository());
    });

    CardioActivityData activity() => CardioActivityData.fromSession(
      CardioSession(
        id: 'cardio_1',
        exerciseId: 'outdoor_run',
        exerciseName: 'Outdoor Run',
        category: 'Running',
        durationSeconds: 1500,
        distanceKm: 4.02,
        caloriesBurned: 300,
        startTime: DateTime(2026, 11, 16, 7),
        route: _outAndBack(),
      ),
    );

    test(
      'a published run stores the right metadata and only the masked route',
      () async {
        final post = await CardioPostPublisher.publish(
          activity(),
          caption: 'Lovely morning',
          privacy: RoutePrivacyMode.hide200,
        );
        expect(server.creates, 1);
        final row = server.rows.single;
        expect(row['type'], 'cardio');
        expect(row['description'], 'Lovely morning');
        final m = row['metadata'] as Map<String, dynamic>;
        expect(m['activity'], 'running');
        expect(m['distanceKm'], 4.02);
        expect(m['durationSeconds'], 1500);
        expect(m['calories'], 300);
        expect(m['caloriesEstimated'], isTrue);
        final route = RoutePoint.listFromJson(m['route']);
        expect(route.length, greaterThan(10));
        expect(
          route.length,
          lessThanOrEqualTo(CardioPostPublisher.maxRoutePoints),
        );
        expect(
          route.map(_fromHome).reduce(math.min),
          greaterThanOrEqualTo(199),
        );
        expect(CommunityCloudRepository.isCloudId(post.id), isTrue);
      },
    );

    test(
      'another member sees the post with its route and statistics',
      () async {
        await CardioPostPublisher.publish(
          activity(),
          caption: 'Hello',
          privacy: RoutePrivacyMode.hide200,
        );
        server.viewer = 'other';
        final feed = await server.fetchFeed();
        expect(feed.length, 1);
        final d = CardioActivityData.fromPost(feed.single)!;
        expect(d.kind, CardioKind.running);
        expect(d.distanceKm, 4.02);
        expect(d.durationSeconds, 1500);
        expect(d.routeMasked, isTrue);
        expect(
          d.route.map(_fromHome).reduce(math.min),
          greaterThanOrEqualTo(199),
        );
        expect(d.isSample, isFalse);
      },
    );

    testWidgets('the post opens from the feed with its route and statistics', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await CardioPostPublisher.publish(
        activity(),
        caption: 'Hello',
        privacy: RoutePrivacyMode.hide200,
      );
      server.viewer = 'other';
      final post = (await server.fetchFeed()).single;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SingleChildScrollView(child: PostCard(post: post)),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('4.02 km'), findsOneWidget);
      await tester.tap(find.text(post.title));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PostDetailScreen), findsOneWidget);
      expect(find.byKey(const Key('cardio_route_large')), findsOneWidget);
      expect(find.byKey(const Key('stat_rate')), findsOneWidget);
    });

    test('likes and comments work for another member', () async {
      final post = await CardioPostPublisher.publish(
        activity(),
        caption: '',
        privacy: RoutePrivacyMode.hide200,
      );
      server.viewer = 'other';
      await server.setLiked(post.id, true);
      expect(server.likes, contains('${post.id}|other'));
      await server.setLiked(post.id, false);
      expect(server.likes, isEmpty);
      final c = await server.addComment(post.id, 'Nice pace');
      expect(c.userId, 'other');
      expect((await server.fetchComments(post.id)).single.text, 'Nice pace');
    });

    test(
      'another member cannot remove the post, and cannot see it once hidden',
      () async {
        final post = await CardioPostPublisher.publish(
          activity(),
          caption: '',
          privacy: RoutePrivacyMode.hide200,
        );
        server.viewer = 'other';
        await server.deletePost(post.id);
        expect(server.rows.length, 1, reason: 'not theirs to delete');
        server.rows.single['hidden'] = true;
        expect(await server.fetchFeed(), isEmpty);
        server.viewer = 'author';
        expect(
          (await server.fetchFeed()).length,
          1,
          reason: 'the author still sees it',
        );
      },
    );

    test(
      'the unmasked route never reaches the server when masking is on',
      () async {
        final original = _outAndBack();
        await CardioPostPublisher.publish(
          activity(),
          caption: '',
          privacy: RoutePrivacyMode.hide500,
        );
        final stored = jsonEncode(server.rows.single);
        expect(stored, isNot(contains(original.first.lat.toStringAsFixed(5))));
        expect(stored, isNot(contains(original.last.lat.toStringAsFixed(5))));
      },
    );

    test(
      'sample activities and Showcase actions never reach the server',
      () async {
        await ShowcaseModeProvider.instance.enableShowcaseMode();
        addTearDown(ShowcaseModeProvider.instance.disableShowcaseMode);
        final sample = SampleCommunity.posts().firstWhere(
          (p) => p.type == ActivityPostType.cardio,
        );
        expect(CommunityCloudRepository.isCloudId(sample.id), isFalse);
        await expectLater(
          CardioPostPublisher.publish(
            CardioActivityData.fromPost(sample)!,
            caption: '',
          ),
          throwsStateError,
        );
        expect(server.creates, 0);
        expect(server.rows, isEmpty);
      },
    );
  });
}
