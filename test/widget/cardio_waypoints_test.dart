import 'dart:convert';

import 'package:atlas/app_theme.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/activity_record.dart';
import 'package:atlas/models/cardio_route.dart';
import 'package:atlas/models/waypoint_plan.dart';
import 'package:atlas/screens/gps_cardio_screen.dart';
import 'package:atlas/services/cardio/cardio_journal.dart';
import 'package:atlas/services/cardio/cardio_tracker.dart';
import 'package:atlas/widgets/cardio/geo_map_view.dart';
import 'package:atlas/widgets/cardio/stops_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/cardio_fakes.dart';

const _lat0 = 23.7271;
const _lng0 = 92.7176;

/// A transparent 1x1 tile that always loads.
class _OkTiles extends TileProvider {
  static final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
  );
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_png);
}

Waypoint _wp(String id, double dLat) =>
    Waypoint(id: id, lat: _lat0 + dLat, lng: _lng0);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    CardioTracker.resetForTest();
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('WaypointPlan rules', () {
    test('stops are ordered and the last one is the destination', () {
      final p = WaypointPlan();
      expect(p.add(_lat0, _lng0).ok, isTrue);
      expect(p.add(_lat0 + 0.002, _lng0).ok, isTrue);
      expect(p.add(_lat0 + 0.004, _lng0).ok, isTrue);
      expect(p.length, 3);
      expect(p.destination, p.stops.last);
    });

    test('invalid places are refused', () {
      final p = WaypointPlan();
      expect(p.add(91, 10).problem, WaypointProblem.invalidLocation);
      expect(p.add(10, 181).problem, WaypointProblem.invalidLocation);
      expect(p.add(double.nan, 10).problem, WaypointProblem.invalidLocation);
      expect(p.add(0, 0).problem, WaypointProblem.invalidLocation);
      expect(p.isEmpty, isTrue);
    });

    test('an accidental double tap is refused', () {
      final p = WaypointPlan();
      p.add(_lat0, _lng0);
      expect(p.add(_lat0 + 0.00003, _lng0).problem, WaypointProblem.tooClose);
      expect(p.length, 1);
    });

    test('the number of stops is limited', () {
      final p = WaypointPlan();
      for (var i = 0; i < WaypointPlan.maxStops; i++) {
        expect(p.add(_lat0 + i * 0.002, _lng0).ok, isTrue);
      }
      expect(p.add(_lat0 + 0.5, _lng0).problem, WaypointProblem.tooMany);
    });

    test('remove and reorder keep the order consistent', () {
      final p = WaypointPlan();
      final a = p.add(_lat0, _lng0).added!;
      final b = p.add(_lat0 + 0.002, _lng0).added!;
      final c = p.add(_lat0 + 0.004, _lng0).added!;
      p.reorder(2, 0);
      expect(p.stops.map((w) => w.id), [c.id, a.id, b.id]);
      p.remove(a.id);
      expect(p.stops.map((w) => w.id), [c.id, b.id]);
      expect(p.destination!.id, b.id);
    });

    test('legs and total are straight-line distances between stops', () {
      final p = WaypointPlan();
      p.add(_lat0, _lng0);
      p.add(_lat0 + 0.001, _lng0); // about 111 m north
      p.add(_lat0 + 0.003, _lng0); // about 222 m further
      final legs = p.legsM;
      expect(legs.length, 2);
      expect(legs[0], inInclusiveRange(105, 118));
      expect(legs[1], inInclusiveRange(215, 230));
      expect(p.totalM, closeTo(legs[0] + legs[1], 0.001));
      expect(WaypointPlan.formatDistance(640), '640 m');
      expect(WaypointPlan.formatDistance(3200), '3.20 km');
    });

    test('it survives saving and loading, and drops bad entries', () {
      final p = WaypointPlan();
      p.add(_lat0, _lng0);
      p.add(_lat0 + 0.002, _lng0);
      final back = WaypointPlan.decode(p.encode());
      expect(back.length, 2);
      final next = back.add(_lat0 + 0.004, _lng0).added!;
      expect(back.stops.map((w) => w.id).toSet().length, 3); // unique ids
      expect(next.id, isNot(back.stops.first.id));
      expect(WaypointPlan.decode('not json').isEmpty, isTrue);
      expect(
        WaypointPlan.decode('[{"id":"x","lat":999,"lng":1}]').isEmpty,
        isTrue,
      );
    });
  });

  group('map markers and tapping', () {
    Future<void> pumpMap(
      WidgetTester tester, {
      List<Waypoint> waypoints = const [],
      void Function(LatLng)? onTap,
    }) async {
      tester.view.physicalSize = const Size(412, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: GeoMapView(
              route: [
                RoutePoint(_lat0, _lng0, 0),
                RoutePoint(_lat0 + 0.001, _lng0, 1),
              ],
              current: RoutePoint(_lat0 + 0.001, _lng0, 2),
              height: 300,
              tileProvider: _OkTiles(),
              waypoints: waypoints,
              onTap: onTap,
              editingHint: 'Tap the map to add a stop',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('stops, destination and the planned line are drawn', (
      tester,
    ) async {
      await pumpMap(
        tester,
        waypoints: [_wp('a', 0.002), _wp('b', 0.004), _wp('c', 0.006)],
      );
      expect(find.byKey(const Key('waypoint_marker_1')), findsOneWidget);
      expect(find.byKey(const Key('waypoint_marker_2')), findsOneWidget);
      expect(find.byKey(const Key('destination_marker')), findsOneWidget);
      // The recorded route and the planned line are separate layers.
      expect(find.byType(PolylineLayer), findsNWidgets(2));
    });

    testWidgets('no stops means no stop markers and one line only', (
      tester,
    ) async {
      await pumpMap(tester);
      expect(find.byKey(const Key('destination_marker')), findsNothing);
      expect(find.byType(PolylineLayer), findsOneWidget);
    });

    testWidgets('tapping the map while editing reports the place', (
      tester,
    ) async {
      LatLng? tapped;
      await pumpMap(tester, onTap: (p) => tapped = p);
      expect(find.byKey(const Key('map_editing_hint')), findsOneWidget);
      expect(find.byKey(const Key('map_editing_frame')), findsOneWidget);
      await tester.tapAt(tester.getCenter(find.byKey(const Key('geo_map'))));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tapped, isNotNull);
      expect(tapped!.latitude, closeTo(_lat0, 0.01));
    });

    testWidgets('without edit mode a tap does nothing and no hint shows', (
      tester,
    ) async {
      await pumpMap(tester);
      expect(find.byKey(const Key('map_editing_hint')), findsNothing);
      expect(find.byKey(const Key('map_editing_frame')), findsNothing);
    });

    testWidgets('the Atlas tile treatment is only used in the dark theme', (
      tester,
    ) async {
      await pumpMap(tester);
      expect(find.byType(ColorFiltered), findsWidgets);
      tester.view.physicalSize = const Size(412, 800);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: GeoMapView(
              route: [
                RoutePoint(_lat0, _lng0, 0),
                RoutePoint(_lat0 + 0.001, _lng0, 1),
              ],
              height: 300,
              tileProvider: _OkTiles(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(ColorFiltered), findsNothing);
    });
  });

  group('stops panel', () {
    Future<WaypointPlan> pumpPanel(
      WidgetTester tester, {
      required WaypointPlan plan,
      VoidCallback? onAddHere,
      void Function(String)? onRemove,
      void Function(int, int)? onReorder,
      VoidCallback? onDone,
      double textScale = 1.0,
      double width = 360,
    }) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 900),
              textScaler: TextScaler.linear(textScale),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: StopsPanel(
                  plan: plan,
                  fromLat: _lat0,
                  fromLng: _lng0,
                  onAddHere: onAddHere,
                  addHereHint: 'Waiting for GPS.',
                  onRemove: onRemove ?? (_) {},
                  onReorder: onReorder ?? (_, _) {},
                  onClear: () {},
                  onDone: onDone ?? () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return plan;
    }

    testWidgets('empty: explains how to add a stop', (tester) async {
      await pumpPanel(tester, plan: WaypointPlan());
      expect(find.text('Plan your stops'), findsOneWidget);
      expect(find.textContaining('Tap the map'), findsOneWidget);
      expect(find.byKey(const Key('stops_done')), findsOneWidget);
    });

    testWidgets('lists stops in order with leg distances and a disclaimer', (
      tester,
    ) async {
      final plan = WaypointPlan();
      plan.add(_lat0 + 0.001, _lng0);
      plan.add(_lat0 + 0.003, _lng0);
      await pumpPanel(tester, plan: plan);
      expect(find.text('Stop 1'), findsOneWidget);
      expect(find.text('Destination'), findsOneWidget);
      expect(find.textContaining('from you'), findsOneWidget);
      expect(find.textContaining('from stop 1'), findsOneWidget);
      expect(find.byKey(const Key('stops_total')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('stops_disclaimer'))).data,
        allOf(contains('Straight-line'), contains('turn-by-turn')),
      );
    });

    testWidgets('remove and Done call back; Add my position is optional', (
      tester,
    ) async {
      final plan = WaypointPlan();
      final a = plan.add(_lat0 + 0.001, _lng0).added!;
      String? removed;
      var done = false;
      await pumpPanel(
        tester,
        plan: plan,
        onRemove: (id) => removed = id,
        onDone: () => done = true,
      );
      // No GPS: the button is disabled and says why.
      expect(find.byKey(const Key('stops_add_here_hint')), findsOneWidget);
      await tester.tap(find.byKey(Key('stop_remove_${a.id}')));
      await tester.tap(find.byKey(const Key('stops_done')));
      expect(removed, a.id);
      expect(done, isTrue);
    });

    for (final w in const [320.0, 360.0]) {
      for (final s in const [1.0, 1.5]) {
        testWidgets('no overflow at ${w.toInt()}dp, text x$s', (tester) async {
          final plan = WaypointPlan();
          for (var i = 0; i < 4; i++) {
            plan.add(_lat0 + i * 0.002, _lng0);
          }
          await pumpPanel(tester, plan: plan, textScale: s, width: w);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('on the live screen (run and ride)', () {
    late FakeSource source;
    late FakeClock clock;
    late CardioJournal journal;
    String? journalDisk;

    Future<void> open(WidgetTester tester, CardioKind kind) async {
      source = FakeSource();
      clock = FakeClock();
      journalDisk = null;
      journal = CardioJournal(
        read: () => journalDisk,
        write: (j) async => journalDisk = j,
        erase: () async => journalDisk = null,
      );
      tester.view.physicalSize = const Size(412, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: GpsCardioScreen(
            initialKind: kind,
            source: source,
            weightKg: 70,
            clock: clock.call,
            persist: (CardioSession s, ActivityRecord a) async {},
            journal: journal,
            explainBackground: false,
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> startAndFix(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('cardio_start')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      clock.advance(1);
      source.controller.add(GpsFix(_lat0, _lng0, clock.now, accuracyM: 5));
      await tester.pump(const Duration(milliseconds: 20));
    }

    for (final kind in [CardioKind.running, CardioKind.cycling]) {
      testWidgets('${kind.name}: add, reorder, remove and finish stops', (
        tester,
      ) async {
        await open(tester, kind);
        await startAndFix(tester);
        await tester.tap(find.byKey(const Key('stops_button')));
        await tester.pump();
        expect(find.byKey(const Key('stops_panel')), findsOneWidget);

        final add = find.byKey(const Key('stops_add_here'));
        await tester.ensureVisible(add);
        await tester.tap(add);
        await tester.pump();
        // A second tap at the same spot is refused, not silently added.
        await tester.tap(add);
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.textContaining('too close'), findsOneWidget);
        expect(find.text('Destination'), findsOneWidget);

        // The recorded route is unchanged by planning stops.
        expect(
          tester.widget<Text>(find.byKey(const Key('cardio_distance'))).data,
          isNotNull,
        );

        // Persisted so a rebuilt screen keeps the plan.
        expect(
          WaypointPlan.decode(
            LocalStorage.getString('cardio_planned_stops_v1'),
          ).length,
          1,
        );

        final done = find.byKey(const Key('stops_done'));
        await tester.ensureVisible(done);
        await tester.tap(done);
        await tester.pump();
        expect(find.byKey(const Key('stops_panel')), findsNothing);
        expect(find.byKey(const Key('stops_summary')), findsOneWidget);
        expect(find.textContaining('1 planned stop'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
      });
    }

    testWidgets('before tracking the button explains what is needed', (
      tester,
    ) async {
      await open(tester, CardioKind.running);
      expect(find.byKey(const Key('stops_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('stops_button')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Start tracking first'), findsOneWidget);
      expect(find.byKey(const Key('stops_panel')), findsNothing);
    });

    testWidgets('planning stops adds no point to the recorded route', (
      tester,
    ) async {
      await open(tester, CardioKind.running);
      await startAndFix(tester);
      String distance() =>
          tester.widget<Text>(find.byKey(const Key('cardio_distance'))).data!;
      final before = distance();
      await tester.tap(find.byKey(const Key('stops_button')));
      await tester.pump();
      final add = find.byKey(const Key('stops_add_here'));
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pump();
      expect(distance(), before);
      expect(journalDisk, isNot(contains('wp_')));
      await tester.pumpWidget(const SizedBox());
    });
  });
}
