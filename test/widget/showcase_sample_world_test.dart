import 'package:atlas/app_theme.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/activity_post.dart';
import 'package:atlas/models/post_comment.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/providers/showcase_mode_provider.dart';
import 'package:atlas/screens/athlete_profile_screen.dart';
import 'package:atlas/screens/community_screen.dart';
import 'package:atlas/services/cloud/cloud_session.dart';
import 'package:atlas/services/community/community_cloud_repository.dart';
import 'package:atlas/services/community/post_engagement.dart';
import 'package:atlas/services/community/sample_community.dart';
import 'package:atlas/services/moderation_service.dart';
import 'package:atlas/services/saved_content_service.dart';
import 'package:atlas/services/showcase_mode_service.dart';
import 'package:atlas/services/social_graph_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records anything that would reach the server.
class _RecordingCloud extends CommunityCloudRepository {
  final calls = <String>[];

  @override
  Future<void> setLiked(String postId, bool liked) async =>
      calls.add('like:$postId');

  @override
  Future<PostComment> addComment(String postId, String body) async {
    calls.add('comment:$postId');
    throw StateError('sample posts must never reach the server');
  }

  @override
  Future<List<PostComment>> fetchComments(String postId) async {
    calls.add('fetchComments:$postId');
    return const [];
  }

  @override
  Future<List<ActivityPost>> fetchUserPosts(
    String userId, {
    int limit = CommunityCloudRepository.profilePostLimit,
  }) async {
    calls.add('posts:$userId');
    return const [];
  }
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(412, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.darkTheme, home: home));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

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
    ShowcaseModeService.resetInstance();
    await ShowcaseModeProvider.instance.disableShowcaseMode();
  });

  tearDown(() async {
    CloudSession.debugUserIdOverride = null;
    CommunityCloudRepository.setInstance(CommunityCloudRepository());
    await ShowcaseModeProvider.instance.disableShowcaseMode();
  });

  group('Showcase Mode uses the shared sample community', () {
    test('there is one dataset: Showcase serves the SampleCommunity posts', () {
      final normal = SampleCommunity.posts().map((p) => p.id).toList();
      expect(
        ShowcaseModeService.instance
            .getShowcaseCommunityPosts()
            .map((p) => p.id)
            .toList(),
        normal,
      );
      expect(
        ShowcaseModeService.instance
            .getDemoCommunityPosts()
            .map((p) => p.id)
            .toList(),
        normal,
      );
    });

    test('all 11 sample athletes are present as authors', () {
      final authors = ShowcaseModeService.instance
          .getShowcaseCommunityPosts()
          .map((p) => p.userId)
          .toSet();
      expect(authors.length, 11);
      expect(authors, SampleCommunity.sampleUserIds());
    });

    test('posts, comments, likes and profiles are identical in both modes', () async {
      List<Object> snapshot() => [
        for (final p in SampleCommunity.posts())
          '${p.id}|${p.likes}|${p.commentsList.length}|${p.userName}|${p.description}',
        for (final a in SampleCommunity.athletes())
          () {
            final pr = SampleCommunity.profileFor(a.id)!;
            return '${pr.userId}|${pr.bio}|${pr.prs.map((x) => x.value).join(',')}|'
                '${pr.milestones.join(',')}|${pr.workoutCount}|${pr.streakDays}';
          }(),
      ];

      final normal = snapshot();
      await ShowcaseModeProvider.instance.enableShowcaseMode();
      final showcase = snapshot();
      expect(showcase, normal);
      expect(
        ShowcaseModeService.instance
            .getShowcaseCommunityPosts()
            .map((p) => p.id)
            .toList(),
        SampleCommunity.posts().map((p) => p.id).toList(),
      );
    });

    testWidgets(
      'the Community feed in Showcase Mode shows labelled sample posts',
      (tester) async {
        await ShowcaseModeProvider.instance.enableShowcaseMode();
        await _pump(tester, const CommunityScreen());
        final first = SampleCommunity.posts().first;
        expect(find.byKey(Key('sample_badge_${first.id}')), findsOneWidget);
        expect(find.text('No posts yet'), findsNothing);
      },
    );

    for (final athlete in SampleCommunity.athletes()) {
      testWidgets('${athlete.name} opens a complete profile in Showcase Mode', (
        tester,
      ) async {
        await ShowcaseModeProvider.instance.enableShowcaseMode();
        await _pump(
          tester,
          AthleteProfileScreen(userId: athlete.id, name: athlete.name),
        );

        expect(find.byKey(const Key('sample_profile_badge')), findsOneWidget);
        expect(find.byKey(const Key('profile_no_posts')), findsNothing);
        final posts = SampleCommunity.postsBy(athlete.id);
        expect(posts.length, inInclusiveRange(6, 10));
        expect(
          tester
              .widget<Text>(find.byKey(const Key('profile_posts_count')))
              .data,
          '${posts.length}',
        );
        for (final p in posts) {
          expect(
            find.byKey(Key('profile_post_${p.id}')),
            findsOneWidget,
            reason: p.id,
          );
        }

        await tester.tap(find.byKey(const Key('profile_tab_prs')));
        await tester.pump();
        for (final pr in SampleCommunity.profileFor(athlete.id)!.prs) {
          expect(find.text(pr.value), findsWidgets, reason: pr.exercise);
        }

        await tester.tap(find.byKey(const Key('profile_tab_about')));
        await tester.pump();
        expect(find.text('Goal'), findsOneWidget);
        expect(find.text('MILESTONES'), findsOneWidget);
      });
    }
  });

  group('Showcase sample interactions stay local', () {
    test(
      'liking and commenting on a sample post never reaches the server',
      () async {
        final cloud = _RecordingCloud();
        CommunityCloudRepository.setInstance(cloud);
        CloudSession.debugUserIdOverride = () =>
            'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
        await ShowcaseModeProvider.instance.enableShowcaseMode();

        final sample = SampleCommunity.posts().first;
        expect(PostEngagement.isCloudPost(sample), isFalse);
        await PostEngagement.persistLike(sample.copyWith(isLiked: true));
        final comment = await PostEngagement.addComment(sample, 'Nice');

        expect(cloud.calls, isEmpty);
        expect(LocalStorage.getSampleLikedPostIds(), contains(sample.id));
        expect(
          LocalStorage.getCommentsForPost(sample.id).single.id,
          comment.id,
        );
        expect(LocalStorage.getCommunityPosts(), isEmpty);
      },
    );

    test('every sample id is a non-server id', () {
      for (final p in SampleCommunity.posts()) {
        expect(CommunityCloudRepository.isCloudId(p.id), isFalse);
        expect(CommunityCloudRepository.isCloudId(p.userId), isFalse);
      }
    });
  });
}
