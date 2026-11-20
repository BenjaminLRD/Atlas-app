import 'package:atlas/models/activity_record.dart';
import 'package:atlas/models/cardio_route.dart';
import 'package:atlas/services/cardio/cardio_tracker.dart';
import 'package:atlas/services/community/weekly_stats.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mocks/cardio_fakes.dart';

// About 11.1 m of latitude per 0.0001 degrees.
const _lat0 = 23.7271;
const _lng0 = 92.7176;

GpsFix _fix(FakeClock clock, double northM, {double? accuracy = 5}) =>
    GpsFix(_lat0 + northM / 111195, _lng0, clock.now, accuracyM: accuracy);

void main() {
  late FakeClock clock;
  late FakeSource source;

  CardioTracker tracker(CardioKind kind, {double? weight = 70}) =>
      CardioTracker(
        kind: kind,
        source: source,
        weightKg: weight,
        clock: clock.call,
      );

  setUp(() {
    CardioTracker.resetForTest();
    clock = FakeClock();
    source = FakeSource();
  });

  /// Runs north at [mps] metres per second for [seconds], one fix a second.
  void run(CardioTracker t, {required double mps, required int seconds}) {
    var north = t.route.isEmpty ? 0.0 : 0.0;
    // Continue from the last recorded point.
    if (t.route.isNotEmpty) {
      north = (t.route.last.lat - _lat0) * 111195;
    }
    for (var i = 0; i < seconds; i++) {
      clock.advance(1);
      north += mps;
      t.onFix(_fix(clock, north));
    }
  }

  group('activity selection', () {
    test('running and cycling are distinct kinds with their own wording', () {
      expect(CardioKind.running.label, 'Running');
      expect(CardioKind.cycling.label, 'Cycling');
      expect(CardioKind.running.primaryRateLabel, 'Pace');
      expect(CardioKind.cycling.primaryRateLabel, 'Speed');
      expect(CardioKind.fromKey('running'), CardioKind.running);
      expect(CardioKind.fromKey('Cycling'), CardioKind.cycling);
      expect(CardioKind.fromKey('rowing'), isNull);
      expect(CardioKind.fromKey(null), isNull);
    });
  });

  group('distance, time and pace', () {
    test('distance comes from the recorded positions', () async {
      final t = tracker(CardioKind.running);
      expect(await t.start(), isTrue);
      run(t, mps: 3, seconds: 100); // 300 m
      expect(t.distanceM, closeTo(297, 8));
      expect(t.distanceKm, closeTo(0.3, 0.01));
      expect(t.elapsed.inSeconds, 100);
      expect(t.route.length, greaterThan(30));
    });

    test('average pace and current pace come from measured speed', () async {
      final t = tracker(CardioKind.running);
      await t.start();
      run(t, mps: 3, seconds: 120); // 3 m/s = 10.8 km/h = 5:33 /km
      expect(t.avgSpeedKmh, closeTo(10.8, 0.3));
      expect(t.avgPaceSecPerKm, closeTo(333, 8));
      expect(t.currentSpeedKmh, closeTo(10.8, 0.5));
      expect(CardioFormat.pace(t.avgPaceSecPerKm), matches(r'^5:\d\d$'));
    });

    test(
      'speed and pace are unavailable until something is measured',
      () async {
        final t = tracker(CardioKind.cycling);
        await t.start();
        expect(t.avgSpeedKmh, isNull);
        expect(t.avgPaceSecPerKm, isNull);
        expect(t.currentSpeedKmh, isNull);
        expect(CardioFormat.pace(null), '–');
        expect(CardioFormat.speed(null), '–');
        // Genuine zero distance is a real 0, not a dash.
        expect(t.distanceKm, 0);
      },
    );

    test('standing still adds no distance and no current pace', () async {
      final t = tracker(CardioKind.running);
      await t.start();
      run(t, mps: 3, seconds: 30);
      final before = t.distanceM;
      for (var i = 0; i < 30; i++) {
        clock.advance(1);
        // The same spot, wobbling by a metre.
        t.onFix(
          _fix(
            clock,
            (t.route.last.lat - _lat0) * 111195 + (i.isEven ? 1 : -1),
          ),
        );
      }
      expect(t.distanceM, closeTo(before, 1));
      expect(t.currentSpeedKmh, isNull);
    });

    test('a position that is too inaccurate is ignored', () async {
      final t = tracker(CardioKind.running);
      await t.start();
      run(t, mps: 3, seconds: 10);
      final d = t.distanceM;
      clock.advance(1);
      t.onFix(_fix(clock, 5000, accuracy: 200));
      expect(t.distanceM, d);
      expect(t.gps, GpsStatus.weak);
    });

    test('a jump no runner could make is dropped', () async {
      final t = tracker(CardioKind.running);
      await t.start();
      run(t, mps: 3, seconds: 10);
      final d = t.distanceM;
      clock.advance(1);
      t.onFix(_fix(clock, 3000)); // 3 km in a second
      expect(t.distanceM, d);
    });

    test('a rider may go faster than a runner can', () async {
      final t = tracker(CardioKind.cycling);
      await t.start();
      run(t, mps: 9, seconds: 20); // 32 km/h
      expect(t.distanceM, closeTo(177, 9));
    });
  });

  group('pause and resume', () {
    test('paused time and distance are not counted', () async {
      final t = tracker(CardioKind.running);
      await t.start();
      run(t, mps: 3, seconds: 60); // 180 m
      t.pause();
      expect(t.isPaused, isTrue);
      // A minute passes and the athlete keeps moving, but it is not recorded.
      for (var i = 0; i < 60; i++) {
        clock.advance(1);
        t.onFix(_fix(clock, 180 + 3.0 * (i + 1)));
      }
      expect(t.distanceM, closeTo(177, 9));
      expect(t.elapsed.inSeconds, 60);
      expect(t.paused.inSeconds, 60);
      t.resume();
      expect(t.isRunning, isTrue);
      run(t, mps: 3, seconds: 30);
      // The 180 m travelled while paused is not added.
      expect(t.distanceM, closeTo(177 + 87, 14));
      expect(t.elapsed.inSeconds, 90);
    });

    test('pausing twice or resuming when not paused does nothing', () async {
      final t = tracker(CardioKind.running);
      await t.start();
      t.resume();
      expect(t.isRunning, isTrue);
      t.pause();
      t.pause();
      expect(t.isPaused, isTrue);
    });

    test(
      'finishing while paused keeps the paused time out of the duration',
      () async {
        final t = tracker(CardioKind.running);
        await t.start();
        run(t, mps: 3, seconds: 60);
        t.pause();
        clock.advance(120);
        final r = t.finish()!;
        expect(r.activeSeconds, 60);
        expect(r.pausedSeconds, 120);
      },
    );
  });

  group('GPS permission and signal', () {
    test(
      'permission denied: no session starts and the reason is shown',
      () async {
        source.access = LocationAccess.denied;
        final t = tracker(CardioKind.running);
        expect(await t.start(), isFalse);
        expect(t.state, TrackerState.idle);
        expect(t.gps, GpsStatus.permissionDenied);
        expect(t.finish(), isNull);
      },
    );

    test('permission denied for good is reported separately', () async {
      source.access = LocationAccess.deniedForever;
      final t = tracker(CardioKind.running);
      expect(await t.start(), isFalse);
      expect(t.gps, GpsStatus.permissionDeniedForever);
    });

    test('location switched off is reported', () async {
      source.access = LocationAccess.serviceDisabled;
      final t = tracker(CardioKind.cycling);
      expect(await t.start(), isFalse);
      expect(t.gps, GpsStatus.serviceDisabled);
    });

    test('it searches for GPS, then reports a good signal', () async {
      final t = tracker(CardioKind.running);
      await t.start();
      expect(t.gps, GpsStatus.searching);
      run(t, mps: 3, seconds: 3);
      expect(t.gps, GpsStatus.good);
    });

    test(
      'a lost signal is flagged and recovers when positions return',
      () async {
        final t = tracker(CardioKind.running);
        await t.start();
        run(t, mps: 3, seconds: 20);
        clock.advance(CardioTracker.signalTimeout.inSeconds + 3);
        t.tick();
        expect(t.gps, GpsStatus.weak);
        // Time still counts, distance does not move on its own.
        final d = t.distanceM;
        expect(t.distanceM, d);
        run(t, mps: 3, seconds: 5);
        expect(t.gps, GpsStatus.good);
      },
    );

    test('GPS switched off mid-session is reported', () async {
      final t = tracker(CardioKind.running);
      await t.start();
      source.controller.addError(StateError('gps off'));
      await Future<void>.delayed(Duration.zero);
      expect(t.gps, GpsStatus.serviceDisabled);
      expect(t.isRunning, isTrue);
    });
  });

  group('route recording', () {
    test('every accepted position is added in order', () async {
      final t = tracker(CardioKind.running);
      await t.start();
      run(t, mps: 4, seconds: 40);
      final r = t.route;
      expect(r.length, greaterThan(20));
      for (var i = 1; i < r.length; i++) {
        expect(r[i].lat, greaterThan(r[i - 1].lat));
      }
      expect(t.startPoint, r.first);
      expect(t.currentPosition, isNotNull);
    });

    test('positions that are not accepted are not drawn', () async {
      final t = tracker(CardioKind.running);
      await t.start();
      run(t, mps: 3, seconds: 5);
      final n = t.route.length;
      clock.advance(1);
      t.onFix(_fix(clock, 99999, accuracy: 500));
      expect(t.route.length, n);
    });

    test('the stream feeds the tracker', () async {
      final t = tracker(CardioKind.running);
      await t.start();
      for (var i = 1; i <= 10; i++) {
        clock.advance(1);
        source.controller.add(_fix(clock, i * 4.0));
      }
      await Future<void>.delayed(Duration.zero);
      expect(t.distanceM, closeTo(36, 4));
    });
  });

  group('finishing and discarding', () {
    test(
      'finishing returns the result once, however often it is called',
      () async {
        final t = tracker(CardioKind.running);
        await t.start();
        run(t, mps: 3, seconds: 120);
        final a = t.finish()!;
        final b = t.finish()!;
        expect(identical(a, b), isTrue);
        expect(a.kind, CardioKind.running);
        expect(a.activeSeconds, 120);
        expect(a.distanceKm, closeTo(0.36, 0.02));
        expect(a.route, isNotEmpty);
        expect(t.state, TrackerState.finished);
      },
    );

    test('a discarded session produces no result', () async {
      final t = tracker(CardioKind.running);
      await t.start();
      run(t, mps: 3, seconds: 60);
      t.discard();
      expect(t.state, TrackerState.discarded);
      expect(t.finish(), isNull);
    });

    test('positions after finishing are ignored', () async {
      final t = tracker(CardioKind.running);
      await t.start();
      run(t, mps: 3, seconds: 60);
      final r = t.finish()!;
      run(t, mps: 3, seconds: 30);
      expect(t.distanceM, r.distanceM);
    });
  });

  group('calories are an estimate, or not available', () {
    test('no body weight, no calorie figure', () async {
      final t = tracker(CardioKind.running, weight: null);
      await t.start();
      run(t, mps: 3, seconds: 300);
      expect(t.caloriesEstimate, isNull);
      expect(t.finish()!.caloriesEstimate, isNull);
    });

    test('too little time or no measured speed gives no figure', () async {
      final t = tracker(CardioKind.running);
      await t.start();
      run(t, mps: 3, seconds: 30);
      expect(t.caloriesEstimate, isNull);
    });

    test('a defensible estimate from MET, weight and time', () async {
      final t = tracker(CardioKind.running, weight: 70);
      await t.start();
      run(t, mps: 3, seconds: 600); // 10.8 km/h for 10 minutes -> MET 9.8
      final expected = 9.8 * 70 * (600 / 3600);
      expect(t.caloriesEstimate, closeTo(expected, 1));
      expect(CardioTracker.metFor(CardioKind.cycling, 10), 4.0);
      expect(CardioTracker.metFor(CardioKind.cycling, 23), 10.0);
      expect(CardioTracker.metFor(CardioKind.running, 10.5), 9.8);
      expect(
        CardioTracker.estimateCalories(
          CardioKind.running,
          20,
          10,
          const Duration(minutes: 10),
        ),
        isNull,
        reason: 'an implausible weight is not used',
      );
    });

    test('profile weights are read carefully', () {
      expect(parseProfileWeightKg('72'), 72);
      expect(parseProfileWeightKg('72.5 kg'), 72.5);
      expect(parseProfileWeightKg('160 lb'), closeTo(72.57, 0.05));
      expect(parseProfileWeightKg(''), isNull);
      expect(parseProfileWeightKg('abc'), isNull);
      expect(parseProfileWeightKg('5'), isNull);
    });
  });

  group('saved sessions', () {
    CardioSession session({List<RoutePoint> route = const []}) => CardioSession(
      id: 'cardio_1',
      exerciseId: 'outdoor_run',
      exerciseName: 'Outdoor Run',
      category: 'Running',
      durationSeconds: 1800,
      distanceKm: 5.0,
      caloriesBurned: 350,
      startTime: DateTime(2026, 11, 16, 7),
      route: route,
      pausedSeconds: 45,
    );

    test('the route, kind and paused time survive a save and load', () {
      final s = session(
        route: const [RoutePoint(23.7, 92.7, 1), RoutePoint(23.71, 92.71, 2)],
      );
      final back = CardioSession.fromJson(s.toJson());
      expect(back.kind, CardioKind.running);
      expect(back.route, s.route);
      expect(back.hasRoute, isTrue);
      expect(back.pausedSeconds, 45);
      expect(back.avgSpeedKmh, closeTo(10, 0.01));
    });

    test('older sessions without a route still load', () {
      final json = session().toJson()..remove('route');
      final back = CardioSession.fromJson(json);
      expect(back.route, isEmpty);
      expect(back.caloriesKnown, isTrue);
    });

    test('unknown calories are kept unknown through a save', () {
      final s = session().copyWith(caloriesKnown: false, caloriesBurned: 0);
      expect(CardioSession.fromJson(s.toJson()).caloriesKnown, isFalse);
    });

    test('a non-GPS exercise has no activity kind', () {
      final s = session().copyWith(category: 'Rowing');
      expect(s.kind, isNull);
    });
  });

  group('route helpers', () {
    test('route length matches the distance between points', () {
      const a = RoutePoint(23.7271, 92.7176);
      final b = RoutePoint(23.7271 + 0.001, 92.7176);
      expect(Geo.routeLengthM([a, b]), closeTo(111.2, 1));
    });

    test('downsampling keeps the ends and the cap', () {
      final route = [
        for (var i = 0; i < 1000; i++) RoutePoint(23 + i * 1e-5, 92),
      ];
      final d = Geo.downsample(route, 100);
      expect(d.length, 100);
      expect(d.first, route.first);
      expect(d.last, route.last);
      expect(Geo.downsample(route.take(10).toList(), 100).length, 10);
    });

    test('shared routes lose the first and last stretch', () {
      final route = [
        for (var i = 0; i <= 200; i++) RoutePoint(23 + i * 0.0001, 92),
      ]; // about 2.2 km
      final t = GeoPrivacy.trimEnds(route, 200);
      expect(t.length, lessThan(route.length - 30));
      final startGap = Geo.distanceM(
        route.first.lat,
        route.first.lng,
        t.first.lat,
        t.first.lng,
      );
      expect(startGap, greaterThanOrEqualTo(199));
      // A route too short to hide safely is left alone.
      final short = route.take(8).toList();
      expect(GeoPrivacy.trimEnds(short, 200), short);
    });

    test('bad points are rejected when reading a route', () {
      final r = RoutePoint.listFromJson([
        [23.7, 92.7],
        [999, 1],
        ['x', 1],
        [23.8],
        [23.9, 92.9, 5],
      ]);
      expect(r.length, 2);
    });
  });

  group('weekly statistics', () {
    CardioSession cardio(
      String id,
      DateTime at,
      double km, {
      String cat = 'Running',
    }) => CardioSession(
      id: id,
      exerciseId: 'x',
      exerciseName: 'x',
      category: cat,
      durationSeconds: 1800,
      distanceKm: km,
      caloriesBurned: 100,
      startTime: at,
    );

    test('runs and rides this week are totalled once each', () {
      final monday = DateTime(2026, 11, 16);
      final w = WeeklyStats.forWeek(
        history: const [],
        start: monday,
        cardio: [
          cardio('a', monday.add(const Duration(days: 1)), 5),
          cardio('a', monday.add(const Duration(days: 1)), 5), // duplicate id
          cardio('b', monday.add(const Duration(days: 2)), 20, cat: 'Cycling'),
          cardio('c', monday.subtract(const Duration(days: 2)), 9),
          cardio('d', monday.add(const Duration(days: 3)), 4, cat: 'Rowing'),
        ],
      );
      expect(w.cardioSessions, 2);
      expect(w.cardioKm, 25);
      // Strength figures are untouched by cardio.
      expect(w.workouts, isNull);
      expect(w.minutes, isNull);
    });

    test('no cardio this week is unknown, not zero', () {
      final w = WeeklyStats.forWeek(
        history: const [],
        start: DateTime(2026, 11, 16),
      );
      expect(w.cardioKm, isNull);
      expect(w.cardioSessions, isNull);
    });
  });
}
