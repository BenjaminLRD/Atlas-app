import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/activity_post.dart';
import 'package:atlas/models/social_profile.dart';
import 'package:atlas/services/social/community_feed_service.dart';
import 'package:atlas/services/social/community_insights_service.dart';
import 'package:atlas/services/social/social_leaderboard_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  group('Atlas Social Fitness Ecosystem 2.0 Tests (Phase E.3)', () {
    test(
      '1. SocialProfile models rank promotions correctly based on lifetime XP',
      () {
        expect(
          SocialAthleteRank.fromXp(450),
          equals(SocialAthleteRank.beginner),
        );
        expect(
          SocialAthleteRank.fromXp(1200),
          equals(SocialAthleteRank.risingAthlete),
        );
        expect(
          SocialAthleteRank.fromXp(8500),
          equals(SocialAthleteRank.ironWarrior),
        );
        expect(
          SocialAthleteRank.fromXp(18000),
          equals(SocialAthleteRank.elite),
        );
        expect(
          SocialAthleteRank.fromXp(35000),
          equals(SocialAthleteRank.legend),
        );

        const profile = SocialProfile(
          userId: 'usr_test',
          username: 'sam_iron',
          displayName: 'Sam Iron',
          totalXp: 16500,
          rank: SocialAthleteRank.elite,
          workoutsCompleted: 45,
          totalVolumeKg: 154000.0,
          currentStreakDays: 12,
        );

        expect(profile.rankDisplay, contains('Elite'));
        expect(profile.rankDisplay, contains('👑'));

        final json = profile.toJson();
        expect(json['user_id'], equals('usr_test'));
        expect(json['total_xp'], equals(16500));

        final fromJson = SocialProfile.fromJson(json);
        expect(fromJson.displayName, equals('Sam Iron'));
        expect(fromJson.rank, equals(SocialAthleteRank.elite));
      },
    );

    test(
      '2. SocialLeaderboardService ranks athletes accurately across categories',
      () {
        final service = SocialLeaderboardService.instance;
        // The service ranks whatever profiles it is given; it holds none of its
        // own. These are test fixtures, not app data.
        SocialProfile p(
          String id,
          String name,
          int xp,
          int streak,
          double kg,
        ) => SocialProfile(
          userId: id,
          username: id,
          displayName: name,
          avatarUrl: '',
          fitnessLevel: 'Intermediate',
          totalXp: xp,
          rank: SocialAthleteRank.fromXp(xp),
          followersCount: 0,
          followingCount: 0,
          workoutsCompleted: 10,
          totalVolumeKg: kg,
          currentStreakDays: streak,
          achievements: const [],
        );
        final fixtures = [
          p('t_a', 'Alex Carter', 34200, 24, 348000),
          p('t_b', 'Maya Chen', 21800, 18, 215000),
          p('t_c', 'Liam Test', 4800, 6, 64000),
        ];
        expect(
          service.computeRankings(category: LeaderboardCategory.weeklyXp),
          isEmpty,
        );

        final xpRankings = service.computeRankings(
          category: LeaderboardCategory.weeklyXp,
          profiles: fixtures,
        );
        expect(xpRankings.first.rank, equals(1));
        expect(xpRankings.first.profile.displayName, equals('Alex Carter'));
        expect(
          xpRankings.first.numericScore,
          greaterThan(xpRankings[1].numericScore),
        );

        final consistencyRankings = service.computeRankings(
          category: LeaderboardCategory.workoutConsistency,
          profiles: fixtures,
        );
        expect(
          consistencyRankings.first.profile.currentStreakDays,
          greaterThanOrEqualTo(
            consistencyRankings[1].profile.currentStreakDays,
          ),
        );

        final volumeRankings = service.computeRankings(
          category: LeaderboardCategory.totalVolume,
          profiles: fixtures,
        );
        expect(volumeRankings.first.metricValue, contains('tons lifted'));
        expect(
          volumeRankings.first.numericScore,
          greaterThan(volumeRankings.last.numericScore),
        );
      },
    );

    test(
      '4. CommunityFeedService creates transformation posts and manages interactions',
      () {
        final feedService = CommunityFeedService.instance;
        final initialCount = feedService.getPosts().length;

        final newPost = feedService.createTransformationPost(
          userId: 'usr_sarah',
          userName: 'Sarah Jenkins',
          userAvatar: 'https://avatar.url',
          userRank: 'Iron Warrior ⚔️',
          title: '6-Month Transformation',
          caption: 'Down 6kg of fat, up 15kg on my Squat!',
          beforeWeight: 68.0,
          afterWeight: 62.0,
          timeSpan: '6 Months',
        );

        expect(feedService.getPosts().length, equals(initialCount + 1));
        expect(newPost.type, equals(ActivityPostType.transformation));
        expect(newPost.description, contains('-6.0 kg'));

        // Like interaction
        final likedPost = feedService.toggleLike(newPost.id);
        expect(likedPost, isNotNull);
        expect(likedPost!.isLiked, isTrue);
        expect(likedPost.likes, equals(1));

        // Comment interaction
        final commentedPost = feedService.addComment(
          newPost.id,
          'Incredible progress! Keep it up 🔥',
        );
        expect(commentedPost, isNotNull);
        expect(commentedPost!.comments, equals(1));
      },
    );

    test(
      '5. CommunityInsightsService generates milestone summaries and peer benchmarking',
      () {
        final insightsService = CommunityInsightsService.instance;

        final milestone = insightsService.generateCommunityMilestoneSummary(
          totalWorkoutsCompleted: 15200,
          totalTonsLifted: 140000.0,
          activeAthletes: 4100,
        );
        expect(milestone, contains('15200 workouts'));
        expect(milestone, contains('140k tons'));
        expect(milestone, contains('4100 active athletes'));

        final benchmark = insightsService.generatePeerBenchmarking(
          userProgressScore: 85.0,
          goal: 'Hypertrophy',
        );
        expect(benchmark, contains('improved faster than'));
        expect(benchmark, contains('Hypertrophy'));
      },
    );
  });
}
