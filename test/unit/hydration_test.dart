import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/hydration.dart';
import 'package:atlas/services/hydration/hydration_goal_calculator.dart';
import 'package:atlas/services/hydration/hydration_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A service wired to a fake clock and an in-memory "disk".
class Rig {
  Rig({DateTime? now}) : clock = now ?? DateTime(2026, 11, 18, 12) {
    svc = make();
  }

  DateTime clock;
  String? disk;
  int writes = 0;
  double? weight = 70;
  List<HydrationActivity> activities = [];
  bool showcase = false;
  String user = 'u1';
  late HydrationService svc;

  HydrationService make() => HydrationService(
    clock: () => clock,
    userId: () => user,
    isShowcase: () => showcase,
    weightKg: () => weight,
    activities: (_) => activities,
    read: () => disk,
    write: (j) async {
      writes++;
      disk = j;
    },
  );

  /// A new service reading the same disk, like reopening the app.
  HydrationService restart() => svc = make();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('glass visualisation', () {
    test('0 ml: ten empty glasses for a 2,500 ml goal', () {
      final f = GlassMath.fills(0, 2500);
      expect(f.length, 10);
      expect(f.every((v) => v == 0), isTrue);
    });

    test('250 ml fills exactly one glass', () {
      final f = GlassMath.fills(250, 2500);
      expect(f.first, 1);
      expect(f.skip(1).every((v) => v == 0), isTrue);
    });

    test('375 ml is one and a half glasses, not rounded', () {
      final f = GlassMath.fills(375, 2500);
      expect(f[0], 1);
      expect(f[1], 0.5);
      expect(f.skip(2).every((v) => v == 0), isTrue);
      expect(GlassMath.glassesConsumed(375), 1.5);
      expect(GlassMath.glassLabel(1.5), '1.5');
    });

    test('1,000 ml is 4 full and 6 remaining', () {
      final f = GlassMath.fills(1000, 2500);
      expect(f.where((v) => v == 1).length, 4);
      expect(f.where((v) => v == 0).length, 6);
      expect(GlassMath.glassesRemaining(1000, 2500), 6);
    });

    test('the exact goal fills every glass', () {
      final f = GlassMath.fills(2500, 2500);
      expect(f.every((v) => v == 1), isTrue);
      expect(GlassMath.glassesRemaining(2500, 2500), 0);
    });

    test('over the goal stays full and remaining is zero', () {
      final f = GlassMath.fills(3100, 2500);
      expect(f.length, 10);
      expect(f.every((v) => v == 1), isTrue);
      expect(GlassMath.glassesRemaining(3100, 2500), 0);
    });

    test('a goal that is not a multiple of 250 rounds the glass count up', () {
      expect(GlassMath.totalGlasses(2300), 10);
      expect(GlassMath.totalGlasses(2500), 10);
      expect(GlassMath.totalGlasses(2550), 11);
      expect(GlassMath.totalGlasses(0), 0);
      // 130 ml is just over half of the first glass.
      expect(GlassMath.fills(130, 2300).first, closeTo(0.52, 1e-9));
    });

    test('volumes and glass counts read cleanly', () {
      expect(GlassMath.volumeLabel(750), '750 ml');
      expect(GlassMath.volumeLabel(1000), '1 L');
      expect(GlassMath.volumeLabel(1250), '1.25 L');
      expect(GlassMath.volumeLabel(2500), '2.5 L');
      expect(GlassMath.glassLabel(4), '4');
    });
  });

