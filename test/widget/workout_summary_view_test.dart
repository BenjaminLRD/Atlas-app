import 'package:atlas/app_theme.dart';
import 'package:atlas/services/exercise/muscle_map.dart';
import 'package:atlas/services/workout_summary.dart';
import 'package:atlas/widgets/workout/workout_summary_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSummaryData _data({
  double? volume = 12450,
  int? calories = 320,
  int? xp = 120,
  int? streak = 3,
  double? avgSet = 35,
  List<SummaryPersonalRecord> prs = const [
    SummaryPersonalRecord(
      exerciseName: 'Barbell Bench Press',
      type: 'Heaviest Lift',
      valueText: '145.5 kg',
      improvementPercent: 3.9,
    ),
  ],
  int setsCompleted = 9,
  DateTime? end,
}) {
  final start = DateTime(2026, 11, 16, 16, 30);
  return WorkoutSummaryData(
    workoutName: 'Push Day',
    completedAt: end ?? DateTime(2026, 11, 16, 17, 15),
    startTime: start,
    endTime: end ?? DateTime(2026, 11, 16, 17, 15),
    duration: const Duration(minutes: 45),
    exercisesCompleted: 3,
    exercisesTotal: 4,
    setsCompleted: setsCompleted,
    setsTotal: 12,
    totalVolumeKg: volume,
    caloriesEstimate: calories,
    xpEarned: xp,
    personalRecords: prs,
    streakDays: streak,
    averageSetSeconds: avgSet,
    muscles: MuscleMap.fromNames(['Chest', 'Triceps'], ['Front Deltoids']),
  );
}

Future<void> _pump(
  WidgetTester tester,
  WorkoutSummaryData data, {
  double width = 400,
  VoidCallback? onFinish,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: WorkoutSummaryView(data: data, onFinish: onFinish ?? () {}),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('shows the workout, date, time, counts and volume', (
    tester,
  ) async {
    await _pump(tester, _data());
    expect(find.textContaining('Well done'), findsOneWidget);
    expect(find.textContaining('Push Day'), findsOneWidget);
    expect(find.text('Mon 16 Nov 2026'), findsOneWidget);
    expect(find.text('16:30'), findsOneWidget);
    expect(find.text('17:15'), findsOneWidget);
    expect(find.text('45m 00s'), findsOneWidget);
    expect(find.text('3/4'), findsOneWidget);
    expect(find.text('9/12'), findsOneWidget);
    expect(find.text('12,450 kg'), findsOneWidget);
    expect(find.text('320 kcal'), findsOneWidget);
    expect(find.text('+120'), findsOneWidget);
    expect(find.text('35s'), findsOneWidget);
  });

  testWidgets('a real PR is prominent and listed with its improvement', (
    tester,
  ) async {
    await _pump(tester, _data());
    expect(find.byKey(const Key('summary_pr')), findsOneWidget);
    expect(find.text('145.5 kg'), findsNWidgets(2)); // tile and list
    expect(find.byKey(const Key('summary_pr_list')), findsOneWidget);
    expect(find.text('+3.9%'), findsOneWidget);
  });

  testWidgets('a real streak is shown with its days', (tester) async {
    await _pump(tester, _data());
    expect(find.byKey(const Key('summary_streak')), findsOneWidget);
    expect(find.text('3 days'), findsOneWidget);
    await _pump(tester, _data(streak: 1));
    expect(find.text('1 day'), findsOneWidget);
  });

  testWidgets('no PR and no streak are shown when there are none', (
    tester,
  ) async {
    await _pump(tester, _data(prs: const [], streak: null));
    expect(find.byKey(const Key('summary_pr')), findsNothing);
    expect(find.byKey(const Key('summary_pr_list')), findsNothing);
    expect(find.byKey(const Key('summary_streak')), findsNothing);
    expect(find.textContaining('PR'), findsNothing);
    expect(find.textContaining('days'), findsNothing);
  });

  testWidgets('unknown values stay unknown, a real zero stays 0', (
    tester,
  ) async {
    await _pump(
      tester,
      _data(
        volume: null,
        calories: null,
        xp: null,
        avgSet: null,
        setsCompleted: 0,
      ),
    );
    // Volume and calories are dashes, not 0.
    for (final key in ['summary_volume', 'summary_calories']) {
      expect(
        find.descendant(of: find.byKey(Key(key)), matching: find.text('—')),
        findsOneWidget,
        reason: key,
      );
    }
    expect(find.textContaining('0 kg'), findsNothing);
    expect(find.textContaining('0 kcal'), findsNothing);
    // Tiles that have nothing to say are left out.
    expect(find.byKey(const Key('summary_xp')), findsNothing);
    expect(find.byKey(const Key('summary_avg_set')), findsNothing);
    // Finished sets really are zero.
    expect(find.text('0/12'), findsOneWidget);
  });

  testWidgets('lists the muscles that were worked', (tester) async {
    await _pump(tester, _data());
    final muscles = find.byKey(const Key('summary_muscles'));
    expect(
      find.descendant(of: muscles, matching: find.text('Chest')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: muscles, matching: find.text('Front delts')),
      findsOneWidget,
    );
  });

  testWidgets('Finish calls back, and the layout fits a narrow phone', (
    tester,
  ) async {
    var finished = 0;
    await _pump(tester, _data(), width: 320, onFinish: () => finished++);
    expect(tester.takeException(), isNull);
    final finish = find.byKey(const Key('summary_finish'));
    await tester.tap(finish);
    // The button animates before it acts.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(finished, 1);
  });

  test('formatters', () {
    expect(WorkoutSummaryView.formatVolume(1234567), '1,234,567 kg');
    expect(WorkoutSummaryView.formatVolume(980), '980 kg');
    expect(
      WorkoutSummaryView.formatDuration(const Duration(minutes: 75)),
      '1h 15m',
    );
    expect(WorkoutSummaryView.formatDuration(const Duration(seconds: 9)), '9s');
  });
}
