import 'package:atlas/app_theme.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/atlas_challenge.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/providers/showcase_mode_provider.dart';
import 'package:atlas/screens/challenge_detail_screen.dart';
import 'package:atlas/screens/community_screen.dart';
import 'package:atlas/screens/friends_screen.dart';
import 'package:atlas/screens/new_challenge_screen.dart';
import 'package:atlas/services/challenges/atlas_challenge_service.dart';
import 'package:atlas/services/challenges/challenge_progress.dart';
import 'package:atlas/services/community/sample_world.dart';
import 'package:atlas/services/gamification/bonus_xp.dart';
import 'package:atlas/services/moderation_service.dart';
import 'package:atlas/services/reward_queue_service.dart';
import 'package:atlas/services/saved_content_service.dart';
import 'package:atlas/services/social_graph_service.dart';
import 'package:atlas/services/social_service.dart';
import 'package:atlas/services/steps/step_models.dart';
import 'package:atlas/widgets/community/challenges_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime(2026, 11, 18, 12); // a Wednesday

WorkoutHistory _w(DateTime at, {int seconds = 3000}) => WorkoutHistory(
  workoutName: 'Session',
  dateCompleted: at,
  durationSeconds: seconds,
  exercisesCompleted: 3,
  completionPercentage: 100,
  totalVolume: 1000,
  totalSets: 9,
  totalReps: 90,
);

ChallengeInputs _inputs({
  List<WorkoutHistory> history = const [],
  List<DayStepTotal> steps = const [],
}) => ChallengeInputs(history: history, stepDays: steps, now: _now);

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

Widget _tab({ChallengeInputs? inputs, bool steps = true}) => Scaffold(
  body: ChallengesTab(
    inputsOverride: inputs ?? _inputs(),
    stepsAvailableOverride: steps,
  ),
);

