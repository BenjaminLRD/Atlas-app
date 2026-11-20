import 'package:atlas/services/steps/step_ledger.dart';
import 'package:atlas/services/steps/step_models.dart';
import 'package:atlas/widgets/activity/step_status_panel.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/nutrition_progress.dart';
import 'package:atlas/models/nutrition_summary.dart';
import 'package:atlas/models/progress_summary.dart';
import 'package:atlas/models/user_progress.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';
import 'package:atlas/services/health/recovery_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mocks/fake_step_sensor.dart';

DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 11, day, hour, minute);

void main() {
  group('StepLedger: turning counter readings into days', () {
    test('the first reading starts counting at zero, nothing is credited', () {
      final l = StepLedger();
      l.observe(5000, at(14, 8));
      final t = l.totalFor(at(14, 8));
      expect(t.steps, 0);
      expect(t.phoneSince, at(14, 8));
    });

    test('steps between two readings on the same day are counted', () {
      final l = StepLedger();
      l.observe(5000, at(14, 8));
      l.observe(5120, at(14, 8, 5));
      l.observe(5400, at(14, 12));
      expect(l.totalFor(at(14, 12)).steps, 400);
    });

    test(
      'steps taken while the app was closed on the same day are counted',
      () {
        final l = StepLedger();
        l.observe(5000, at(14, 8));
        // Next reading hours later, counter ran on its own.
        l.observe(9000, at(14, 18));
        expect(l.totalFor(at(14, 18)).steps, 4000);
      },
    );

    test(
      'a gap over midnight with the app closed is not credited to a day',
      () {
        final l = StepLedger();
        l.observe(5000, at(14, 22));
        l.observe(5600, at(15, 8)); // app was not listening in between
        expect(l.totalFor(at(14, 22)).steps, 0);
        expect(l.totalFor(at(15, 8)).steps, 0);
        expect(l.days['2026-11-15']!.unattributedSteps, 600);
      },
    );

    test('listening through midnight credits the new steps to the new day', () {
      final l = StepLedger();
      l.observe(5000, at(14, 23, 50), continuousSince: at(14, 20));
      l.observe(5030, at(15, 0, 10), continuousSince: at(14, 20));
      expect(l.totalFor(at(14, 23, 50)).steps, 0);
      expect(l.totalFor(at(15, 0, 10)).steps, 30);
    });

    test('a phone restart (counter lower than before) is never negative', () {
      final l = StepLedger();
      l.observe(5000, at(14, 8));
      l.observe(5200, at(14, 9));
      l.observe(40, at(14, 10)); // rebooted (or a stale value: wait and see)
      expect(l.totalFor(at(14, 10)).steps, 200); // nothing added or removed
      l.observe(90, at(14, 11)); // still low an hour later: it was a restart
      expect(l.days['2026-11-14']!.unattributedSteps, 40);
      expect(l.totalFor(at(14, 11)).steps, 250);
    });

    test(
      'an idle midnight starts the new day at zero only while listening',
      () {
        final listening = StepLedger();
        listening.observe(5000, at(14, 23), continuousSince: at(14, 20));
        listening.startDayIfListening(at(15, 7), continuousSince: at(14, 20));
        final t = listening.totalFor(at(15, 7));
        expect(t.steps, 0);
        expect(t.phoneSince, at(15, 0));

        final notListening = StepLedger();
        notListening.observe(5000, at(14, 23));
        notListening.startDayIfListening(at(15, 7), continuousSince: at(15, 6));
        expect(notListening.totalFor(at(15, 7)).steps, isNull);
        notListening.startDayIfListening(at(15, 7), continuousSince: null);
        expect(notListening.totalFor(at(15, 7)).steps, isNull);
      },
    );

    test('the last seven days have no steps where nothing was read', () {
      final l = StepLedger();
      l.observe(100, at(14, 8));
      l.observe(300, at(14, 9));
      final week = l.lastDays(at(14, 12));
      expect(week.length, 7);
      expect(week.last.steps, 200);
      expect(week.take(6).every((d) => d.steps == null), isTrue);
      expect(week.first.dayKey, '2026-11-08');
    });

    test('it survives being saved and loaded, and drops unreadable data', () {
      final l = StepLedger();
      l.observe(100, at(14, 8));
      l.observe(250, at(14, 9));
      l.setHealthConnect('2026-11-13', 7000, at(14, 9));
      final back = StepLedger.decode(l.encode());
      expect(back.lastCounter, 250);
      expect(back.totalFor(at(14, 9)).steps, 150);
      expect(back.totalFor(at(13, 9)).steps, 7000);

      expect(StepLedger.decode('not json').days, isEmpty);
      expect(StepLedger.decode(null).lastCounter, isNull);
      expect(StepLedger.decode('').days, isEmpty);
    });

    test('only the last 60 days are kept', () {
      final l = StepLedger();
      for (var i = 0; i < 70; i++) {
        l.observe(
          i * 10,
          DateTime(2026, 1, 1).add(Duration(days: i, hours: 8)),
        );
      }
      expect(l.days.length, StepLedger.keepDays);
    });
  });

  group('DayStepTotal: two sources, never added', () {
    DayStepTotal total({int? phone, int? hc}) => DayStepTotal.fromRecord(
      '2026-11-14',
      DayStepRecord(
        dayKey: '2026-11-14',
        phoneSteps: phone,
        healthConnectSteps: hc,
      ),
    );

    test('no source: no steps, shown as dashes', () {
      final t = total();
      expect(t.steps, isNull);
      expect(t.source, isNull);
      expect(t.display, '--');
      expect(t.hasReading, isFalse);
      expect(DayStepTotal.fromRecord('x', null).steps, isNull);
    });

    test('phone only', () {
      final t = total(phone: 4120);
      expect(t.steps, 4120);
      expect(t.source, StepSource.phoneSensor);
      expect(t.display, '4120');
    });

    test('Health Connect only', () {
      final t = total(hc: 6300);
      expect(t.steps, 6300);
      expect(t.source, StepSource.healthConnect);
    });

    test('both: the larger one is used, they are not added', () {
      final t = total(phone: 4120, hc: 6300);
      expect(t.steps, 6300);
      expect(t.source, StepSource.healthConnect);
      expect(t.phoneSteps, 4120);
      expect(t.healthConnectSteps, 6300);
      final p = total(phone: 7000, hc: 6300);
      expect(p.steps, 7000);
      expect(p.source, StepSource.phoneSensor);
    });

    test('a tie goes to the phone', () {
      expect(total(phone: 500, hc: 500).source, StepSource.phoneSensor);
    });

    test('a zero from one source is a real reading', () {
      final t = total(phone: 0, hc: 0);
      expect(t.steps, 0);
      expect(t.display, '0');
    });

    test('sources that differ by more than a fifth are flagged', () {
      expect(total(phone: 4120, hc: 6300).sourcesDisagree, isTrue);
      expect(total(phone: 5000, hc: 5400).sourcesDisagree, isFalse);
      expect(total(phone: 50, hc: 90).sourcesDisagree, isFalse); // too small
      expect(total(phone: 4000).sourcesDisagree, isFalse);
    });
  });

  group('StepCounterService: permission and sensor', () {
    test('permission not granted: no counting, no number', () async {
      final sensor = FakeStepSensor();
      final perm = FakeStepPermission(current: StepPermission.denied);
      final s = makeStepService(sensor: sensor, permission: perm);
      await s.start();
      expect(s.status, StepSensorStatus.needsPermission);
      expect(sensor.listens, 0);
      expect(s.today.steps, isNull);
      expect(s.today.display, '--');
      expect(s.week.every((d) => d.steps == null), isTrue);
    });

    test(
      'permission refused for good: says so and can open settings',
      () async {
        final perm = FakeStepPermission(
          current: StepPermission.permanentlyDenied,
        );
        final s = makeStepService(permission: perm);
        await s.start();
        expect(s.status, StepSensorStatus.permissionPermanentlyDenied);
        expect(s.today.steps, isNull);
        await s.openSettings();
        expect(perm.settingsOpened, 1);
      },
    );

    test('asking and being allowed starts counting', () async {
      final sensor = FakeStepSensor();
      final perm = FakeStepPermission(
        current: StepPermission.denied,
        answer: StepPermission.granted,
      );
      final s = makeStepService(sensor: sensor, permission: perm);
      await s.start();
      final result = await s.requestPermission();
      expect(result, StepPermission.granted);
      expect(perm.requests, 1);
      expect(s.status, StepSensorStatus.waitingForFirstReading);
      expect(s.today.steps, isNull); // listening, but no reading yet
      sensor.emit(1000);
      expect(s.status, StepSensorStatus.active);
      expect(s.today.steps, 0);
      sensor.emit(1075);
      expect(s.today.steps, 75);
    });

    test('asking and being refused leaves it off', () async {
      final sensor = FakeStepSensor();
      final perm = FakeStepPermission(
        current: StepPermission.denied,
        answer: StepPermission.permanentlyDenied,
      );
      final s = makeStepService(sensor: sensor, permission: perm);
      await s.requestPermission();
      expect(s.status, StepSensorStatus.permissionPermanentlyDenied);
      expect(sensor.listens, 0);
      expect(s.today.steps, isNull);
    });

    test(
      'a phone without a step sensor is unavailable, never zero steps',
      () async {
        final sensor = FakeStepSensor();
        final s = makeStepService(sensor: sensor);
        await s.start();
        sensor.fail('StepCount not available');
        expect(s.status, StepSensorStatus.unavailable);
        expect(s.lastError, contains('not available'));
        expect(s.today.steps, isNull);
        expect(s.today.display, '--');
      },
    );

    test(
      'Health Connect still counts when the phone sensor is unavailable',
      () async {
        final sensor = FakeStepSensor();
        final clock = TestClock(at(14, 12));
        final s = makeStepService(
          sensor: sensor,
          clock: clock,
          healthReader: (days) async => {
            '2026-11-14': 5200,
            '2026-11-13': 8100,
          },
        );
        await s.start();
        sensor.fail('StepCount not available');
        expect(s.status, StepSensorStatus.unavailable);
        expect(s.today.steps, 5200);
        expect(s.today.source, StepSource.healthConnect);
        expect(s.week[5].steps, 8100);
        expect(s.healthConnectHasData, isTrue);
      },
    );

    test('no sensor reading yet is not shown as zero', () async {
      final s = makeStepService();
      await s.start();
      expect(s.status, StepSensorStatus.waitingForFirstReading);
      expect(s.today.steps, isNull);
    });

    test(
      'permission taken away while the app is open stops counting',
      () async {
        final sensor = FakeStepSensor();
        final perm = FakeStepPermission();
        final s = makeStepService(sensor: sensor, permission: perm);
        await s.start();
        sensor.emit(100);
        sensor.emit(160);
        expect(s.today.steps, 60);
        perm.current = StepPermission.denied; // user turned it off in settings
        await s.onResumed();
        expect(s.status, StepSensorStatus.needsPermission);
        expect(sensor.isListening, isFalse);
      },
    );

    test(
      'permission given in settings while away starts counting on resume',
      () async {
        final sensor = FakeStepSensor();
        final perm = FakeStepPermission(
          current: StepPermission.permanentlyDenied,
        );
        final s = makeStepService(sensor: sensor, permission: perm);
        await s.start();
        expect(sensor.listens, 0);
        perm.current = StepPermission.granted;
        await s.onResumed();
        expect(s.status, StepSensorStatus.waitingForFirstReading);
        sensor.emit(500);
        expect(s.status, StepSensorStatus.active);
      },
    );

    test('a platform with no separate permission starts counting', () async {
      final sensor = FakeStepSensor();
      final perm = FakeStepPermission(current: StepPermission.notRequired);
      final s = makeStepService(sensor: sensor, permission: perm);
      await s.start();
      expect(s.status, StepSensorStatus.waitingForFirstReading);
    });
  });

  group('StepCounterService: restarts and day changes', () {
    test('the count survives an app restart on the same day', () async {
      final storage = MemoryStepStorage();
      final clock = TestClock(at(14, 8));
      final sensor1 = FakeStepSensor();
      final s1 = makeStepService(
        sensor: sensor1,
        storage: storage,
        clock: clock,
      );
      await s1.start();
      sensor1.emit(2000);
      clock.advance(const Duration(minutes: 30));
      sensor1.emit(2300);
      expect(s1.today.steps, 300);
      await s1.onPaused();

      // App closed; the phone counted 450 more steps by itself.
      clock.advance(const Duration(hours: 3));
      final sensor2 = FakeStepSensor();
      final s2 = makeStepService(
        sensor: sensor2,
        storage: storage,
        clock: clock,
      );
      expect(s2.today.steps, 300); // loaded from storage before any reading
      await s2.start();
      sensor2.emit(2750);
      expect(s2.today.steps, 750);
    });

    test(
      'a restart across midnight does not invent steps for either day',
      () async {
        final storage = MemoryStepStorage();
        final clock = TestClock(at(14, 22));
        final sensor1 = FakeStepSensor();
        final s1 = makeStepService(
          sensor: sensor1,
          storage: storage,
          clock: clock,
        );
        await s1.start();
        sensor1.emit(1000);
        sensor1.emit(1200);
        await s1.onPaused();

        clock.now = at(15, 7);
        final sensor2 = FakeStepSensor();
        final s2 = makeStepService(
          sensor: sensor2,
          storage: storage,
          clock: clock,
        );
        await s2.start();
        sensor2.emit(3000);
        expect(s2.today.steps, 0);
        expect(s2.week[5].steps, 200); // yesterday keeps what was observed
        expect(s2.week[5].dayKey, '2026-11-14');
      },
    );

    test('the app open through midnight rolls over to a fresh day', () async {
      final clock = TestClock(at(14, 23, 30));
      final sensor = FakeStepSensor();
      final s = makeStepService(sensor: sensor, clock: clock);
      await s.start();
      sensor.emit(1000);
      sensor.emit(1100);
      expect(s.today.steps, 100);

      clock.now = at(15, 7); // nobody walked overnight: no readings arrived
      expect(s.today.dayKey, '2026-11-15');
      expect(s.today.steps, 0);
      expect(s.today.phoneSince, at(15, 0));
      expect(s.week[5].steps, 100);

      sensor.emit(1140);
      expect(s.today.steps, 40);
    });

    test(
      'a phone restart does not create negative or invented steps',
      () async {
        final clock = TestClock(at(14, 8));
        final sensor = FakeStepSensor();
        final s = makeStepService(sensor: sensor, clock: clock);
        await s.start();
        sensor.emit(8000);
        sensor.emit(8100);
        sensor.emit(30); // phone rebooted, counter starts again
        expect(s.today.steps, 100);
      },
    );
  });

  group('StepCounterService: Health Connect and conflicts', () {
    test('Health Connect and the phone are kept apart and not added', () async {
      final sensor = FakeStepSensor();
      final clock = TestClock(at(14, 12));
      final s = makeStepService(
        sensor: sensor,
        clock: clock,
        healthReader: (days) async => {'2026-11-14': 6300},
      );
      await s.start();
      sensor.emit(100);
      sensor.emit(4220);
      final t = s.today;
      expect(t.phoneSteps, 4120);
      expect(t.healthConnectSteps, 6300);
      expect(t.steps, 6300); // larger source, not 10,420
      expect(t.source, StepSource.healthConnect);
      expect(t.sourcesDisagree, isTrue);
    });

    test(
      'when the phone count is higher it wins and Health Connect is not added',
      () async {
        final sensor = FakeStepSensor();
        final s = makeStepService(
          sensor: sensor,
          clock: TestClock(at(14, 12)),
          healthReader: (days) async => {'2026-11-14': 3000},
        );
        await s.start();
        sensor.emit(0);
        sensor.emit(3600);
        expect(s.today.steps, 3600);
        expect(s.today.source, StepSource.phoneSensor);
      },
    );

    test('Health Connect failing or having no data changes nothing', () async {
      final sensor = FakeStepSensor();
      final s = makeStepService(
        sensor: sensor,
        clock: TestClock(at(14, 12)),
        healthReader: (days) async => throw StateError('no health store'),
      );
      await s.start();
      sensor.emit(10);
      sensor.emit(60);
      expect(s.today.steps, 50);
      expect(s.healthConnectHasData, isFalse);

      final empty = makeStepService(
        clock: TestClock(at(14, 12)),
        healthReader: (days) async => {},
      );
      await empty.start();
      expect(empty.today.steps, isNull);
      expect(empty.healthConnectHasData, isFalse);
    });

    test(
      'a refresh replaces the Health Connect value, it never accumulates',
      () async {
        var value = 4000;
        final s = makeStepService(
          clock: TestClock(at(14, 12)),
          healthReader: (days) async => {'2026-11-14': value},
        );
        await s.start();
        expect(s.today.steps, 4000);
        value = 4500;
        await s.refreshHealthConnect();
        expect(s.today.steps, 4500);
        await s.refreshHealthConnect();
        expect(s.today.steps, 4500);
      },
    );

    test('the weekly list and today use the same daily totals', () async {
      final sensor = FakeStepSensor();
      final clock = TestClock(at(14, 12));
      final s = makeStepService(
        sensor: sensor,
        clock: clock,
        healthReader: (days) async => {'2026-11-12': 9000, '2026-11-14': 2000},
      );
      await s.start();
      sensor.emit(10);
      sensor.emit(3010);
      expect(s.today.steps, 3000);
      expect(s.week.last.steps, s.today.steps);
      expect(s.week.last.source, s.today.source);
      expect(s.week[4].steps, 9000);
      expect(s.week[3].steps, isNull);
    });
  });

  group('step status text', () {
    final none = DayStepTotal.fromRecord('2026-11-14', null);

    test('each problem has its own words and the right action', () {
      final needs = StepStatusText.of(StepSensorStatus.needsPermission, none);
      expect(needs.actionLabel, 'Allow step counting');
      expect(needs.actionRequestsPermission, isTrue);

      final denied = StepStatusText.of(
        StepSensorStatus.permissionPermanentlyDenied,
        none,
      );
      expect(denied.actionLabel, 'Open app settings');
      expect(denied.actionRequestsPermission, isFalse);

      final gone = StepStatusText.of(StepSensorStatus.unavailable, none);
      expect(gone.message, contains('no step counter'));
      expect(gone.actionLabel, isNull);

      expect(
        StepStatusText.of(
          StepSensorStatus.waitingForFirstReading,
          none,
        ).message,
        contains('first reading'),
      );
      expect(
        StepStatusText.of(
          StepSensorStatus.active,
          none,
          supported: false,
        ).message,
        contains('phones'),
      );
    });

    test('a reading names its source', () {
      final phone = DayStepTotal.fromRecord(
        '2026-11-14',
        DayStepRecord(
          dayKey: '2026-11-14',
          phoneSteps: 4120,
          phoneSince: at(14, 7, 42),
        ),
      );
      expect(
        StepStatusText.of(StepSensorStatus.active, phone).message,
        'Phone step counter · counting since 07:42',
      );
      final hc = DayStepTotal.fromRecord(
        '2026-11-14',
        const DayStepRecord(
          dayKey: '2026-11-14',
          phoneSteps: 4120,
          healthConnectSteps: 6300,
        ),
      );
      expect(
        StepStatusText.of(StepSensorStatus.active, hc).message,
        'From Health Connect (higher) · Phone sensor 4,120',
      );
    });
  });

  group('step status panel', () {
    testWidgets('permission needed: no number, one button that asks', (
      tester,
    ) async {
      final perm = FakeStepPermission(
        current: StepPermission.denied,
        answer: StepPermission.denied,
      );
      final s = makeStepService(permission: perm, clock: TestClock(at(14, 12)));
      await s.start();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StepStatusPanel(service: s)),
        ),
      );
      expect(find.textContaining('Allow physical activity'), findsOneWidget);
      expect(find.text('Allow step counting'), findsOneWidget);
      await tester.tap(find.byKey(const Key('step_status_action')));
      await tester.pump();
      expect(perm.requests, 1);
    });

    testWidgets('permanently refused: the button opens settings', (
      tester,
    ) async {
      final perm = FakeStepPermission(
        current: StepPermission.permanentlyDenied,
      );
      final s = makeStepService(permission: perm, clock: TestClock(at(14, 12)));
      await s.start();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StepStatusPanel(service: s)),
        ),
      );
      expect(find.text('Open app settings'), findsOneWidget);
      await tester.tap(find.byKey(const Key('step_status_action')));
      await tester.pump();
      expect(perm.settingsOpened, 1);
      expect(perm.requests, 0);
    });

    testWidgets(
      'counting: shows the source and no button, and follows new steps',
      (tester) async {
        final sensor = FakeStepSensor();
        final s = makeStepService(sensor: sensor, clock: TestClock(at(14, 12)));
        await s.start();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: StepStatusPanel(service: s)),
          ),
        );
        expect(find.textContaining('first reading'), findsOneWidget);
        sensor.emit(100);
        sensor.emit(160);
        await tester.pump();
        expect(find.textContaining('Phone step counter'), findsOneWidget);
        expect(find.byKey(const Key('step_status_action')), findsNothing);
      },
    );
  });

  group('step consumers use the same total', () {
    FitnessContext ctx({int? steps}) => FitnessContext(
      nutritionSummary: NutritionSummary.empty(),
      progressSummary: ProgressSummary.zero(),
      userProgress: UserProgress.initial(),
      nutritionProgress: NutritionProgress.initial(),
      todaySteps: steps,
      stepGoal: 10000,
      generatedAt: DateTime(2026, 11, 14),
    );

    test('the coach is told steps are not recorded, never zero', () {
      const builder = CoachPromptBuilder();
      final none = builder.buildPrompt(message: 'steps?', context: ctx());
      expect(
        none,
        contains('not recorded (the step counter has no reading today)'),
      );
      expect(none, isNot(contains('0 / 10000 steps')));
      final some = builder.buildPrompt(
        message: 'steps?',
        context: ctx(steps: 4120),
      );
      expect(some, contains('4120 / 10000 steps'));
    });

    test('a step count survives the context round trip, null stays null', () {
      expect(FitnessContext.fromJson(ctx(steps: 55).toJson()).todaySteps, 55);
      expect(FitnessContext.fromJson(ctx().toJson()).todaySteps, isNull);
    });

    test('recovery uses the given steps; no reading is neutral', () {
      final svc = RecoveryService.instance;
      final low = svc.calculateRecovery(stepsToday: 1000).activityComponent;
      final good = svc.calculateRecovery(stepsToday: 9000).activityComponent;
      final unknown = svc.calculateRecovery(stepsToday: null).activityComponent;
      expect(good, 20.0);
      expect(low, 12.0);
      expect(unknown, isNull); // no step reading: the pillar is skipped
    });
  });
}
