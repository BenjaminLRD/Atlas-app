import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/widgets/common/app_header.dart';
import 'package:atlas/app_theme.dart';

void main() {
  Widget buildTestableHeader(
    Widget child, {
    Size surfaceSize = const Size(320, 640),
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(size: surfaceSize),
        child: Scaffold(
          appBar: child as PreferredSizeWidget,
          body: const SizedBox(),
        ),
      ),
    );
  }

  group('AppHeader Widget Tests', () {
    testWidgets(
      'AppHeader.standard renders without overflow on 320px small screen with long text',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildTestableHeader(
            const AppHeader.standard(
              title: 'Very Long User Name That Might Overflow Small Screens',
              subtitle:
                  'Extremely Long Subtitle Description For Testing Truncation',
              userInitials: 'AG',
              showNotifications: true,
              showSettings: true,
            ),
            surfaceSize: const Size(320, 640),
          ),
        );

        expect(find.byType(AppHeader), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'AppHeader menu button maintains fixed 44x44 dimensions by default',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestableHeader(
            const AppHeader.standard(title: 'Title', subtitle: 'Subtitle'),
          ),
        );

        final menuFinder = find.bySemanticsLabel('Open navigation menu');
        expect(menuFinder, findsOneWidget);
        final size = tester.getSize(menuFinder);
        expect(size.width, equals(44.0));
        expect(size.height, equals(44.0));
      },
    );

    testWidgets(
      'AppHeader onMenuTap callback executes when menu button is tapped',
      (WidgetTester tester) async {
        bool menuTapped = false;
        await tester.pumpWidget(
          buildTestableHeader(
            AppHeader.standard(
              title: 'Title',
              subtitle: 'Subtitle',
              onMenuTap: () {
                menuTapped = true;
              },
            ),
          ),
        );

        final menuFinder = find.byTooltip('Open navigation menu');
        expect(menuFinder, findsOneWidget);
        await tester.tap(menuFinder);
        await tester.pump();

        expect(menuTapped, isTrue);
      },
    );

    testWidgets(
      'AppHeader avatar maintains fixed 44x44 dimensions when showAvatar is true',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestableHeader(
            const AppHeader.standard(
              title: 'Title',
              subtitle: 'Subtitle',
              userInitials: 'JD',
              showAvatar: true,
              showMenuButton: false,
            ),
          ),
        );

        final avatarFinder = find.bySemanticsLabel('User profile avatar');
        expect(avatarFinder, findsOneWidget);
        final size = tester.getSize(avatarFinder);
        expect(size.width, equals(44.0));
        expect(size.height, equals(44.0));
      },
    );

    testWidgets(
      'AppHeader.back renders back button, title, and subtitle cleanly',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildTestableHeader(
            const AppHeader.back(
              title: 'Workout History & Analysis',
              subtitle: 'Detailed breakdown of recent sessions',
            ),
            surfaceSize: const Size(320, 640),
          ),
        );

        expect(find.text('Workout History & Analysis'), findsOneWidget);
        expect(
          find.text('Detailed breakdown of recent sessions'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'AppHeader.centered renders symmetrical action space and title',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestableHeader(
            const AppHeader.centered(title: 'Centered Screen Header'),
          ),
        );

        expect(find.text('Centered Screen Header'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
