import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/widgets/ai_chat_button.dart';
import 'package:atlas/widgets/floating_scanner_button.dart';
import 'package:atlas/widgets/floating_action_bubble_stack.dart';

Widget createTestApp(Widget child, {Size size = const Size(390, 844)}) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(
        body: Stack(
          children: [
            const Center(child: Text('Main Screen Content')),
            Positioned(
              bottom: 80,
              right: 18,
              child: child,
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. FloatingScannerButton UI & Styling Tests', () {
    testWidgets('FloatingScannerButton renders with circle shape and qr_code_scanner icon', (tester) async {
      await tester.pumpWidget(createTestApp(const FloatingScannerButton(size: 40.0)));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(FloatingScannerButton), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsOneWidget);

      final buttonFinder = find.byType(FloatingScannerButton);
      final size = tester.getSize(buttonFinder);
      expect(size.width, equals(40.0));
      expect(size.height, equals(40.0));
    });

    testWidgets('FloatingScannerButton responds to user tap with callback', (tester) async {
      int tapCount = 0;
      await tester.pumpWidget(
        createTestApp(
          FloatingScannerButton(
            size: 40.0,
            onCustomTap: () => tapCount++,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(find.byType(FloatingScannerButton));
      await tester.pump(const Duration(milliseconds: 200));

      expect(tapCount, equals(1));
    });
  });

  group('2. FloatingActionBubbleStack Layout & Spacing Tests', () {
    testWidgets('Renders FloatingScannerButton stacked vertically above AiChatButton with 8dp spacing', (tester) async {
      await tester.pumpWidget(createTestApp(const FloatingActionBubbleStack()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(FloatingScannerButton), findsOneWidget);
      expect(find.byType(AiChatButton), findsOneWidget);

      final scannerRect = tester.getRect(find.byType(FloatingScannerButton));
      final chatRect = tester.getRect(find.byType(AiChatButton));

      // Verify vertical stacking: scanner button is above chat button
      expect(scannerRect.bottom, lessThan(chatRect.top));
      expect(chatRect.top - scannerRect.bottom, closeTo(8.0, 0.5));

      // Verify scanner button is smaller than AI chat button (40dp < 52dp)
      expect(scannerRect.width, lessThan(chatRect.width));
      expect(scannerRect.width, equals(40.0));
      expect(chatRect.width, greaterThanOrEqualTo(52.0));
    });
  });

  group('3. Multi-Device Viewport Responsiveness Tests', () {
    final viewports = [
      const Size(320, 568), // Small device (iPhone SE 1st gen)
      const Size(360, 640), // Compact Android
      const Size(390, 844), // Standard iPhone 14
      const Size(412, 915), // Flagship Android
    ];

    for (final size in viewports) {
      testWidgets('FloatingActionBubbleStack renders cleanly on ${size.width}x${size.height} without overflow', (tester) async {
        await tester.pumpWidget(
          createTestApp(const FloatingActionBubbleStack(), size: size),
        );
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(FloatingActionBubbleStack), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
