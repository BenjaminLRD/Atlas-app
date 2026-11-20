import 'dart:async';

import 'package:atlas/app_theme.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/data/profile_provider.dart';
import 'package:atlas/models/exercise.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/screens/cardio_session_screen.dart';
import 'package:atlas/screens/workout_session_screen.dart';
import 'package:atlas/services/challenge_service.dart';
import 'package:atlas/widgets/common/app_button.dart';
import 'package:atlas/widgets/common/workout_completion_celebration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _cardioExercise = Exercise(
  id: 'treadmill_run',
  name: 'Treadmill Run',
  muscleGroup: 'Cardiovascular',
  equipment: 'Treadmill',
  type: ExerciseType.cardio,
  metValue: 9.8,
  cardioCategory: 'Running',
);

Future<void> _settle(WidgetTester tester, [int ms = 400]) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(Duration(milliseconds: ms ~/ 4));
  }
}

/// Opens the strength session from a host screen, so a pop is visible.
Future<void> _openStrengthSession(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const WorkoutSessionScreen(
                  workoutName: 'Test Push Workout',
                  workoutId: 'test_push_01',
                ),
              ),
            ),
            child: const Text('Start Session'),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
  await tester.tap(find.text('Start Session'));
  await _settle(tester);
  expect(find.byType(WorkoutSessionScreen), findsOneWidget);

  // Complete one set so "Finish Workout Early" appears.
  await tester.tap(find.textContaining('START SET'));
  await _settle(tester);
  await tester.tap(find.textContaining('COMPLETE SET'));
  await _settle(tester);
}

