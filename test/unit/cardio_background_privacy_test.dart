import 'dart:io';
import 'dart:math' as math;

import 'package:atlas/models/cardio_activity_data.dart';
import 'package:atlas/models/cardio_route.dart';
import 'package:atlas/services/cardio/cardio_journal.dart';
import 'package:atlas/services/cardio/cardio_tracker.dart';
import 'package:atlas/services/cardio/geolocator_location_source.dart';
import 'package:atlas/services/cardio/route_privacy.dart';
import 'package:atlas/services/community/cardio_post_publisher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import '../mocks/cardio_fakes.dart';

const _lat0 = 23.7271;
const _lng0 = 92.7176;

GpsFix _fix(FakeClock c, double northM, {double eastM = 0}) => GpsFix(
  _lat0 + northM / 111195,
  _lng0 + eastM / (111195 * math.cos(_lat0 * math.pi / 180)),
  c.now,
  accuracyM: 5,
);

/// A 4 km out-and-back route heading north from a "home" at the origin.
List<RoutePoint> _outAndBack({double km = 4}) {
  final pts = <RoutePoint>[];
  final steps = (km * 1000 / 2 / 10).round();
  for (var i = 0; i <= steps; i++) {
    pts.add(RoutePoint(_lat0 + (i * 10) / 111195, _lng0, i * 1000));
  }
  for (var i = steps; i >= 0; i--) {
    pts.add(
      RoutePoint(
        _lat0 + (i * 10) / 111195,
        _lng0 + 0.0003,
        (2 * steps - i) * 1000,
      ),
    );
  }
  return pts;
}

double _fromHome(RoutePoint p) => Geo.distanceM(_lat0, _lng0, p.lat, p.lng);

