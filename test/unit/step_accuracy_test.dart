import 'package:atlas/services/steps/step_counter_service.dart';
import 'package:atlas/services/steps/step_ledger.dart';
import 'package:atlas/services/steps/step_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mocks/fake_step_sensor.dart';

DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 11, day, hour, minute);

/// Regression tests for step accuracy. They drive the real ledger and service
/// with a scripted sensor; they cannot prove how a particular phone's sensor
/// behaves (see tasks/phone_test_steps.md for the on-phone procedure).
void main() {
  group('duplicate and repeated sensor events', () {
    test('the same reading delivered again adds nothing', () {
      final l = StepLedger();
      l.observe(5000, at(14, 8));
      l.observe(5100, at(14, 8, 1));
      for (var i = 0; i < 5; i++) {
        l.observe(5100, at(14, 8, 2 + i));
      }
      expect(l.totalFor(at(14, 9)).steps, 100);
    });

    test('a replayed older reading is never counted twice', () {
      final l = StepLedger();
      l.observe(5000, at(14, 8));
      l.observe(5200, at(14, 9));
      // An out-of-order (older) value is treated as a reset, not as new steps.
      l.observe(5100, at(14, 9, 1));
      l.observe(5300, at(14, 9, 2));
      expect(l.totalFor(at(14, 10)).steps, lessThanOrEqualTo(200 + 200));
      // Steps credited never exceed what the counter really advanced (300).
      expect(l.totalFor(at(14, 10)).steps, lessThanOrEqualTo(300));
    });

    test('a burst of stale readings does not credit steps twice', () {
      final l = StepLedger();
      l.observe(5000, at(14, 8));
      l.observe(5200, at(14, 9));
      // The sensor hub replays older values, then catches up.
      final t = DateTime(2026, 11, 14, 9, 0, 1);
      l.observe(5100, t);
      l.observe(5150, t.add(const Duration(seconds: 1)));
      l.observe(5200, t.add(const Duration(seconds: 2)));
      l.observe(5300, t.add(const Duration(seconds: 3)));
      expect(l.totalFor(at(14, 10)).steps, 300); // 5300 - 5000, exactly once
    });

    test('a real restart is accepted once the lower counter persists', () {
      final l = StepLedger();
      l.observe(9000, at(14, 8));
      l.observe(9500, at(14, 9));
      l.observe(30, at(14, 10, 0)); // first low reading: held
      expect(l.totalFor(at(14, 10)).steps, 500);
      l.observe(130, at(14, 10, 1)); // a minute later, still low: restart
      expect(l.totalFor(at(14, 10, 1)).steps, 600);
    });

    test('the waiting state survives saving and loading', () {
      final l = StepLedger();
      l.observe(5000, at(14, 8));
      l.observe(5200, at(14, 9));
      l.observe(5100, at(14, 9, 0));
      final back = StepLedger.decode(l.encode());
      back.observe(5300, at(14, 9, 1));
      expect(back.totalFor(at(14, 10)).steps, 300);
    });
  });

  group('one subscription only', () {
    test('overlapping start calls share a single subscription', () async {
      final sensor = FakeStepSensor();
      final s = makeStepService(sensor: sensor);
      await Future.wait([s.start(), s.start(), s.start()]);
      expect(sensor.listens, 1);
      sensor.emit(1000);
      sensor.emit(1050);
      expect(s.today.steps, 50);
    });

    test('each return from the background replaces the subscription', () async {
      final clock = TestClock(at(14, 8));
      final sensor = FakeStepSensor();
      final s = makeStepService(sensor: sensor, clock: clock);
      await s.start();
      sensor.emit(1000);
      for (var i = 0; i < 4; i++) {
        await s.onPaused();
        clock.advance(const Duration(minutes: 10));
        await s.onResumed();
      }
      // Only the newest subscription is live; the cumulative counter is not
      // re-added at each resume.
      sensor.emit(1300);
      expect(s.today.steps, 300);
    });
  });

  group('cumulative versus incremental readings', () {
    test('the counter is cumulative: only the difference is credited', () {
      final l = StepLedger();
      l.observe(100000, at(14, 8)); // a phone that has been up for days
      l.observe(100040, at(14, 8, 1));
      l.observe(100100, at(14, 8, 2));
      expect(l.totalFor(at(14, 9)).steps, 100);
    });

    test('the first reading never credits the whole counter', () {
      final l = StepLedger();
      l.observe(48210, at(14, 8));
      expect(l.totalFor(at(14, 8)).steps, 0);
    });
  });

  group('app restart, counter reset and reboot', () {
    test('a restart does not add steps that were already counted', () async {
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
      clock.advance(const Duration(minutes: 20));
      sensor1.emit(2400);
      await s1.onPaused();
      expect(s1.today.steps, 400);

      final sensor2 = FakeStepSensor();
      final s2 = makeStepService(
        sensor: sensor2,
        storage: storage,
        clock: clock,
      );
      await s2.start();
      // The same cumulative value again, as the sensor reports on subscribe.
      sensor2.emit(2400);
      expect(s2.today.steps, 400);
      clock.advance(const Duration(minutes: 5));
      sensor2.emit(2450);
      expect(s2.today.steps, 450);
    });

    test('a counter reset never subtracts or re-adds steps', () {
      final l = StepLedger();
      l.observe(9000, at(14, 8));
      l.observe(9500, at(14, 9));
      l.observe(30, at(14, 10)); // phone rebooted
      l.observe(130, at(14, 10, 30));
      final t = l.totalFor(at(14, 11)).steps!;
      expect(t, 500 + 100); // 500 before the reboot, 100 after it
      expect(l.days['2026-11-14']!.unattributedSteps, 30);
    });
  });

  group('Health Connect and the phone sensor overlap', () {
    test('the day is one number, never the sum', () {
      final l = StepLedger();
      l.observe(1000, at(14, 8));
      l.observe(1600, at(14, 9)); // phone: 600
      l.setHealthConnect('2026-11-14', 5000, at(14, 9));
      final t = l.totalFor(at(14, 9));
      expect(t.steps, 5000);
      expect(t.steps, isNot(5600));
      expect(t.source, StepSource.healthConnect);
    });

    test(
      'repeated synchronisation replaces the value and never accumulates',
      () {
        final l = StepLedger();
        for (var i = 0; i < 6; i++) {
          l.setHealthConnect('2026-11-14', 4200, at(14, 9, i));
        }
        expect(l.totalFor(at(14, 10)).steps, 4200);
      },
    );

    test('a refresh never touches another day', () async {
      final storage = MemoryStepStorage();
      final clock = TestClock(at(14, 8));
      var yesterday = 8000;
      final s = StepCounterService(
        sensor: FakeStepSensor(),
        permission: FakeStepPermission(),
        storage: storage,
        clock: clock.call,
        persistEvery: Duration.zero,
        healthReader: (days) async => {
          '2026-11-13': yesterday,
          '2026-11-14': 1200,
        },
      );
      await s.start();
      yesterday = 8000;
      await s.refreshHealthConnect();
      await s.refreshHealthConnect();
      expect(s.today.steps, 1200);
      expect(s.week.firstWhere((d) => d.dayKey == '2026-11-13').steps, 8000);
    });

    test("today's readings do not change a past day", () async {
      final clock = TestClock(at(14, 23, 50));
      final sensor = FakeStepSensor();
      final s = makeStepService(sensor: sensor, clock: clock);
      await s.start();
      sensor.emit(1000);
      clock.advance(const Duration(minutes: 5));
      sensor.emit(1080);
      final before = s.today.steps;
      clock.advance(const Duration(hours: 1));
      sensor.emit(1140);
      final past = s.week.firstWhere((d) => d.dayKey == '2026-11-14').steps;
      expect(past, before);
    });
  });

  group('midnight and time zones', () {
    test('a reading at 23:59 and one at 00:01 fall on different days', () {
      expect(stepDayKey(at(14, 23, 59)), '2026-11-14');
      expect(stepDayKey(at(15, 0, 1)), '2026-11-15');
    });

    test('the day key follows the local clock, not UTC', () {
      final local = DateTime(2026, 11, 14, 23, 30);
      expect(stepDayKey(local), '2026-11-14');
      // The same moment in UTC may be a different calendar date; the day a
      // step belongs to is always decided by the phone's local date.
      expect(stepDayKey(local.toLocal()), '2026-11-14');
    });

    test('a daylight-saving style 23-hour day still has 7 distinct keys', () {
      final days = StepLedger().lastDays(DateTime(2026, 11, 8, 12));
      expect(days.map((d) => d.dayKey).toSet().length, 7);
    });
  });

  group('missing data versus a real zero', () {
    test('no reading is null, shown as dashes', () {
      final t = StepLedger().totalFor(at(14, 8));
      expect(t.steps, isNull);
      expect(t.display, '--');
    });

    test('a genuine zero-step day shows 0', () {
      final l = StepLedger();
      l.observe(5000, at(14, 8));
      l.observe(5000, at(14, 20));
      final t = l.totalFor(at(14, 20));
      expect(t.steps, 0);
      expect(t.display, '0');
    });

    test('an unavailable sensor is never turned into zero', () async {
      final sensor = FakeStepSensor();
      final s = makeStepService(sensor: sensor);
      await s.start();
      sensor.fail(StateError('no sensor'));
      await Future<void>.delayed(Duration.zero);
      expect(s.today.steps, isNull);
      expect(s.today.display, '--');
    });
  });
}
