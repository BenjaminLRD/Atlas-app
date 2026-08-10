import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aizawl_gym/app_theme.dart';
import 'package:aizawl_gym/models/badge.dart';
import 'package:aizawl_gym/models/reward_event.dart';
import 'package:aizawl_gym/services/daily_motivation_service.dart';
import 'package:aizawl_gym/services/reward_queue_service.dart';
import 'package:aizawl_gym/widgets/common/achievement_gallery.dart';
import 'package:aizawl_gym/widgets/common/animated_rank_progress_card.dart';
import 'package:aizawl_gym/widgets/common/app_animation.dart';
import 'package:aizawl_gym/widgets/common/app_empty_state.dart';
import 'package:aizawl_gym/widgets/common/daily_motivation_card.dart';
import 'package:aizawl_gym/widgets/common/rank_up_dialog.dart';
import 'package:aizawl_gym/widgets/common/reward_celebration_overlay.dart';
import 'package:aizawl_gym/widgets/common/workout_completion_celebration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    RewardQueueService.resetInstance();
  });

  group('1. Design Tokens System', () {
    test('AppGradients defines valid Linear and Radial Gradients', () {
      expect(AppGradients.vitalityGreen.colors.length, greaterThanOrEqualTo(2));
      expect(AppGradients.goldRank.colors.length, greaterThanOrEqualTo(2));
      expect(AppGradients.emeraldGlow.colors.length, greaterThanOrEqualTo(2));
      expect(AppGradients.neonXp.colors.length, greaterThanOrEqualTo(2));
      expect(AppGradients.darkGlass.colors.length, greaterThanOrEqualTo(2));
      expect(AppGradients.lightGlass.colors.length, greaterThanOrEqualTo(2));
    });

    test('AppShadows defines valid elevation shadows', () {
      expect(AppShadows.ambientGlow.blurRadius, equals(24));
      expect(AppShadows.goldGlow.blurRadius, equals(28));
      expect(AppShadows.softCard.blurRadius, equals(16));
    });

    test('AppCurves and AppDurations contain expected animation physics', () {
      expect(AppCurves.spring, equals(Curves.elasticOut));
      expect(AppCurves.smoothOut, equals(Curves.easeOutCubic));
      expect(AppDurations.shimmer, equals(const Duration(milliseconds: 1500)));
      expect(AppDurations.countUp, equals(const Duration(milliseconds: 1200)));
    });
  });

  group('2. Animation Library Widgets', () {
    testWidgets('AppAnimation helpers render children properly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AppAnimation.slideFadeIn(
                  child: const Text('SlideFadeIn Child'),
                ),
                AppAnimation.scaleIn(
                  child: const Text('ScaleIn Child'),
                ),
                AppAnimation.scaleBounce(
                  active: true,
                  child: const Text('ScaleBounce Child'),
                ),
                AppAnimation.pulseGlow(
                  child: const Text('PulseGlow Child'),
                ),
                AppAnimation.shimmer(
                  child: const Text('Shimmer Child'),
                ),
                AppAnimation.countNumber(
                  endValue: 500,
                  prefix: '+',
                  suffix: ' XP',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('SlideFadeIn Child'), findsOneWidget);
      expect(find.text('ScaleIn Child'), findsOneWidget);
      expect(find.text('ScaleBounce Child'), findsOneWidget);
      expect(find.text('PulseGlow Child'), findsOneWidget);
      expect(find.text('Shimmer Child'), findsOneWidget);
      expect(find.byType(Text), findsWidgets);
    });
  });

  group('3. Reward Event System & Queue Service', () {
    test('RewardQueueService enqueues and sorts events by priority descending', () {
      final queue = RewardQueueService.instance;
      queue.clearQueue();

      final rankEvent = RewardEvent.rankUp(
        const RankUpDetails(
          previousRank: 'Bronze',
          newRank: 'Silver',
          xpGained: 500,
          message: 'Great progress!',
        ),
      );

      final achievementEvent = RewardEvent.achievement(
        const AchievementBadge(
          id: 'badge_test_1',
          title: 'Test Badge',
          description: 'Badge desc',
          iconCodePoint: 0xe000,
          category: 'Milestone',
          rarity: 'Common',
        ),
      );

      final xpBonusEvent = RewardEvent.xpBonus(amount: 100, source: 'Workout');

      queue.enqueue(xpBonusEvent);
      queue.enqueue(achievementEvent);
      queue.enqueue(rankEvent);

      expect(queue.pendingCount, equals(3));
      expect(queue.peek()?.id, equals(rankEvent.id)); // Priority 100 first

      final firstDequeued = queue.dequeue();
      expect(firstDequeued?.id, equals(rankEvent.id));

      final secondDequeued = queue.dequeue();
      expect(secondDequeued?.id, equals(achievementEvent.id)); // Priority 80 second

      final thirdDequeued = queue.dequeue();
      expect(thirdDequeued?.id, equals(xpBonusEvent.id)); // Priority 50 third
    });

    test('RewardQueueService rejects duplicate event IDs', () {
      final queue = RewardQueueService.instance;
      queue.clearQueue();

      final event1 = RewardEvent.xpBonus(amount: 100, source: 'Test', customId: 'dup_01');
      final event2 = RewardEvent.xpBonus(amount: 100, source: 'Test', customId: 'dup_01');

      expect(queue.enqueue(event1), isTrue);
      expect(queue.enqueue(event2), isFalse);
      expect(queue.pendingCount, equals(1));
    });
  });

  group('4. Reward Overlays & Rank Progression Widgets', () {
    testWidgets('AnimatedRankProgressCard renders rank and XP metrics', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AnimatedRankProgressCard(
              currentRank: 'Gold',
              nextRank: 'Platinum',
              currentXp: 750,
              targetXp: 1000,
            ),
          ),
        ),
      );

      expect(find.text('GOLD'), findsOneWidget);
      expect(find.text('250 XP to Platinum'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('RewardCelebrationOverlay renders reward title and XP pill', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RewardCelebrationOverlay(
              details: RewardCelebrationDetails(
                title: 'LEGENDARY MILESTONE',
                description: 'Completed 100 sessions',
                xpGained: 1000,
              ),
            ),
          ),
        ),
      );

      expect(find.text('LEGENDARY MILESTONE'), findsOneWidget);
      expect(find.text('Completed 100 sessions'), findsOneWidget);
      expect(find.text('CLAIM REWARD'), findsOneWidget);
    });

    testWidgets('WorkoutCompletionCelebration renders completion summary stats', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WorkoutCompletionCelebration(
              workoutTitle: 'Leg Day Blast',
              durationMinutes: 45,
              exercisesCompleted: 5,
              caloriesBurned: 350,
              xpEarned: 500,
              isPersonalRecord: true,
            ),
          ),
        ),
      );

      expect(find.text('WORKOUT COMPLETE!'), findsOneWidget);
      expect(find.text('Leg Day Blast'), findsOneWidget);
      expect(find.text('NEW PERSONAL RECORD!'), findsOneWidget);
      expect(find.text('VIEW SUMMARY'), findsOneWidget);
    });
  });

  group('5. Daily Motivation System', () {
    test('DailyMotivationService retrieves quotes consistently', () {
      final quote = DailyMotivationService.getDailyQuote();
      expect(quote.quote.isNotEmpty, isTrue);
      expect(quote.author.isNotEmpty, isTrue);
      expect(quote.coachTip.isNotEmpty, isTrue);

      final randomQuote = DailyMotivationService.getRandomQuote();
      expect(randomQuote.quote.isNotEmpty, isTrue);
    });

    testWidgets('DailyMotivationCard renders quote and coach tip', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DailyMotivationCard(),
          ),
        ),
      );

      expect(find.text('DAILY MOTIVATION'), findsOneWidget);
      expect(find.byIcon(Icons.format_quote_rounded), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });
  });

  group('6. Empty State Presets & Achievement Gallery', () {
    testWidgets('AppEmptyState preset constructors render cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  AppEmptyState.noWorkouts(),
                  AppEmptyState.noAchievements(),
                  AppEmptyState.noHistory(),
                  AppEmptyState.noChat(),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('No Workouts Logged Yet'), findsOneWidget);
      expect(find.text('No Badges Unlocked Yet'), findsOneWidget);
      expect(find.text('No History Recorded'), findsOneWidget);
      expect(find.text('Ask AI Coach Anything'), findsOneWidget);
    });

    testWidgets('AchievementGallery displays badges and progress header', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AchievementGallery(
                unlockedBadgeIds: ['first_workout', 'workouts_10'],
              ),
            ),
          ),
        ),
      );

      expect(find.text('ACHIEVEMENTS UNLOCKED'), findsOneWidget);
      expect(find.text('First Workout'), findsOneWidget);
      expect(find.text('First 10 Workouts'), findsOneWidget);
    });
  });
}
