import 'package:atlas/app_theme.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/activity_post.dart';
import 'package:atlas/models/athlete_profile.dart';
import 'package:atlas/models/post_comment.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/screens/athlete_profile_screen.dart';
import 'package:atlas/services/cloud/cloud_session.dart';
import 'package:atlas/services/cloud/cloud_sync_coordinator.dart';
import 'package:atlas/services/community/community_cloud_repository.dart';
import 'package:atlas/services/community/post_engagement.dart';
import 'package:atlas/services/community/profile_resolver.dart';
import 'package:atlas/services/community/sample_community.dart';
import 'package:atlas/services/moderation_service.dart';
import 'package:atlas/services/saved_content_service.dart';
import 'package:atlas/services/social_graph_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _me = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _other = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';

String _uuid(int n) =>
    '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

ActivityPost _serverPost(int n, {String userId = _other, int likes = 0}) =>
    ActivityPost(
      id: _uuid(n),
      userId: userId,
      userName: 'Real Member',
      type: ActivityPostType.workout,
      title: 'Server post $n',
      description: 'Stored on the server.',
      likes: likes,
      createdAt: DateTime.now().subtract(Duration(minutes: n)),
    );

/// Records what would be sent to the server, always under the signed-in user.
class _FakeCloud extends CommunityCloudRepository {
  final calls = <String>[];
  List<ActivityPost> userPosts = [];
  bool failMember = false;

  @override
  Future<void> setLiked(String postId, bool liked) async =>
      calls.add('${CloudSession.userId}:like:$postId:$liked');