void main() {
  late FakeClock clock;
  late FakeSource source;
  String? disk;
  late CardioJournal journal;

  setUp(() {
    CardioTracker.resetForTest();
    clock = FakeClock();
    source = FakeSource();
    disk = null;
    journal = CardioJournal(
      read: () => disk,
      write: (j) async => disk = j,
      erase: () async => disk = null,
    );
  });

  CardioTracker make({
    CardioKind kind = CardioKind.running,
    bool withJournal = true,
  }) => CardioTracker(
    kind: kind,
    source: source,
    weightKg: 70,
    clock: clock.call,
    journal: withJournal ? journal : null,
  );

  group('background tracking configuration', () {
    test('Android: a foreground service with an ongoing notification', () {
      final s =
          GeolocatorLocationSource.settingsFor(
                TargetPlatform.android,
                activityLabel: 'Running',
              )
              as AndroidSettings;
      final n = s.foregroundNotificationConfig!;
      expect(n.notificationTitle, 'Atlas is recording your running');
      expect(n.notificationText, isNotEmpty);
      expect(n.setOngoing, isTrue);
      expect(n.enableWakeLock, isTrue);
      expect(s.accuracy, LocationAccuracy.best);
    });

    test('iOS: background updates with the system indicator', () {
      final s =
          GeolocatorLocationSource.settingsFor(TargetPlatform.iOS)
              as AppleSettings;
      expect(s.allowBackgroundLocationUpdates, isTrue);
      expect(s.showBackgroundLocationIndicator, isTrue);
      expect(s.pauseLocationUpdatesAutomatically, isFalse);
      expect(s.activityType, ActivityType.fitness);
    });

    test('other platforms get plain settings, no background claim', () {
      final s = GeolocatorLocationSource.settingsFor(TargetPlatform.windows);
      expect(s, isNot(isA<AndroidSettings>()));
      expect(s, isNot(isA<AppleSettings>()));
    });

    test('the Android manifest declares the location foreground service', () {
      final m = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(m, contains('android.permission.FOREGROUND_SERVICE_LOCATION'));
      expect(m, contains('android.permission.FOREGROUND_SERVICE"'));
      expect(m, contains('android.permission.ACCESS_FINE_LOCATION'));
      // No always-on background location permission is requested.
      expect(m, isNot(contains('ACCESS_BACKGROUND_LOCATION')));
    });

    test(
      'the iOS Info.plist has the location background mode and a reason',
      () {
        final p = File('ios/Runner/Info.plist').readAsStringSync();
        expect(p, contains('UIBackgroundModes'));
        expect(p, contains('<string>location</string>'));
        expect(p, contains('NSLocationWhenInUseUsageDescription'));
      },
    );
  });

  group('background lifecycle', () {
    test(
      'starting opens one location stream with the activity in the notification',
      () async {
        final t = make();
        expect(await t.start(), isTrue);
        expect(source.listens, 1);
        expect(source.lastLabel, 'Running');
        expect(t.isLocationServiceRunning, isTrue);
        t.discard();
      },
    );

    test('time keeps counting while the app is in the background', () async {
      final t = make();
      await t.start();
      // Ten minutes pass with the screen locked and the UI timer stopped.
      for (var i = 1; i <= 600; i++) {
        clock.advance(1);
        if (i % 2 == 0) source.controller.add(_fix(clock, i * 3.0));
      }
      await Future<void>.delayed(Duration.zero);
      expect(t.elapsed.inSeconds, 600);
      expect(t.distanceM, closeTo(1797, 40));
      expect(t.route.length, greaterThan(100));
      t.discard();
    });

    test('pause and resume keep the same service running', () async {
      final t = make();
      await t.start();
      t.pause();
      expect(t.isLocationServiceRunning, isTrue);
      t.resume();
      expect(t.isLocationServiceRunning, isTrue);
      expect(source.listens, 1);
      t.discard();
    });

    test('finishing stops the background service', () async {
      final t = make();
      await t.start();
      for (var i = 1; i <= 30; i++) {
        clock.advance(2);
        t.onFix(_fix(clock, i * 6.0));
      }
      t.finish();
      expect(t.isLocationServiceRunning, isFalse);
      expect(source.controller.hasListener, isFalse);
      expect(CardioTracker.isAnyRecording, isFalse);
    });

    test(
      'discarding stops the service and removes the recovery copy',
      () async {
        final t = make();
        await t.start();
        expect(disk, isNotNull, reason: 'a copy is written at the start');
        t.discard();
        expect(t.isLocationServiceRunning, isFalse);
        expect(source.controller.hasListener, isFalse);
        expect(disk, isNull);
      },
    );

    test('a second session cannot start a second service', () async {
      final a = make();
      final source2 = FakeSource();
      final b = CardioTracker(
        kind: CardioKind.cycling,
        source: source2,
        clock: clock.call,
      );
      expect(await a.start(), isTrue);
      expect(await b.start(), isFalse);
      expect(b.gps, GpsStatus.busy);
      expect(b.state, TrackerState.idle);
      expect(source.listens, 1);
      expect(source2.listens, 0, reason: 'no second service was opened');
      a.finish();
      expect(await b.start(), isTrue, reason: 'free again after finishing');
      expect(source2.listens, 1);
      b.discard();
    });

    test('starting twice on the same session does nothing', () async {
      final t = make();
      await t.start();
      expect(await t.start(), isFalse);
      expect(source.listens, 1);
      t.discard();
    });

    test('disposing the tracker releases the service and the slot', () async {
      final t = make();
      await t.start();
      t.dispose();
      expect(source.controller.hasListener, isFalse);
      expect(CardioTracker.isAnyRecording, isFalse);
    });
  });

  group('recovery after the app is ended', () {
    test('a copy is saved as the run goes on', () async {
      final t = make();
      await t.start();
      for (var i = 1; i <= 25; i++) {
        clock.advance(2);
        t.onFix(_fix(clock, i * 6.0));
      }
      final snap = journal.load()!;
      expect(snap.kind, CardioKind.running);
      expect(snap.route.length, greaterThan(10));
      expect(snap.distanceM, greaterThan(100));
      expect(snap.activeMs, greaterThan(20000));
      t.discard();
    });

    test(
      'a copy survives and becomes a saveable session with a stable id',
      () async {
        final t = make();
        await t.start();
        for (var i = 1; i <= 60; i++) {
          clock.advance(2);
          t.onFix(_fix(clock, i * 6.0));
        }
        t.pause(); // pause forces a final copy
        // The app is killed here: no finish, no discard.
        final recovered = CardioJournal(
          read: () => disk,
          write: (_) async {},
          erase: () async {},
        );
        final snap = recovered.load()!;
        expect(snap.paused, isTrue);
        final draft = snap.toDraft(weightKg: 70);
        expect(draft.distanceM, closeTo(t.distanceM, 1));
        expect(draft.activeSeconds, closeTo(120, 2));
        expect(draft.caloriesEstimate, isNotNull);
        final (session, activity) = CardioSessionBuilder.build(draft);
        expect(session.category, 'Running');
        expect(session.route, isNotEmpty);
        expect(session.id, draft.sessionId);
        expect(activity.id, 'act_${session.id}');
        // Building again gives the same id, so saving twice replaces, not duplicates.
        expect(CardioSessionBuilder.build(draft).$1.id, session.id);
        t.discard();
      },
    );

    test('a damaged or empty copy is ignored', () {
      expect(
        CardioJournal(
          read: () => '{nope',
          write: (_) async {},
          erase: () async {},
        ).load(),
        isNull,
      );
      expect(
        CardioJournal(
          read: () => null,
          write: (_) async {},
          erase: () async {},
        ).load(),
        isNull,
      );
      expect(
        CardioJournal(
          read: () => '{"kind":"x"}',
          write: (_) async {},
          erase: () async {},
        ).load(),
        isNull,
      );
    });

    test('a failing write never stops the recording', () async {
      final bad = CardioJournal(
        read: () => null,
        write: (_) async => throw StateError('disk full'),
        erase: () async {},
      );
      final t = CardioTracker(
        kind: CardioKind.running,
        source: source,
        clock: clock.call,
        journal: bad,
      );
      await t.start();
      clock.advance(2);
      t.onFix(_fix(clock, 5));
      expect(t.isRunning, isTrue);
      t.discard();
    });
  });

  group('route privacy', () {
    test('full route and no route are honoured', () {
      final r = _outAndBack();
      final full = RoutePrivacy.apply(r, RoutePrivacyMode.none, seed: 1);
      expect(full.route.length, r.length);
      expect(full.masked, isFalse);
      final none = RoutePrivacy.apply(r, RoutePrivacyMode.noRoute, seed: 1);
      expect(none.hasRoute, isFalse);
    });

    test('nothing near home survives, wherever it is on the route', () {
      final r = _outAndBack();
      for (final mode in [RoutePrivacyMode.hide200, RoutePrivacyMode.hide500]) {
        for (var seed = 0; seed < 25; seed++) {
          final m = RoutePrivacy.apply(r, mode, seed: seed * 7919);
          expect(m.hasRoute, isTrue, reason: '$mode $seed');
          final closest = m.route.map(_fromHome).reduce(math.min);
          expect(
            closest,
            greaterThanOrEqualTo(mode.radiusM.toDouble()),
            reason: '$mode seed $seed leaked a point at ${closest}m',
          );
          expect(m.masked, isTrue);
        }
      }
    });

    test(
      'a loop that returns past the start door halfway is cut there too',
      () {
        // North 1 km, back to the door, then east 1 km, then back to the door.
        final pts = <RoutePoint>[];
        for (var i = 0; i <= 100; i++) {
          pts.add(RoutePoint(_lat0 + (i * 10) / 111195, _lng0));
        }
        for (var i = 100; i >= 0; i--) {
          pts.add(RoutePoint(_lat0 + (i * 10) / 111195, _lng0 + 0.0002));
        }
        for (var i = 0; i <= 100; i++) {
          pts.add(
            RoutePoint(
              _lat0 + 0.0005,
              _lng0 +
                  0.0004 +
                  i * 10 / (111195 * math.cos(_lat0 * math.pi / 180)),
            ),
          );
        }
        pts.add(RoutePoint(_lat0, _lng0 + 0.00001)); // finish at the door
        final m = RoutePrivacy.apply(pts, RoutePrivacyMode.hide200, seed: 3);
        expect(
          m.route.map(_fromHome).reduce(math.min),
          greaterThanOrEqualTo(200),
        );
      },
    );

    test('the hidden radius varies a little between activities', () {
      final radii = {
        for (var s = 0; s < 40; s++)
          RoutePrivacy.radiusFor(RoutePrivacyMode.hide200, s * 104729),
      };
      expect(radii.length, greaterThan(10));
      expect(radii.every((r) => r >= 200 && r <= 250), isTrue);
      // The same activity always gets the same radius.
      expect(
        RoutePrivacy.radiusFor(RoutePrivacyMode.hide200, 42),
        RoutePrivacy.radiusFor(RoutePrivacyMode.hide200, 42),
      );
    });

    test('a route too short to hide safely is not shared at all', () {
      final short = [
        for (var i = 0; i <= 30; i++)
          RoutePoint(_lat0 + (i * 10) / 111195, _lng0),
      ]; // 300 m
      final m = RoutePrivacy.apply(short, RoutePrivacyMode.hide200, seed: 1);
      expect(m.hasRoute, isFalse);
      expect(m.tooShortToHide, isTrue);
      expect(
        RoutePrivacy.apply(
          const [],
          RoutePrivacyMode.hide200,
          seed: 1,
        ).hasRoute,
        isFalse,
      );
    });

    test('masking works on a copy: the original route is untouched', () {
      final r = _outAndBack();
      final before = List<RoutePoint>.of(r);
      RoutePrivacy.apply(r, RoutePrivacyMode.hide500, seed: 5);
      expect(r, before);
    });

    test('each choice has a plain explanation', () {
      for (final m in RoutePrivacyMode.values) {
        expect(m.label, isNotEmpty);
        expect(m.explanation.length, greaterThan(30));
      }
      expect(RoutePrivacyMode.fromName('hide500'), RoutePrivacyMode.hide500);
      expect(RoutePrivacyMode.fromName('garbage'), RoutePrivacyMode.hide200);
      expect(RoutePrivacyMode.fromName(null), RoutePrivacyMode.hide200);
    });
  });

  group('what is published', () {
    CardioActivityData data(List<RoutePoint> route) => CardioActivityData(
      kind: CardioKind.running,
      title: 'Outdoor Run',
      date: DateTime(2026, 11, 16, 7),
      distanceKm: 4,
      durationSeconds: 1500,
      avgSpeedKmh: 9.6,
      route: route,
    );

    List<RoutePoint> published(Map<String, dynamic> m) =>
        RoutePoint.listFromJson(m['route']);

    test('the post metadata holds only the masked route', () {
      final original = _outAndBack();
      final d = data(original);
      final post = CardioPostPublisher.buildDraft(
        d,
        caption: '',
        privacy: RoutePrivacyMode.hide200,
      );
      final m = post.metadata!;
      expect(m['routeMasked'], isTrue);
      final shared = published(m);
      expect(shared, isNotEmpty);
      for (final p in shared) {
        expect(_fromHome(p), greaterThanOrEqualTo(199));
      }
      // The first and last original points are nowhere in the metadata.
      final text = m.toString();
      expect(text, isNot(contains(original.first.lat.toStringAsFixed(5))));
      expect(shared.length, lessThan(original.length));
    });

    test('the athlete\'s own route is not changed by sharing', () {
      final original = _outAndBack();
      final before = List<RoutePoint>.of(original);
      final d = data(original);
      CardioPostPublisher.buildDraft(
        d,
        caption: 'x',
        privacy: RoutePrivacyMode.hide500,
      );
      expect(d.route, before);
      expect(d.route.first, before.first);
    });

    test('no-route sharing puts no coordinates in the post', () {
      final post = CardioPostPublisher.buildDraft(
        data(_outAndBack()),
        caption: '',
        privacy: RoutePrivacyMode.noRoute,
      );
      final m = post.metadata!;
      expect(m.containsKey('route'), isFalse);
      expect(m['routeShared'], isFalse);
      expect(m['distanceKm'], 4);
      expect(CardioActivityData.fromPost(post)!.routeShared, isFalse);
    });

    test('a too-short route is withheld, not published revealing', () {
      final short = [
        for (var i = 0; i <= 30; i++)
          RoutePoint(_lat0 + (i * 10) / 111195, _lng0),
      ];
      final post = CardioPostPublisher.buildDraft(data(short), caption: '');
      expect(post.metadata!.containsKey('route'), isFalse);
      expect(post.metadata!['routeShared'], isFalse);
    });

    test('the full route is shared only when the athlete chose that', () {
      final original = _outAndBack();
      final post = CardioPostPublisher.buildDraft(
        data(original),
        caption: '',
        privacy: RoutePrivacyMode.none,
      );
      expect(post.metadata!.containsKey('routeMasked'), isFalse);
      expect(
        _fromHome(published(post.metadata!).first),
        lessThan(5),
        reason: 'unmasked by explicit choice',
      );
    });

    test('shared routes are capped in size', () {
      final long = [
        for (var i = 0; i < 3000; i++) RoutePoint(_lat0 + i * 0.00005, _lng0),
      ];
      final post = CardioPostPublisher.buildDraft(
        data(long),
        caption: '',
        privacy: RoutePrivacyMode.hide200,
      );
      expect(
        published(post.metadata!).length,
        lessThanOrEqualTo(CardioPostPublisher.maxRoutePoints),
      );
    });
  });
}
