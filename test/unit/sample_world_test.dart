import 'package:atlas/models/activity_post.dart';
import 'package:atlas/services/community/community_cloud_repository.dart';
import 'package:atlas/services/community/sample_community.dart';
import 'package:atlas/services/community/sample_world.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('sample world integrity', () {
    test('has about a dozen distinct athletes', () {
      final a = SampleWorld.athletes;
      expect(a.length, inInclusiveRange(10, 12));
      expect(a.map((x) => x.key).toSet().length, a.length);
      expect(a.map((x) => x.username).toSet().length, a.length);
      expect(
        a.map((x) => x.avatar).toSet().length,
        a.length,
        reason: 'two athletes share a photo',
      );
      for (final x in a) {
        expect(x.bio.trim(), isNotEmpty);
        expect(x.goal.trim(), isNotEmpty);
        expect(x.prs, isNotEmpty);
        expect(x.milestones, isNotEmpty);
        expect(x.stats.weeklyWorkouts, inInclusiveRange(1, 7));
      }
    });

    test('each athlete has 6 to 10 posts', () {
      for (final a in SampleWorld.athletes) {
        final n = SampleWorld.posts.where((p) => p.athlete == a.key).length;
        expect(n, inInclusiveRange(6, 10), reason: a.name);
      }
    });

    test('post ids and captions are unique and every post is demo content', () {
      final posts = SampleCommunity.posts();
      expect(posts.map((p) => p.id).toSet().length, posts.length);
      expect(posts.map((p) => p.description).toSet().length, posts.length);
      expect(posts.every((p) => p.isSample), isTrue);
      expect(
        posts.any((p) => CommunityCloudRepository.isCloudId(p.id)),
        isFalse,
      );
    });

    test(
      'everyone who comments or likes is a sample athlete with a full profile',
      () {
        for (final s in SampleWorld.posts) {
          expect(SampleWorld.byKey(s.athlete), isNotNull, reason: s.id);
          for (final k in s.likedBy) {
            expect(SampleWorld.byKey(k), isNotNull, reason: '${s.id} like $k');
          }
          for (final c in s.comments) {
            expect(
              SampleWorld.byKey(c.by),
              isNotNull,
              reason: '${s.id} by ${c.by}',
            );
          }
        }
        for (final p in SampleCommunity.posts()) {
          for (final c in p.commentsList) {
            final profile = SampleCommunity.profileFor(c.userId);
            expect(profile, isNotNull, reason: c.userId);
            expect(
              SampleCommunity.postsBy(c.userId),
              isNotEmpty,
              reason: '${c.userName} has no posts to show',
            );
            expect(profile!.isSample, isTrue);
          }
        }
      },
    );

    test('an athlete does not like their own post', () {
      for (final s in SampleWorld.posts) {
        expect(s.likedBy.contains(s.athlete), isFalse, reason: s.id);
      }
    });

    test('personal-record posts match the athlete\'s own PR list', () {
      for (final p in SampleCommunity.posts()) {
        if (p.type != ActivityPostType.achievement) continue;
        final kg = p.prNewWeightKg;
        if (kg <= 0) continue;
        final a = SampleWorld.byId(p.userId)!;
        expect(
          a.prs.any((r) => r.exercise == p.prExerciseName && r.kg == kg),
          isTrue,
          reason: '${a.name}: ${p.prExerciseName} $kg kg not in their PR list',
        );
      }
    });

    test(
      'comments never come before the post and nothing is in the future',
      () {
        final now = DateTime.now().add(const Duration(seconds: 5));
        for (final p in SampleCommunity.posts()) {
          expect(p.createdAt.isBefore(now), isTrue);
          for (final c in p.commentsList) {
            expect(c.createdAt.isBefore(p.createdAt), isFalse, reason: p.id);
            expect(c.createdAt.isAfter(now), isFalse, reason: p.id);
          }
        }
      },
    );

    test('sample profiles carry demo details and are labelled', () {
      final p = SampleCommunity.profileFor('usr_alex')!;
      expect(p.isSample, isTrue);
      expect(p.username, 'alex.carter');
      expect(p.hasBio, isTrue);
      expect(p.prs, isNotEmpty);
      expect(p.milestones, isNotEmpty);
      expect(
        p.fitness.map((f) => f.label),
        containsAll(['Goal', 'Level', 'Training style']),
      );
      expect(SampleCommunity.profileFor('usr_real_member'), isNull);
    });

    test(
      'likes on a sample post count sample likers plus the user\'s own',
      () async {
        final target = SampleCommunity.posts().first;
        await SampleCommunity.setLiked(target.id, true);
        final again = SampleCommunity.posts().firstWhere(
          (p) => p.id == target.id,
        );
        expect(again.likes, target.likes + 1);
        expect(
          SampleCommunity.likedByNames(target.id).length,
          lessThanOrEqualTo(again.likes),
        );
      },
    );
  });
}
