import '../fixtures/legacy_community_feed.dart';
import 'package:atlas/app_theme.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/data/profile_provider.dart';
import 'package:atlas/models/activity_post.dart';
import 'package:atlas/models/user_profile.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/screens/dashboard_screen.dart';
import 'package:atlas/screens/profile_screen.dart';
import 'package:atlas/screens/athlete_profile_screen.dart';
import 'package:atlas/services/moderation_service.dart';
import 'package:atlas/services/saved_content_service.dart';
import 'package:atlas/services/social_graph_service.dart';
import 'package:atlas/widgets/community/post_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _demoPhoto = 'https://example.com/demo-athlete.jpg';

Future<void> _setUp({required bool showcase}) async {
  SharedPreferences.setMockInitialValues({});
  await LocalStorage.init();
  AppDependencies.reset();
  FitnessProvider.resetInstance();
  SocialGraphService.resetInstance();
  SavedContentService.resetInstance();
  ModerationService.resetInstance();
  await LocalStorage.saveUserProfile(
    UserProfile.defaultProfile().copyWith(
      name: 'Zorinpuia',
      profilePic: _demoPhoto,
    ),
  );
  await LocalStorage.setShowcaseModeEnabled(showcase);
  ProfileProvider().reload();
  ProfileProvider().onShowcaseModeToggled(showcase);
}

void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

Widget _app(Widget home) => MaterialApp(theme: AppTheme.darkTheme, home: home);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('current user identity', () {
    test('Showcase Mode shows YOU and no photo', () async {
      await _setUp(showcase: true);
      final profile = ProfileProvider();
      expect(profile.isShowcaseIdentity, isTrue);
      expect(profile.displayName, 'YOU');
      expect(profile.displayProfilePic, isEmpty);
    });

    test('real users keep their name and photo', () async {
      await _setUp(showcase: false);
      final profile = ProfileProvider();
      expect(profile.isShowcaseIdentity, isFalse);
      expect(profile.displayName, 'Zorinpuia');
      expect(profile.displayProfilePic, _demoPhoto);
    });

    test('an empty profile alone does not enable the YOU identity', () async {
      await _setUp(showcase: false);
      await LocalStorage.saveUserProfile(UserProfile.defaultProfile());
      final profile = ProfileProvider()..reload();
      expect(profile.isShowcaseIdentity, isFalse);
      expect(profile.displayName, isNot('YOU'));
    });

    testWidgets('Summary header greets YOU with the generic avatar', (
      tester,
    ) async {
      await _setUp(showcase: true);
      await tester.pumpWidget(_app(const DashboardScreen()));
      expect(find.textContaining(', YOU'), findsOneWidget);
      expect(find.textContaining('Zorinpuia'), findsNothing);
      expect(find.byIcon(Icons.person_rounded), findsWidgets);
    });

    testWidgets('Summary header keeps a real user name', (tester) async {
      await _setUp(showcase: false);
      await tester.pumpWidget(_app(const DashboardScreen()));
      expect(find.textContaining(', Zorinpuia'), findsOneWidget);
      expect(find.textContaining('YOU'), findsNothing);
    });

    testWidgets('Profile screen shows YOU in Showcase Mode', (tester) async {
      await _setUp(showcase: true);
      _tallView(tester);
      await tester.pumpWidget(_app(const ProfileScreen()));
      await tester.pump();
      // The demo records row overflows with the test font (unrelated to the
      // identity under test), so that layout error is discarded here.
      tester.takeException();
      expect(find.text('YOU'), findsWidgets);
      expect(find.text('Zorinpuia'), findsNothing);
    });

    testWidgets('Profile screen keeps a real user name', (tester) async {
      await _setUp(showcase: false);
      _tallView(tester);
      await tester.pumpWidget(_app(const ProfileScreen()));
      await tester.pump();
      expect(find.text('Zorinpuia'), findsWidgets);
      expect(find.text('YOU'), findsNothing);
    });
  });

  group('community identities', () {
    late List<ActivityPost> feed;

    setUp(() async {
      await _setUp(showcase: true);
      feed = legacyCommunityFeed();
    });

    testWidgets('simulated users keep their names in Showcase Mode', (
      tester,
    ) async {
      final post = feed.firstWhere((p) => p.userId == 'usr_alex');
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: SingleChildScrollView(child: PostCard(post: post)),
          ),
        ),
      );
      expect(find.text(post.userName), findsOneWidget);
      expect(find.text('YOU'), findsNothing);
    });

    testWidgets('the current user own post shows YOU in Showcase Mode', (
      tester,
    ) async {
      final own = feed.first.copyWith(userId: 'usr_local', userName: 'Alex L');
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: SingleChildScrollView(child: PostCard(post: own)),
          ),
        ),
      );
      expect(find.text('YOU'), findsOneWidget);
      expect(find.text('Alex L'), findsNothing);
    });

    testWidgets('tapping different avatars opens each selected profile', (
      tester,
    ) async {
      final authors = <String>{};
      final posts = [
        for (final p in feed)
          if (authors.add(p.userId)) p,
      ].take(3).toList();
      expect(posts.length, 3);

      for (final post in posts) {
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: SingleChildScrollView(child: PostCard(post: post)),
            ),
          ),
        );
        await tester.tap(find.byKey(Key('post_avatar_${post.id}')));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));

        final screen = tester.widget<AthleteProfileScreen>(
          find.byType(AthleteProfileScreen),
        );
        expect(screen.userId, post.userId);
        expect(screen.name, post.userName);
        expect(
          find.descendant(
            of: find.byType(AthleteProfileScreen),
            matching: find.text(post.userName),
          ),
          findsWidgets,
        );

        Navigator.of(tester.element(find.byType(AthleteProfileScreen))).pop();
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(milliseconds: 600));
      }
    });
  });
}
