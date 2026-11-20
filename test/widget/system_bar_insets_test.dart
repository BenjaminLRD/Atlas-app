import 'package:atlas/app_theme.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/data/profile_provider.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/screens/dashboard_screen.dart';
import 'package:atlas/widgets/common/app_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Android 15+ draws apps edge to edge, so the status bar overlaps anything
/// that is not padded by its inset.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
  });

  void setInsets(WidgetTester tester, Size size, double top, double bottom) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
    tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
    addTearDown(tester.view.reset);
  }

  const configs = [
    (Size(360, 640), 24.0, 0.0), // small phone, 3-button navigation
    (Size(411, 891), 40.0, 24.0), // tall phone, gesture bar
    (Size(412, 915), 48.0, 34.0), // large status bar / cutout
  ];

  for (final (size, top, bottom) in configs) {
    testWidgets('Summary header sits below a ${top.toInt()}px status bar on '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      setInsets(tester, size, top, bottom);
      await LocalStorage.saveUserProfile(
        UserProfile.defaultProfile().copyWith(name: 'Lal'),
      );
      ProfileProvider().reload();

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.darkTheme, home: const DashboardScreen()),
      );

      final header = find.byType(AppHeader);
      expect(header, findsOneWidget);
      // Everything in the header must start below the status bar.
      final headerContent = find.descendant(
        of: header,
        matching: find.byType(Text),
      );
      expect(headerContent, findsWidgets);
      for (final element in headerContent.evaluate()) {
        final rect = tester.getRect(find.byWidget(element.widget));
        expect(rect.top, greaterThanOrEqualTo(top));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('AppHeader opting out of the safe area is not padded', (
    tester,
  ) async {
    // Documents why the Summary screen must not pass useSafeArea: false.
    setInsets(tester, const Size(360, 740), 40, 24);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppHeader.standard(
            title: 'Title',
            userInitials: 'L',
            useSafeArea: false,
          ),
        ),
      ),
    );
    expect(tester.getTopLeft(find.text('Title')).dy, lessThan(40));
  });
}