Future<AtlasChallenge> _make({
  String? opponent,
  ChallengeMetric metric = ChallengeMetric.workouts,
  double target = 4,
  int xp = 0,
  String title = 'Four workouts',
}) => AtlasChallengeService.instance.create(
  title: title,
  metric: metric,
  target: target,
  durationDays: 7,
  opponentKey: opponent,
  xpReward: xp,
  now: DateTime(2026, 11, 16, 8),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    AppDependencies.reset();
    FitnessProvider.resetInstance();
    AtlasChallengeService.resetInstance();
    RewardQueueService.resetInstance();
    SocialGraphService.resetInstance();
    SavedContentService.resetInstance();
    ModerationService.resetInstance();
    SocialService.resetInstance();
    BonusXp.awarder = BonusXp.saveOnly;
    await ShowcaseModeProvider.instance.disableShowcaseMode();
  });

  tearDown(() {
    BonusXp.awarder = BonusXp.saveOnly;
  });

  group('Challenges tab', () {
    testWidgets('shows labelled sample invitations that can be answered', (
      tester,
    ) async {
      await _pump(tester, _tab());
      expect(find.byKey(const Key('invitations_heading')), findsOneWidget);
      expect(
        find.byKey(const Key('invite_ch_invite_zothanpuii')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('invite_ch_invite_marcus')), findsOneWidget);
      expect(find.text('SAMPLE'), findsWidgets);
      expect(find.byKey(const Key('no_active_challenges')), findsOneWidget);

      await tester.tap(find.byKey(const Key('invite_accept_ch_invite_marcus')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const Key('challenge_ch_invite_marcus')),
        findsOneWidget,
      );
      expect(find.text('ACTIVE'), findsWidgets);

      await tester.tap(
        find.byKey(const Key('invite_decline_ch_invite_zothanpuii')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const Key('invite_ch_invite_zothanpuii')),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('challenges_past_tab')));
      await tester.pump();
      expect(find.text('DECLINED'), findsOneWidget);
      expect(
        find.byKey(const Key('challenge_ch_invite_zothanpuii')),
        findsOneWidget,
      );
    });

    testWidgets('active and past are separate lists', (tester) async {
      await AtlasChallengeService.instance.seedSampleInvitationsOnce(now: _now);
      final running = await _make(title: 'Running one');
      final done = await _make(title: 'Done one', target: 1);
      await _pump(
        tester,
        _tab(inputs: _inputs(history: [_w(DateTime(2026, 11, 17, 8))])),
      );
      // "Done one" completed from a real logged workout, so it is in Past.
      expect(find.byKey(Key('challenge_${running.id}')), findsOneWidget);
      expect(find.byKey(Key('challenge_${done.id}')), findsNothing);
      await tester.tap(find.byKey(const Key('challenges_past_tab')));
      await tester.pump();
      expect(find.byKey(Key('challenge_${done.id}')), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);
      expect(find.byKey(Key('challenge_${running.id}')), findsNothing);
    });

    testWidgets('your progress shows the logged workouts, nothing scripted', (
      tester,
    ) async {
      final c = await _make(target: 4);
      await _pump(
        tester,
        _tab(
          inputs: _inputs(
            history: [
              _w(DateTime(2026, 11, 16, 9)),
              _w(DateTime(2026, 11, 17, 9)),
            ],
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.byKey(Key('progress_you_${c.id}'))).data,
        '2 / 4 workouts',
      );
      expect(find.byKey(Key('progress_opp_${c.id}')), findsNothing);
    });

    testWidgets('no invented participant counts anywhere', (tester) async {
      await _make(opponent: 'maya');
      await _pump(tester, _tab());
      expect(find.textContaining('athletes'), findsNothing);
      expect(find.textContaining('participants'), findsNothing);
      expect(find.textContaining('312'), findsNothing);
      expect(find.byKey(const Key('challenges_footer')), findsOneWidget);
    });

    testWidgets(
      'a sample opponent is labelled and scripted, never mixed into your progress',
      (tester) async {
        final c = await _make(opponent: 'daniel', target: 20);
        await _pump(tester, _tab());
        final daniel = SampleWorld.byKey('daniel')!;
        final expected = ChallengeProgressCalculator.scriptedOpponent(
          c,
          daniel,
          _now,
        );
        expect(
          tester.widget<Text>(find.byKey(Key('progress_opp_${c.id}'))).data,
          '${expected.round()} / 20 workouts',
        );
        expect(
          tester.widget<Text>(find.byKey(Key('progress_you_${c.id}'))).data,
          '0 / 20 workouts',
        );
        expect(find.text('Against Daniel Kim'), findsOneWidget);
        expect(find.text('SAMPLE'), findsWidgets);
      },
    );

    testWidgets('step challenges are unavailable without step readings', (
      tester,
    ) async {
      final c = await _make(
        metric: ChallengeMetric.stepDays,
        target: 7,
        title: '7 step days',
      );
      await _pump(tester, _tab());
      expect(
        tester.widget<Text>(find.byKey(Key('progress_you_${c.id}'))).data,
        'Unavailable',
      );
      expect(find.byKey(Key('progress_unavailable_${c.id}')), findsOneWidget);
    });

    testWidgets('step challenges count real readings when they exist', (
      tester,
    ) async {
      final c = await _make(
        metric: ChallengeMetric.stepDays,
        target: 7,
        title: '7 step days',
      );
      await _pump(
        tester,
        _tab(
          inputs: _inputs(
            steps: [
              DayStepTotal(
                dayKey: stepDayKey(DateTime(2026, 11, 16)),
                steps: 12000,
              ),
              DayStepTotal(
                dayKey: stepDayKey(DateTime(2026, 11, 17)),
                steps: 4000,
              ),
            ],
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.byKey(Key('progress_you_${c.id}'))).data,
        '1 / 7 days',
      );
    });

    testWidgets('completing pays XP once and moves the challenge to Past', (
      tester,
    ) async {
      final paid = <int>[];
      BonusXp.awarder = (a) async => paid.add(a);
      final made = await _make(target: 1, xp: 150);
      await _pump(
        tester,
        _tab(inputs: _inputs(history: [_w(DateTime(2026, 11, 17, 8))])),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(paid, [150]);
      expect(AtlasChallengeService.instance.byId(made.id)!.rewardPaid, isTrue);
    });
  });

  group('New challenge', () {
    Future<void> openNew(
      WidgetTester tester, {
      bool steps = true,
      String? opponent,
    }) async {
      await _pump(
        tester,
        NewChallengeScreen(
          initialOpponentKey: opponent,
          stepsAvailableOverride: steps,
        ),
      );
    }

    testWidgets('a preset starts an active self-challenge', (tester) async {
      await openNew(tester);
      await tester.tap(find.byKey(const Key('preset_m150')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('create_challenge')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final list = AtlasChallengeService.instance.active();
      expect(list.single.title, '150 workout minutes');
      expect(list.single.isSample, isFalse);
      expect(list.single.startDate, isNotNull);
    });

    testWidgets('step presets are unavailable without step readings', (
      tester,
    ) async {
      await openNew(tester, steps: false);
      expect(find.byKey(const Key('preset_steps_unavailable')), findsOneWidget);
      await tester.tap(find.byKey(const Key('preset_s7')), warnIfMissed: false);
      await tester.pump();
      await tester.tap(find.byKey(const Key('create_challenge')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // The unavailable preset was not selectable, so a measurable one started.
      expect(
        AtlasChallengeService.instance.active().single.metric.needsSteps,
        isFalse,
      );
    });

    testWidgets('step presets work when readings exist', (tester) async {
      await openNew(tester, steps: true);
      expect(find.byKey(const Key('preset_steps_unavailable')), findsNothing);
      await tester.tap(find.byKey(const Key('preset_s7')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('create_challenge')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        AtlasChallengeService.instance.active().single.metric,
        ChallengeMetric.stepDays,
      );
    });

    testWidgets('a custom challenge is validated and created', (tester) async {
      await openNew(tester);
      await tester.tap(find.byKey(const Key('preset_custom')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('custom_target')), '0');
      await tester.tap(find.byKey(const Key('create_challenge')));
      await tester.pump();
      expect(find.byKey(const Key('custom_error')), findsOneWidget);
      expect(AtlasChallengeService.instance.all(), isEmpty);

      await tester.enterText(find.byKey(const Key('custom_target')), '6');
      await tester.tap(find.byKey(const Key('custom_days_14')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('create_challenge')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final c = AtlasChallengeService.instance.active().single;
      expect(c.target, 6);
      expect(c.durationDays, 14);
      expect(c.xpReward, 0);
    });

    testWidgets(
      'challenging a sample athlete is labelled and says real members are not available',
      (tester) async {
        await openNew(tester, opponent: 'maya');
        expect(find.byKey(const Key('real_challenges_note')), findsOneWidget);
        expect(find.text('CHALLENGE MAYA'), findsOneWidget);
        await tester.tap(find.byKey(const Key('create_challenge')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final c = AtlasChallengeService.instance.active().single;
        expect(c.opponentKey, 'maya');
        expect(c.isSample, isTrue);
      },
    );

    testWidgets('there is no way to pick a real member', (tester) async {
      await openNew(tester);
      for (final a in SampleWorld.athletes) {
        expect(find.byKey(Key('opponent_${a.key}')), findsOneWidget);
      }
      expect(find.byKey(const Key('opponent_self')), findsOneWidget);
      expect(find.textContaining('(sample)'), findsNWidgets(11));
    });
  });

  group('Challenge details', () {
    testWidgets('shows objective, dates, status, progress and the self note', (
      tester,
    ) async {
      final c = await _make(target: 4);
      await _pump(
        tester,
        ChallengeDetailScreen(
          challengeId: c.id,
          inputsOverride: _inputs(history: [_w(DateTime(2026, 11, 16, 9))]),
        ),
      );
      expect(find.byKey(const Key('detail_title')), findsOneWidget);
      expect(find.text('4 workouts'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('detail_dates'))).data,
        'Dates: 16 Nov to 22 Nov',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('detail_time_left'))).data,
        '5 days left',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('detail_you_value'))).data,
        '1 / 4 workouts',
      );
      expect(find.byKey(const Key('self_note')), findsOneWidget);
      expect(find.byKey(const Key('sample_note')), findsNothing);
    });

    testWidgets(
      'a sample duel shows who is ahead and labels the scripted side',
      (tester) async {
        final c = await _make(opponent: 'jenny', target: 30);
        await _pump(
          tester,
          ChallengeDetailScreen(
            challengeId: c.id,
            inputsOverride: _inputs(
              history: [
                _w(DateTime(2026, 11, 16, 9)),
                _w(DateTime(2026, 11, 17, 9)),
                _w(DateTime(2026, 11, 17, 18)),
              ],
            ),
          ),
        );
        expect(find.byKey(const Key('sample_note')), findsOneWidget);
        expect(find.byKey(const Key('detail_opp_value')), findsOneWidget);
        expect(find.byKey(const Key('lead_line')), findsOneWidget);
        expect(find.text('SAMPLE'), findsWidgets);
      },
    );

    testWidgets('unavailable steps are explained, not shown as zero', (
      tester,
    ) async {
      final c = await _make(metric: ChallengeMetric.stepDays, target: 7);
      await _pump(
        tester,
        ChallengeDetailScreen(challengeId: c.id, inputsOverride: _inputs()),
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('detail_you_value'))).data,
        'Unavailable',
      );
      expect(find.byKey(const Key('detail_unavailable')), findsOneWidget);
    });

    testWidgets('an invitation can be accepted from its page', (tester) async {
      await AtlasChallengeService.instance.seedSampleInvitationsOnce(now: _now);
      await _pump(
        tester,
        ChallengeDetailScreen(
          challengeId: 'ch_invite_marcus',
          inputsOverride: _inputs(),
        ),
      );
      expect(find.text('INVITED'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('detail_dates'))).data,
        'Dates: set when you accept',
      );
      await tester.tap(find.byKey(const Key('detail_accept')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('ACTIVE'), findsOneWidget);
      expect(find.byKey(const Key('detail_accept')), findsNothing);
    });

    testWidgets('an invitation can be declined from its page', (tester) async {
      await AtlasChallengeService.instance.seedSampleInvitationsOnce(now: _now);
      await _pump(
        tester,
        ChallengeDetailScreen(
          challengeId: 'ch_invite_zothanpuii',
          inputsOverride: _inputs(),
        ),
      );
      await tester.tap(find.byKey(const Key('detail_decline')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('DECLINED'), findsOneWidget);
    });

    testWidgets('an expired challenge says why', (tester) async {
      final c = await AtlasChallengeService.instance.create(
        title: 'Old',
        metric: ChallengeMetric.workouts,
        target: 5,
        durationDays: 7,
        now: DateTime(2026, 11, 1),
      );
      await _pump(
        tester,
        ChallengeDetailScreen(challengeId: c.id, inputsOverride: _inputs()),
      );
      expect(find.text('EXPIRED'), findsOneWidget);
      expect(find.byKey(const Key('detail_end_note')), findsOneWidget);
    });

    testWidgets('removing a challenge deletes it', (tester) async {
      final c = await _make();
      await _pump(
        tester,
        ChallengeDetailScreen(challengeId: c.id, inputsOverride: _inputs()),
      );
      await tester.tap(find.byKey(const Key('remove_challenge')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(AtlasChallengeService.instance.all(), isEmpty);
    });
  });

  group('Where challenges appear', () {
    testWidgets('the Community Challenges tab is the new tab', (tester) async {
      await _pump(tester, const CommunityScreen());
      await tester.tap(find.text('Challenges'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('new_challenge_button')), findsOneWidget);
      expect(find.textContaining('athletes'), findsNothing);
    });

    testWidgets('the Friends screen has no invented challenge, only your own', (
      tester,
    ) async {
      await _pump(tester, const FriendsScreen(), size: const Size(1200, 3000));
      expect(find.byKey(const Key('challenges_summary')), findsOneWidget);
      expect(find.byKey(const Key('challenges_summary_empty')), findsOneWidget);
      expect(find.textContaining('Leg Volume Showdown'), findsNothing);
      expect(find.textContaining('11,200'), findsNothing);
    });

    for (final size in const [Size(320, 568), Size(360, 640), Size(412, 915)]) {
      testWidgets('challenge cards fit ${size.width.toInt()}px', (
        tester,
      ) async {
        await AtlasChallengeService.instance.seedSampleInvitationsOnce(
          now: _now,
        );
        await _make(
          opponent: 'zothanpuii',
          title: 'A fairly long challenge title for a narrow phone',
        );
        await _make(
          metric: ChallengeMetric.stepDays,
          target: 7,
          title: '10,000 steps a day for 7 days',
        );
        await _pump(tester, _tab(), size: Size(size.width, 3000));
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('challenges_past_tab')));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets(
        'the Friends challenge summary fits ${size.width.toInt()}px',
        (tester) async {
          await _make(
            opponent: 'maya',
            title: 'A fairly long challenge title for a narrow phone',
          );
          await _pump(tester, const FriendsScreen(), size: size);
          expect(tester.takeException(), isNull);
        },
      );

      testWidgets('the new challenge page fits ${size.width.toInt()}px', (
        tester,
      ) async {
        await _pump(
          tester,
          const NewChallengeScreen(stepsAvailableOverride: true),
          size: Size(size.width, 3000),
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('preset_custom')));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
