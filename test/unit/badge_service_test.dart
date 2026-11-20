import 'dart:io';

import 'package:atlas/app_theme.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/data/mock_badges.dart';
import 'package:atlas/models/user_progress.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/screens/ranked_screen.dart';
import 'package:atlas/services/achievement_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    FitnessProvider.resetInstance();
  });

  tearDown(FitnessProvider.resetInstance);

  group('BadgeService without FitnessProvider', () {
    test('the source no longer refers to the provider', () {
      final source = File('lib/data/mock_badges.dart').readAsStringSync();
      expect(source.contains('fitness_provider'), isFalse);
      expect(source.contains('FitnessProvider.'), isFalse);
    });

    test('with nothing unlocked the recent badges are the preview set', () {
      final service = BadgeService(unlockedAchievementIds: () => const []);
      final recent = service.getRecentBadges();

      expect(recent.map((b) => b.id), [
        'streak_7',
        'workouts_10',
        'personal_record',
      ]);
      expect(recent.every((b) => b.isUnlocked), isTrue);
      final now = DateTime.now();
      final days = recent
          .map((b) => now.difference(b.earnedDate!).inDays)
          .toList();
      expect(days, [2, 5, 8]);
    });

    test(
      'recent badges are the unlocked ones, and unknown ids are ignored',
      () {
        final service = BadgeService(
          unlockedAchievementIds: () => const [
            'first_workout',
            'streak_7',
            'not_a_badge',
          ],
        );
        final recent = service.getRecentBadges();

        expect(recent.map((b) => b.id), ['first_workout', 'streak_7']);
        expect(recent.every((b) => b.isUnlocked), isTrue);
        final now = DateTime.now();
        expect(
          recent.every((b) => now.difference(b.earnedDate!).inDays == 1),
          isTrue,
        );
      },
    );

    test('all badges lists every achievement with the right locked state', () {
      final service = BadgeService(
        unlockedAchievementIds: () => const ['first_workout', 'meals_10'],
      );
      final all = service.getAllBadges();

      expect(
        all.map((b) => b.id),
        AchievementService.allAchievements.map((b) => b.id),
      );
      final unlocked = all.where((b) => b.isUnlocked).map((b) => b.id);
      expect(unlocked, ['first_workout', 'meals_10']);
      for (final b in all) {
        expect(
          b.earnedDate == null,
          !b.isUnlocked,
          reason: '${b.id}: only unlocked badges have an earned date',
        );
      }
    });

    test('every call reads the current achievements', () {
      var unlocked = <String>[];
      final service = BadgeService(unlockedAchievementIds: () => unlocked);

      expect(service.getAllBadges().where((b) => b.isUnlocked), isEmpty);
      unlocked = ['first_workout'];
      expect(
        service.getAllBadges().where((b) => b.isUnlocked).map((b) => b.id),
        ['first_workout'],
      );
      expect(service.getRecentBadges().map((b) => b.id), ['first_workout']);
    });

    test('it only reads: the source list is not changed', () {
      final ids = ['first_workout'];
      final service = BadgeService(unlockedAchievementIds: () => ids);
      service.getRecentBadges();
      service.getAllBadges();
      expect(ids, ['first_workout']);
    });
  });

  group('RankedScreen still shows the athlete\'s badges', () {
    /// Layout overflow reports are not what these tests are about (the test
    /// font is wider than the real one); any other error still fails them.
    final otherErrors = <FlutterErrorDetails>[];

    Future<void> pumpScreen(WidgetTester tester) async {
      otherErrors.clear();
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        if (!details.exceptionAsString().contains('overflowed')) {
          otherErrors.add(details);
        }
      };
      addTearDown(() => FlutterError.onError = previous);
      tester.view.physicalSize = const Size(900, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.darkTheme, home: const RankedScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('unlocked achievements from the progress appear', (
      tester,
    ) async {
      await LocalStorage.saveUserProgress(
        UserProgress.initial().copyWith(achievements: ['first_workout']),
      );
      FitnessProvider.resetInstance();
      FitnessProvider.instance.refreshAll();

      await pumpScreen(tester);

      expect(find.text('First Workout'), findsWidgets);
      expect(otherErrors, isEmpty);
    });

    testWidgets('the screen follows the progress when it changes', (
      tester,
    ) async {
      await pumpScreen(tester);
      // Nothing unlocked: the preview set is shown, not this badge.
      expect(find.text('First Workout'), findsNothing);

      await LocalStorage.saveUserProgress(
        UserProgress.initial().copyWith(achievements: ['first_workout']),
      );
      FitnessProvider.instance.refreshAll();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('First Workout'), findsWidgets);
    });
  });
}
