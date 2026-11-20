import 'dart:io';

import 'package:atlas/app_theme.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/screens/edit_profile_screen.dart';
import 'package:atlas/services/profile_photo_store.dart';
import 'package:atlas/widgets/app_drawer.dart';
import 'package:atlas/widgets/common/app_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A valid 1x1 PNG.
const List<int> _png = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

bool _isFileImage(Widget w) => w is Image && w.image is FileImage;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    tmp = Directory.systemTemp.createTempSync('atlas_avatar_');
  });

  tearDown(() {
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('profile picture display', () {
    test('a device path is a local file, a web address is not', () {
      expect(AppImage.isLocalFilePath('/data/user/0/app/cache/a.jpg'), isTrue);
      expect(AppImage.isLocalFilePath('C:\\Users\\x\\a.png'), isTrue);
      expect(AppImage.isLocalFilePath('https://x.test/a.png'), isFalse);
      expect(AppImage.isLocalFilePath('assets/a.png'), isFalse);
      expect(AppImage.isLocalFilePath('  '), isFalse);
    });

    testWidgets('a picked photo (a file path) is drawn, not the fallback', (
      tester,
    ) async {
      final f = File('${tmp.path}/pick.png')..writeAsBytesSync(_png);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AppImage.avatar(imageUrl: f.path, radius: 20)),
        ),
      );
      expect(find.byWidgetPredicate(_isFileImage), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsNothing);
    });

    testWidgets('no photo shows the default avatar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AppImage.avatar(imageUrl: null, radius: 20)),
        ),
      );
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      expect(find.byWidgetPredicate(_isFileImage), findsNothing);
    });

    testWidgets('a missing or broken file falls back gracefully', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final bad = File('${tmp.path}/broken.png')..writeAsBytesSync([1, 2, 3]);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  AppImage.avatar(imageUrl: '${tmp.path}/gone.png', radius: 20),
                  AppImage.avatar(imageUrl: bad.path, radius: 20),
                ],
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      });
      expect(find.byIcon(Icons.person_rounded), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the avatar is a circle of the requested size', (tester) async {
      final f = File('${tmp.path}/pick.png')..writeAsBytesSync(_png);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: AppImage.avatar(imageUrl: f.path, radius: 20)),
          ),
        ),
      );
      expect(tester.getSize(find.byType(AppImage)), const Size(40, 40));
      expect(find.byType(ClipRRect), findsWidgets);
    });

    testWidgets('the drawer avatar follows the saved profile picture '
        'immediately and after a restart', (tester) async {
      final f = File('${tmp.path}/pick.png')..writeAsBytesSync(_png);
      final profile = AppDependencies.instance.profileProvider;
      await profile.updateField('profilePic', '');
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: AppDrawer()),
        ),
      );
      await tester.pump();
      expect(find.byWidgetPredicate(_isFileImage), findsNothing);

      await profile.updateField('profilePic', f.path);
      await tester.pump();
      expect(find.byWidgetPredicate(_isFileImage), findsOneWidget);

      // Reopening the app reads the same stored path.
      profile.reload();
      expect(profile.displayProfilePic, f.path);
      await tester.pump();
      expect(find.byWidgetPredicate(_isFileImage), findsOneWidget);
    });

    testWidgets('Showcase shows the generic avatar and keeps the real photo', (
      tester,
    ) async {
      final f = File('${tmp.path}/pick.png')..writeAsBytesSync(_png);
      final profile = AppDependencies.instance.profileProvider;
      await profile.updateField('profilePic', f.path);
      await LocalStorage.setShowcaseModeEnabled(true);
      addTearDown(() => LocalStorage.setShowcaseModeEnabled(false));
      expect(profile.displayProfilePic, isEmpty);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: AppDrawer()),
        ),
      );
      await tester.pump();
      expect(find.byWidgetPredicate(_isFileImage), findsNothing);
      // The real photo is untouched underneath.
      expect(profile.profilePic, f.path);
    });
  });

  group('keeping the picked photo', () {
    test('copies it into the profile folder and drops older copies', () async {
      final a = File('${tmp.path}/a.jpg')..writeAsBytesSync(_png);
      final base = Directory('${tmp.path}/app')..createSync();
      final first = await ProfilePhotoStore.persist(a.path, baseDir: base);
      expect(first, isNot(a.path));
      expect(File(first).existsSync(), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final second = await ProfilePhotoStore.persist(a.path, baseDir: base);
      expect(second, isNot(first));
      expect(File(second).existsSync(), isTrue);
      expect(File(first).existsSync(), isFalse);
    });

    test('a missing source returns the original path', () async {
      final p = '${tmp.path}/nope.jpg';
      expect(await ProfilePhotoStore.persist(p), p);
    });
  });

  group('Edit Profile layout', () {
    for (final w in const [320.0, 360.0, 412.0]) {
      for (final scale in const [1.0, 1.5]) {
        testWidgets('no overflow at ${w.toInt()}dp, text x$scale', (
          tester,
        ) async {
          tester.view.physicalSize = Size(w, 800);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(w, 800),
                  textScaler: TextScaler.linear(scale),
                ),
                child: const EditProfileScreen(),
              ),
            ),
          );
          await tester.pump();
          await tester.scrollUntilVisible(
            find.text('Units System'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump();
          expect(find.text('Metric (kg/cm)'), findsOneWidget);
          expect(find.text('Imperial (lbs/in)'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('the unit options sit under the title, inside the card', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.darkTheme, home: const EditProfileScreen()),
      );
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Units System'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      final title = tester.getTopLeft(find.text('Units System'));
      final chip = tester.getTopLeft(find.text('Metric (kg/cm)'));
      final imperial = tester.getTopRight(find.text('Imperial (lbs/in)'));
      expect(chip.dy, greaterThan(title.dy));
      expect(imperial.dx, lessThanOrEqualTo(360));
    });
  });
}
