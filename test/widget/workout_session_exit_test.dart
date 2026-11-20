import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/data/profile_provider.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/screens/workout_overview_screen.dart';
import 'package:atlas/screens/workout_session_screen.dart';
import 'package:atlas/main.dart';
import 'package:atlas/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    ProfileProvider().reload();
  });

  group('WorkoutSessionScreen Exit & Lifecycle Tests', () {
    testWidgets(
      'Opening Exit confirmation dialog and tapping Cancel keeps user on WorkoutSessionScreen',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: WorkoutSessionScreen()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Tap X button
        final closeButtonFinder = find.byIcon(Icons.close_rounded);
        expect(closeButtonFinder, findsOneWidget);

        await tester.tap(closeButtonFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify dialog is open
        expect(find.text('Pause & Exit Workout?'), findsOneWidget);
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Exit'), findsOneWidget);

        // Tap Cancel
        await tester.tap(find.text('Cancel'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Verify dialog is closed and WorkoutSessionScreen remains
        expect(find.text('Pause & Exit Workout?'), findsNothing);
        expect(find.byType(WorkoutSessionScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Tapping Exit in pushed WorkoutSessionScreen actually pops navigation stack',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WorkoutSessionScreen(
                          workoutName: 'Test Push Workout',
                          workoutId: 'test_push_01',
                        ),
                      ),
                    );
                  },
                  child: const Text('Start Session'),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Push WorkoutSessionScreen
        await tester.tap(find.text('Start Session'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(WorkoutSessionScreen), findsOneWidget);

        // Complete 1 set
        final startSetFinder = find.textContaining('START SET');
        expect(startSetFinder, findsOneWidget);
        await tester.tap(startSetFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        final completeSetFinder = find.textContaining('COMPLETE SET');
        expect(completeSetFinder, findsOneWidget);
        await tester.tap(completeSetFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Tap X button to open exit dialog
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Pause & Exit Workout?'), findsOneWidget);

        // Tap Exit (AppButton has scale animation before calling onPressed)
        await tester.tap(find.text('Exit'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        // Verify WorkoutSessionScreen is popped and caller screen is visible
        expect(find.byType(WorkoutSessionScreen), findsNothing);
        expect(find.text('Start Session'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Verify active session progress was saved
        final savedSession = AppDependencies.instance.workoutService
            .getActiveSession();
        expect(savedSession, isNotNull);
        expect(savedSession?.workoutName, equals('Test Push Workout'));
        expect(savedSession?.completedSets.first.first, isTrue);
      },
    );

    testWidgets(
      'Workouts tab opens the overview, not a running session, and exiting a '
      'pushed session returns to it',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.darkTheme, home: const MainShell()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Workouts'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // The tab no longer drops the user straight into a session.
        expect(find.byType(WorkoutOverviewScreen), findsOneWidget);
        expect(find.byType(WorkoutSessionScreen), findsNothing);
        expect(find.textContaining('START SET'), findsNothing);

        // A session pushed from the overview exits back to it.
        final nav = Navigator.of(
          tester.element(find.byType(WorkoutOverviewScreen)),
        );
        nav.push(
          MaterialPageRoute(builder: (_) => const WorkoutSessionScreen()),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.textContaining('START SET'), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Exit'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(WorkoutSessionScreen), findsNothing);
        expect(find.byType(WorkoutOverviewScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Early exit saves progress without marking workout completed or awarding rewards',
      (WidgetTester tester) async {
        final initialHistoryCount = AppDependencies.instance.workoutService
            .getWorkoutHistory()
            .length;

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WorkoutSessionScreen(
                          workoutName: 'Early Exit Test',
                          workoutId: 'early_exit_01',
                        ),
                      ),
                    );
                  },
                  child: const Text('Start Session'),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await tester.tap(find.text('Start Session'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap X and Exit early
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Exit'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Verify no new completed history record was added
        final finalHistoryCount = AppDependencies.instance.workoutService
            .getWorkoutHistory()
            .length;
        expect(finalHistoryCount, equals(initialHistoryCount));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Rest timer cancels cleanly on early exit without setState errors',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WorkoutSessionScreen(
                          workoutName: 'Rest Timer Exit Test',
                          workoutId: 'rest_exit_01',
                        ),
                      ),
                    );
                  },
                  child: const Text('Start Session'),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await tester.tap(find.text('Start Session'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Complete a set to trigger rest timer
        await tester.tap(find.textContaining('START SET'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await tester.tap(find.textContaining('COMPLETE SET'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Verify rest timer is active
        expect(find.textContaining('REST TIMER'), findsOneWidget);

        // Exit early during rest timer
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('Exit'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Verify no setState after dispose exceptions
        expect(tester.takeException(), isNull);
      },
    );
  });
}