  group('daily totals', () {
    test(
      'consumed, remaining, progress and glasses for the example day',
      () async {
        final r = Rig();
        r.weight = 78.125; // 2500 ml baseline
        await r.svc.log(1500);
        final d = r.svc.today;
        expect(d.goalMl, 2500);
        expect(d.consumedMl, 1500);
        expect(d.remainingMl, 1000);
        expect(d.progress, closeTo(0.6, 1e-9));
        expect(GlassMath.glassesConsumed(d.consumedMl), 6);
        expect(GlassMath.glassesRemaining(d.consumedMl, d.goalMl!), 4);
      },
    );

    test('adding, custom amounts and removing update every figure', () async {
      final r = Rig()..weight = 78.125;
      final a = await r.svc.log(250);
      await r.svc.log(330);
      expect(r.svc.today.consumedMl, 580);
      await r.svc.remove(a!.id);
      expect(r.svc.today.consumedMl, 330);
      expect(r.svc.today.remainingMl, 2170);
      expect(r.svc.week().totalKnownMl, 330);
    });

    test('an amount outside 1 to 5000 ml is refused', () async {
      final r = Rig();
      expect(await r.svc.log(0), isNull);
      expect(await r.svc.log(-5), isNull);
      expect(await r.svc.log(5001), isNull);
      expect(r.svc.today.entries, isEmpty);
    });

    test('the amount is stored exactly, never rounded to a glass', () async {
      final r = Rig();
      await r.svc.log(373);
      expect(r.svc.today.consumedMl, 373);
      expect(r.svc.today.entries.single.amountMl, 373);
    });

    test('exceeding the goal keeps counting and reports the extra', () async {
      final r = Rig()..weight = 78.125;
      await r.svc.log(2500);
      await r.svc.log(400);
      final d = r.svc.today;
      expect(d.remainingMl, 0);
      expect(d.overMl, 400);
      expect(d.progress, greaterThan(1));
    });

    test('repeating a request id records the drink once', () async {
      final r = Rig();
      await r.svc.log(250, requestId: 'tap-1');
      await r.svc.log(250, requestId: 'tap-1');
      await r.svc.log(250, requestId: 'tap-1');
      expect(r.svc.today.entries.length, 1);
      expect(r.svc.today.consumedMl, 250);
    });

    test('editing an entry corrects the total', () async {
      final r = Rig();
      final e = await r.svc.log(500);
      expect(await r.svc.edit(e!.id, 300), isTrue);
      expect(r.svc.today.consumedMl, 300);
      expect(await r.svc.edit(e.id, 0), isFalse);
      expect(await r.svc.edit('nope', 100), isFalse);
    });
  });

  group('persistence', () {
    test('records survive closing and reopening', () async {
      final r = Rig();
      await r.svc.log(250);
      await r.svc.log(400);
      final again = r.restart();
      expect(again.today.consumedMl, 650);
      expect(again.today.entries.length, 2);
    });

    test('edits and deletions are saved', () async {
      final r = Rig();
      final a = await r.svc.log(250);
      final b = await r.svc.log(400);
      await r.svc.edit(b!.id, 500);
      await r.svc.remove(a!.id);
      expect(r.restart().today.consumedMl, 500);
    });

    test('a damaged save is ignored, not a crash', () {
      final r = Rig()..disk = '{not json';
      expect(r.svc.today.consumedMl, 0);
      expect(r.svc.week().totalKnownMl, 0);
    });

    test('each account sees only its own records', () async {
      final r = Rig();
      await r.svc.log(250);
      r.user = 'u2';
      expect(r.svc.today.consumedMl, 0);
      await r.svc.log(500);
      expect(r.svc.today.consumedMl, 500);
      r.user = 'u1';
      expect(r.svc.today.consumedMl, 250);
    });

    test('the day is the local day it was logged on', () async {
      final r = Rig(now: DateTime(2026, 11, 18, 23, 59));
      await r.svc.log(250);
      r.clock = DateTime(2026, 11, 19, 0, 1);
      await r.svc.log(250);
      expect(r.svc.today.consumedMl, 250);
      expect(r.svc.day('2026-11-18').consumedMl, 250);
    });
  });