Future<void> _openFinishDialog(WidgetTester tester) async {
  final early = find.text('Finish Workout Early');
  expect(early, findsOneWidget);
  await tester.ensureVisible(early);
  await tester.pump();
  await tester.tap(early);
  await _settle(tester, 800);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    ProfileProvider().reload();
    FitnessProvider.resetInstance();
    ChallengeService.resetInstance();
    FitnessProvider.instance.refreshAll();
  });

  tearDown(() async {
    FitnessProvider.instance.rewardStageHook = null;
    await LocalStorage.setShowcaseModeEnabled(false);
  });

  group('strength Finish & Save', () {
    testWidgets('saves once and shows the XP that was awarded', (tester) async {
      await _openStrengthSession(tester);
      final xpBefore = LocalStorage.getUserProgress().totalXP;

      await _openFinishDialog(tester);
      expect(find.text('Finish Workout?'), findsOneWidget);
      await tester.tap(find.text('Finish & Save'));
      await _settle(tester, 800);

      expect(LocalStorage.getWorkoutHistory(), hasLength(1));
      expect(LocalStorage.getWorkoutSessions(), hasLength(1));
      final celebration = tester.widget<WorkoutCompletionCelebration>(
        find.byType(WorkoutCompletionCelebration),
      );
      final stored = LocalStorage.getWorkoutHistory().single;
      // The celebration shows what the record and the progress got.
      expect(celebration.xpEarned, stored.xpEarned);
      expect(
        LocalStorage.getUserProgress().totalXP - xpBefore,
        greaterThanOrEqualTo(stored.xpEarned),
      );
    });

    testWidgets('shows the summary of the saved workout and Finish closes it', (
      tester,
    ) async {
      await _openStrengthSession(tester);
      await _openFinishDialog(tester);
      await tester.tap(find.text('Finish & Save'));
      await _settle(tester, 800);

      // The summary describes the workout that was just saved.
      final stored = LocalStorage.getWorkoutSessions().single;
      expect(find.byKey(const Key('workout_summary')), findsOneWidget);
      expect(find.textContaining('Test Push Workout'), findsWidgets);
      final sets = stored.exercises.fold<int>(
        0,
        (n, e) => n + e.sets.where((s) => s.completed).length,
      );
      expect(sets, 1);
      expect(
        find.descendant(
          of: find.byKey(const Key('summary_sets')),
          matching: find.textContaining('$sets/'),
        ),
        findsOneWidget,
      );
      // A first workout has no history to beat: nothing is invented.
      expect(find.byKey(const Key('summary_pr')), findsNothing);

      // Finish closes the summary, and the workout screen follows as before.
      await tester.tap(find.byKey(const Key('summary_finish')));
      // The first workout also earns reward pop-ups; dismiss them as a user
      // would, then the workout screen closes behind the summary.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 400));
        for (final label in ['CONTINUE', 'CLAIM REWARD']) {
          final next = find.text(label);
          if (next.evaluate().isNotEmpty) {
            await tester.tap(next.first);
          }
        }
      }
      expect(find.byKey(const Key('workout_summary')), findsNothing);
      expect(find.byType(WorkoutSessionScreen), findsNothing);
      expect(LocalStorage.getWorkoutHistory(), hasLength(1));
    });

    testWidgets('a second tap in the same moment does not save twice', (
      tester,
    ) async {
      await _openStrengthSession(tester);
      final xpBefore = LocalStorage.getUserProgress().totalXP;

      await _openFinishDialog(tester);
      final button = find.text('Finish & Save');
      await tester.tap(button);
      await tester.tap(button, warnIfMissed: false);
      await _settle(tester, 800);

      expect(LocalStorage.getWorkoutHistory(), hasLength(1));
      expect(LocalStorage.getWorkoutSessions(), hasLength(1));
      expect(LocalStorage.getUserProgress().completedWorkouts, 1);
      final stored = LocalStorage.getWorkoutHistory().single;
      expect(
        LocalStorage.getUserProgress().totalXP - xpBefore,
        lessThan(stored.xpEarned + 2000),
      );
      // The screen underneath was not popped by the second tap.
      expect(find.byType(WorkoutSessionScreen), findsOneWidget);
    });

    testWidgets(
      'while it is saving, the finish dialog cannot be opened again',
      (tester) async {
        await _openStrengthSession(tester);
        final gate = Completer<void>();
        FitnessProvider.instance.rewardStageHook = (stage) async {
          if (stage == 'recordSaved') await gate.future;
        };

        await _openFinishDialog(tester);
        await tester.tap(find.text('Finish & Save'));
        await _settle(tester, 800);
        // The save is waiting inside the completion flow.
        expect(LocalStorage.getWorkoutHistory(), hasLength(1));
        expect(find.byType(WorkoutCompletionCelebration), findsNothing);

        // Asking to finish again while it saves does nothing: no second dialog.
        final early = find.text('Finish Workout Early');
        expect(early, findsOneWidget, reason: 'the button is still on screen');
        await tester.ensureVisible(early);
        await tester.pump();
        await tester.tap(early);
        await _settle(tester, 800);
        expect(find.text('Finish Workout?'), findsNothing);

        gate.complete();
        await _settle(tester, 800);
        expect(LocalStorage.getWorkoutHistory(), hasLength(1));
        expect(LocalStorage.getUserProgress().completedWorkouts, 1);
      },
    );

    testWidgets('a failed save says so and can be tried again', (tester) async {
      await _openStrengthSession(tester);
      FitnessProvider.instance.rewardStageHook = (stage) async {
        if (stage == 'recordSaved') throw StateError('disk full');
      };

      await _openFinishDialog(tester);
      await tester.tap(find.text('Finish & Save'));
      await _settle(tester, 800);

      expect(
        find.textContaining('Could not save your workout'),
        findsOneWidget,
      );
      expect(find.byType(WorkoutSessionScreen), findsOneWidget);
      expect(LocalStorage.getUserProgress().completedWorkouts, 0);
      expect(tester.takeException(), isNull);

      // Try again: the workout that was saved is picked up, once.
      FitnessProvider.instance.rewardStageHook = null;
      final xpBefore = LocalStorage.getUserProgress().totalXP;
      await _openFinishDialog(tester);
      await tester.tap(find.text('Finish & Save'));
      await _settle(tester, 800);

      expect(LocalStorage.getWorkoutHistory(), hasLength(1));
      expect(LocalStorage.getUserProgress().completedWorkouts, 1);
      expect(LocalStorage.getUserProgress().totalXP, greaterThan(xpBefore));
    });

    testWidgets(
      'if the dialog button fires twice, the screen is not popped by the second',
      (tester) async {
        await _openStrengthSession(tester);
        await _openFinishDialog(tester);

        // Two presses that both reach the handler (a double tap whose second
        // callback arrives while the dialog is still closing).
        final button = tester.widget<AppButton>(
          find.byWidgetPredicate(
            (w) => w is AppButton && w.label == 'Finish & Save',
          ),
        );
        button.onPressed!();
        button.onPressed!();
        await _settle(tester, 800);

        // Only the dialog was closed: the session screen is still there to
        // show the celebration, and the workout was saved once.
        expect(find.byType(WorkoutSessionScreen), findsOneWidget);
        expect(find.byType(WorkoutCompletionCelebration), findsOneWidget);
        expect(LocalStorage.getWorkoutHistory(), hasLength(1));
        expect(LocalStorage.getUserProgress().completedWorkouts, 1);
      },
    );

    testWidgets('showcase mode leaves the real data alone', (tester) async {
      final realProgress = LocalStorage.getUserProgress().toJson();
      await LocalStorage.setShowcaseModeEnabled(true);
      await FitnessProvider.instance.onShowcaseModeToggled(true);

      await _openStrengthSession(tester);
      await _openFinishDialog(tester);
      await tester.tap(find.text('Finish & Save'));
      await _settle(tester, 800);

      // The demo screen finished normally...
      expect(find.byType(WorkoutCompletionCelebration), findsOneWidget);
      // ...and nothing real changed.
      expect(LocalStorage.getWorkoutHistory(), isEmpty);
      expect(LocalStorage.getWorkoutSessions(), isEmpty);
      expect(LocalStorage.getPendingWorkoutRewards(), isEmpty);
      expect(LocalStorage.getUserProgress().toJson(), realProgress);
    });
  });

  group('cardio Finish Session', () {
    Future<void> openCardio(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: CardioSessionScreen(exercise: _cardioExercise)),
      );
      // The button stays disabled for the first seconds.
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Finish Session'),
            )
            .onPressed,
        isNull,
      );
      await tester.pump(const Duration(seconds: 4));
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Finish Session'),
            )
            .onPressed,
        isNotNull,
      );
    }

    testWidgets('saves once, and a second tap does nothing', (tester) async {
      await tester.runAsync(() async {});
      await openCardio(tester);
      final xpBefore = LocalStorage.getUserProgress().totalXP;

      final finish = find.widgetWithText(ElevatedButton, 'Finish Session');
      await tester.tap(finish);
      await tester.tap(finish, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(LocalStorage.getCardioSessions(), hasLength(1));
      expect(find.text('Cardio Completed!'), findsOneWidget);
      final gained = LocalStorage.getUserProgress().totalXP - xpBefore;
      expect(gained, greaterThan(0));
      // The button is disabled while and after saving.
      expect(tester.widget<ElevatedButton>(finish).onPressed, isNull);
    });

    testWidgets('if the handler is called twice, one completion is shown', (
      tester,
    ) async {
      await openCardio(tester);
      final finish = find.widgetWithText(ElevatedButton, 'Finish Session');
      final onPressed = tester.widget<ElevatedButton>(finish).onPressed!;

      // Both calls happen before the screen has rebuilt with the button off.
      onPressed();
      onPressed();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Cardio Completed!'), findsOneWidget);
      expect(LocalStorage.getCardioSessions(), hasLength(1));
    });

    testWidgets('a failed save says so, and the next tap saves it once', (
      tester,
    ) async {
      await openCardio(tester);
      final xpBefore = LocalStorage.getUserProgress().totalXP;
      FitnessProvider.instance.rewardStageHook = (stage) async {
        if (stage == 'cardioSaved') throw StateError('disk full');
      };

      final finish = find.widgetWithText(ElevatedButton, 'Finish Session');
      await tester.tap(finish);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.textContaining('Could not save your session'),
        findsOneWidget,
      );
      expect(find.text('Cardio Completed!'), findsNothing);
      expect(LocalStorage.getUserProgress().totalXP, xpBefore);
      // The button works again.
      expect(tester.widget<ElevatedButton>(finish).onPressed, isNotNull);

      FitnessProvider.instance.rewardStageHook = null;
      await tester.tap(finish);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Cardio Completed!'), findsOneWidget);
      expect(LocalStorage.getCardioSessions(), hasLength(1));
      expect(LocalStorage.getUserProgress().totalXP, greaterThan(xpBefore));
    });

    testWidgets('showcase mode leaves the real data alone', (tester) async {
      final realProgress = LocalStorage.getUserProgress().toJson();
      final realActivities = LocalStorage.getActivityRecords().length;
      await LocalStorage.setShowcaseModeEnabled(true);
      await FitnessProvider.instance.onShowcaseModeToggled(true);

      await openCardio(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Finish Session'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Cardio Completed!'), findsOneWidget);
      expect(LocalStorage.getCardioSessions(), isEmpty);
      expect(LocalStorage.getActivityRecords().length, realActivities);
      expect(LocalStorage.getUserProgress().toJson(), realProgress);
    });
  });
}
