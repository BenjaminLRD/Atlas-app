import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/atlas_challenge.dart';
import 'package:atlas/services/challenges/atlas_challenge_service.dart';
import 'package:atlas/services/challenges/thirty_day_challenge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AtlasChallenge _challenge({
  required DateTime start,
  int days = 30,
  AtlasChallengeStatus status = AtlasChallengeStatus.active,
  String? opponent,
}) => AtlasChallenge(
  id: 'c_${start.millisecondsSinceEpoch}',
  title: '30-Day Fitness Challenge',
  metric: ChallengeMetric.workouts,
  target: 20,
  durationDays: days,
  createdAt: start,
  status: status,
  startDate: start,
  endDate: DateTime(start.year, start.month, start.day + days),
  opponentKey: opponent,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    AtlasChallengeService.resetInstance();
  });

  final start = DateTime(2026, 11, 1);
  final now = DateTime(2026, 11, 12, 9, 30); // day 12

  group('finding the accepted challenge', () {
    test('only your own active 30-day challenge counts', () {
      final mine = _challenge(start: start);
      expect(ThirtyDayChallenge.find([mine]), mine);
      expect(
        ThirtyDayChallenge.find([_challenge(start: start, days: 14)]),
        isNull,
      );
      expect(
        ThirtyDayChallenge.find([
          _challenge(start: start, status: AtlasChallengeStatus.expired),
        ]),
        isNull,
      );
      expect(
        ThirtyDayChallenge.find([_challenge(start: start, opponent: 'maya')]),
        isNull,
        reason: 'a challenge against a sample athlete is not yours',
      );
      expect(ThirtyDayChallenge.find(const []), isNull);
    });

    test('accepting uses the existing challenge service, once', () async {
      final svc = AtlasChallengeService();
      expect(ThirtyDayChallenge.find(svc.all()), isNull);
      final a = await ThirtyDayChallenge.accept(svc, now: now);
      final b = await ThirtyDayChallenge.accept(svc, now: now);
      expect(a.id, b.id);
      expect(svc.all().length, 1);
      expect(svc.active().single.durationDays, 30);
      expect(svc.active().single.title, ThirtyDayChallenge.defaultTitle);
      expect(ThirtyDayChallenge.find(svc.all()), isNotNull);
    });
  });

  group('days and progress', () {
    test('only days with a completed workout are filled', () {
      final v = ThirtyDayChallenge.view(
        challenge: _challenge(start: start),
        workoutDates: [
          DateTime(2026, 11, 1, 18),
          DateTime(2026, 11, 3, 7),
          DateTime(2026, 11, 12, 8), // today
        ],
        now: now,
      );
      expect(v.days.length, 30);
      expect(v.days[0].done, isTrue);
      expect(v.days[1].done, isFalse, reason: 'no workout, not filled');
      expect(v.days[2].done, isTrue);
      expect(v.days[11].done, isTrue);
      expect(v.completedDays, 3);
      expect(v.percent, 10);
      expect(v.todayDone, isTrue);
    });

    test('the date moving on does not fill any day by itself', () {
      final none = ThirtyDayChallenge.view(
        challenge: _challenge(start: start),
        workoutDates: const [],
        now: now,
      );
      expect(none.completedDays, 0);
      expect(none.percent, 0);
      final later = ThirtyDayChallenge.view(
        challenge: _challenge(start: start),
        workoutDates: const [],
        now: now.add(const Duration(days: 10)),
      );
      expect(later.completedDays, 0);
      expect(later.dayNumber, 22);
    });

    test('day states: done, today, missed and upcoming', () {
      final v = ThirtyDayChallenge.view(
        challenge: _challenge(start: start),
        workoutDates: [DateTime(2026, 11, 1)],
        now: now,
      );
      expect(v.days[0].done, isTrue);
      expect(v.days[1].missed, isTrue);
      expect(v.days[11].isToday, isTrue);
      expect(v.days[11].done, isFalse);
      expect(v.days[11].missed, isFalse);
      expect(v.days[12].isPast, isFalse);
      expect(v.days[12].done, isFalse);
      expect(v.days.where((d) => d.isToday).length, 1);
    });

    test('the day number is 1 to 30 and the end is recognised', () {
      viewAt(DateTime n) => ThirtyDayChallenge.view(
        challenge: _challenge(start: start),
        workoutDates: const [],
        now: n,
      );
      expect(viewAt(DateTime(2026, 11, 1)).dayNumber, 1);
      expect(viewAt(DateTime(2026, 11, 12)).dayNumber, 12);
      expect(viewAt(DateTime(2026, 11, 30)).dayNumber, 30);
      expect(viewAt(DateTime(2026, 11, 30)).ended, isFalse);
      final over = viewAt(DateTime(2026, 12, 15));
      expect(over.dayNumber, 30);
      expect(over.ended, isTrue);
    });

    test('workouts in the future or before the start are ignored', () {
      final v = ThirtyDayChallenge.view(
        challenge: _challenge(start: start),
        workoutDates: [
          DateTime(2026, 10, 30),
          DateTime(2026, 11, 20), // later than "now"
        ],
        now: now,
      );
      expect(v.completedDays, 0);
    });

    test('several workouts on one day fill that day once', () {
      final v = ThirtyDayChallenge.view(
        challenge: _challenge(start: start),
        workoutDates: [
          DateTime(2026, 11, 2, 7),
          DateTime(2026, 11, 2, 12),
          DateTime(2026, 11, 2, 19),
        ],
        now: now,
      );
      expect(v.completedDays, 1);
    });

    test('progress is the share of the thirty days completed', () {
      final v = ThirtyDayChallenge.view(
        challenge: _challenge(start: start),
        workoutDates: [for (var d = 1; d <= 9; d++) DateTime(2026, 11, d)],
        now: now,
      );
      expect(v.completedDays, 9);
      expect(v.percent, 30);
    });
  });

  group('the Showcase sample', () {
    test('is an accepted challenge on day 12 with believable progress', () {
      final v = ThirtyDayChallenge.sample(now: now);
      expect(v.isSample, isTrue);
      expect(v.dayNumber, 12);
      expect(v.days.length, 30);
      expect(v.completedDays, 9);
      expect(v.percent, 30);
      expect(v.days.where((d) => d.missed).length, 2);
      expect(v.days[11].isToday, isTrue);
      expect(v.days[11].done, isFalse);
      expect(v.days.skip(12).every((d) => !d.done), isTrue);
    });

    test('a workout done during the demo fills today only', () {
      final v = ThirtyDayChallenge.sample(now: now, demoWorkoutDates: [now]);
      expect(v.days[11].done, isTrue);
      expect(v.completedDays, 10);
    });

    test('building it never touches the real challenges or storage', () async {
      final svc = AtlasChallengeService();
      ThirtyDayChallenge.sample(now: now);
      expect(svc.all(), isEmpty);
      expect(LocalStorage.getString('atlas_challenges_self_v1'), isNull);
      expect(LocalStorage.getString('atlas_challenges_sample_v1'), isNull);
    });
  });
}
