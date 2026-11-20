import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/models/motivational_quote.dart';
import 'package:atlas/widgets/common/motivational_quote_bottom_sheet.dart';
import 'package:atlas/widgets/common/app_image.dart';
import 'package:atlas/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MotivationalQuote Data Integrity & Media Binding Tests', () {
    final catalog = MotivationalQuote.defaultCatalog();

    test('Default catalog contains verified curated quotes', () {
      expect(catalog.length, greaterThanOrEqualTo(5));
      for (final quote in catalog) {
        expect(quote.id.isNotEmpty, isTrue);
        expect(quote.characterName.isNotEmpty, isTrue);
        expect(quote.characterSource.isNotEmpty, isTrue);
        expect(quote.quoteText.isNotEmpty, isTrue);
        expect(quote.highlightText.isNotEmpty, isTrue);
        expect(quote.avatarSymbol.isNotEmpty, isTrue);
        expect(quote.powerTag.isNotEmpty, isTrue);
      }
    });

    test(
      'No quote resolves to an exercise library image or generic gym photo',
      () {
        for (final quote in catalog) {
          if (quote.assetPath != null) {
            expect(quote.assetPath, startsWith('assets/quotes/'));
            expect(quote.assetPath, isNot(contains('assets/exercises/')));
            expect(quote.assetPath, isNot(contains('bench_press')));
            expect(quote.assetPath, isNot(contains('squat')));
            expect(quote.assetPath, isNot(contains('deadlift')));
          }
          if (quote.imageUrl != null) {
            expect(
              quote.imageUrl,
              isNot(contains('photo-1517838277536-f5f99be501cd')),
            );
            expect(
              quote.imageUrl,
              isNot(contains('photo-1534438327276-14e5300c3a48')),
            );
            expect(
              quote.imageUrl,
              isNot(contains('photo-1581009146145-b5ef050c2e1e')),
            );
            expect(
              quote.imageUrl,
              isNot(contains('photo-1541534741688-6078c6bfb5c5')),
            );
          }
        }
      },
    );

    test(
      'All local character quote assets exist on disk without broken paths',
      () {
        final quotesWithAssets = catalog
            .where((q) => q.assetPath != null)
            .toList();
        expect(quotesWithAssets.length, greaterThanOrEqualTo(5));

        for (final quote in quotesWithAssets) {
          final path = quote.assetPath!;
          final file = File(path);
          expect(
            file.existsSync(),
            isTrue,
            reason:
                'Asset file for ${quote.characterName} at "$path" must exist on disk.',
          );
        }
      },
    );

    test(
      'Specific character quotes bind to their exact 1:1 character assets',
      () {
        final goku = catalog.firstWhere((q) => q.id == 'quote_goku');
        expect(goku.characterName, 'Goku');
        expect(goku.characterSource, 'Dragon Ball');
        expect(goku.assetPath, 'assets/quotes/goku.jpg');
        expect(goku.hasDedicatedAsset, isTrue);

        final naruto = catalog.firstWhere((q) => q.id == 'quote_naruto');
        expect(naruto.characterName, 'Naruto Uzumaki');
        expect(naruto.characterSource, 'Naruto');
        expect(naruto.assetPath, 'assets/quotes/naruto.png');
        expect(naruto.hasDedicatedAsset, isTrue);

        final saitama = catalog.firstWhere((q) => q.id == 'quote_saitama');
        expect(saitama.characterName, 'Saitama');
        expect(saitama.characterSource, 'One Punch Man');
        expect(saitama.assetPath, 'assets/quotes/saitama.jpg');
        expect(saitama.hasDedicatedAsset, isTrue);

        final garou = catalog.firstWhere((q) => q.id == 'quote_garou');
        expect(garou.characterName, 'Garou');
        expect(garou.characterSource, 'One Punch Man');
        expect(garou.assetPath, 'assets/quotes/garou.jpg');
        expect(garou.hasDedicatedAsset, isTrue);

        final allmight = catalog.firstWhere((q) => q.id == 'quote_allmight');
        expect(allmight.characterName, 'All Might');
        expect(allmight.characterSource, 'My Hero Academia');
        expect(allmight.assetPath, 'assets/quotes/allmight.jpg');
        expect(allmight.hasDedicatedAsset, isTrue);
      },
    );

    test(
      'Quotes without dedicated image assets cleanly use placeholder mode',
      () {
        final bruceLee = catalog.firstWhere((q) => q.id == 'quote_bruce_lee');
        expect(bruceLee.characterName, 'Bruce Lee');
        expect(bruceLee.hasDedicatedAsset, isFalse);
        expect(bruceLee.assetPath, isNull);
        expect(bruceLee.imageUrl, isNull);

        final marcus = catalog.firstWhere(
          (q) => q.id == 'quote_marcus_aurelius',
        );
        expect(marcus.characterName, 'Marcus Aurelius');
        expect(marcus.hasDedicatedAsset, isFalse);
        expect(marcus.assetPath, isNull);

        final arnold = catalog.firstWhere((q) => q.id == 'quote_arnold');
        expect(arnold.characterName, 'Arnold Schwarzenegger');
        expect(arnold.hasDedicatedAsset, isFalse);
        expect(arnold.assetPath, isNull);
      },
    );
  });

  group('MotivationalQuoteBottomSheet UI & Interaction Tests', () {
    testWidgets(
      'Renders quote character image when dedicated asset is present',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: MotivationalQuoteBottomSheet(
                initialIndex: 0, // Goku
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('QUOTE OF THE DAY'), findsOneWidget);
        expect(find.text('Goku'), findsOneWidget);
        expect(find.text('•  Dragon Ball'), findsOneWidget);
        expect(find.byType(AppImage), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Renders dedicated quote placeholder when asset is missing or null',
      (WidgetTester tester) async {
        const customPlaceholderQuote = MotivationalQuote(
          id: 'test_placeholder_quote',
          characterName: 'Seneca',
          characterSource: 'Letters from a Stoic',
          quoteText: 'We suffer more often in imagination than in reality.',
          highlightText: 'imagination',
          avatarSymbol: '🏛',
          powerTag: 'STOIC WISDOM',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(
              body: MotivationalQuoteBottomSheet(
                quotes: [customPlaceholderQuote],
                initialIndex: 0,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('SENECA'), findsOneWidget);
        expect(find.text('🏛'), findsOneWidget);
        expect(find.text('STOIC WISDOM'), findsOneWidget);
        expect(find.text('•  Letters from a Stoic'), findsOneWidget);
        // Verify no AppImage rendered because dedicated placeholder container is used
        expect(find.byType(AppImage), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Tapping "Another Quote" button deterministically updates quote and image/placeholder',
      (WidgetTester tester) async {
        final catalog = MotivationalQuote.defaultCatalog();

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: MotivationalQuoteBottomSheet(
                quotes: catalog,
                initialIndex: 0,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Index 0: Goku
        expect(find.text('Goku'), findsOneWidget);
        expect(find.text('•  Dragon Ball'), findsOneWidget);
        expect(find.byType(AppImage), findsOneWidget);

        // Tap Another Quote -> Index 1: Naruto
        await tester.tap(find.text('Another Quote'));
        await tester.pumpAndSettle();

        expect(find.text('Naruto Uzumaki'), findsOneWidget);
        expect(find.text('•  Naruto'), findsOneWidget);
        expect(find.byType(AppImage), findsOneWidget);

        // Tap Another Quote -> Index 2: Saitama
        await tester.tap(find.text('Another Quote'));
        await tester.pumpAndSettle();

        expect(find.text('Saitama'), findsOneWidget);
        expect(find.text('•  One Punch Man'), findsOneWidget);
        expect(find.byType(AppImage), findsOneWidget);

        // Advance until Bruce Lee (Dedicated Placeholder)
        final bruceIndex = catalog.indexWhere((q) => q.id == 'quote_bruce_lee');
        // Advance remaining steps to reach Bruce Lee
        for (int i = 3; i <= bruceIndex; i++) {
          await tester.tap(find.text('Another Quote'));
          await tester.pumpAndSettle();
        }

        expect(find.text('Bruce Lee'), findsOneWidget);
        expect(find.text('BRUCE LEE'), findsOneWidget);
        expect(find.text('龍'), findsOneWidget);
        expect(find.text('UNYIELDING WILL'), findsOneWidget);
        expect(find.byType(AppImage), findsNothing);

        expect(tester.takeException(), isNull);
      },
    );

    const viewports = [
      Size(320, 800),
      Size(360, 800),
      Size(390, 844),
      Size(412, 915),
    ];

    for (final size in viewports) {
      testWidgets(
        'MotivationalQuoteBottomSheet renders without overflow at ${size.width}x${size.height}',
        (WidgetTester tester) async {
          tester.view.physicalSize = Size(size.width * 2, size.height * 2);
          tester.view.devicePixelRatio = 2.0;

          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: MotivationalQuoteBottomSheet(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('QUOTE OF THE DAY'), findsOneWidget);
          expect(find.text('Another Quote'), findsOneWidget);
          expect(find.text('Share'), findsOneWidget);
          expect(tester.takeException(), isNull);

          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        },
      );
    }
  });
}
