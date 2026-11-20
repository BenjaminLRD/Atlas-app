import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/models/challenge.dart';
import 'package:atlas/models/fitness_context.dart';
import 'package:atlas/models/leaderboard_entry.dart';
import 'package:atlas/models/progress_summary.dart';
import 'package:atlas/models/transformation_post.dart';
import 'package:atlas/models/user_progress.dart';
import 'package:atlas/services/ranked/rank_ladder.dart';
import 'package:atlas/services/ranked/ranked_progress_store.dart';
import 'package:atlas/models/user_xp.dart';
import 'package:atlas/models/workout_history.dart';
import 'package:atlas/data/gamification_service.dart';
import 'package:atlas/data/local_storage.dart';
import '../mocks/mock_ai_provider.dart';
import 'package:atlas/services/challenge_service.dart';
import 'package:atlas/services/leaderboard_service.dart';
import 'package:atlas/services/social_service.dart';
import 'package:atlas/services/transformation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    ChallengeService.resetInstance();
    SocialService.resetInstance();
  });

  group('1. XP & Rank Progression System', () {
    test('Calculates UserXP levels and thresholds correctly', () {
      expect(UserXP.calculateLevel(0), 1);
      expect(UserXP.calculateLevel(499), 1);
      expect(UserXP.calculateLevel(500), 2);
      expect(UserXP.calculateLevel(5000), 11);

      final userXp = UserXP(
        userId: 'test_user',
        totalXP: 52400,
        currentLevel: 105,
        lastUpdated: DateTime.now(),
      );

      expect(userXp.currentLevel, 105);
      expect(userXp.levelProgressFraction, greaterThanOrEqualTo(0.0));
      expect(userXp.levelProgressFraction, lessThanOrEqualTo(1.0));
    });

    test(
      'Rank ladder: one division per Ranked point, Bronze III to Champion I',
      () {
        expect(RankLadder.fromPoints(0).isRanked, isFalse);
        expect(RankLadder.fromPoints(1).title, 'Bronze III');
        expect(RankLadder.fromPoints(3).title, 'Bronze I');
        expect(RankLadder.fromPoints(4).title, 'Silver III');
        expect(RankLadder.fromPoints(13).title, 'Diamond III');
        expect(RankLadder.fromPoints(18).title, 'Champion I');
        expect(RankLadder.fromPoints(20).title, 'Champion I');
        expect(RankLadder.fromPoints(18).next, isNull);
        expect(RankLadder.fromPoints(5).next!.title, 'Silver I');
      },
    );

    test('XP never changes rank; only verified milestones do', () async {
      final service = GamificationService();
      await RankedProgressStore.save(const RankedSnapshot());
      expect(service.addXP(50000, UserProgress.initial()).fullRank, 'Unranked');

      await RankedProgressStore.save(const RankedSnapshot(points: 7));
      expect(service.addXP(10, UserProgress.initial()).fullRank, 'Gold III');
      final next = service.getNextRankRequirement();
      expect(next['nextRank'], 'Gold II');
      expect(next['neededMilestones'], 1);
    });
  });

  group('2. GamificationService & Milestone Awards', () {
    test(
      'Awards workout XP, streak bonuses, and unlocks Ranked mode after 5 sessions',
      () async {
        final service = GamificationService();
        var progress = UserProgress.initial();
        await service.saveProgress(progress);

        expect(progress.rankedUnlocked, isFalse);

        // Complete 5 workouts
        for (int i = 1; i <= 5; i++) {
          final workout = WorkoutHistory(
            workoutName: 'Push Day',
            dateCompleted: DateTime.now(),
            durationSeconds: 3000,
            exercisesCompleted: 5,
            completionPercentage: 100.0,
            personalRecords: i == 1 ? ['Bench 100kg'] : [],
          );
          progress = await service.awardWorkoutXP(workout, progress);
        }

        expect(progress.completedWorkouts, 5);
        expect(progress.rankedUnlocked, isTrue);
        expect(progress.workoutStreak, 5);
        expect(progress.achievements, contains('first_workout'));
        expect(progress.achievements, contains('ranked_unlocked'));
        expect(progress.achievements, contains('workout_5'));
        expect(progress.achievements, contains('first_pr'));
      },
    );

    test('Awards +250 XP bonus on 7-day streak milestone', () async {
      final service = GamificationService();
      var progress = const UserProgress(
        totalXP: 600,
        completedWorkouts: 6,
        workoutStreak: 6,
        longestStreak: 6,
        totalWorkoutMinutes: 180,
        totalVolumeLifted: 10000,
        rankedUnlocked: true,
        currentRank: 'Bronze',
        currentDivision: 'IV',
        achievements: [],
      );

      final workout7 = WorkoutHistory(
        workoutName: 'Leg Day',
        dateCompleted: DateTime.now(),
        durationSeconds: 3600,
        exercisesCompleted: 6,
        completionPercentage: 100.0,
      );

      progress = await service.awardWorkoutXP(workout7, progress);
      // Base: 100 + 25 (100% completion) + 250 (7-day milestone) = 375 XP
      expect(progress.totalXP, 600 + 375);
      expect(progress.workoutStreak, 7);
      expect(progress.achievements, contains('streak_7'));
    });
  });

  group('3. Fitness Challenges System', () {
    test('Validates Challenge model attributes and countdown calculations', () {
      final now = DateTime.now();
      final challenge = Challenge(
        id: 'ch_volume_50k',
        title: 'Volume Titan',
        description: 'Hit 50,000kg cumulative volume this week',
        category: 'volume',
        targetValue: 50000.0,
        currentProgress: 25000.0,
        participants: 1420,
        rewardXP: 800,
        startDate: now.subtract(const Duration(days: 1)),
        endDate: now.add(const Duration(days: 4, hours: 6)),
      );

      expect(challenge.type, 'volume');
      expect(challenge.target, 50000.0);
      expect(challenge.currentProgress, 25000.0);
      expect(challenge.participants, 1420);
      expect(challenge.countdownLabel, contains('4d'));
      expect(challenge.countdownLabel, contains('left'));
    });

    test('Challenge serialization and copyWith works seamlessly', () {
      final original = Challenge(
        id: 'ch_push_1000',
        title: '1000 Push Athletes',
        description: '1000 athletes complete Push Day',
        category: 'training',
        targetValue: 1000.0,
        currentProgress: 750.0,
        participants: 840,
        rewardXP: 1000,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(days: 7)),
      );

      final json = original.toJson();
      final revived = Challenge.fromJson(json);

      expect(revived.id, original.id);
      expect(revived.title, original.title);
      expect(revived.targetValue, 1000.0);
      expect(revived.participants, 840);
      expect(revived.rewardXP, 1000);
    });
  });

  group('4. Competitive Leaderboards', () {
    test(
      'With no server data there are no invented leaderboard entries',
      () async {
        final service = LeaderboardService();
        const invented = {
          'usr_alex',
          'usr_maya',
          'usr_daniel',
          'usr_emma',
          'usr_liam',
        };
        final lists = [
          await service.getGlobalLeaderboard(),
          await service.getLocalLeaderboard(country: 'India'),
          await service.getFriendsLeaderboard(userId: 'usr_local'),
        ];
        for (final entries in lists) {
          expect(entries.where((e) => invented.contains(e.userId)), isEmpty);
        }
      },
    );

    test('Sorts the entries it does know in descending XP order', () async {
      final service = LeaderboardService();
      for (final xp in [100, 900, 400]) {
        try {
          await service.updateLeaderboardEntry(
            LeaderboardEntry(
              id: 'lb_test_$xp',
              userId: 'usr_test_$xp',
              displayName: 'Test $xp',
              totalXP: xp,
              rankTitle: 'Test',
              division: '',
              country: 'India',
              updatedAt: DateTime(2026, 1, 1),
            ),
          );
        } catch (_) {
          // No server in tests: the local copy is still recorded.
        }
      }
      final entries = await service.getGlobalLeaderboard();
      for (int i = 0; i < entries.length - 1; i++) {
        expect(
          entries[i].totalXP,
          greaterThanOrEqualTo(entries[i + 1].totalXP),
        );
      }
    });
  });

  group('5. Transformation Journey & Privacy Controls', () {
    test('Filters transformations according to privacy settings', () async {
      final service = TransformationService();

      final publicPost = TransformationPost(
        id: 'tf_pub',
        userId: 'usr_author_1',
        userName: 'Author One',
        beforeWeight: 80.0,
        afterWeight: 75.0,
        timeSpanLabel: '8 Weeks',
        strengthGains: {'Bench': 10.0},
        caption: 'Public cut journey',
        privacy: TransformationPrivacy.public,
        createdAt: DateTime.now(),
      );

      final followersPost = TransformationPost(
        id: 'tf_fol',
        userId: 'usr_author_2',
        userName: 'Author Two',
        beforeWeight: 60.0,
        afterWeight: 68.0,
        timeSpanLabel: '12 Weeks',
        strengthGains: {'Squat': 25.0},
        caption: 'Followers bulk',
        privacy: TransformationPrivacy.followersOnly,
        createdAt: DateTime.now(),
      );

      final privatePost = TransformationPost(
        id: 'tf_priv',
        userId: 'usr_author_3',
        userName: 'Author Three',
        beforeWeight: 95.0,
        afterWeight: 88.0,
        timeSpanLabel: '6 Months',
        caption: 'Private journey',
        privacy: TransformationPrivacy.private,
        createdAt: DateTime.now(),
      );

      await service.addTransformation(publicPost);
      await service.addTransformation(followersPost);
      await service.addTransformation(privatePost);

      // Viewer 1: Stranger (not following author 2, not author 3)
      final strangerView = service.getTransformations(
        viewerUserId: 'usr_stranger',
        isFollowing: false,
      );
      final strangerIds = strangerView.map((p) => p.id).toList();
      expect(strangerIds, contains('tf_pub'));
      expect(strangerIds, isNot(contains('tf_fol')));
      expect(strangerIds, isNot(contains('tf_priv')));

      // Viewer 2: Follower of author 2
      final followerView = service.getTransformations(
        viewerUserId: 'usr_follower',
        isFollowing: true,
      );
      final followerIds = followerView.map((p) => p.id).toList();
      expect(followerIds, contains('tf_pub'));
      expect(followerIds, contains('tf_fol'));
      expect(followerIds, isNot(contains('tf_priv')));

      // Viewer 3: Author 3 viewing own private posts
      final author3View = service.getTransformations(
        viewerUserId: 'usr_author_3',
        targetUserId: 'usr_author_3',
      );
      expect(author3View.map((p) => p.id), contains('tf_priv'));
    });
  });

  group('6. Friend System & Safety Blocking', () {
    test('Manages friend requests, approvals, and blocking', () async {
      final service = SocialService();

      // Send friend request
      final request = await service.sendFriendRequest(
        requesterId: 'usr_sender',
        receiverId: 'usr_local',
      );
      expect(request.status, 'pending');

      final pending = await service.getPendingRequests(userId: 'usr_local');
      expect(pending.any((f) => f.id == request.id), isTrue);

      // Accept request
      await service.acceptFriendRequest(
        friendshipId: request.id,
        userId: 'usr_local',
      );

      // Block user
      await service.blockUser(
        currentUserId: 'usr_local',
        targetUserId: 'usr_sender',
      );
      expect(service.isUserBlocked('usr_sender'), isTrue);
    });
  });

  group('7. AI Community Integration', () {
    test(
      'AI Coach generates friend group comparison and rank motivation',
      () async {
        const provider = MockAIProvider();
        final context = FitnessContext.initial().copyWith(
          progressSummary: ProgressSummary.zero().copyWith(
            totalWorkouts: 4,
            currentStreak: 2,
          ),
        );

        final friendResponse = await provider.generateResponse(
          message: 'How is my training compared to my friend group?',
          context: context,
          history: [],
        );

        expect(friendResponse, contains('friend group'));
        expect(friendResponse, contains('4 days/week'));
        expect(friendResponse, contains('2 days'));

        final rankResponse = await provider.generateResponse(
          message: 'What is my current rank?',
          context: context,
          history: [],
        );

        expect(rankResponse, contains('ranked'));
        expect(rankResponse, contains('Gold'));
        expect(rankResponse, contains('Complete 3 more workouts'));
      },
    );
  });
}