  group('weekly history', () {
    test('Monday to Sunday with correct labels and totals', () async {
      final r = Rig(now: DateTime(2026, 11, 18, 12)); // a Wednesday
      await r.svc.log(1000, at: DateTime(2026, 11, 16, 9));
      await r.svc.log(500, at: DateTime(2026, 11, 17, 9));
      await r.svc.log(250, at: DateTime(2026, 11, 18, 9));
      final w = r.svc.week();
      expect(w.start, DateTime(2026, 11, 16));
      expect(w.days.length, 7);
      expect(w.days.first.dayKey, '2026-11-16');
      expect(w.days.last.dayKey, '2026-11-22');
      expect(w.days.first.date.weekday, DateTime.monday);
      expect(w.days.last.date.weekday, DateTime.sunday);
      expect(w.totalKnownMl, 1750);
      expect(w.totalLitres, 1.75);
      expect(w.days.where((d) => d.isToday).single.dayKey, '2026-11-18');
    });

    test('a week across a month boundary', () async {
      final r = Rig(now: DateTime(2026, 12, 2, 10)); // Wed; week starts 30 Nov
      await r.svc.log(800, at: DateTime(2026, 11, 30, 8));
      await r.svc.log(600, at: DateTime(2026, 12, 1, 8));
      final w = r.svc.week();
      expect(w.days.first.dayKey, '2026-11-30');
      expect(w.days[1].dayKey, '2026-12-01');
      expect(w.totalKnownMl, 1400);
    });

    test('a week across a year boundary', () async {
      final r = Rig(now: DateTime(2027, 1, 1, 10)); // Fri; week starts 28 Dec
      await r.svc.log(900, at: DateTime(2026, 12, 29, 8));
      await r.svc.log(700, at: DateTime(2027, 1, 1, 8));
      final w = r.svc.week();
      expect(w.days.first.dayKey, '2026-12-28');
      expect(w.days.last.dayKey, '2027-01-03');
      expect(w.totalKnownMl, 1600);
    });

    test('a day with no record is not a confirmed zero', () async {
      final r = Rig(now: DateTime(2026, 11, 18, 12));
      await r.svc.log(500, at: DateTime(2026, 11, 16, 9));
      final w = r.svc.week();
      expect(w.days[0].status, HydrationDayStatus.recorded);
      expect(w.days[1].status, HydrationDayStatus.noData);
      expect(w.days[1].totalMl, isNull);
      expect(w.knownDays, 1);

      await r.svc.confirmNoWater('2026-11-17');
      final w2 = r.svc.week();
      expect(w2.days[1].status, HydrationDayStatus.confirmedZero);
      expect(w2.days[1].totalMl, 0);
      expect(w2.knownDays, 2);
      expect(w2.totalKnownMl, 500, reason: 'a confirmed zero adds nothing');
    });

    test('a confirmed zero is dropped when water is logged that day', () async {
      final r = Rig(now: DateTime(2026, 11, 18, 12));
      await r.svc.confirmNoWater('2026-11-17');
      await r.svc.log(250, at: DateTime(2026, 11, 17, 9));
      expect(r.svc.day('2026-11-17').status, HydrationDayStatus.recorded);
      expect(await r.svc.confirmNoWater('2026-11-17'), isFalse);
      expect(
        await r.svc.confirmNoWater('2026-11-25'),
        isFalse,
        reason: 'future',
      );
    });

    test('editing or deleting a previous entry updates the week', () async {
      final r = Rig(now: DateTime(2026, 11, 18, 12));
      final e = await r.svc.log(1000, at: DateTime(2026, 11, 16, 9));
      await r.svc.log(500, at: DateTime(2026, 11, 17, 9));
      expect(r.svc.week().totalKnownMl, 1500);
      await r.svc.edit(e!.id, 600);
      expect(r.svc.week().totalKnownMl, 1100);
      expect(r.svc.day('2026-11-16').consumedMl, 600);
      await r.svc.remove(e.id);
      expect(r.svc.week().totalKnownMl, 500);
      // Deleting the only entry leaves the day as no data, not as a zero.
      expect(r.svc.day('2026-11-16').status, HydrationDayStatus.noData);
    });

    test('history lists recorded days newest first and always today', () async {
      final r = Rig(now: DateTime(2026, 11, 18, 12));
      await r.svc.log(500, at: DateTime(2026, 11, 14, 9));
      await r.svc.log(500, at: DateTime(2026, 11, 16, 9));
      final keys = r.svc.history().map((d) => d.dayKey).toList();
      expect(keys, ['2026-11-18', '2026-11-16', '2026-11-14']);
    });
  });

