import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../fixtures/legacy_community_feed.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/activity_post.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/providers/showcase_mode_provider.dart';
import 'package:atlas/screens/community_screen.dart';
import 'package:atlas/services/community/sample_community.dart';
import 'package:atlas/services/moderation_service.dart';
import 'package:atlas/services/saved_content_service.dart';
import 'package:atlas/services/social_graph_service.dart';
import 'package:atlas/widgets/community/community_avatar_helper.dart';
import 'package:atlas/widgets/community/create_post_modal.dart';
import 'package:atlas/widgets/community/post_card.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SocialGraphService.resetInstance();
    SavedContentService.resetInstance();
    ModerationService.resetInstance();
  });

  group('Community Hub Overhaul: Avatars & Realistic Profile Pictures', () {
    test('CommunityAvatarHelper returns distinct deterministic avatars', () {
      final alexAvatar = CommunityAvatarHelper.getAvatarForUser(
        userId: 'usr_alex',
        userName: 'Alex Carter',
      );
      final mayaAvatar = CommunityAvatarHelper.getAvatarForUser(
        userId: 'usr_maya',
        userName: 'Maya Chen',
      );
      final danielAvatar = CommunityAvatarHelper.getAvatarForUser(
        userId: 'usr_daniel',
        userName: 'Daniel Kim',
      );
      final sophiaAvatar = CommunityAvatarHelper.getAvatarForUser(
        userId: 'usr_sophia',
        userName: 'Sophia Martinez',
      );
      final liamAvatar = CommunityAvatarHelper.getAvatarForUser(
        userId: 'usr_liam',
        userName: 'Liam O\'Connor',
      );

      expect(alexAvatar, isNotEmpty);
      expect(mayaAvatar, isNotEmpty);
      expect(danielAvatar, isNotEmpty);
      expect(sophiaAvatar, isNotEmpty);
      expect(liamAvatar, isNotEmpty);

      // Verify they are different avatars
      expect(alexAvatar != mayaAvatar, isTrue);
      expect(mayaAvatar != danielAvatar, isTrue);
      expect(danielAvatar != sophiaAvatar, isTrue);
    });

    testWidgets('PostCard renders CommunityAvatar and author rank', (
      tester,
    ) async {
      final feed = legacyCommunityFeed();
      final post = feed.first;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: PostCard(post: post),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Alex Carter'), findsOneWidget);
      expect(find.text('Diamond II'), findsOneWidget);
      expect(find.text('New Deadlift PR Crushed! 🏆'), findsOneWidget);
      expect(
        find.text('New deadlift PR today. Finally broke through 140 kg.'),
        findsOneWidget,
      );
    });
  });

  group('Community Hub Overhaul: 5 Rich Social Media Posts in Feed', () {
    test('Default showcase feed contains all 5 required post types', () {
      final feed = legacyCommunityFeed();
      expect(feed.length, greaterThanOrEqualTo(5));

      // Post 1: Workout Photo / PR
      final prPost = feed.firstWhere((p) => p.id == 'post_pr_1');
      expect(prPost.userName, 'Alex Carter');
      expect(prPost.userRank, 'Diamond II');
      expect(prPost.prNewWeightKg, 140.0);
      expect(prPost.images.isNotEmpty, isTrue);

      // Post 2: Meal Prep Food Photo
      final mealPost = feed.firstWhere((p) => p.id == 'post_meal_1');
      expect(mealPost.userName, 'Maya Chen');
      expect(mealPost.userRank, 'Platinum I');
      expect(mealPost.mealCalories, 850);
      expect(mealPost.mealProteinGrams, 60);
      expect(mealPost.images.isNotEmpty, isTrue);

      // Post 3: Protein Shake
      final shakePost = feed.firstWhere((p) => p.id == 'post_shake_1');
      expect(shakePost.userName, 'Daniel Kim');
      expect(shakePost.description, contains('Post-workout shake'));
      expect(shakePost.mealIngredients, contains('Whey'));
      expect(shakePost.mealIngredients, contains('Peanut butter'));
      expect(shakePost.images.isNotEmpty, isTrue);

      // Post 4: Workout Video
      final videoPost = feed.firstWhere((p) => p.id == 'post_video_1');
      expect(videoPost.userName, 'Sophia Martinez');
      expect(videoPost.userRank, 'Iron Warrior ⚔️');
      expect(videoPost.metadata?['isVideo'], isTrue);
      expect(videoPost.metadata?['videoDuration'], '0:45');
      expect(videoPost.images.isNotEmpty, isTrue);

      // Post 5: Progress / Achievement
      final progressPost = feed.firstWhere((p) => p.id == 'post_progress_1');
      expect(progressPost.userName, 'Liam O\'Connor');
      expect(progressPost.metadata?['streak'], '8 week streak');
      expect(progressPost.metadata?['strengthGain'], '+15% Strength');
      expect(progressPost.images.isNotEmpty, isTrue);
    });

    testWidgets(
      'a post flagged as video without a playable file shows no play button',
      (tester) async {
        final feed = legacyCommunityFeed();
        final videoPost = feed.firstWhere((p) => p.id == 'post_video_1');

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: PostCard(post: videoPost),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        // No video file exists for this post, so no fake play button, pill or
        // invented duration is drawn.
        expect(find.text('WORKOUT VIDEO'), findsNothing);
        expect(find.text('0:45'), findsNothing);
        expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      },
    );
  });

  group('Community Hub Overhaul: Competitive Rankings Tab', () {
    testWidgets(
      'Showcase Mode opens Rankings on the labelled sample leaderboard',
      (tester) async {
        await ShowcaseModeProvider.instance.enableShowcaseMode();

        await tester.pumpWidget(
          MaterialApp(theme: ThemeData.dark(), home: const CommunityScreen()),
        );
        await tester.pump();

        final rankingsTab = find.text('Rankings');
        expect(rankingsTab, findsOneWidget);
        await tester.tap(rankingsTab);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // The old invented division header, XP and position are gone.
        expect(find.text('12,450 XP'), findsNothing);
        expect(find.text('YOUR POSITION'), findsNothing);
        expect(find.textContaining(' XP'), findsNothing);

        // Sample leaderboard, labelled, with the shared sample athletes.
        expect(find.byKey(const Key('sample_board_banner')), findsOneWidget);
        expect(find.byKey(const Key('podium_1')), findsOneWidget);
        expect(find.byKey(const Key('rankings_real_tab')), findsOneWidget);
      },
    );
  });

  group('Community Hub Overhaul: Create Post Experience', () {
    testWidgets('CreatePostModal allows post type selection and publishing', (
      tester,
    ) async {
      ActivityPost? createdPost;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    CreatePostModal.show(
                      context,
                      onPostCreated: (post) => createdPost = post,
                    );
                  },
                  child: const Text('Open Modal'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Open Modal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Create Post'), findsOneWidget);
      expect(find.text('+ Add Photo'), findsOneWidget);
      expect(find.text('🎥 Add Video'), findsOneWidget);
      expect(find.text('PUBLISH POST'), findsOneWidget);

      // Tap + Add Photo to attach sample media
      await tester.tap(find.text('+ Add Photo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Submit post
      await tester.ensureVisible(find.text('PUBLISH POST'));
      await tester.tap(find.text('PUBLISH POST'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(createdPost, isNotNull);
      // Posts are authored by whoever is signed in, never a fixed demo user.
      expect(
        createdPost!.userId,
        FitnessProvider.instance.currentUser?.id ?? 'usr_local',
      );
      expect(createdPost!.userName, isNot('Alex Lalremruata'));
    });
  });

  group('Community Hub Overhaul: Showcase Gating & Fresh User Isolation', () {
    testWidgets(
      'Fresh user with Showcase OFF sees the sample feed and only their own week in Rankings',
      (tester) async {
        await ShowcaseModeProvider.instance.disableShowcaseMode();
        LocalStorage.clearCommunityPosts();

        await tester.pumpWidget(
          MaterialApp(theme: ThemeData.dark(), home: const CommunityScreen()),
        );
        await tester.pump();

        // Feed tab: populated by the always-available, labelled sample
        // community instead of an empty state.
        expect(find.text('No posts yet'), findsNothing);
        expect(
          find.byKey(Key('sample_badge_${SampleCommunity.posts().first.id}')),
          findsOneWidget,
        );

        // Rankings opens on Real: only your own week, no invented board.
        await tester.tap(find.text('Rankings'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byKey(const Key('your_week_card')), findsOneWidget);
        expect(find.byKey(const Key('no_member_leaderboard')), findsOneWidget);
        expect(find.byKey(const Key('sample_board_banner')), findsNothing);
        expect(find.text("You're not ranked yet"), findsNothing);
      },
    );
  });
}
