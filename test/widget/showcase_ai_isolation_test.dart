import 'package:atlas/app_theme.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/data/mock_food_database.dart';
import 'package:atlas/data/profile_provider.dart';
import 'package:atlas/models/food_item.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/services/challenge_service.dart';
import 'package:atlas/widgets/coach/ai_chat_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(Widget child) => MaterialApp(
  theme: AppTheme.darkTheme,
  home: Scaffold(body: child),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    ProfileProvider().reload();
    FitnessProvider.resetInstance();
    ChallengeService.resetInstance();
    FitnessProvider.instance.refreshAll();
  });

  tearDown(() async {
    await LocalStorage.setShowcaseModeEnabled(false);
  });

  group('The chat status strip', () {
    testWidgets('in Showcase it says no sign-in is needed', (tester) async {
      await tester.pumpWidget(
        _host(const AiChatStatusBanner(isSignedIn: true, isShowcase: true)),
      );
      final text = tester.widget<Text>(find.byKey(const Key('ai_status_text')));
      expect(text.data, AiChatStatusBanner.showcaseText);
      expect(find.textContaining('Sign in'), findsNothing);
    });

    testWidgets('in Showcase it is never the sign-in prompt even if the '
        'provider reports signed out', (tester) async {
      await tester.pumpWidget(
        _host(const AiChatStatusBanner(isSignedIn: false, isShowcase: true)),
      );
      expect(find.textContaining('Sign in to chat'), findsNothing);
      expect(find.text(AiChatStatusBanner.showcaseText), findsOneWidget);
    });

    testWidgets('a build with no backend still says so in Showcase', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const AiChatStatusBanner(
            isSignedIn: false,
            isShowcase: true,
            backendMissing: true,
          ),
        ),
      );
      expect(find.text(AiChatStatusBanner.backendMissingText), findsOneWidget);
    });

    testWidgets('outside Showcase it is unchanged', (tester) async {
      await tester.pumpWidget(
        _host(const AiChatStatusBanner(isSignedIn: false)),
      );
      expect(find.text(AiChatStatusBanner.signedOutText), findsOneWidget);
      await tester.pumpWidget(
        _host(const AiChatStatusBanner(isSignedIn: true)),
      );
      expect(find.text(AiChatStatusBanner.signedInText), findsOneWidget);
    });
  });

  group('Foods logged in Showcase', () {
    FoodItem food() => MockFoodDatabase.defaultFoods.first;

    test('stay in memory and never reach the real nutrition log', () async {
      final realBefore = LocalStorage.getTodayNutritionLog().totals.itemCount;
      final xpBefore = LocalStorage.getUserProgress().totalXP;
      await LocalStorage.setShowcaseModeEnabled(true);
      await FitnessProvider.instance.onShowcaseModeToggled(true);
      final consumedBefore = FitnessProvider.instance.todayConsumed;

      await FitnessProvider.instance.addFoodToMeal('Breakfast', food(), 100);

      expect(
        FitnessProvider.instance.todayConsumed.itemCount,
        consumedBefore.itemCount + 1,
        reason: 'the demo log shows it',
      );
      expect(FitnessProvider.instance.showcaseLoggedMeals, hasLength(1));

      await LocalStorage.setShowcaseModeEnabled(false);
      expect(
        LocalStorage.getTodayNutritionLog().totals.itemCount,
        realBefore,
        reason: 'the real log is untouched',
      );
      expect(LocalStorage.getUserProgress().totalXP, xpBefore);
    });

    test('are dropped when Showcase ends, so nothing leaks across', () async {
      await LocalStorage.setShowcaseModeEnabled(true);
      await FitnessProvider.instance.onShowcaseModeToggled(true);
      await FitnessProvider.instance.addFoodToMeal('Lunch', food(), 100);
      expect(FitnessProvider.instance.showcaseLoggedMeals, isNotEmpty);

      await LocalStorage.setShowcaseModeEnabled(false);
      await FitnessProvider.instance.onShowcaseModeToggled(false);
      expect(FitnessProvider.instance.showcaseLoggedMeals, isEmpty);

      // And a new Showcase starts clean.
      await LocalStorage.setShowcaseModeEnabled(true);
      await FitnessProvider.instance.onShowcaseModeToggled(true);
      expect(FitnessProvider.instance.showcaseLoggedMeals, isEmpty);
    });

    test('outside Showcase, logging still goes to the real log', () async {
      await FitnessProvider.instance.addFoodToMeal('Breakfast', food(), 100);
      expect(FitnessProvider.instance.showcaseLoggedMeals, isEmpty);
      expect(
        LocalStorage.getTodayNutritionLog().totals.itemCount,
        greaterThanOrEqualTo(1),
      );
    });

    test('the unit rule still applies in Showcase', () async {
      await LocalStorage.setShowcaseModeEnabled(true);
      await FitnessProvider.instance.onShowcaseModeToggled(true);
      // A solid food cannot be logged in millilitres.
      final solid = MockFoodDatabase.defaultFoods.firstWhere(
        (f) => f.nutritionBasis == NutritionBasis.per100g,
      );
      await expectLater(
        FitnessProvider.instance.addFoodToMeal('Lunch', solid, 100, 'ml'),
        throwsArgumentError,
      );
      expect(FitnessProvider.instance.showcaseLoggedMeals, isEmpty);
    });
  });
}