  group('personalised goal', () {
    test('baseline follows body weight', () {
      int g(double kg) =>
          HydrationGoalCalculator.calculate(weightKg: kg).goalMl;
      expect(g(50), 1600);
      expect(g(70), 2250);
      expect(g(85), 2700);
      expect(g(110), 3500, reason: 'capped');
      expect(g(35), 1500, reason: 'floored');
      expect(g(70), lessThan(g(85)));
    });

    test('targets are rounded, not falsely precise', () {
      for (final kg in [52.3, 61.7, 73.9, 88.8]) {
        expect(HydrationGoalCalculator.calculate(weightKg: kg).goalMl % 50, 0);
      }
    });

    test('missing or implausible weight gives a labelled provisional goal', () {
      for (final w in [null, 0.0, 12.0, 900.0]) {
        final g = HydrationGoalCalculator.calculate(weightKg: w);
        expect(g.basis, HydrationGoalBasis.provisional);
        expect(g.goalMl, HydrationGoalCalculator.provisionalMl);
        expect(g.explanation, contains('weight'));
      }
    });

    test('activity raises the goal conservatively and is labelled', () {
      final base = HydrationGoalCalculator.calculate(weightKg: 70);
      final g = HydrationGoalCalculator.calculate(
        weightKg: 70,
        activities: const [
          HydrationActivity(id: 'a', minutes: 60, cardio: false),
        ],
      );
      expect(base.basis, HydrationGoalBasis.baseline);
      expect(g.basis, HydrationGoalBasis.activityAdjusted);
      expect(g.activityMl, 300);
      expect(g.goalMl, base.goalMl + 300);
      expect(g.baselineMl, base.goalMl);
    });

    test(
      'cardio counts more per minute than strength, hard more than easy',
      () {
        int act(HydrationActivity a) => HydrationGoalCalculator.activityMl([a]);
        final strength = act(
          const HydrationActivity(id: 's', minutes: 30, cardio: false),
        );
        final easy = act(
          const HydrationActivity(id: 'e', minutes: 30, cardio: true, met: 6),
        );
        final hard = act(
          const HydrationActivity(id: 'h', minutes: 30, cardio: true, met: 10),
        );
        expect(strength, 150);
        expect(easy, 210);
        expect(hard, 270);
      },
    );

    test('the same activity is counted once', () {
      const a = HydrationActivity(id: 'run1', minutes: 40, cardio: true);
      expect(
        HydrationGoalCalculator.activityMl([a, a, a]),
        HydrationGoalCalculator.activityMl([a]),
      );
    });

    test('extreme activity cannot push the goal to an extreme', () {
      final g = HydrationGoalCalculator.calculate(
        weightKg: 120,
        activities: [
          for (var i = 0; i < 10; i++)
            HydrationActivity(id: 'x$i', minutes: 300, cardio: true, met: 12),
        ],
      );
      expect(g.activityMl, HydrationGoalCalculator.maxActivityMl);
      expect(g.goalMl, lessThanOrEqualTo(HydrationGoalCalculator.maxGoalMl));
    });

    test('a manual goal is used, kept within sane limits and explained', () {
      final g = HydrationGoalCalculator.calculate(weightKg: 70, manualMl: 3000);
      expect(g.goalMl, 3000);
      expect(g.basis, HydrationGoalBasis.manual);
      expect(
        HydrationGoalCalculator.calculate(manualMl: 50).goalMl,
        HydrationGoalCalculator.minManualMl,
      );
      expect(
        HydrationGoalCalculator.calculate(manualMl: 99999).goalMl,
        HydrationGoalCalculator.maxManualMl,
      );
    });

    test(
      'finishing a workout raises today once, however often it is refreshed',
      () async {
        final r = Rig()..weight = 70;
        final before = r.svc.today.goalMl!;
        r.activities = [
          const HydrationActivity(id: 'w1', minutes: 60, cardio: false),
        ];
        expect(await r.svc.refreshTodayGoal(), isTrue);
        final after = r.svc.today.goalMl!;
        expect(after, before + 300);
        expect(await r.svc.refreshTodayGoal(), isFalse);
        expect(await r.svc.refreshTodayGoal(), isFalse);
        // The same workout passed twice is still counted once.
        r.activities = [
          const HydrationActivity(id: 'w1', minutes: 60, cardio: false),
          const HydrationActivity(id: 'w1', minutes: 60, cardio: false),
        ];
        expect(r.svc.today.goalMl, after);
      },
    );

    test('past days keep the target they had when the goal changes', () async {
      final r = Rig(now: DateTime(2026, 11, 17, 12))..weight = 70;
      await r.svc.refreshTodayGoal(); // 17th: 2250
      await r.svc.log(1000);
      expect(r.svc.today.goalMl, 2250);

      // The next day the athlete is heavier, trains and sets nothing.
      r.clock = DateTime(2026, 11, 18, 12);
      r.weight = 90;
      r.activities = [
        const HydrationActivity(id: 'w', minutes: 90, cardio: true),
      ];
      await r.svc.refreshTodayGoal();
      expect(r.svc.today.goalMl, greaterThan(2250));
      final past = r.svc.day('2026-11-17');
      expect(past.goalMl, 2250);
      expect(past.progress, closeTo(1000 / 2250, 1e-9));

      // A manual change today does not touch it either.
      await r.svc.setManualGoal(3000);
      expect(r.svc.day('2026-11-17').goalMl, 2250);
      expect(r.restart().day('2026-11-17').goalMl, 2250);
    });

    test('a day with no recorded target stays unavailable', () async {
      final r = Rig(now: DateTime(2026, 11, 18, 12));
      await r.svc.log(500, at: DateTime(2026, 11, 10, 9));
      final d = r.svc.day('2026-11-10');
      expect(d.goal, isNull);
      expect(d.goalMl, isNull);
      expect(d.progress, isNull);
      expect(d.remainingMl, isNull);
      expect(d.consumedMl, 500);
    });

    test('manual goal can be set, persisted and cleared', () async {
      final r = Rig()..weight = 70;
      await r.svc.setManualGoal(2800);
      expect(r.svc.today.goalMl, 2800);
      expect(r.svc.today.goal!.basis, HydrationGoalBasis.manual);
      expect(r.restart().today.goalMl, 2800);
      await r.svc.setManualGoal(null);
      expect(r.svc.today.goalMl, 2250);
      expect(r.svc.today.goal!.basis, HydrationGoalBasis.baseline);
    });
  });

