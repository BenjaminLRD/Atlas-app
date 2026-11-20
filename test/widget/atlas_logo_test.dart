import 'package:atlas/screens/splash_screen.dart';
import 'package:atlas/widgets/common/atlas_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('logo mark keeps its size and is labelled for accessibility', (
    tester,
  ) async {
    for (final size in [24.0, 38.0, 112.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: AtlasLogoMark(size: size, glow: size > 100),
          ),
        ),
      );
      expect(tester.getSize(find.byType(AtlasLogoMark)), Size(size, size));
      expect(find.bySemanticsLabel('Atlas AI logo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('wordmark shows ATLAS in light text and AI in green', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: AtlasWordmark())),
    );
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byType(AtlasWordmark),
        matching: find.byType(Text),
      ),
    );
    final spans = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect(spans.map((s) => s.text), ['ATLAS ', 'AI']);
    expect(spans[0].style!.color, isNot(spans[1].style!.color));
  });

  testWidgets('splash screen shows the logo instead of the old bolt', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump();
    expect(find.byType(AtlasLogoMark), findsOneWidget);
    expect(find.byIcon(Icons.bolt_rounded), findsNothing);
    // Let the splash timers run out so no timers are left pending.
    await tester.pump(const Duration(seconds: 3));
  });
}
