import 'package:atlas/app_theme.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/activity_post.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/screens/athlete_profile_screen.dart';
import 'package:atlas/screens/community_screen.dart';
import 'package:atlas/screens/edit_profile_screen.dart';
import 'package:atlas/screens/friends_screen.dart';
import 'package:atlas/screens/post_detail_screen.dart';
import 'package:atlas/services/community/sample_community.dart';
import 'package:atlas/services/challenges/atlas_challenge_service.dart';
import 'package:atlas/screens/new_challenge_screen.dart';
import 'package:atlas/services/moderation_service.dart';
import 'package:atlas/services/saved_content_service.dart';
import 'package:atlas/services/social_graph_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ActivityPost _realPost({
  String id = 'local_post_1',
  String userId = 'usr_local',
}) => ActivityPost(
  id: id,
  userId: userId,
  userName: 'Me',
  type: ActivityPostType.workout,
  title: 'My real leg day',
  description: 'Logged by the user.',
  createdAt: DateTime.now().subtract(const Duration(hours: 2)),
);

Future<void> _pump(WidgetTester tester, Widget home, {Size? size}) async {
  // A tall default view so lazily built list items are all on screen.
  tester.view.physicalSize = size ?? const Size(412, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme, home: home));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _profile(
  WidgetTester tester, {
  String id = 'usr_alex',
  String name = 'Alex Carter',
  Size? size,
}) => _pump(
  tester,
  AthleteProfileScreen(userId: id, name: name, rank: 'Diamond II'),
  size: size,
);

