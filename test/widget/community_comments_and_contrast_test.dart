import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../fixtures/legacy_community_feed.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/activity_post.dart';
import 'package:atlas/providers/showcase_mode_provider.dart';
import 'package:atlas/screens/community_screen.dart';
import 'package:atlas/services/community/sample_community.dart';
import 'package:atlas/services/moderation_service.dart';
import 'package:atlas/services/saved_content_service.dart';
import 'package:atlas/services/social_graph_service.dart';
import 'package:atlas/widgets/community/post_card.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SocialGraphService.resetInstance();
    SavedContentService.resetInstance();
    ModerationService.resetInstance();
  });

  group('Community Hub: Post-Specific Comments & Count Consistency', () {
    testWidgets(
      'TEST 1 & 2: Post A and Post B have distinct comment collections and matching counts',
      (tester) async {
        final feed = legacyCommunityFeed();
        final postA = feed.firstWhere((p) => p.id == 'post_pr_1');
        final postB = feed.firstWhere((p) => p.id == 'post_meal_1');

        // Post A: 12 comments
        expect(postA.comments, 12);
        expect(postA.commentsList.length, 12);
        expect(postA.commentsList.first.text, 'That lockout was insane 🔥');

        // Post B: 9 comments
        expect(postB.comments, 9);
        expect(postB.commentsList.length, 9);
        expect(
          postB.commentsList.first.text,
          'That chicken bowl actually looks amazing.',
        );

        // Render Post A
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: SingleChildScrollView(child: PostCard(post: postA)),
            ),
          ),
        );
        await tester.pump();

        // Ensure button is visible then verify displayed comment count on Post A card
        final commentBtn = find.byIcon(Icons.chat_bubble_outline_rounded);
        await tester.ensureVisible(commentBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('12'), findsOneWidget);

        // Tap comment button to open sheet for Post A
        await tester.tap(commentBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Header must strictly show Comments (12)
        expect(find.text('Comments (12)'), findsOneWidget);
        // Comments inside belong to Post A
        expect(find.text('That lockout was insane 🔥'), findsOneWidget);
        expect(
          find.text('That chicken bowl actually looks amazing.'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'TEST 3 & 4: Adding a comment increments count, updates sheet, leaves other posts unaffected, and persists',
      (tester) async {
        final feed = legacyCommunityFeed();
        final postA = feed.firstWhere((p) => p.id == 'post_pr_1');
        final postB = feed.firstWhere((p) => p.id == 'post_meal_1');

        ActivityPost? updatedPostA;

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    PostCard(
                      post: postA,
                      onPostUpdated: (p) => updatedPostA = p,
                    ),
                    PostCard(post: postB),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final firstCommentBtn = find
            .byIcon(Icons.chat_bubble_outline_rounded)
            .first;
        await tester.ensureVisible(firstCommentBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Post A has 12 comments, Post B has 9 comments
        expect(find.text('12'), findsOneWidget);
        expect(find.text('9'), findsOneWidget);

        // Open Post A comments
        await tester.tap(firstCommentBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Comments (12)'), findsOneWidget);

        // Enter new comment
        await tester.enterText(
          find.byType(TextField),
          'Awesome lift brother! Keep it up 🔥',
        );
        await tester.pump();

        // Tap send button
        await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Comment count must increase to 13
        expect(find.text('Comments (13)'), findsOneWidget);

        // Scroll to newly added comment in the sheet
        final newCommentFinder = find.text(
          'Awesome lift brother! Keep it up 🔥',
        );
        await tester.scrollUntilVisible(
          newCommentFinder,
          100,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.pump();
        expect(newCommentFinder, findsOneWidget);

        // Close bottom sheet
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Card A should now display 13, Card B should still display 9
        expect(find.text('13'), findsOneWidget);
        expect(find.text('9'), findsOneWidget);
        expect(updatedPostA, isNotNull);
        expect(updatedPostA!.comments, 13);
        expect(
          updatedPostA!.commentsList.any(
            (c) => c.text == 'Awesome lift brother! Keep it up 🔥',
          ),
          isTrue,
        );

        // Reopen Post A comments sheet to verify new comment is still present
        await tester.tap(firstCommentBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Comments (13)'), findsOneWidget);

        // Verify persistence in LocalStorage
        final storedComments = LocalStorage.getCommentsForPost('post_pr_1');
        expect(
          storedComments.any(
            (c) => c.text == 'Awesome lift brother! Keep it up 🔥',
          ),
          isTrue,
        );
      },
    );

    testWidgets(
      'TEST 5: Post with 0 comments shows Comments (0) and clean empty state',
      (tester) async {
        final zeroPost = ActivityPost(
          id: 'post_fresh_0',
          userId: 'usr_local',
          userName: 'Alex Lalremruata',
          type: ActivityPostType.workout,
          title: 'Morning Leg Workout',
          description: 'First workout logged today.',
          likes: 3,
          createdAt: DateTime.now(),
          commentsList: const [],
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: SingleChildScrollView(child: PostCard(post: zeroPost)),
            ),
          ),
        );
        await tester.pump();

        final commentBtn = find.byIcon(Icons.chat_bubble_outline_rounded);
        await tester.ensureVisible(commentBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Displays 0 comments on card
        expect(find.text('0'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);

        // Tap comment button
        await tester.tap(commentBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Header shows Comments (0)
        expect(find.text('Comments (0)'), findsOneWidget);
        expect(find.text('No comments yet'), findsOneWidget);
        expect(
          find.text('Be the first to share your thoughts on this post!'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'TEST 6 & 7: Fresh user sees the labelled sample feed with Showcase OFF and ON',
      (tester) async {
        // 1. Showcase OFF
        await ShowcaseModeProvider.instance.disableShowcaseMode();
        LocalStorage.clearCommunityPosts();

        await tester.pumpWidget(
          MaterialApp(theme: ThemeData.dark(), home: const CommunityScreen()),
        );
        await tester.pump();

        // The sample community is always there, so the feed is never empty,
        // and every sample post is labelled as such.
        expect(find.text('No posts yet'), findsNothing);
        expect(
          find.byKey(Key('sample_badge_${SampleCommunity.posts().first.id}')),
          findsOneWidget,
        );

        // 2. Showcase ON
        await ShowcaseModeProvider.instance.enableShowcaseMode();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(
        find.text(SampleCommunity.posts().first.title),
        findsOneWidget,
      );
      },
    );

    testWidgets('TEST 8: Comment sheet text contrast & readability', (
      tester,
    ) async {
      final feed = legacyCommunityFeed();
      final post = feed.firstWhere((p) => p.id == 'post_pr_1');

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(child: PostCard(post: post)),
          ),
        ),
      );
      await tester.pump();

      final commentBtn = find.byIcon(Icons.chat_bubble_outline_rounded);
      await tester.ensureVisible(commentBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Open comment sheet
      await tester.tap(commentBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Header text
      final headerFinder = find.text('Comments (12)');
      expect(headerFinder, findsOneWidget);

      // Input field hint
      expect(find.text('Add a comment...'), findsOneWidget);
      // Close button
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      // Send button
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });
  });
}
