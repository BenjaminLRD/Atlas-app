import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/models/activity_post.dart';
import 'package:atlas/services/community/sample_community.dart';
import 'package:atlas/services/athlete/athlete_state_engine.dart';
import 'package:atlas/services/athlete/insight_generation_service.dart';
import 'package:atlas/services/athlete/strength_prediction_engine.dart';
import 'package:atlas/services/showcase_mode_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Atlas Investor Readiness & Showcase Presentation (Showcase Mode)', () {
    late ShowcaseModeService showcaseService;

    setUp(() {
      ShowcaseModeService.resetInstance();
      showcaseService = ShowcaseModeService.instance;
    });

    test(
      '1. ShowcaseModeService enables and disables showcase mode correctly',
      () {
        expect(showcaseService.isShowcaseMode, isFalse);

        showcaseService.enableShowcaseMode();
        expect(showcaseService.isShowcaseMode, isTrue);

        showcaseService.disableShowcaseMode();
        expect(showcaseService.isShowcaseMode, isFalse);
      },
    );

    test(
      '2. getShowcaseUserProfile generates complete athlete showcase profile',
      () {
        final profile = showcaseService.getShowcaseUserProfile();

        expect(profile.name, 'Alex Lalremruata');
        expect(profile.fitnessGoal, 'Hypertrophy & Strength');
        expect(profile.workoutExperience, contains('Powerbuilder'));
        expect(profile.subscription, 'Premium Pro');
        expect(profile.weight, '77.5');
        expect(profile.height, '178');
      },
    );

    test(
      '3. getShowcaseWorkoutHistory contains 48 sessions totaling 580,000 kg volume and PRs',
      () {
        final history = showcaseService.getShowcaseWorkoutHistory();

        expect(history.length, 48);
        final totalVolume = history.fold(0.0, (sum, w) => sum + w.totalVolume);
        expect(totalVolume, closeTo(580000.0, 1.0));

        final pushSession = history.first;
        expect(pushSession.workoutName, contains('Upper Push'));
        expect(pushSession.completionPercentage, 100.0);
        expect(pushSession.personalRecords, isNotEmpty);
        expect(pushSession.personalRecords.first, contains('110.0 kg'));
        expect(pushSession.formScore, 94.0);
      },
    );

    test('4. getShowcaseBadges returns tiered achievement badges', () {
      final badges = showcaseService.getShowcaseBadges();

      expect(badges.length, 4);
      expect(
        badges.map((b) => b.category),
        containsAll(['Strength', 'Consistency', 'Volume', 'Nutrition']),
      );
      expect(
        badges.map((b) => b.rarity),
        containsAll(['Epic', 'Legendary', 'Rare']),
      );
    });

    test('5. getShowcaseCommunityPosts serves the shared sample community', () {
      final posts = showcaseService.getShowcaseCommunityPosts();

      expect(posts.length, greaterThanOrEqualTo(2));
      expect(posts.every((p) => p.isSample), isTrue);
      expect(posts.any((p) => p.type == ActivityPostType.achievement), isTrue);
      expect(posts.any((p) => p.type == ActivityPostType.meal), isTrue);
      expect(
        posts.map((p) => p.id).toList(),
        SampleCommunity.posts().map((p) => p.id).toList(),
      );
    });

    test(
      '6. getShowcaseFitnessContext builds full multidimensional context snapshot',
      () {
        final ctx = showcaseService.getShowcaseFitnessContext();

        expect(ctx.userProfile?.name, 'Alex Lalremruata');
        expect(ctx.recoveryState?.recoveryScore, 88);
        expect(ctx.userProgress.currentRank, 'Gold');
        expect(ctx.userProgress.workoutStreak, 12);
        expect(ctx.progressSummary.totalVolume, 580000.0);
        expect(ctx.nutritionSummary.proteinGoalHitPercentage, 92.0);
      },
    );

    test(
      '7. getShowcaseDigitalAthlete returns complete twin with 1RM profiles',
      () {
        final athlete = showcaseService.getShowcaseDigitalAthlete();

        expect(athlete.userId, 'usr_showcase_athlete');
        expect(athlete.physicalProfile.age, 26);
        expect(athlete.physicalProfile.weightKg, 77.5);
        expect(athlete.strengthProfile.estimated1RM['Bench Press'], 110.0);
        expect(athlete.strengthProfile.estimated1RM['Squat'], 142.5);
        expect(athlete.strengthProfile.estimated1RM['Deadlift'], 175.0);
        expect(athlete.recoveryProfile.averageRecoveryScore, 88.0);
        expect(athlete.nutritionProfile.dailyCalories, 2650);
        expect(athlete.nutritionProfile.dailyProteinGrams, 185.0);
      },
    );

    test(
      '8. loadDemoAthleteMode activates demo mode and seeds AthleteStateEngine',
      () async {
        await showcaseService.loadDemoAthleteMode();

        expect(showcaseService.isShowcaseMode, isTrue);
        final seededAthlete = AthleteStateEngine.instance.getAthlete(
          'usr_showcase_athlete',
        );
        expect(seededAthlete.physicalProfile.age, 26);
        expect(seededAthlete.strengthProfile.strengthLevel, 'Advanced');
      },
    );

    test(
      '9. StrengthPredictionEngine forecasts compound curves for showcase athlete',
      () {
        final athlete = showcaseService.getShowcaseDigitalAthlete();
        final timeline = StrengthPredictionEngine.instance.predictProgression(
          athlete,
        );

        expect(timeline.predictions.length, greaterThanOrEqualTo(4));
        final bench = timeline.predictions.firstWhere(
          (p) => p.exerciseName == 'Bench Press',
        );
        expect(bench.current1RMKg, 110.0);
        expect(bench.predicted4WeeksKg, greaterThan(110.0));
        expect(bench.predicted12WeeksKg, greaterThan(bench.predicted4WeeksKg));
      },
    );

    test(
      '10. InsightGenerationService produces proactive insights on showcase athlete',
      () {
        final athlete = showcaseService.getShowcaseDigitalAthlete();
        final insights = InsightGenerationService.instance
            .generateWeeklyInsights(athlete);

        expect(insights, isNotEmpty);
        expect(insights.any((i) => i.category == 'strength'), isTrue);
      },
    );
  });
}