const _sizes = [
  Size(320, 568),
  Size(360, 640),
  Size(412, 915),
  Size(800, 1280),
];

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
    AtlasChallengeService.resetInstance();
  });

  group('Athlete profile', () {
    Future<void> openTab(WidgetTester tester, String tab) async {
      await tester.tap(find.byKey(Key('profile_tab_$tab')));
      await tester.pump();
    }

    testWidgets('a sample athlete shows the header, counts, tabs and labels', (
      tester,
    ) async {
      await _profile(tester);
      expect(find.text('Alex Carter'), findsOneWidget);
      expect(find.text('alex.carter'), findsOneWidget); // app bar username
      expect(find.byKey(const Key('sample_profile_badge')), findsOneWidget);
      expect(find.byKey(const Key('sample_profile_note')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('profile_posts_count'))).data,
        '7',
      );
      expect(find.text('PRS'), findsWidgets);
      expect(find.text('WORKOUTS'), findsOneWidget);
      for (final tab in ['posts', 'prs', 'about']) {
        expect(find.byKey(Key('profile_tab_$tab')), findsOneWidget);
      }
      expect(find.text('FOLLOW'), findsOneWidget);
      expect(find.text('CHALLENGE'), findsOneWidget);
      expect(find.byKey(const Key('profile_post_sp_alex_1')), findsOneWidget);
    });

    testWidgets('no followers, following, XP, division or country anywhere', (
      tester,
    ) async {
      await _profile(tester);
      for (final tab in ['posts', 'prs', 'about']) {
        await openTab(tester, tab);
        for (final text in [
          'FOLLOWERS',
          'FOLLOWING',
          ' XP',
          'Division',
          'Country',
        ]) {
          expect(find.textContaining(text), findsNothing, reason: '$tab $text');
        }
      }
    });

    testWidgets('PRs tab lists the athlete own records', (tester) async {
      await _profile(tester);
      await openTab(tester, 'prs');
      expect(find.text('Barbell Deadlift'), findsOneWidget);
      expect(find.text('140 kg x 3'), findsOneWidget);
    });

    testWidgets('About tab shows goal, style, schedule and milestones', (
      tester,
    ) async {
      await _profile(tester);
      await openTab(tester, 'about');
      for (final t in [
        'Goal',
        'Level',
        'Training style',
        'Schedule',
        'MILESTONES',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.text('100 workouts logged'), findsOneWidget);
    });

    testWidgets('highlights land on the right tab or filtered grid', (
      tester,
    ) async {
      await _profile(tester);
      final all = SampleCommunity.postsBy('usr_alex');

      await tester.tap(find.byKey(const Key('hl_meals')));
      await tester.pump();
      expect(find.byKey(const Key('profile_filter_chip')), findsOneWidget);
      for (final p in all) {
        expect(
          find.byKey(Key('profile_post_${p.id}')),
          p.type == ActivityPostType.meal ? findsOneWidget : findsNothing,
          reason: p.id,
        );
      }

      await tester.tap(find.byKey(const Key('hl_routines')));
      await tester.pump();
      for (final p in all) {
        expect(
          find.byKey(Key('profile_post_${p.id}')),
          p.type == ActivityPostType.routine ? findsOneWidget : findsNothing,
          reason: p.id,
        );
      }

      // Clearing the chip shows everything again.
      tester
          .widget<InputChip>(find.byKey(const Key('profile_filter_chip')))
          .onDeleted!();
      await tester.pump();
      expect(find.byKey(const Key('profile_filter_chip')), findsNothing);
      expect(find.byKey(const Key('profile_post_sp_alex_1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('hl_prs')));
      await tester.pump();
      expect(find.text('140 kg x 3'), findsOneWidget);

      await tester.tap(find.byKey(const Key('hl_milestones')));
      await tester.pump();
      expect(find.text('MILESTONES'), findsOneWidget);
    });

    testWidgets('a real member has no highlights, PRs tab or Challenge', (
      tester,
    ) async {
      await _profile(tester, id: 'usr_real_stranger', name: 'Real Member');
      expect(find.text('Real Member'), findsOneWidget);
      expect(find.byKey(const Key('sample_profile_badge')), findsNothing);
      expect(find.text('FOLLOW'), findsOneWidget);
      expect(find.text('CHALLENGE'), findsNothing);
      expect(find.byKey(const Key('profile_tab_prs')), findsNothing);
      expect(find.byKey(const Key('hl_prs')), findsNothing);
      expect(find.byKey(const Key('profile_no_posts')), findsOneWidget);
      await openTab(tester, 'about');
      expect(find.byKey(const Key('profile_not_shared')), findsOneWidget);
    });

    testWidgets('your own profile shows dashes when nothing is recorded', (
      tester,
    ) async {
      await LocalStorage.saveUserProfile(
        UserProfile.defaultProfile().copyWith(
          name: 'Zorinpuia',
          fitnessGoal: 'Strength',
          workoutExperience: '',
        ),
      );
      await LocalStorage.saveCommunityPosts([_realPost()]);
      await _profile(tester, id: 'usr_local', name: 'Me');

      expect(find.text('Zorinpuia'), findsOneWidget);
      expect(find.text('EDIT PROFILE'), findsOneWidget);
      expect(find.text('FOLLOW'), findsNothing);
      expect(find.text('CHALLENGE'), findsNothing);
      expect(find.byKey(const Key('sample_profile_badge')), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('profile_workouts_count')))
            .data,
        '--',
      );
      expect(
        tester.widget<Text>(find.byKey(const Key('profile_streak_count'))).data,
        '--',
      );
      expect(find.byKey(const Key('hl_prs')), findsNothing);
      expect(find.byKey(const Key('hl_streak')), findsNothing);
      expect(
        find.byKey(const Key('profile_post_local_post_1')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('profile_post_sp_alex_1')), findsNothing);

      await openTab(tester, 'prs');
      expect(find.byKey(const Key('profile_no_prs')), findsOneWidget);

      await openTab(tester, 'about');
      expect(find.text('Strength'), findsOneWidget);
      expect(find.text('Level'), findsNothing);
      expect(find.byKey(const Key('profile_add_bio')), findsOneWidget);
      expect(find.byKey(const Key('profile_visibility_note')), findsOneWidget);
      // No privacy switches that only look functional.
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('your own profile uses your real workout history', (
      tester,
    ) async {
      await LocalStorage.saveWorkoutHistory([
        WorkoutHistory(
          workoutName: 'Push Day',
          dateCompleted: DateTime.now().subtract(const Duration(hours: 2)),
          durationSeconds: 3000,
          exercisesCompleted: 4,
          completionPercentage: 100,
          totalVolume: 5000,
          totalSets: 12,
          totalReps: 100,
          personalRecords: const ['Bench Press: 80 kg'],
        ),
      ]);
      FitnessProvider.instance.refreshWorkoutHistory();
      await _profile(tester, id: 'usr_local', name: 'Me');

      expect(
        tester
            .widget<Text>(find.byKey(const Key('profile_workouts_count')))
            .data,
        '1',
      );
      expect(find.byKey(const Key('hl_prs')), findsOneWidget);
      await openTab(tester, 'prs');
      expect(find.text('Bench Press: 80 kg'), findsOneWidget);
    });

    testWidgets('Edit profile opens the editor and reloads on return', (
      tester,
    ) async {
      await LocalStorage.saveUserProfile(
        UserProfile.defaultProfile().copyWith(name: 'Zorinpuia'),
      );
      // Wide view: the editor's unit-chip rows overflow under the test font
      // on narrow screens, which is unrelated to this screen.
      await _profile(
        tester,
        id: 'usr_local',
        name: 'Me',
        size: const Size(1200, 3000),
      );
      await tester.tap(find.text('EDIT PROFILE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(EditProfileScreen), findsOneWidget);

      Navigator.of(tester.element(find.byType(EditProfileScreen))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AthleteProfileScreen), findsOneWidget);
      expect(find.text('Zorinpuia'), findsOneWidget);
    });

    testWidgets('a name saved in the editor shows on your profile', (
      tester,
    ) async {
      await LocalStorage.saveUserProfile(
        UserProfile.defaultProfile().copyWith(
          name: 'Zorinpuia',
          email: 'zorin@example.com',
          phone: '9876543210',
          height: '170',
          weight: '70',
        ),
      );
      await _profile(
        tester,
        id: 'usr_local',
        name: 'Me',
        size: const Size(1200, 3000),
      );
      await tester.tap(find.text('EDIT PROFILE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Zorinpuia'),
        'Zorin Edited',
      );
      final save = find.text('Save Changes');
      await tester.ensureVisible(save);
      await tester.pump();
      await tester.tap(save);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 800));

      expect(LocalStorage.getUserProfile().name, 'Zorin Edited');
      expect(find.byType(EditProfileScreen), findsNothing);
      expect(find.text('Zorin Edited'), findsOneWidget);
    });

    testWidgets('Follow toggles and Challenge opens the challenge builder', (
      tester,
    ) async {
      await _profile(tester);
      await tester.tap(find.text('FOLLOW'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('FOLLOWING'), findsOneWidget);
      expect(SocialGraphService.instance.isFollowing('usr_alex'), isTrue);

      await tester.tap(find.text('CHALLENGE'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(NewChallengeScreen), findsOneWidget);
      expect(
        tester
            .widget<NewChallengeScreen>(find.byType(NewChallengeScreen))
            .initialOpponentKey,
        'alex',
      );
    });

    testWidgets('tapping a post in the grid opens the post page', (
      tester,
    ) async {
      await _profile(tester);
      await tester.tap(find.byKey(const Key('profile_post_sp_alex_1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PostDetailScreen), findsOneWidget);
    });

    for (final size in _sizes) {
      testWidgets('profile fits a ${size.width.toInt()}px wide screen', (
        tester,
      ) async {
        await _profile(tester, size: size);
        expect(tester.takeException(), isNull);
        expect(find.text('Alex Carter'), findsOneWidget);
        await openTab(tester, 'about');
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Post page', () {
    ActivityPost sample() =>
        SampleCommunity.posts().firstWhere((p) => p.id == 'sp_alex_1');

    testWidgets('shows media, caption, likes, comments and a comment box', (
      tester,
    ) async {
      await _pump(tester, PostDetailScreen(post: sample()));
      expect(find.byKey(const Key('post_detail_sample_badge')), findsOneWidget);
      expect(find.byKey(const Key('post_detail_media')), findsOneWidget);
      expect(find.textContaining('Two years ago I pulled 100'), findsOneWidget);
      expect(find.byKey(const Key('post_detail_like')), findsOneWidget);
      expect(find.text('COMMENTS (4)'), findsOneWidget);
      expect(
        find.byKey(const Key('post_detail_comment_field')),
        findsOneWidget,
      );
    });

    testWidgets('liking a sample post is kept apart from real records', (
      tester,
    ) async {
      final before = sample().likes;
      await _pump(tester, PostDetailScreen(post: sample()));
      await tester.tap(find.byKey(const Key('post_detail_like')));
      await tester.pump();
      expect(find.text('${before + 1}'), findsOneWidget);
      expect(LocalStorage.getSampleLikedPostIds(), contains('sp_alex_1'));
      expect(LocalStorage.getCommunityPosts(), isEmpty);
    });

    testWidgets('a comment on a sample post never becomes a real post', (
      tester,
    ) async {
      await _pump(tester, PostDetailScreen(post: sample()));
      await tester.enterText(
        find.byKey(const Key('post_detail_comment_field')),
        'Great lift!',
      );
      await tester.tap(find.byKey(const Key('post_detail_send')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('COMMENTS (5)'), findsOneWidget);
      expect(
        LocalStorage.getCommentsForPost('sp_alex_1').map((c) => c.text),
        contains('Great lift!'),
      );
      expect(LocalStorage.getCommunityPosts(), isEmpty);
    });

    testWidgets('a real post has no SAMPLE label and saves its like', (
      tester,
    ) async {
      await LocalStorage.saveCommunityPosts([_realPost()]);
      await _pump(tester, PostDetailScreen(post: _realPost()));
      expect(find.byKey(const Key('post_detail_sample_badge')), findsNothing);
      expect(find.byKey(const Key('post_detail_no_comments')), findsOneWidget);

      await tester.tap(find.byKey(const Key('post_detail_like')));
      await tester.pump();
      expect(LocalStorage.getCommunityPosts().single.likes, 1);
      expect(LocalStorage.getCommunityPosts().single.isLiked, isTrue);
      expect(LocalStorage.getSampleLikedPostIds(), isEmpty);
    });

    testWidgets('an empty comment is ignored', (tester) async {
      await _pump(tester, PostDetailScreen(post: _realPost()));
      await tester.enterText(
        find.byKey(const Key('post_detail_comment_field')),
        '   ',
      );
      await tester.tap(find.byKey(const Key('post_detail_send')));
      await tester.pump();
      expect(find.byKey(const Key('post_detail_no_comments')), findsOneWidget);
    });

    testWidgets('tapping the author opens their profile', (tester) async {
      await _pump(tester, PostDetailScreen(post: sample()));
      await tester.tap(find.byKey(const Key('post_detail_author')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AthleteProfileScreen), findsOneWidget);
    });

    testWidgets('a post without media still renders', (tester) async {
      await _pump(
        tester,
        PostDetailScreen(post: _realPost().copyWith(images: const [])),
      );
      expect(find.byKey(const Key('post_detail_media')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    for (final size in _sizes) {
      testWidgets('post page fits a ${size.width.toInt()}px wide screen', (
        tester,
      ) async {
        await _pump(tester, PostDetailScreen(post: sample()), size: size);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Opening profiles from every entry point', () {
    testWidgets('a feed author opens that athlete', (tester) async {
      await _pump(tester, const CommunityScreen());
      final post = SampleCommunity.posts().first;
      await tester.ensureVisible(find.byKey(Key('post_avatar_${post.id}')));
      await tester.pump();
      await tester.tap(find.byKey(Key('post_avatar_${post.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final screen = tester.widget<AthleteProfileScreen>(
        find.byType(AthleteProfileScreen),
      );
      expect(screen.userId, post.userId);
      expect(find.text(post.userName), findsWidgets);
    });

    testWidgets('a commenter on the post page opens that athlete', (
      tester,
    ) async {
      final post = SampleCommunity.posts().firstWhere(
        (p) => p.id == 'sp_alex_1',
      );
      await _pump(tester, PostDetailScreen(post: post));
      final commenter = post.commentsList.firstWhere(
        (c) => c.userId != post.userId,
      );
      final avatar = find.byKey(Key('comment_avatar_${commenter.id}'));
      await tester.ensureVisible(avatar);
      await tester.pump();
      await tester.tap(avatar);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final screen = tester.widget<AthleteProfileScreen>(
        find.byType(AthleteProfileScreen),
      );
      expect(screen.userId, commenter.userId);
    });

    testWidgets(
      'every commenter in the sample feed opens a profile with posts',
      (tester) async {
        for (final post in SampleCommunity.posts()) {
          for (final c in post.commentsList) {
            final profile = SampleCommunity.profileFor(c.userId);
            expect(profile, isNotNull, reason: '${post.id} ${c.userName}');
            expect(
              SampleCommunity.postsBy(c.userId),
              isNotEmpty,
              reason: '${post.id} ${c.userName}',
            );
          }
        }
      },
    );

    testWidgets('a friend opens the athlete profile', (tester) async {
      await FitnessProvider.instance.loadFriends();
      final friends = FitnessProvider.instance.friends;
      expect(friends, isNotEmpty);
      // Wide view: an existing friend-challenge card overflows under the
      // test font on narrow screens, which is unrelated to profiles.
      await _pump(tester, const FriendsScreen(), size: const Size(1200, 3000));
      await tester.tap(find.text('Friends').first);
      await tester.pump();
      await tester.tap(find.text(friends.first.displayName).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      final screen = tester.widget<AthleteProfileScreen>(
        find.byType(AthleteProfileScreen),
      );
      expect(screen.userId, friends.first.userId);
    });
  });

  group('Feed', () {
    testWidgets('tapping a post in the feed opens the post page', (
      tester,
    ) async {
      await _pump(tester, const CommunityScreen());
      final first = SampleCommunity.posts().first;
      final body = find.byKey(Key('post_body_${first.id}'));
      await tester.ensureVisible(body);
      await tester.pump();
      // Tap the caption area; tapping a video's picture plays the video.
      await tester.tapAt(tester.getTopLeft(body) + const Offset(24, 12));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(PostDetailScreen), findsOneWidget);
    });

    testWidgets('a like given on the post page is kept when returning', (
      tester,
    ) async {
      await _pump(tester, const CommunityScreen());
      final first = SampleCommunity.posts().first;
      final body = find.byKey(Key('post_body_${first.id}'));
      await tester.ensureVisible(body);
      await tester.pump();
      // Tap the caption area; tapping a video's picture plays the video.
      await tester.tapAt(tester.getTopLeft(body) + const Offset(24, 12));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byKey(const Key('post_detail_like')));
      await tester.pump();
      Navigator.of(tester.element(find.byType(PostDetailScreen))).pop();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byIcon(Icons.favorite_rounded), findsWidgets);
      expect(LocalStorage.getSampleLikedPostIds(), contains(first.id));
    });
  });
}
