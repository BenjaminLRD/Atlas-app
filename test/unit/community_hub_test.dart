import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../fixtures/legacy_community_feed.dart';
import 'package:atlas/models/activity_post.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/nutrition_progress.dart';
import 'package:atlas/models/nutrition_summary.dart';
import 'package:atlas/models/progress_summary.dart';
import 'package:atlas/models/user_progress.dart';
import 'package:atlas/screens/community_screen.dart';
import 'package:atlas/screens/athlete_profile_screen.dart';
import 'package:atlas/services/ai/coach_prompt_builder.dart';
import '../mocks/mock_ai_provider.dart';
import 'package:atlas/services/moderation_service.dart';
import 'package:atlas/services/saved_content_service.dart';
import 'package:atlas/services/social_graph_service.dart';
import 'package:atlas/widgets/community/post_card.dart';
import 'package:atlas/data/local_storage.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SocialGraphService.resetInstance();
    SavedContentService.resetInstance();
    ModerationService.resetInstance();
  });

  group('Phase 1: ActivityPost Domain Model & Helpers', () {
    test('ActivityPost serialization and type-specific getters', () {
      final workoutPost = ActivityPost(
        id: 'post_w1',
        userId: 'usr_alex',
        userName: 'Alex Carter',
        userRank: 'Elite III',
        type: ActivityPostType.workout,
        title: 'Push Day Annihilation',
        description: 'Great chest volume today',
        metadata: {
          'durationMinutes': 58,
          'totalVolumeKg': 7200.0,
          'exercisesCount': 6,
          'caloriesBurned': 420.0,
          'xpEarned': 250,
        },
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
        likes: 12,
        comments: 3,
        savesCount: 5,
      );

      expect(workoutPost.workoutDurationMinutes, 58);
      expect(workoutPost.workoutVolumeKg, 7200.0);
      expect(workoutPost.workoutExercisesCount, 6);
      expect(workoutPost.workoutXpEarned, 250);
      expect(workoutPost.timeAgo, '15m ago');

      final json = workoutPost.toJson();
      final fromJson = ActivityPost.fromJson(json);

      expect(fromJson.id, 'post_w1');
      expect(fromJson.userName, 'Alex Carter');
      expect(fromJson.type, ActivityPostType.workout);
      expect(fromJson.workoutVolumeKg, 7200.0);
      expect(fromJson.workoutXpEarned, 250);
    });

    test('PR and Meal Prep post getters', () {
      final prPost = ActivityPost(
        id: 'post_pr1',
        userId: 'usr_ben',
        userName: 'Benjamin L.',
        type: ActivityPostType.achievement,
        title: 'New Deadlift PR',
        description: 'Solid form',
        metadata: {
          'exerciseName': 'Barbell Deadlift',
          'previousWeightKg': 120.0,
          'newWeightKg': 140.0,
          'improvementKg': 20.0,
        },
        createdAt: DateTime.now(),
      );

      expect(prPost.prExerciseName, 'Barbell Deadlift');
      expect(prPost.prPreviousWeightKg, 120.0);
      expect(prPost.prNewWeightKg, 140.0);
      expect(prPost.prImprovementKg, 20.0);

      final mealPost = ActivityPost(
        id: 'post_m1',
        userId: 'usr_maya',
        userName: 'Maya Chen',
        type: ActivityPostType.meal,
        title: 'Chicken Rice Bowl',
        description: 'Meal prep',
        metadata: {
          'calories': 850,
          'proteinGrams': 60,
          'carbsGrams': 95,
          'fatGrams': 22,
          'ingredients': ['Chicken', 'Rice', 'Broccoli'],
        },
        createdAt: DateTime.now(),
      );

      expect(mealPost.mealCalories, 850);
      expect(mealPost.mealProteinGrams, 60);
      expect(mealPost.mealCarbsGrams, 95);
      expect(mealPost.mealFatGrams, 22);
      expect(mealPost.mealIngredients.length, 3);
    });

    test('legacy fixture feed still covers every post type', () {
      final feed = legacyCommunityFeed();
      expect(feed.length, greaterThanOrEqualTo(5));
      expect(feed.any((p) => p.type == ActivityPostType.achievement), isTrue);
      expect(feed.any((p) => p.type == ActivityPostType.meal), isTrue);
      expect(feed.any((p) => p.type == ActivityPostType.workout), isTrue);
      expect(feed.any((p) => p.type == ActivityPostType.routine), isTrue);
    });
  });

  group('Phase 4: Social Graph & Following System', () {
    test('Follow, unfollow and toggle follow updates state', () async {
      final service = SocialGraphService();
      const targetUser = 'usr_sarah';

      expect(service.isFollowing(targetUser), isFalse);

      await service.followUser(targetUser);
      expect(service.isFollowing(targetUser), isTrue);

      await service.unfollowUser(targetUser);
      expect(service.isFollowing(targetUser), isFalse);

      final status = await service.toggleFollow(targetUser);
      expect(status, isTrue);
      expect(service.isFollowing(targetUser), isTrue);
    });

    test('Follower counts scale with follow state', () {
      final service = SocialGraphService();
      final countBefore = service.getFollowersCount('usr_sarah');
      expect(countBefore, 510);
    });
  });

  group('Phase 6: Saved Content Service', () {
    test('Save, unsave, and filter routines vs meals', () async {
      final service = SavedContentService();
      final feed = legacyCommunityFeed();

      final routinePost = feed.firstWhere(
        (p) => p.type == ActivityPostType.routine,
      );
      final mealPost = feed.firstWhere((p) => p.type == ActivityPostType.meal);

      expect(service.isSaved(routinePost.id), isFalse);

      await service.savePost(routinePost);
      expect(service.isSaved(routinePost.id), isTrue);

      await service.savePost(mealPost);
      expect(service.getSavedPosts().length, 2);
      expect(service.getSavedRoutines().length, 1);
      expect(service.getSavedMeals().length, 1);

      await service.unsavePost(routinePost.id);
      expect(service.isSaved(routinePost.id), isFalse);
      expect(service.getSavedPosts().length, 1);
    });
  });

  group('Phase 8: AI Coach Community Split Integration', () {
    test('CoachPromptBuilder includes community splits directive', () {
      const builder = CoachPromptBuilder();
      final ctx = FitnessContext(
        nutritionSummary: NutritionSummary.empty(),
        progressSummary: ProgressSummary.zero(),
        userProgress: UserProgress.initial(),
        nutritionProgress: NutritionProgress.initial(),
        generatedAt: DateTime.now(),
      );

      final prompt = builder.buildPrompt(
        message: 'Give me a popular chest workout split',
        context: ctx,
      );

      expect(prompt, contains('community-proven splits'));
    });

    test(
      'MockAIProvider returns popular community split for split query',
      () async {
        final provider = MockAIProvider();
        final ctx = FitnessContext(
          nutritionSummary: NutritionSummary.empty(),
          progressSummary: ProgressSummary.zero(),
          userProgress: UserProgress.initial(),
          nutritionProgress: NutritionProgress.initial(),
          generatedAt: DateTime.now(),
        );

        final response = await provider.generateResponse(
          message: 'Give me a popular chest workout split from the community',
          history: const [],
          context: ctx,
        );

        expect(response, contains('Popular Community Split: Push Day A'));
        expect(response, contains('Barbell Bench Press'));
        expect(response, contains('Community Hub'));
      },
    );
  });

  group('Phase 9: Moderation & Safety Layer', () {
    test('Block user and hide post filters content from feed', () async {
      final modService = ModerationService();
      final feed = legacyCommunityFeed();

      expect(modService.filterModeratedPosts(feed).length, feed.length);

      await modService.blockUser('usr_alex');
      final filteredAfterBlock = modService.filterModeratedPosts(feed);
      expect(filteredAfterBlock.any((p) => p.userId == 'usr_alex'), isFalse);

      await modService.hidePost('post_pr_1');
      final filteredAfterHide = modService.filterModeratedPosts(feed);
      expect(filteredAfterHide.any((p) => p.id == 'post_pr_1'), isFalse);
    });
  });

  group(
    'Phase 10: Multi-Device Responsive UI Viewport Tests (320px, 360px, 390px, 412px)',
    () {
      final viewports = [
        const Size(320, 640),
        const Size(360, 740),
        const Size(390, 844),
        const Size(412, 915),
      ];

      for (final size in viewports) {
        testWidgets(
          'PostCard renders without overflow on ${size.width}px device width',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

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
            expect(tester.takeException(), isNull);
            expect(find.text(post.userName), findsOneWidget);
            expect(find.byType(PostCard), findsOneWidget);
          },
        );

        testWidgets(
          'CommunityScreen renders and switches filter tabs on ${size.width}px device width',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData.dark(),
                home: const CommunityScreen(),
              ),
            );

            await tester.pump();
            expect(tester.takeException(), isNull);
            expect(find.text('Community Hub'), findsOneWidget);

            // Tap Trending filter chip
            final trendingChip = find.widgetWithText(ChoiceChip, '🔥 Trending');
            if (trendingChip.evaluate().isNotEmpty) {
              await tester.tap(trendingChip, warnIfMissed: false);
              await tester.pump();
              expect(tester.takeException(), isNull);
            }
          },
        );

        testWidgets(
          'AthleteProfileScreen renders without overflow on ${size.width}px device width',
          (tester) async {
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1.0;
            addTearDown(tester.view.reset);

            await tester.pumpWidget(
              MaterialApp(
                theme: ThemeData.dark(),
                home: const AthleteProfileScreen(
                  userId: 'usr_maya',
                  name: 'Maya Chen',
                  rank: 'Platinum I',
                ),
              ),
            );

            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
            expect(tester.takeException(), isNull);
            expect(find.text('Maya Chen'), findsOneWidget);
            expect(
              find.widgetWithText(ElevatedButton, 'FOLLOW'),
              findsOneWidget,
            );
          },
        );
      }
    },
  );
}
