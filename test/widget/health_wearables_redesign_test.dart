import 'package:atlas/data/local_storage.dart';
import 'package:atlas/screens/health_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(360, 800),
  double textScale = 1.0,
  Brightness brightness = Brightness.dark,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark
          ? ThemeData.dark()
          : ThemeData.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: const HealthDashboardScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  testWidgets('shows the grouped sections and honest empty values', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Health & Wearables'), findsOneWidget);
    expect(find.text('SLEEP & RECOVERY'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('RECOVERY BREAKDOWN'), findsOneWidget);
    expect(find.text('LAST 7 DAYS'), findsOneWidget);
    expect(find.text('DATA SOURCES'), findsOneWidget);
    // No readings: the tiles say so instead of showing zeros or invented data.
    expect(find.text('Distance: --'), findsOneWidget);
    expect(find.text('Resting: --'), findsOneWidget);
    expect(find.text('Deep sleep: --'), findsOneWidget);
    expect(find.text('0 bpm'), findsNothing);
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.byKey(const Key('recovery_unavailable_note')), findsOneWidget);
  });

  testWidgets('the connection badge reflects data, not an assumption', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byKey(const Key('health_connect_status')), findsOneWidget);
    expect(find.text('NO DATA YET'), findsOneWidget);
    expect(find.text('CONNECTED'), findsNothing);
  });

  testWidgets('section headings are not drawn in a near-invisible colour', (
    tester,
  ) async {
    await _pump(tester);
    // On the dark background every heading must be a light colour. The old
    // headings used the light-theme dark text and vanished.
    for (final label in ['TODAY', 'RECOVERY BREAKDOWN', 'LAST 7 DAYS']) {
      final text = tester.widget<Text>(find.text(label));
      final c = text.style!.color!;
      expect(c.computeLuminance(), greaterThan(0.5), reason: label);
    }
    final score = tester.widget<Text>(find.text('Recovery score'));
    expect(score.style!.color!.computeLuminance(), greaterThan(0.5));
  });

  testWidgets('rendering the page writes no health or sleep records', (
    tester,
  ) async {
    await LocalStorage.setShowcaseModeEnabled(true);
    addTearDown(() => LocalStorage.setShowcaseModeEnabled(false));
    final before = LocalStorage.getWorkoutHistory().length;
    await _pump(tester);
    expect(LocalStorage.getWorkoutHistory().length, before);
    expect(tester.takeException(), isNull);
  });

  for (final size in const [Size(320, 640), Size(360, 740), Size(412, 915)]) {
    for (final scale in const [1.0, 1.3, 1.5]) {
      testWidgets('no overflow at ${size.width.toInt()}dp x$scale text', (
        tester,
      ) async {
        await _pump(tester, size: size, textScale: scale);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('light theme renders without errors', (tester) async {
    await _pump(tester, brightness: Brightness.light);
    expect(tester.takeException(), isNull);
  });
}