  group('Showcase Mode', () {
    test('shows labelled sample history for the sample athlete', () {
      final r = Rig(now: DateTime(2026, 11, 18, 15));
      r.showcase = true;
      r.weight = 77.5;
      final w = r.svc.week();
      expect(r.svc.isSample, isTrue);
      expect(w.days.every((d) => d.isSample), isTrue);
      final past = w.days.where(
        (d) => !d.isToday && d.date.isBefore(DateTime(2026, 11, 18)),
      );
      expect(
        past.where((d) => d.status == HydrationDayStatus.recorded),
        isNotEmpty,
      );
      // The demo covers completed, partial and no-data days.
      final recorded = w.days.where((d) => d.progress != null).toList();
      expect(recorded.any((d) => d.progress! >= 1), isTrue);
      expect(recorded.any((d) => d.progress! < 1), isTrue);
      expect(w.days.any((d) => d.status == HydrationDayStatus.noData), isTrue);
    });

    test('sample targets come from the sample athlete weight and workouts', () {
      final r = Rig(now: DateTime(2026, 11, 18, 15))
        ..showcase = true
        ..weight = 77.5;
      final goals = r.svc
          .history(limit: 10)
          .map((d) => d.goalMl)
          .whereType<int>();
      expect(goals, isNotEmpty);
      // 77.5 kg gives a 2,500 ml baseline; workout days are above it.
      expect(goals.every((g) => g >= 2500), isTrue);
    });

    test('logging in Showcase never reaches real storage', () async {
      final r = Rig(now: DateTime(2026, 11, 18, 15));
      await r.svc.log(400); // a real record first
      final realDisk = r.disk;
      final realWrites = r.writes;
      r.showcase = true;
      final before = r.svc.today.consumedMl;
      await r.svc.log(250);
      await r.svc.log(500);
      expect(r.svc.today.consumedMl, before + 750);
      expect(r.writes, realWrites, reason: 'nothing written');
      expect(r.disk, realDisk);
      expect(r.svc.today.entries.any((e) => e.userId == 'sample'), isTrue);
    });

    test('real records and sample records never mix', () async {
      final r = Rig(now: DateTime(2026, 11, 18, 15));
      await r.svc.log(400);
      r.showcase = true;
      expect(r.svc.today.entries.every((e) => e.userId == 'sample'), isTrue);
      expect(
        r.svc.today.entries.any((e) => e.amountMl == 400 && e.userId == 'u1'),
        isFalse,
      );
      r.showcase = false;
      expect(r.svc.today.consumedMl, 400, reason: 'the real record is intact');
      expect(r.svc.week().days.every((d) => !d.isSample), isTrue);
    });

    test('what was done in Showcase is dropped when it ends', () async {
      final r = Rig(now: DateTime(2026, 11, 18, 15));
      r.showcase = true;
      await r.svc.log(900);
      final during = r.svc.today.consumedMl;
      r.showcase = false;
      expect(r.svc.today.consumedMl, 0);
      r.showcase = true;
      expect(r.svc.today.consumedMl, lessThan(during), reason: 'fresh sample');
    });

    test('LocalStorage holds no hydration data after Showcase use', () async {
      final r = Rig(now: DateTime(2026, 11, 18, 15));
      r.showcase = true;
      await r.svc.log(250);
      expect(LocalStorage.getHydrationJson(), isNull);
    });
  });
}
