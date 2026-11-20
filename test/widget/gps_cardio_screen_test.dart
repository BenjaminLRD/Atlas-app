import 'package:atlas/app_theme.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/activity_record.dart';
import 'package:atlas/models/cardio_route.dart';
import 'package:atlas/screens/gps_cardio_screen.dart';
import 'package:atlas/services/cardio/cardio_journal.dart';
import 'package:atlas/services/cardio/cardio_tracker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/cardio_fakes.dart';

const _lat0 = 23.7271;
const _lng0 = 92.7176;

class _Saves {
  final List<CardioSession> sessions = [];
  final List<ActivityRecord> activities = [];
  int failuresLeft = 0;

  Future<void> call(CardioSession s, ActivityRecord a) async {
    if (failuresLeft > 0) {
      failuresLeft--;
      throw StateError('disk full');
    }
    // Saving by id: the same session replaces itself.
    sessions.removeWhere((e) => e.id == s.id);
    activities.removeWhere((e) => e.id == a.id);
    sessions.add(s);
    activities.add(a);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSource source;
  late FakeClock clock;
  late _Saves saves;
  late CardioJournal journal;
  String? journalDisk;
  bool? popped;

  setUp(() async {
    CardioTracker.resetForTest();
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    source = FakeSource();
    clock = FakeClock();
    saves = _Saves();
    journalDisk = null;
    journal = CardioJournal(
      read: () => journalDisk,
      write: (j) async => journalDisk = j,
      erase: () async => journalDisk = null,
    );
    popped = null;
  });

  Future<void> open(
    WidgetTester tester, {
    CardioKind kind = CardioKind.running,
    Size size = const Size(412, 915),
    double? weight = 70,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Builder(
          builder: (ctx) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('open'),
                onPressed: () async {
                  popped = await Navigator.of(ctx).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => GpsCardioScreen(
                        initialKind: kind,
                        source: source,
                        weightKg: weight,
                        clock: clock.call,
                        persist: saves.call,
                        journal: journal,
                        explainBackground: false,
                      ),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
  }

  Future<void> start(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('cardio_start')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Sends a fix every second heading north at [mps].
  Future<void> move(
    WidgetTester tester, {
    required double mps,
    required int seconds,
    double from = 0,
  }) async {
    var north = from;
    for (var i = 0; i < seconds; i++) {
      clock.advance(1);
      north += mps;
      source.controller.add(
        GpsFix(_lat0 + north / 111195, _lng0, clock.now, accuracyM: 5),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }
  }

  /// Stops the one-second timer so the test can end.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  String distanceText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('cardio_distance'))).data!;

  group('activity selection', () {
    testWidgets('running shows pace labels', (tester) async {
      await open(tester);
      await start(tester);
      expect(find.text('Current pace'), findsOneWidget);
      expect(find.text('Avg pace'), findsOneWidget);
      expect(find.text('Current speed'), findsNothing);
      await close(tester);
    });

    testWidgets('cycling shows speed labels', (tester) async {
      await open(tester, kind: CardioKind.cycling);
      await start(tester);
      expect(find.text('Current speed'), findsOneWidget);
      expect(find.text('Avg speed'), findsOneWidget);
      expect(find.text('Current pace'), findsNothing);
      await close(tester);
    });

    testWidgets('the activity can be switched before starting only', (
      tester,
    ) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('kind_cycling')));
      await tester.pump();
      expect(find.text('Start ride'), findsOneWidget);
      await tester.tap(find.byKey(const Key('kind_running')));
      await tester.pump();
      expect(find.text('Start run'), findsOneWidget);
      await tester.tap(find.byKey(const Key('kind_cycling')));
      await tester.pump();
      await start(tester);
      // Now locked: tapping running does nothing.
      await tester.tap(find.byKey(const Key('kind_running')));
      await tester.pump();
      expect(find.text('Current speed'), findsOneWidget);
      await close(tester);
    });
  });

  group('GPS problems', () {
    testWidgets('permission denied explains itself and does not start', (
      tester,
    ) async {
      source.access = LocationAccess.denied;
      await open(tester);
      await start(tester);
      expect(find.byKey(const Key('gps_status')), findsOneWidget);
      expect(find.textContaining('location permission'), findsOneWidget);
      expect(find.byKey(const Key('cardio_start')), findsOneWidget);
      expect(find.byKey(const Key('cardio_finish')), findsNothing);
      await close(tester);
    });

    testWidgets('permission denied for good offers Settings', (tester) async {
      source.access = LocationAccess.deniedForever;
      await open(tester);
      await start(tester);
      expect(find.byKey(const Key('open_app_settings')), findsOneWidget);
      await close(tester);
    });

    testWidgets('location switched off offers to turn it on', (tester) async {
      source.access = LocationAccess.serviceDisabled;
      await open(tester);
      await start(tester);
      expect(find.byKey(const Key('open_location_settings')), findsOneWidget);
      await close(tester);
    });

    testWidgets('searching, then a lost signal is shown', (tester) async {
      await open(tester);
      await start(tester);
      expect(find.textContaining('Searching for GPS'), findsOneWidget);
      await move(tester, mps: 3, seconds: 5);
      expect(find.byKey(const Key('gps_status')), findsNothing);
      clock.advance(20);
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('GPS signal is weak'), findsOneWidget);
      await close(tester);
    });
  });

  group('live statistics', () {
    testWidgets('distance and duration follow the recorded positions', (
      tester,
    ) async {
      await open(tester);
      await start(tester);
      expect(distanceText(tester), '0.00');
      await move(tester, mps: 3, seconds: 100);
      final km = double.parse(distanceText(tester));
      expect(km, closeTo(0.297, 0.01));
      expect(
        tester.widget<Text>(
          find.descendant(
            of: find.byKey(const Key('live_duration')),
            matching: find.text('01:40'),
          ),
        ),
        isNotNull,
      );
      expect(find.byKey(const Key('live_map')), findsOneWidget);
      await close(tester);
    });

    testWidgets('without a body weight calories say so, not zero', (
      tester,
    ) async {
      await open(tester, weight: null);
      await start(tester);
      await move(tester, mps: 3, seconds: 90);
      expect(find.text('Calories (needs weight)'), findsOneWidget);
      expect(
        find.textContaining('your weight in your profile'),
        findsOneWidget,
      );
      await close(tester);
    });

    testWidgets('with a weight calories are labelled an estimate', (
      tester,
    ) async {
      await open(tester);
      await start(tester);
      await move(tester, mps: 3, seconds: 90);
      expect(find.text('Calories (est.)'), findsOneWidget);
      await close(tester);
    });
  });

  group('pause and resume', () {
    testWidgets('pause freezes time and distance; resume continues', (
      tester,
    ) async {
      await open(tester);
      await start(tester);
      await move(tester, mps: 3, seconds: 60);
      final before = distanceText(tester);
      await tester.tap(find.byKey(const Key('cardio_pause_resume')));
      await tester.pump();
      expect(find.text('Resume'), findsOneWidget);
      await move(tester, mps: 3, seconds: 30, from: 180);
      expect(distanceText(tester), before);
      await tester.tap(find.byKey(const Key('cardio_pause_resume')));
      await tester.pump();
      expect(find.text('Pause'), findsOneWidget);
      await close(tester);
    });
  });

  group('finishing, saving and discarding', () {
    testWidgets('finishing saves one activity with the route and kind', (
      tester,
    ) async {
      await open(tester);
      await start(tester);
      await move(tester, mps: 3, seconds: 120);
      await tester.tap(find.byKey(const Key('cardio_finish')));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      expect(saves.sessions, hasLength(1));
      final s = saves.sessions.single;
      expect(s.category, 'Running');
      expect(s.exerciseId, 'outdoor_run');
      expect(s.durationSeconds, 120);
      expect(s.distanceKm, closeTo(0.357, 0.02));
      expect(s.route.length, greaterThan(20));
      expect(s.caloriesKnown, isTrue);
      expect(s.isCompleted, isTrue);
      expect(saves.activities.single.type, ActivityType.cardio);
      expect(find.text('Run saved'), findsOneWidget);
      expect(find.byKey(const Key('summary_map')), findsOneWidget);
      expect(find.byKey(const Key('summary_save')), findsNothing);
      await close(tester);
    });

    testWidgets('a cycling session is saved as cycling', (tester) async {
      await open(tester, kind: CardioKind.cycling);
      await start(tester);
      await move(tester, mps: 8, seconds: 120);
      await tester.tap(find.byKey(const Key('cardio_finish')));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      expect(saves.sessions.single.category, 'Cycling');
      expect(saves.sessions.single.exerciseId, 'outdoor_cycling');
      expect(find.text('Ride saved'), findsOneWidget);
      await close(tester);
    });

    testWidgets('a failed save can be retried and is saved once', (
      tester,
    ) async {
      saves.failuresLeft = 1;
      await open(tester);
      await start(tester);
      await move(tester, mps: 3, seconds: 90);
      await tester.tap(find.byKey(const Key('cardio_finish')));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      expect(saves.sessions, isEmpty);
      expect(find.textContaining('Could not save'), findsOneWidget);
      await tester.tap(find.byKey(const Key('summary_save')));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      expect(saves.sessions, hasLength(1));
      expect(find.byKey(const Key('summary_save')), findsNothing);
      await close(tester);
    });

    testWidgets('almost no movement is offered for discarding, not saved', (
      tester,
    ) async {
      await open(tester);
      await start(tester);
      await move(tester, mps: 0, seconds: 20);
      await tester.tap(find.byKey(const Key('cardio_finish')));
      await tester.pumpAndSettle();
      expect(find.text('Not enough to save'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm_yes')));
      await tester.pumpAndSettle();
      expect(saves.sessions, isEmpty);
      expect(popped, isFalse);
      await close(tester);
    });

    testWidgets('discarding asks first and saves nothing', (tester) async {
      await open(tester);
      await start(tester);
      await move(tester, mps: 3, seconds: 90);
      await tester.tap(find.byKey(const Key('cardio_discard')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Discard this run'), findsOneWidget);
      // Keep going: nothing happens.
      await tester.tap(find.text('Keep going'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('cardio_finish')), findsOneWidget);
      await tester.tap(find.byKey(const Key('cardio_discard')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_yes')));
      await tester.pumpAndSettle();
      expect(saves.sessions, isEmpty);
      expect(popped, isFalse);
      await close(tester);
    });

    testWidgets('leaving mid-session discards after confirmation', (
      tester,
    ) async {
      await open(tester);
      await start(tester);
      await move(tester, mps: 3, seconds: 60);
      await tester.tap(find.byKey(const Key('cardio_back')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Leave this run'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm_yes')));
      await tester.pumpAndSettle();
      expect(saves.sessions, isEmpty);
      await close(tester);
    });
  });

  group('sharing', () {
    testWidgets('in Showcase Mode sharing is off and says why', (tester) async {
      await LocalStorage.setShowcaseModeEnabled(true);
      addTearDown(() => LocalStorage.setShowcaseModeEnabled(false));
      await open(tester);
      await start(tester);
      await move(tester, mps: 3, seconds: 90);
      await tester.tap(find.byKey(const Key('cardio_finish')));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('summary_share')), findsNothing);
      expect(find.byKey(const Key('share_showcase_note')), findsOneWidget);
      await close(tester);
    });

    testWidgets('signed out or in, a real activity offers to share', (
      tester,
    ) async {
      await open(tester);
      await start(tester);
      await move(tester, mps: 3, seconds: 90);
      await tester.tap(find.byKey(const Key('cardio_finish')));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('summary_share')), findsOneWidget);
      expect(find.byKey(const Key('privacy_hide200')), findsOneWidget);
      expect(find.byKey(const Key('privacy_preview')), findsOneWidget);
      expect(find.byKey(const Key('share_caption')), findsOneWidget);
      await close(tester);
    });
  });

  group('responsive layout', () {
    for (final size in const [Size(320, 568), Size(360, 640), Size(412, 915)]) {
      testWidgets('live and summary fit ${size.width.toInt()} dp', (
        tester,
      ) async {
        await open(tester, size: size);
        expect(tester.takeException(), isNull, reason: 'before start');
        await start(tester);
        await move(tester, mps: 3, seconds: 90);
        expect(tester.takeException(), isNull, reason: 'live');
        await tester.tap(find.byKey(const Key('cardio_finish')));
        await tester.pumpAndSettle(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull, reason: 'summary');
        await close(tester);
      });
    }
  });
}
