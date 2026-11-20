import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/screens/onboarding_screen.dart';
import 'package:atlas/widgets/common/atlas_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    AppDependencies.reset();
  });

  testWidgets('onboarding welcome uses the shared Atlas AI logo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await tester.pump();

    expect(find.byType(AtlasLogoMark), findsOneWidget);
    expect(find.byType(AtlasWordmark), findsOneWidget);
    // The old lightning-bolt emblem is gone from the welcome step.
    expect(
      find.descendant(
        of: find.byType(OnboardingScreen),
        matching: find.byIcon(Icons.bolt_rounded),
      ),
      findsNothing,
    );
    // Existing actions are untouched.
    expect(find.text('⚡ TRY SHOWCASE MODE (NO SIGNUP)'), findsOneWidget);
    expect(find.text('Already have an account? Log In'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
