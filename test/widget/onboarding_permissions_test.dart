import 'package:atlas/app_theme.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/screens/onboarding/permissions_step.dart';
import 'package:atlas/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Fake implements OnboardingPermissionGateway {
  final Map<OnboardingPermission, PermState> initial;
  final Map<OnboardingPermission, PermState> answer;
  final requests = <OnboardingPermission>[];
  final settings = <OnboardingPermission>[];

  _Fake({
    Map<OnboardingPermission, PermState>? initial,
    Map<OnboardingPermission, PermState>? answer,
  }) : initial = initial ?? {},
       answer = answer ?? {};

  @override
  String get healthName => 'Health Connect';

  @override
  Future<PermState> check(OnboardingPermission p) async =>
      initial[p] ?? PermState.notAsked;

  @override
  Future<PermState> request(OnboardingPermission p) async {
    requests.add(p);
    return answer[p] ?? PermState.granted;
  }

  @override
  Future<void> openSettings(OnboardingPermission p) async => settings.add(p);
}

Future<void> _pump(
  WidgetTester tester,
  OnboardingPermissionGateway g, {
  double width = 390,
  double scale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 900),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(body: OnboardingPermissionsStep(gateway: g)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  testWidgets('it explains each permission and asks for nothing by itself', (
    tester,
  ) async {
    final g = _Fake();
    await _pump(tester, g);
    expect(find.text('Physical activity'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Health Connect'), findsOneWidget);
    expect(
      find.textContaining('Without it, steps show as unavailable'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Used only while you record one'),
      findsOneWidget,
    );
    expect(find.text('OPTIONAL'), findsOneWidget);
    expect(find.byKey(const Key('perm_footer')), findsOneWidget);
    expect(g.requests, isEmpty);
  });

  testWidgets('allowing asks once and shows the result', (tester) async {
    final g = _Fake();
    await _pump(tester, g);
    await tester.tap(find.byKey(const Key('allow_Allow location')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(g.requests, [OnboardingPermission.location]);
    expect(find.byKey(const Key('perm_status_granted')), findsOneWidget);
    expect(find.byKey(const Key('allow_Allow location')), findsNothing);
  });

  testWidgets('already granted shows Allowed and is not asked again', (
    tester,
  ) async {
    final g = _Fake(
      initial: {OnboardingPermission.activity: PermState.granted},
    );
    await _pump(tester, g);
    expect(find.byKey(const Key('perm_status_granted')), findsOneWidget);
    expect(find.byKey(const Key('allow_Allow step counting')), findsNothing);
    expect(g.requests, isEmpty);
  });

  testWidgets('declined is fine and is retried on request only', (
    tester,
  ) async {
    final g = _Fake(answer: {OnboardingPermission.location: PermState.denied});
    await _pump(tester, g);
    await tester.tap(find.byKey(const Key('allow_Allow location')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('perm_status_denied')), findsOneWidget);
    expect(find.textContaining('That is fine'), findsOneWidget);
    expect(g.requests.length, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(g.requests.length, 1);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('permanently denied points to Settings and does not ask', (
    tester,
  ) async {
    final g = _Fake(
      initial: {OnboardingPermission.activity: PermState.permanentlyDenied},
    );
    await _pump(tester, g);
    expect(find.byKey(const Key('perm_status_blocked')), findsOneWidget);
    await tester.tap(find.byKey(const Key('perm_open_settings')));
    await tester.pump();
    expect(g.settings, [OnboardingPermission.activity]);
    expect(g.requests, isEmpty);
  });

  testWidgets('an unavailable integration says so instead of failing', (
    tester,
  ) async {
    final g = _Fake(
      initial: {OnboardingPermission.health: PermState.unavailable},
    );
    await _pump(tester, g);
    expect(find.byKey(const Key('perm_status_unavailable')), findsOneWidget);
    expect(find.textContaining('not available on this phone'), findsOneWidget);
  });

  for (final w in const [320.0, 360.0]) {
    testWidgets('no overflow at ${w.toInt()}dp, text x1.5 and x2', (
      tester,
    ) async {
      for (final s in const [1.5, 2.0]) {
        await _pump(
          tester,
          _Fake(
            initial: {
              OnboardingPermission.activity: PermState.permanentlyDenied,
            },
          ),
          width: w,
          scale: s,
        );
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('onboarding can be completed without allowing anything', (
    tester,
  ) async {
    final g = _Fake();
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: OnboardingScreen(permissionGateway: g),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text("LET'S GET STARTED"));
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Let Atlas use your phone'), findsOneWidget);
    expect(find.byKey(const Key('permissions_skip')), findsOneWidget);
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('Meet Your AI Coach'), findsOneWidget);
    expect(g.requests, isEmpty);
    await tester.tap(find.byKey(const Key('onboarding_back')));
    await tester.pumpAndSettle();
    expect(find.text('Let Atlas use your phone'), findsOneWidget);
  });

  for (final w in const [320.0, 360.0]) {
    testWidgets('every onboarding step fits at ${w.toInt()}dp, text x1.5', (
      tester,
    ) async {
      tester.view.physicalSize = Size(w, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(w, 740),
              textScaler: const TextScaler.linear(1.5),
            ),
            child: OnboardingScreen(permissionGateway: _Fake()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text("LET'S GET STARTED"));
      await tester.pumpAndSettle();
      for (var i = 0; i < 6; i++) {
        expect(tester.takeException(), isNull, reason: 'step $i');
        await tester.tap(find.text('CONTINUE'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Meet Your AI Coach'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