  @override
  Future<PostComment> addComment(String postId, String body) async {
    calls.add('${CloudSession.userId}:comment:$postId');
    return PostComment(
      id: _uuid(999),
      postId: postId,
      userId: CloudSession.userId!,
      userName: 'Me',
      userRank: 'Unranked',
      text: body,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<PostComment>> fetchComments(String postId) async => const [];

  @override
  Future<List<ActivityPost>> fetchUserPosts(
    String userId, {
    int limit = CommunityCloudRepository.profilePostLimit,
  }) async {
    calls.add('posts:$userId');
    return userPosts;
  }

  @override
  Future<({String name, String rank})?> fetchMember(String userId) async {
    if (failMember) throw Exception('offline');
    return (name: 'Real Member', rank: 'Gold I');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeCloud cloud;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    AppDependencies.reset();
    FitnessProvider.resetInstance();
    SocialGraphService.resetInstance();
    SavedContentService.resetInstance();
    ModerationService.resetInstance();
    cloud = _FakeCloud();
    CommunityCloudRepository.setInstance(cloud);
    CloudSession.debugUserIdOverride = () => _me;
  });

  tearDown(() {
    CloudSession.debugUserIdOverride = null;
    CommunityCloudRepository.setInstance(CommunityCloudRepository());
  });

  group('who owns a like or comment', () {
    test(
      'a server post goes to the server under the signed-in user only',
      () async {
        final post = _serverPost(1);
        await PostEngagement.persistLike(
          post.copyWith(isLiked: true, likes: 1),
        );
        final comment = await PostEngagement.addComment(post, 'Nice');

        expect(cloud.calls, [
          '$_me:like:${post.id}:true',
          '$_me:comment:${post.id}',
        ]);
        expect(comment.userId, _me);
        expect(LocalStorage.getSampleLikedPostIds(), isEmpty);
        expect(LocalStorage.getCommentsForPost(post.id), isEmpty);
        expect(LocalStorage.getCommunityPosts(), isEmpty);
      },
    );

    test(
      'a sample post never reaches the server, even when signed in',
      () async {
        final sample = SampleCommunity.posts().first;
        await PostEngagement.persistLike(sample.copyWith(isLiked: true));
        final comment = await PostEngagement.addComment(sample, 'Nice');

        expect(cloud.calls, isEmpty);
        expect(LocalStorage.getSampleLikedPostIds(), contains(sample.id));
        expect(
          LocalStorage.getCommentsForPost(sample.id).single.id,
          comment.id,
        );
        expect(LocalStorage.getCommunityPosts(), isEmpty);
        // Stored as this device user's comment, which the app treats as you.
        expect(ProfileResolver.isSelfId(comment.userId), isTrue);
      },
    );

    test(
      'your own local post stays local and is never sent to the server',
      () async {
        final mine = ActivityPost(
          id: 'local_post_1',
          userId: 'usr_local',
          userName: 'Me',
          type: ActivityPostType.workout,
          title: 'Local',
          description: '',
          createdAt: DateTime.now(),
        );
        await LocalStorage.saveCommunityPosts([mine]);
        await PostEngagement.persistLike(
          mine.copyWith(isLiked: true, likes: 1),
        );

        expect(cloud.calls, isEmpty);
        expect(LocalStorage.getCommunityPosts().single.likes, 1);
        expect(LocalStorage.getSampleLikedPostIds(), isEmpty);
      },
    );

    test('signed out, nothing is treated as a server post', () {
      CloudSession.debugUserIdOverride = null;
      expect(PostEngagement.isCloudPost(_serverPost(1)), isFalse);
    });

    test(
      'a different account signing in clears sample likes and local comments',
      () async {
        final sample = SampleCommunity.posts().first;
        await SampleCommunity.setLiked(sample.id, true);
        await PostEngagement.addComment(sample, 'Mine');
        expect(LocalStorage.getSampleLikedPostIds(), isNotEmpty);

        await LocalStorage.clearUserData(
          keep: CloudSyncCoordinator.isDeviceSettingKey,
        );

        expect(LocalStorage.getSampleLikedPostIds(), isEmpty);
        expect(LocalStorage.getCommentsForPost(sample.id), isEmpty);
      },
    );
  });

  group('profile post counts', () {
    test('a short server list is complete', () async {
      cloud.userPosts = [for (var i = 1; i <= 3; i++) _serverPost(i)];
      final profile = await ProfileResolver.resolve(userId: _other, name: 'x');
      final result = await ProfileResolver.postsFor(profile);
      expect(result.posts.length, 3);
      expect(result.complete, isTrue);
    });

    test('a list that hit the page limit is not complete', () async {
      cloud.userPosts = [
        for (var i = 1; i <= CommunityCloudRepository.profilePostLimit; i++)
          _serverPost(i),
      ];
      final profile = await ProfileResolver.resolve(userId: _other, name: 'x');
      expect((await ProfileResolver.postsFor(profile)).complete, isFalse);
    });

    Future<void> pumpProfile(WidgetTester tester) async {
      tester.view.physicalSize = const Size(412, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const AthleteProfileScreen(userId: _other, name: 'Real Member'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('shows an exact count when every post was loaded', (
      tester,
    ) async {
      cloud.userPosts = [_serverPost(1, likes: 2), _serverPost(2, likes: 3)];
      await pumpProfile(tester);
      expect(
        tester.widget<Text>(find.byKey(const Key('profile_posts_count'))).data,
        '2',
      );
      expect(find.text('LIKES ON THESE POSTS'), findsNothing);
    });

    testWidgets('shows N+ when more posts may exist, never a total', (
      tester,
    ) async {
      cloud.userPosts = [
        for (var i = 1; i <= CommunityCloudRepository.profilePostLimit; i++)
          _serverPost(i, likes: 1),
      ];
      await pumpProfile(tester);
      expect(
        tester.widget<Text>(find.byKey(const Key('profile_posts_count'))).data,
        '${CommunityCloudRepository.profilePostLimit}+',
      );
    });
  });

  group('profile loading states', () {
    test('a failed lookup is a load failure, not an empty profile', () async {
      cloud.failMember = true;
      expect(
        ProfileResolver.resolve(userId: _other, name: 'x'),
        throwsA(isA<ProfileLoadFailure>()),
      );
    });

    test('an id that points at nothing is not found', () async {
      expect(
        ProfileResolver.resolve(userId: 'usr_ghost', name: ''),
        throwsA(isA<ProfileNotFound>()),
      );
      expect(
        ProfileResolver.resolve(userId: '', name: 'Someone'),
        throwsA(isA<ProfileNotFound>()),
      );
    });

    test('a real member is marked as not sharing details', () async {
      final p = await ProfileResolver.resolve(userId: _other, name: 'x');
      expect(p.infoState, ProfileInfoState.notShared);
      expect(p.isSample, isFalse);
      expect(p.hasBio, isFalse);
      expect(p.prs, isEmpty);
    });

    Future<void> pumpScreen(WidgetTester tester, String id, String name) async {
      tester.view.physicalSize = const Size(412, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: AthleteProfileScreen(userId: id, name: name),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    }

    testWidgets('the screen shows a retry page when loading fails', (
      tester,
    ) async {
      cloud.failMember = true;
      await pumpScreen(tester, _other, 'Real Member');
      expect(find.byKey(const Key('profile_load_failed')), findsOneWidget);

      cloud.failMember = false;
      await tester.tap(find.text('RETRY'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const Key('profile_load_failed')), findsNothing);
      await tester.tap(find.byKey(const Key('profile_tab_about')));
      await tester.pump();
      expect(find.byKey(const Key('profile_not_shared')), findsOneWidget);
    });

    testWidgets('the screen says when an account is not available', (
      tester,
    ) async {
      await pumpScreen(tester, 'usr_ghost', '');
      expect(find.byKey(const Key('profile_not_found')), findsOneWidget);
      expect(find.byKey(const Key('profile_no_posts')), findsNothing);
    });

    testWidgets(
      'a sample commenter opens a full profile with their own posts',
      (tester) async {
        await pumpScreen(tester, 'usr_marcus', 'Marcus Vance');
        expect(find.byKey(const Key('sample_profile_badge')), findsOneWidget);
        expect(find.byKey(const Key('profile_no_posts')), findsNothing);
        await tester.tap(find.byKey(const Key('profile_tab_about')));
        await tester.pump();
        expect(find.text('Training style'), findsOneWidget);
      },
    );
  });
}
