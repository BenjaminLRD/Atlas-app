import 'package:atlas/app_theme.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/hydration.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/screens/hydration_screen.dart';
import 'package:atlas/services/hydration/hydration_goal_calculator.dart';
import 'package:atlas/services/hydration/hydration_service.dart';
import 'package:atlas/widgets/hydration/hydration_panels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Rig {
  DateTime clock = DateTime(2026, 11, 18, 15);
  String? disk;
  double? weight = 78.125; // a 2,500 ml baseline
  bool showcase = false;
  List<HydrationActivity> activities = [];
  late HydrationService svc = make();

  HydrationService make() => HydrationService(
    clock: () => clock,
    userId: () => 'u1',
    isShowcase: () => showcase,
    weightKg: () => weight,
    activities: (_) => activities,
    read: () => disk,
    write: (j) async => disk = j,
  );
}

Future<void> _pump(
  WidgetTester tester,
  _Rig rig, {
  Size size = const Size(412, 2600),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: HydrationScreen(service: rig.svc),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
}

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(Key(key))).data!;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    FitnessProvider.resetInstance();
  });

  group('glasses and summary', () {
    testWidgets('an empty day shows ten empty glasses and the full goal', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      expect(find.byKey(const Key('glass_tracker')), findsOneWidget);
      for (var i = 0; i < 10; i++) {
        expect(find.byKey(Key('glass_$i')), findsOneWidget);
      }
      expect(find.byKey(const Key('glass_10')), findsNothing);
      expect(_text(tester, 'glasses_headline'), '0 of 10 glasses');
      expect(_text(tester, 'today_consumed'), '0 ml');
      expect(_text(tester, 'today_goal'), 'of 2.5 L');
      expect(_text(tester, 'today_status'), '2.5 L to go');
    });

    testWidgets('1,000 ml shows 4 glasses drunk and 6 left', (tester) async {
      final rig = _Rig();
      await rig.svc.log(1000);
      await _pump(tester, rig);
      expect(_text(tester, 'glasses_headline'), '4 of 10 glasses');
      expect(
        find.descendant(
          of: find.byKey(const Key('stat_glasses')),
          matching: find.text('4'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('stat_glasses_left')),
          matching: find.text('6'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('stat_percent')),
          matching: find.text('40%'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('stat_remaining')),
          matching: find.text('1.5 L'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('375 ml reads as 1.5 glasses', (tester) async {
      final rig = _Rig();
      await rig.svc.log(375);
      await _pump(tester, rig);
      expect(_text(tester, 'glasses_headline'), '1.5 of 10 glasses');
      expect(_text(tester, 'today_consumed'), '375 ml');
    });

    testWidgets('the 60% example uses the real figures', (tester) async {
      final rig = _Rig();
      await rig.svc.log(1500);
      await _pump(tester, rig);
      expect(_text(tester, 'today_status'), '1 L to go');
      expect(
        find.descendant(
          of: find.byKey(const Key('stat_percent')),
          matching: find.text('60%'),
        ),
        findsOneWidget,
      );
      final fill = tester.getSize(find.byKey(const Key('progress_fill')).first);
      final track = tester.getSize(find.byType(HydrationProgressBar).first);
      expect(fill.width / track.width, closeTo(0.6, 0.02));
    });

    testWidgets('the exact goal and beyond stop the bar at 100% and say so', (
      tester,
    ) async {
      final rig = _Rig();
      await rig.svc.log(2500);
      await _pump(tester, rig);
      expect(_text(tester, 'today_status'), 'Goal reached');
      await rig.svc.log(400);
      await _settle(tester);
      expect(_text(tester, 'today_status'), 'Goal reached, 400 ml over');
      final fill = tester.getSize(find.byKey(const Key('progress_fill')).first);
      final track = tester.getSize(find.byType(HydrationProgressBar).first);
      expect(fill.width, closeTo(track.width, 0.5));
      expect(
        find.descendant(
          of: find.byKey(const Key('stat_percent')),
          matching: find.text('116%'),
        ),
        findsOneWidget,
      );
      expect(_text(tester, 'glasses_headline'), '11.6 of 10 glasses');
    });
  });

  group('logging', () {
    testWidgets('one glass updates everything immediately', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await tester.tap(find.byKey(const Key('add_glass')));
      await _settle(tester);
      expect(_text(tester, 'today_consumed'), '250 ml');
      expect(_text(tester, 'glasses_headline'), '1 of 10 glasses');
      expect(rig.svc.week().totalKnownMl, 250);
      expect(rig.svc.history().first.consumedMl, 250);
    });

    testWidgets('two glasses add 500 ml as one entry', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await tester.tap(find.byKey(const Key('add_two_glasses')));
      await _settle(tester);
      expect(rig.svc.today.entries.single.amountMl, 500);
      expect(_text(tester, 'today_consumed'), '500 ml');
    });

    testWidgets('a double tap records one drink', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await tester.tap(find.byKey(const Key('add_glass')));
      await tester.tap(find.byKey(const Key('add_glass')));
      await _settle(tester);
      expect(rig.svc.today.entries.length, 1);
    });

    testWidgets('a custom amount is logged exactly', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await tester.tap(find.byKey(const Key('add_custom')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('amount_field')), '330');
      await tester.tap(find.byKey(const Key('amount_ok')));
      await tester.pumpAndSettle();
      expect(_text(tester, 'today_consumed'), '330 ml');
      expect(rig.svc.today.entries.single.amountMl, 330);
    });

    testWidgets('an invalid custom amount is refused with a message', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await tester.tap(find.byKey(const Key('add_custom')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('amount_field')), '0');
      await tester.tap(find.byKey(const Key('amount_ok')));
      await tester.pumpAndSettle();
      expect(find.textContaining('whole number'), findsOneWidget);
      expect(rig.svc.today.entries, isEmpty);
    });

    testWidgets('an entry can be removed and every figure follows', (
      tester,
    ) async {
      final rig = _Rig();
      final e = await rig.svc.log(500);
      await _pump(tester, rig);
      expect(find.byKey(Key('entry_${e!.id}')), findsOneWidget);
      await tester.tap(find.byKey(Key('delete_${e.id}')));
      await _settle(tester);
      expect(_text(tester, 'today_consumed'), '0 ml');
      expect(find.byKey(Key('entry_${e.id}')), findsNothing);
    });
  });

  group('the goal', () {
    testWidgets('explains itself and says it is not medical advice', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      expect(_text(tester, 'goal_value'), '2.5 L');
      expect(_text(tester, 'goal_why'), contains('32 ml per kg'));
      expect(find.text('Baseline'), findsOneWidget);
      expect(find.textContaining('not medical advice'), findsOneWidget);
    });

    testWidgets('no weight shows a provisional goal and says what to do', (
      tester,
    ) async {
      final rig = _Rig()..weight = null;
      await _pump(tester, rig);
      expect(find.text('Provisional'), findsOneWidget);
      expect(_text(tester, 'goal_why'), contains('weight'));
      expect(_text(tester, 'today_goal'), 'of 2 L');
    });

    testWidgets(
      'a workout shows an activity-adjusted goal with its breakdown',
      (tester) async {
        final rig = _Rig()
          ..activities = const [
            HydrationActivity(id: 'w', minutes: 60, cardio: false),
          ];
        await _pump(tester, rig);
        expect(find.text('Activity-adjusted'), findsOneWidget);
        expect(
          _text(tester, 'goal_breakdown'),
          'Baseline 2500 ml + activity 300 ml',
        );
        expect(_text(tester, 'goal_value'), '2.8 L');
      },
    );

    testWidgets('the goal can be adjusted and reset', (tester) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await tester.ensureVisible(find.byKey(const Key('goal_adjust')));
      await tester.tap(find.byKey(const Key('goal_adjust')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('amount_field')), '3000');
      await tester.tap(find.byKey(const Key('amount_ok')));
      await tester.pumpAndSettle();
      expect(_text(tester, 'goal_value'), '3 L');
      expect(find.text('Set by you'), findsOneWidget);
      expect(find.byKey(const Key('glass_11')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('goal_reset')));
      await tester.tap(find.byKey(const Key('goal_reset')));
      await tester.pumpAndSettle();
      expect(_text(tester, 'goal_value'), '2.5 L');
    });
  });

  group('week and history', () {
    testWidgets('the week shows each day, today highlighted, total in litres', (
      tester,
    ) async {
      final rig = _Rig();
      await rig.svc.log(1500, at: DateTime(2026, 11, 16, 9));
      await rig.svc.log(750, at: DateTime(2026, 11, 18, 9));
      await _pump(tester, rig);
      expect(_text(tester, 'week_total'), '2.3 L');
      expect(find.textContaining('2 of 7 days recorded'), findsOneWidget);
      for (final k in [
        '2026-11-16',
        '2026-11-17',
        '2026-11-18',
        '2026-11-22',
      ]) {
        expect(find.byKey(Key('week_day_$k')), findsOneWidget);
      }
      for (final label in ['Mon', 'Tue', 'Wed', 'Sun']) {
        expect(find.text(label), findsWidgets);
      }
      // The days with nothing recorded show a dash, not a bar of zero.
      expect(find.byKey(const Key('bar_unknown')), findsWidgets);
    });

    testWidgets('a week over a year boundary is labelled with the month', (
      tester,
    ) async {
      final rig = _Rig()..clock = DateTime(2027, 1, 1, 10);
      await rig.svc.log(500, at: DateTime(2026, 12, 29, 9));
      await _pump(tester, rig);
      expect(find.byKey(const Key('week_day_2026-12-28')), findsOneWidget);
      expect(find.byKey(const Key('week_day_2027-01-03')), findsOneWidget);
      expect(find.text('28 Dec'), findsOneWidget);
      expect(find.text('1 Jan'), findsOneWidget);
    });

    testWidgets('history shows each day with its own recorded goal', (
      tester,
    ) async {
      final rig = _Rig();
      await rig.svc.refreshTodayGoal();
      await rig.svc.log(1000, at: DateTime(2026, 11, 16, 9));
      await _pump(tester, rig);
      expect(
        _text(tester, 'history_goal_2026-11-18'),
        startsWith('Goal 2.5 L'),
      );
      expect(_text(tester, 'history_total_2026-11-16'), '1 L');
      expect(
        _text(tester, 'history_goal_2026-11-16'),
        'Goal for this day not recorded',
      );
    });

    testWidgets('a previous day can be opened, corrected and removed', (
      tester,
    ) async {
      final rig = _Rig();
      final e = await rig.svc.log(1000, at: DateTime(2026, 11, 16, 9));
      await _pump(tester, rig);
      await tester.tap(find.byKey(const Key('history_2026-11-16')));
      await tester.pumpAndSettle();
      expect(_text(tester, 'day_sheet_title'), 'Monday 16 November 2026');
      await tester.tap(find.byKey(Key('edit_${e!.id}')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('amount_field')), '600');
      await tester.tap(find.byKey(const Key('amount_ok')));
      await tester.pumpAndSettle();
      expect(rig.svc.day('2026-11-16').consumedMl, 600);
      expect(rig.svc.week().totalKnownMl, 600);
      await tester.tap(find.byKey(Key('delete_${e.id}')));
      await tester.pumpAndSettle();
      expect(rig.svc.week().totalKnownMl, 0);
      expect(
        _text(tester, 'day_sheet_summary'),
        'Nothing recorded for this day.',
      );
    });

    testWidgets('an empty past day can be confirmed as no water', (
      tester,
    ) async {
      final rig = _Rig();
      await _pump(tester, rig);
      await tester.tap(find.byKey(const Key('week_day_2026-11-17')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_zero')));
      await tester.pumpAndSettle();
      expect(
        rig.svc.day('2026-11-17').status,
        HydrationDayStatus.confirmedZero,
      );
    });
  });

  group('Showcase Mode', () {
    testWidgets('shows labelled sample hydration with the same components', (
      tester,
    ) async {
      final rig = _Rig()
        ..showcase = true
        ..weight = 77.5;
      await _pump(tester, rig);
      expect(find.byKey(const Key('sample_note')), findsOneWidget);
      expect(find.byKey(const Key('glass_tracker')), findsOneWidget);
      expect(find.byKey(const Key('week_total')), findsOneWidget);
      expect(find.textContaining('SAMPLE').evaluate().length, greaterThan(1));
      expect(find.byKey(const Key('bar_unknown')), findsWidgets);
    });

    testWidgets('logging in Showcase writes nothing to the real store', (
      tester,
    ) async {
      final rig = _Rig();
      await rig.svc.log(300);
      final disk = rig.disk;
      rig.showcase = true;
      rig.weight = 77.5;
      await _pump(tester, rig);
      await tester.tap(find.byKey(const Key('add_glass')));
      await _settle(tester);
      expect(rig.disk, disk);
      expect(LocalStorage.getHydrationJson(), isNull);
    });
  });

  group('narrow screens', () {
    for (final size in const [
      Size(320, 2600),
      Size(360, 2600),
      Size(412, 2600),
    ]) {
      testWidgets('fits ${size.width.toInt()} dp with a large goal', (
        tester,
      ) async {
        final rig = _Rig()..weight = 110; // 3.5 L: 14 glasses
        await rig.svc.log(3700);
        await _pump(tester, rig, size: size);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('glass_13')), findsOneWidget);
        expect(find.byKey(const Key('glass_14')), findsNothing);
      });
    }
  });
}
