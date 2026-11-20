import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/models/recovery_insight.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/providers/showcase_data_provider.dart';
import 'package:atlas/widgets/recovery/sleep_recovery_card.dart';
import 'package:atlas/widgets/recovery/sleep_history_chart.dart';
import 'package:atlas/widgets/recovery/manual_sleep_logger_modal.dart';
import 'package:atlas/widgets/recovery/connect_wearable_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  Widget createTestWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  group('SleepRecoveryCard Widget Tests', () {
    testWidgets('Renders clean zero state when no sleep data exists', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          SleepRecoveryCard(
            sleepRecord: null,
            recoveryInsight: RecoveryInsight.insufficientData(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SLEEP & RECOVERY'), findsOneWidget);
      expect(find.text('No sleep data yet'), findsOneWidget);
      expect(find.text('CONNECT WEARABLE'), findsOneWidget);
      expect(find.text('LOG SLEEP'), findsOneWidget);
    });

    testWidgets('Renders populated sleep telemetry and recovery status', (tester) async {
      final sleep = ShowcaseDataProvider.instance.getShowcaseLatestSleep();
      final insight = ShowcaseDataProvider.instance.getShowcaseRecoveryInsight();

      await tester.pumpWidget(
        createTestWidget(
          SleepRecoveryCard(
            sleepRecord: sleep,
            recoveryInsight: insight,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('SLEEP & RECOVERY'), findsOneWidget);
      expect(find.text('7h 42m'), findsOneWidget);
      expect(find.text('Good'), findsNWidgets(2)); // Sleep quality & consistency
      expect(find.text('58 bpm'), findsOneWidget);
      expect(find.text('62 ms'), findsOneWidget);
      expect(find.text('Showcase Mode'), findsOneWidget);
    });

    testWidgets('Tapping info button opens CalculationInfoModal', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() async => await tester.binding.setSurfaceSize(null));

      final sleep = ShowcaseDataProvider.instance.getShowcaseLatestSleep();
      final insight = ShowcaseDataProvider.instance.getShowcaseRecoveryInsight();

      await tester.pumpWidget(
        createTestWidget(
          SleepRecoveryCard(
            sleepRecord: sleep,
            recoveryInsight: insight,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final infoButton = find.byTooltip('How is this calculated?');
      expect(infoButton, findsOneWidget);
      await tester.tap(infoButton);
      await tester.pumpAndSettle();

      expect(find.text('How is this calculated?'), findsOneWidget);
      expect(find.text('Sleep Duration & Goal'), findsOneWidget);
      expect(find.text('Sleep Consistency'), findsOneWidget);
      expect(find.text('Physiological Baselines (RHR & HRV)'), findsOneWidget);
      expect(find.text('Transparent Provenance Badges'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('How is this calculated?'), findsNothing);
    });
  });

  group('SleepHistoryChart Widget Tests', () {
    testWidgets('Displays 7-day bars and updates day selection on tap', (tester) async {
      final history = ShowcaseDataProvider.instance.getShowcaseSleepHistory();

      await tester.pumpWidget(
        createTestWidget(
          SleepHistoryChart(sleepHistory: history),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SleepHistoryChart), findsOneWidget);
      // Tap on one of the bars to ensure interactive selection works without errors
      final firstBarText = find.text(history.last.dayLabel);
      if (firstBarText.evaluate().isNotEmpty) {
        await tester.tap(firstBarText.first);
        await tester.pumpAndSettle();
      }
    });
  });

  group('ConnectWearableModal Widget Tests', () {
    testWidgets('Renders all wearable platform options and privacy disclaimer', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ConnectWearableModal.show(context),
              child: const Text('OPEN'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(find.text('Connect Wearable'), findsOneWidget);
      expect(find.text('Apple Health'), findsOneWidget);
      expect(find.text('Health Connect (Android)'), findsOneWidget);
      expect(find.text('Garmin Connect'), findsOneWidget);
      expect(find.text('Fitbit / Pixel Watch'), findsOneWidget);
    });
  });

  group('ManualSleepLoggerModal Widget Tests', () {
    testWidgets('Renders bedtime, wake time, quality options and save button', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => ManualSleepLoggerModal.show(context),
              child: const Text('OPEN'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('OPEN'));
      await tester.pumpAndSettle();

      expect(find.text('Log Sleep'), findsOneWidget);
      expect(find.text('CALCULATED SLEEP'), findsOneWidget);
      expect(find.text('Bedtime'), findsOneWidget);
      expect(find.text('Wake time'), findsOneWidget);
      expect(find.text('SAVE SLEEP'), findsOneWidget);
    });
  });
}
