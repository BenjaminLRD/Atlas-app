import 'package:atlas/app_theme.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/data/profile_provider.dart';
import 'package:atlas/models/workout_session.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/screens/workout_session_screen.dart';
import 'package:atlas/services/challenge_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: const WorkoutSessionScreen(
        workoutName: 'Timer Workout',
        workoutId: 'timer_workout_01',
      ),
    ),
  );
  await _settle(tester);
}

String _shown(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('set_timer_value'))).data!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Duration now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    ProfileProvider().reload();
    FitnessProvider.resetInstance();
    ChallengeService.resetInstance();
    FitnessProvider.instance.refreshAll();
    now = const Duration(hours: 1);
    WorkoutSessionScreen.setClockOverride = () => now;
  });

  tearDown(() => WorkoutSessionScreen.setClockOverride = null);

  Map<String, dynamic> firstSet() {
    final saved = AppDependencies.instance.workoutService.getActiveSession()!;
    final sets = saved.exercisesData!.first['sets'] as List;
    return Map<String, dynamic>.from(sets.first as Map);
  }

  testWidgets(
    'Start Set shows a running timer; Finish Set saves its duration and rest '
    'begins with the set timer gone',
    (tester) async {
      await _open(tester);
      expect(find.byKey(const Key('set_timer_value')), findsNothing);

      await tester.tap(find.textContaining('START SET'));
      await _settle(tester);
      expect(_shown(tester), '00:00');

      // Time passes with rebuilds in between; the display must not reset.
      now += const Duration(seconds: 20);
      await tester.pump(const Duration(milliseconds: 300));
      now += const Duration(seconds: 12);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_shown(tester), '00:32');

      // Backgrounding: paused then resumed; the time is still exact.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now += const Duration(seconds: 8);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_shown(tester), '00:40');

      await tester.tap(find.textContaining('COMPLETE SET'));
      await _settle(tester);

      // Rest has started; the set timer is no longer shown.
      expect(find.byKey(const Key('set_timer_value')), findsNothing);
      final set = firstSet();
      expect(set['completed'], isTrue);
      expect(set['durationSeconds'], 40);

      // The next set is timed on its own, from zero.
      await tester.tap(find.textContaining('START SET 2'));
      await _settle(tester);
      expect(_shown(tester), '00:00');
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('a set started but never finished is not saved as completed', (
    tester,
  ) async {
    await _open(tester);
    await tester.tap(find.textContaining('START SET'));
    await _settle(tester);
    now += const Duration(seconds: 15);
    await tester.pump(const Duration(milliseconds: 300));

    // Leave the screen mid-set.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));

    final set = firstSet();
    expect(set['completed'], isNot(true));
    expect(set.containsKey('durationSeconds'), isFalse);
  });

  test('set duration round-trips and old records without it still load', () {
    const set = WorkoutSessionSet(
      setNumber: 1,
      weight: 40,
      reps: 10,
      completed: true,
      durationSeconds: 32,
    );
    expect(WorkoutSessionSet.fromJson(set.toJson()).durationSeconds, 32);

    final legacy = WorkoutSessionSet.fromJson({
      'setNumber': 2,
      'weight': 40.0,
      'reps': 8,
      'completed': true,
    });
    expect(legacy.durationSeconds, isNull);
    expect(legacy.toJson().containsKey('durationSeconds'), isFalse);
    expect(set.copyWith(reps: 12).durationSeconds, 32);
  });
}
