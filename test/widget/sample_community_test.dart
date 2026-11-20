import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/activity_post.dart';
import 'package:atlas/providers/showcase_mode_provider.dart';
import 'package:atlas/screens/community_screen.dart';
import 'package:atlas/services/community/community_cloud_repository.dart';
import 'package:atlas/services/community/sample_community.dart';
import 'package:atlas/services/moderation_service.dart';
import 'package:atlas/services/saved_content_service.dart';
import 'package:atlas/services/social_graph_service.dart';
import 'package:atlas/widgets/community/post_card.dart';

ActivityPost _realPost() => ActivityPost(
  id: 'local_post_1',
  userId: 'usr_local',
  userName: 'Me',
  type: ActivityPostType.workout,
  title: 'My real leg day',
  description: 'Logged by the user.',
  createdAt: DateTime.now().subtract(const Duration(days: 3)),
);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SocialGraphService.resetInstance();
    SavedContentService.resetInstance();
    ModerationService.resetInstance();
  });

  group('SampleCommunity data', () {
    test(
      'every sample post is flagged, local-only and uniquely identified',
      () {
        final posts = SampleCommunity.posts();
        expect(posts, isNotEmpty);
        expect(posts.every((p) => p.isSample), isTrue);
        expect(posts.map((p) => p.id).toSet().length, posts.length);
        // Not server ids, so they can never be sent to Supabase.
        expect(
          posts.any((p) => CommunityCloudRepository.isCloudId(p.id)),
          isFalse,
        );
        expect(
          posts.any((p) => CommunityCloudRepository.isCloudId(p.userId)),
          isFalse,
        );
        expect(SampleCommunity.isSampleUser(posts.first.userId), isTrue);
        expect(SampleCommunity.isSampleUser('usr_local'), isFalse);
      },
    );

    test('sample posts are never stored among the user\'s own posts', () async {
      await LocalStorage.saveCommunityPosts([
        _realPost(),
        ...SampleCommunity.posts(),
      ]);
      final stored = LocalStorage.getCommunityPosts();
      expect(stored.map((p) => p.id), ['local_post_1']);
      expect(stored.single.isSample, isFalse);
    });

    test('isSample survives JSON and defaults to false for old data', () {
      final sample = SampleCommunity.posts().first;
      expect(ActivityPost.fromJson(sample.toJson()).isSample, isTrue);
      final old = _realPost().toJson();
      expect(old.containsKey('isSample'), isFalse);
      expect(ActivityPost.fromJson(old).isSample, isFalse);
    });

    test('a like on a sample post is kept apart from real records', () async {
      final target = SampleCommunity.posts().first;
      await SampleCommunity.setLiked(target.id, true);

      final again = SampleCommunity.posts().firstWhere(
        (p) => p.id == target.id,
      );
      expect(again.isLiked, isTrue);
      expect(again.likes, target.likes + 1);
      expect(LocalStorage.getCommunityPosts(), isEmpty);

      await SampleCommunity.setLiked(target.id, false);
      final undone = SampleCommunity.posts().firstWhere(
        (p) => p.id == target.id,
      );
      expect(undone.isLiked, isFalse);
      expect(undone.likes, target.likes);
    });

    test('updating a real post never touches sample ids', () async {
      await LocalStorage.saveCommunityPosts([_realPost()]);
      await LocalStorage.updateCommunityPost(
        _realPost().copyWith(likes: 5, isLiked: true),
      );
      expect(LocalStorage.getCommunityPosts().single.likes, 5);

      await LocalStorage.updateCommunityPost(SampleCommunity.posts().first);
      expect(LocalStorage.getCommunityPosts().length, 1);
    });

    test('blocking a sample athlete stays on the device', () async {
      final sampleUser = SampleCommunity.posts().first.userId;
      await ModerationService.instance.blockUser(sampleUser);
      expect(ModerationService.instance.isUserBlocked(sampleUser), isTrue);
    });
  });

  group('Community screen', () {
    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: ThemeData.dark(), home: const CommunityScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets(
      'a new account sees a populated, labelled feed without Showcase Mode',
      (tester) async {
        expect(ShowcaseModeProvider.instance.isShowcaseModeEnabled, isFalse);
        await pumpScreen(tester);

        expect(find.byType(PostCard), findsWidgets);
        final first = SampleCommunity.posts().first;
        expect(find.byKey(Key('sample_badge_${first.id}')), findsOneWidget);
        expect(find.text('No posts yet'), findsNothing);
      },
    );

    testWidgets('a real post shows first and carries no sample label', (
      tester,
    ) async {
      await LocalStorage.saveCommunityPosts([_realPost()]);
      await pumpScreen(tester);

      expect(find.text('My real leg day'), findsOneWidget);
      expect(find.byKey(const Key('sample_badge_local_post_1')), findsNothing);
      final firstCard = tester.widget<PostCard>(find.byType(PostCard).first);
      expect(firstCard.post.id, 'local_post_1');
      expect(firstCard.post.isSample, isFalse);
    });

    testWidgets('liking a sample post persists and leaves user posts alone', (
      tester,
    ) async {
      final target = SampleCommunity.posts().first;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(child: PostCard(post: target)),
          ),
        ),
      );
      await tester.pump();

      final like = find.byIcon(Icons.favorite_border_rounded);
      await tester.ensureVisible(like);
      await tester.tap(like);
      await tester.pump();

      expect(LocalStorage.getSampleLikedPostIds(), contains(target.id));
      expect(LocalStorage.getCommunityPosts(), isEmpty);
    });
  });
}
