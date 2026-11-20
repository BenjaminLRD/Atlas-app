import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas/navigation/app_navigation.dart';

void main() {
  group('AppNavigation Foundation Unit Tests', () {
    test('1. AppNavSection contains all 5 required logical sections', () {
      expect(AppNavSection.values.length, equals(5));
      expect(AppNavSection.main.title, equals('MAIN'));
      expect(AppNavSection.training.title, equals('TRAINING'));
      expect(AppNavSection.community.title, equals('COMMUNITY'));
      expect(
        AppNavSection.nutritionAndGoals.title,
        equals('NUTRITION & GOALS'),
      );
      expect(AppNavSection.app.title, equals('APP'));
    });

    test(
      '2. AppNavDestination has all required fields and correct destination types',
      () {
        // Bottom tab destinations
        expect(AppNavDestination.home.isBottomTab, isTrue);
        expect(AppNavDestination.home.tabIndex, equals(0));
        expect(AppNavDestination.home.section, equals(AppNavSection.main));

        expect(AppNavDestination.nutrition.isBottomTab, isTrue);
        expect(AppNavDestination.nutrition.tabIndex, equals(1));
        expect(AppNavDestination.nutrition.section, equals(AppNavSection.main));

        expect(AppNavDestination.workouts.isBottomTab, isTrue);
        expect(AppNavDestination.workouts.tabIndex, equals(2));
        expect(AppNavDestination.workouts.section, equals(AppNavSection.main));

        expect(AppNavDestination.community.isBottomTab, isTrue);
        expect(AppNavDestination.community.tabIndex, equals(3));
        expect(AppNavDestination.community.section, equals(AppNavSection.main));

        expect(AppNavDestination.profile.isBottomTab, isTrue);
        expect(AppNavDestination.profile.tabIndex, equals(4));
        expect(AppNavDestination.profile.section, equals(AppNavSection.app));

        // Secondary route destinations
        expect(AppNavDestination.aiCoach.isBottomTab, isFalse);
        expect(AppNavDestination.aiCoach.badge, equals('AI'));
        expect(
          AppNavDestination.aiCoach.section,
          equals(AppNavSection.training),
        );
        expect(AppNavDestination.aiCoach.routeBuilder, isNotNull);

        expect(AppNavDestination.ranked.badge, equals('XP'));
        expect(
          AppNavDestination.ranked.section,
          equals(AppNavSection.training),
        );
        expect(AppNavDestination.ranked.routeBuilder, isNotNull);

        expect(AppNavDestination.leaderboard.badge, equals('HOT'));
        expect(
          AppNavDestination.leaderboard.section,
          equals(AppNavSection.community),
        );
        expect(AppNavDestination.leaderboard.routeBuilder, isNotNull);

        expect(
          AppNavDestination.foodDatabase.section,
          equals(AppNavSection.nutritionAndGoals),
        );
        expect(AppNavDestination.foodDatabase.routeBuilder, isNotNull);

        expect(AppNavDestination.settings.section, equals(AppNavSection.app));
        expect(AppNavDestination.settings.routeBuilder, isNotNull);
      },
    );

    test('3. AppNavigation.sections groups all 5 sections properly', () {
      final sections = AppNavigation.sections;
      expect(sections.length, equals(5));

      final sectionTitles = sections.map((s) => s.title).toList();
      expect(
        sectionTitles,
        equals(['MAIN', 'TRAINING', 'COMMUNITY', 'NUTRITION & GOALS', 'APP']),
      );

      final mainItems = sections[0].items;
      expect(
        mainItems.map((i) => i.id),
        equals(['home', 'nutrition', 'workouts', 'community']),
      );

      final trainingItems = sections[1].items;
      expect(
        trainingItems.map((i) => i.id),
        equals([
          'cardio_tracking',
          'ai_coach',
          'personalization_insights',
          'ranked',
          'progress',
          'goals',
          'equipment',
          'health_dashboard',
        ]),
      );

      final communityItems = sections[2].items;
      expect(
        communityItems.map((i) => i.id),
        equals(['leaderboard', 'achievements']),
      );

      final nutritionItems = sections[3].items;
      expect(
        nutritionItems.map((i) => i.id),
        equals(['meal_plans', 'food_database', 'weight_goal']),
      );

      final appItems = sections[4].items;
      expect(
        appItems.map((i) => i.id),
        equals(['profile', 'notifications', 'settings']),
      );
    });

    test(
      '4. AppNavigation.syncTab updates active destination and tab notifier reactively',
      () {
        AppNavigation.syncTab(0);
        expect(AppNavigation.currentTabNotifier.value, equals(0));
        expect(
          AppNavigation.activeDestinationNotifier.value,
          equals(AppNavDestination.home),
        );

        AppNavigation.syncTab(1);
        expect(AppNavigation.currentTabNotifier.value, equals(1));
        expect(
          AppNavigation.activeDestinationNotifier.value,
          equals(AppNavDestination.nutrition),
        );

        AppNavigation.syncTab(2);
        expect(AppNavigation.currentTabNotifier.value, equals(2));
        expect(
          AppNavigation.activeDestinationNotifier.value,
          equals(AppNavDestination.workouts),
        );

        AppNavigation.syncTab(3);
        expect(AppNavigation.currentTabNotifier.value, equals(3));
        expect(
          AppNavigation.activeDestinationNotifier.value,
          equals(AppNavDestination.community),
        );

        AppNavigation.syncTab(4);
        expect(AppNavigation.currentTabNotifier.value, equals(4));
        expect(
          AppNavigation.activeDestinationNotifier.value,
          equals(AppNavDestination.profile),
        );
      },
    );

    testWidgets(
      '5. AppNavigation.navigate switches tabs and triggers registered callbacks',
      (tester) async {
        int? switchedTab;
        AppNavigation.onTabSwitch = (index) {
          switchedTab = index;
        };

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () =>
                    AppNavigation.navigate(context, AppNavDestination.workouts),
                child: const Text('Go to Workouts'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Go to Workouts'));
        await tester.pump();

        expect(switchedTab, equals(2));
        expect(AppNavigation.currentTabNotifier.value, equals(2));
        expect(
          AppNavigation.activeDestinationNotifier.value,
          equals(AppNavDestination.workouts),
        );

        AppNavigation.onTabSwitch = null;
      },
    );
  });
}
