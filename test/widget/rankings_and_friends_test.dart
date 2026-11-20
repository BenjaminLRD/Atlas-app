import 'dart:math' as math;

import 'package:atlas/app_theme.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/providers/showcase_mode_provider.dart';
import 'package:atlas/screens/athlete_profile_screen.dart';
import 'package:atlas/screens/community_screen.dart';
import 'package:atlas/screens/friends_screen.dart';
import 'package:atlas/services/community/sample_community.dart';
import 'package:atlas/services/community/sample_leaderboard.dart';
import 'package:atlas/services/community/sample_world.dart';
import 'package:atlas/services/community/weekly_stats.dart';
import 'package:atlas/services/moderation_service.dart';
import 'package:atlas/services/saved_content_service.dart';
import 'package:atlas/services/social_graph_service.dart';
import 'package:atlas/services/social_service.dart';
import 'package:atlas/widgets/community/rankings_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

MyWeekly _week({
  int? workouts,
  int? minutes,
  double? volume,
  int? streak,
  int? steps,
  int? prevWorkouts,
  int? prevMinutes,
  int? prevSteps,
  bool hasHistory = true,
}) {
  final start = WeeklyStats.weekStart(DateTime.now());
  return MyWeekly(
    current: WeekStats(
      start: start,
      workouts: workouts,
      minutes: minutes,
      volumeKg: volume,
      avgDailySteps: steps,
      stepDays: steps == null ? 0 : 3,
    ),
    previous: WeekStats(
      start: start.subtract(const Duration(days: 7)),
      workouts: prevWorkouts,
      minutes: prevMinutes,
      avgDailySteps: prevSteps,
    ),
    streakDays: streak,
    hasAnySteps: steps != null || prevSteps != null,
    hasAnyWorkouts: hasHistory,
  );
}

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final la = _lum(a);
  final lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  Size size = const Size(412, 3000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme, home: home));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Widget _tab({MyWeekly? week, bool sample = false}) => Scaffold(
  body: RankingsTab(weeklyOverride: week, startOnSample: sample),
);

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
    SocialService.resetInstance();
    await ShowcaseModeProvider.instance.disableShowcaseMode();
  });

  group('Real tab: your own week only', () {
    testWidgets(
      'opens on Real and shows your recorded week against last week',
      (tester) async {
        await _pump(
          tester,
          _tab(
            week: _week(
              workouts: 3,
              minutes: 142,
              volume: 12400,
              streak: 3,
              steps: 8120,
              prevWorkouts: 2,
              prevMinutes: 96,
              prevSteps: 7000,
            ),
          ),
        );
        expect(find.byKey(const Key('your_week_card')), findsOneWidget);
        Text stat(String k) => tester.widget<Text>(
          find
              .descendant(of: find.byKey(Key(k)), matching: find.byType(Text))
              .first,
        );
        expect(stat('wk_workouts').data, '3');
        expect(stat('wk_minutes').data, '142');
        expect(stat('wk_volume').data, '12,400');
        expect(stat('wk_streak').data, '3');
        expect(stat('wk_steps').data, '8,120');
        expect(find.byKey(const Key('vs_last_week')), findsOneWidget);
        expect(find.text('+1'), findsOneWidget); // workouts 2 -> 3
        expect(find.text('+46'), findsOneWidget); // minutes 96 -> 142
        expect(find.byKey(const Key('steps_unavailable')), findsNothing);
      },
    );

    testWidgets('always explains that there is no member leaderboard', (
      tester,
    ) async {
      await _pump(
        tester,
        _tab(week: _week(workouts: 1, minutes: 30, volume: 100, streak: 1)),
      );
      expect(find.byKey(const Key('no_member_leaderboard')), findsOneWidget);
      expect(find.byKey(const Key('sample_board_banner')), findsNothing);
    });

    testWidgets('no recorded activity: dashes, no invented numbers', (
      tester,
    ) async {
      await _pump(tester, _tab(week: _week(hasHistory: false)));
      for (final k in [
        'wk_workouts',
        'wk_minutes',
        'wk_volume',
        'wk_streak',
        'wk_steps',
      ]) {
        expect(
          tester
              .widget<Text>(
                find
                    .descendant(
                      of: find.byKey(Key(k)),
                      matching: find.byType(Text),
                    )
                    .first,
              )
              .data,
          '--',
          reason: k,
        );
      }
      expect(find.byKey(const Key('no_history_note')), findsOneWidget);
      expect(find.byKey(const Key('steps_unavailable')), findsOneWidget);
      expect(find.textContaining(' XP'), findsNothing);
    });

    testWidgets('a genuinely empty week shows zero, not dashes', (
      tester,
    ) async {
      await _pump(
        tester,
        _tab(
          week: _week(
            workouts: 0,
            minutes: 0,
            volume: 0,
            streak: 0,
            prevWorkouts: 2,
          ),
        ),
      );
      expect(find.byKey(const Key('empty_week_note')), findsOneWidget);
      expect(find.byKey(const Key('no_history_note')), findsNothing);
    });

    testWidgets('unavailable steps are reported, not shown as a number', (
      tester,
    ) async {
      await _pump(
        tester,
        _tab(week: _week(workouts: 2, minutes: 90, volume: 5000, streak: 2)),
      );
      expect(find.byKey(const Key('steps_unavailable')), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find
                  .descendant(
                    of: find.byKey(const Key('wk_steps')),
                    matching: find.byType(Text),
                  )
                  .first,
            )
            .data,
        '--',
      );
    });

    testWidgets(
      'no sample athlete or scripted figure appears on the Real tab',
      (tester) async {
        await _pump(
          tester,
          _tab(week: _week(workouts: 1, minutes: 30, volume: 100, streak: 1)),
        );
        for (final a in SampleWorld.athletes) {
          expect(find.textContaining(a.name), findsNothing, reason: a.name);
        }
      },
    );

    testWidgets('live data: your logged workout this week is counted', (
      tester,
    ) async {
      await LocalStorage.saveWorkoutHistory([
        WorkoutHistory(
          workoutName: 'Today',
          dateCompleted: DateTime.now(),
          durationSeconds: 1800,
          exercisesCompleted: 3,
          completionPercentage: 100,
          totalVolume: 2500,
          totalSets: 9,
          totalReps: 90,
        ),
      ]);
      FitnessProvider.instance.refreshWorkoutHistory();
      await _pump(tester, _tab());
      expect(
        tester
            .widget<Text>(
              find
                  .descendant(
                    of: find.byKey(const Key('wk_workouts')),
                    matching: find.byType(Text),
                  )
                  .first,
            )
            .data,
        '1',
      );
      expect(
        tester
            .widget<Text>(
              find
                  .descendant(
                    of: find.byKey(const Key('wk_minutes')),
                    matching: find.byType(Text),
                  )
                  .first,
            )
            .data,
        '30',
      );
    });
  });

  group('Sample tab: demo leaderboard', () {
    testWidgets('is labelled and ranks all 11 athletes', (tester) async {
      await _pump(tester, _tab(week: _week(hasHistory: false), sample: true));
      expect(find.byKey(const Key('sample_board_banner')), findsOneWidget);
      expect(find.text('SAMPLE'), findsWidgets);
      final rows = SampleLeaderboard.rank(
        SampleCategory.workouts,
        SampleTimeframe.week,
      );
      for (final r in rows.take(3)) {
        expect(find.byKey(Key('podium_${r.rank}')), findsOneWidget);
      }
      for (final r in rows.skip(3)) {
        expect(find.byKey(Key('sample_rank_${r.athlete.key}')), findsOneWidget);
      }
      expect(find.byKey(const Key('your_week_card')), findsNothing);
    });

    testWidgets('categories and timeframes switch the ranking', (tester) async {
      await _pump(tester, _tab(sample: true));
      // Volume is all-time only, so it is not offered for This week.
      expect(find.byKey(const Key('category_volume')), findsNothing);
      await tester.tap(find.byKey(const Key('timeframe_allTime')));
      await tester.pump();
      expect(find.byKey(const Key('category_volume')), findsOneWidget);
      expect(find.byKey(const Key('category_minutes')), findsNothing);

      await tester.tap(find.byKey(const Key('category_volume')));
      await tester.pump();
      final vol = SampleLeaderboard.rank(
        SampleCategory.volume,
        SampleTimeframe.allTime,
      );
      expect(find.text(vol.first.valueLabel), findsWidgets);

      // Back to This week: volume is unsupported, so it falls back.
      await tester.tap(find.byKey(const Key('timeframe_week')));
      await tester.pump();
      expect(find.byKey(const Key('category_volume')), findsNothing);
      expect(find.byKey(const Key('sample_board_banner')), findsOneWidget);
    });

    testWidgets('tapping the podium and a row opens that athlete', (
      tester,
    ) async {
      await _pump(tester, _tab(sample: true));
      final rows = SampleLeaderboard.rank(
        SampleCategory.workouts,
        SampleTimeframe.week,
      );

      await tester.tap(find.byKey(const Key('podium_1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester
            .widget<AthleteProfileScreen>(find.byType(AthleteProfileScreen))
            .userId,
        rows.first.athlete.id,
      );
      Navigator.of(tester.element(find.byType(AthleteProfileScreen))).pop();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));

      final row = rows[5];
      await tester.tap(find.byKey(Key('sample_rank_${row.athlete.key}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        tester
            .widget<AthleteProfileScreen>(find.byType(AthleteProfileScreen))
            .userId,
        row.athlete.id,
      );
    });

    testWidgets('Showcase Mode opens on the Sample tab', (tester) async {
      await ShowcaseModeProvider.instance.enableShowcaseMode();
      await _pump(tester, const CommunityScreen());
      await tester.tap(find.text('Rankings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('sample_board_banner')), findsOneWidget);
      await ShowcaseModeProvider.instance.disableShowcaseMode();
    });
  });

  group('contrast and layout', () {
    testWidgets('headings and notes are readable on the charcoal background', (
      tester,
    ) async {
      await _pump(tester, _tab(week: _week(hasHistory: false)));
      final bg = AppTheme.darkTheme.scaffoldBackgroundColor;
      for (final text in ['No member leaderboard yet']) {
        final style = tester.widget<Text>(find.text(text)).style;
        expect(style?.color, isNotNull, reason: '$text has no explicit colour');
        expect(
          _contrast(style!.color!, bg),
          greaterThanOrEqualTo(4.5),
          reason: text,
        );
      }
    });

    for (final size in const [Size(320, 568), Size(360, 640), Size(412, 915)]) {
      for (final sample in [false, true]) {
        testWidgets(
          'Rankings fits ${size.width.toInt()}px (${sample ? 'sample' : 'real'})',
          (tester) async {
            await _pump(
              tester,
              _tab(
                week: _week(
                  workouts: 3,
                  minutes: 142,
                  volume: 12400,
                  streak: 3,
                  steps: 8120,
                  prevWorkouts: 2,
                ),
                sample: sample,
              ),
              size: size,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  group('Friends are the shared sample athletes', () {
    test(
      'default friends are Alex Carter and Maya Chen with sample-world identities',
      () async {
        final friends = await SocialService.instance.getFriends();
        expect(friends.map((f) => f.userId).toSet(), {'usr_alex', 'usr_maya'});
        for (final f in friends) {
          final a = SampleWorld.byId(f.userId)!;
          expect(f.displayName, a.name);
          expect(f.avatarUrl, a.avatar);
          expect(f.rankTitle, a.rank);
          expect(SampleCommunity.profileFor(f.userId)!.rankTitle, f.rankTitle);
          expect(f.totalXP, 0, reason: 'no invented XP');
        }
      },
    );

    test('the default activity comes from the sample posts', () async {
      final feed = await SocialService.instance.getActivityFeed();
      expect(feed, isNotEmpty);
      final posts = SampleCommunity.posts();
      for (final item in feed) {
        expect(SampleCommunity.isSampleUser(item.userId), isTrue);
        expect(
          posts.any(
            (p) => p.userId == item.userId && item.title.contains(p.title),
          ),
          isTrue,
          reason: item.title,
        );
      }
    });

    testWidgets(
      'the Friends tab shows SAMPLE tags and weekly workouts, never XP',
      (tester) async {
        await FitnessProvider.instance.loadFriends();
        await FitnessProvider.instance.loadActivityFeed();
        await _pump(
          tester,
          const FriendsScreen(),
          size: const Size(1200, 3000),
        );
        await tester.tap(find.text('Friends').first);
        await tester.pump();

        expect(find.text('Alex Carter'), findsWidgets);
        expect(find.text('SAMPLE'), findsWidgets);
        final alex = SampleWorld.byKey('alex')!;
        expect(
          find.text(
            '${alex.rank} • ${alex.stats.weeklyWorkouts} workouts this week',
          ),
          findsOneWidget,
        );
        expect(find.textContaining(' XP'), findsNothing);
        expect(find.textContaining('52400'), findsNothing);
      },
    );

    testWidgets(
      'a friend request is a sample athlete and can still be accepted',
      (tester) async {
        await FitnessProvider.instance.loadFriends();
        await _pump(
          tester,
          const FriendsScreen(),
          size: const Size(1200, 3000),
        );
        await tester.tap(find.text('Requests (1)'));
        await tester.pump();

        expect(find.text('Daniel Kim'), findsOneWidget);
        expect(find.text('SAMPLE'), findsWidgets);
        expect(find.text('Gym Member'), findsNothing);

        await tester.tap(find.text('Accept'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 300)),
        );
        await tester.pump();
        // The accepted request is now a friend, with the same identity.
        expect(FitnessProvider.instance.friendRequests, isEmpty);
        final friends = FitnessProvider.instance.friends;
        expect(friends.map((f) => f.userId), contains('usr_daniel'));
        expect(
          friends.firstWhere((f) => f.userId == 'usr_daniel').displayName,
          SampleWorld.byId('usr_daniel')!.name,
        );
      },
    );

    testWidgets('opening a friend shows the same identity as the profile', (
      tester,
    ) async {
      await FitnessProvider.instance.loadFriends();
      await _pump(tester, const FriendsScreen(), size: const Size(1200, 3000));
      await tester.tap(find.text('Friends').first);
      await tester.pump();
      await tester.tap(find.text('Maya Chen').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final screen = tester.widget<AthleteProfileScreen>(
        find.byType(AthleteProfileScreen),
      );
      expect(screen.userId, 'usr_maya');
      expect(screen.name, SampleWorld.byId('usr_maya')!.name);
      expect(find.byKey(const Key('sample_profile_badge')), findsOneWidget);
    });
  });
}
