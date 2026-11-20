import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/app_dependencies.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/screens/ai/ai_onboarding_screen.dart';
import 'package:atlas/screens/ai_coach_screen.dart';
import 'package:atlas/services/ai/insights/insight_model.dart';
import 'package:atlas/services/ai/memory/fitness_memory.dart';
import 'package:atlas/services/health/health_service.dart';
import 'package:atlas/services/supabase/supabase_client.dart';
import 'package:atlas/widgets/coach/ai_action_preview_card.dart';
import 'package:atlas/widgets/coach/ai_status_indicator.dart';
import 'package:atlas/widgets/coach/coach_summary_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SupabaseClientManager.resetInstance();
    HealthService.resetInstance();
    FitnessMemory.resetInstance();
    AppDependencies.useMock();
  });

  Widget createTestWidget(Widget child, {Size size = const Size(390, 844)}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: child,
      ),
    );
  }

  group('Premium AI Coach Experience & UX Polish Tests', () {
    testWidgets(
      'AIOnboardingScreen renders capabilities and marks completion on CTA tap',
      (tester) async {
        await LocalStorage.setBool(AIOnboardingScreen.completedKey, false);
        expect(AIOnboardingScreen.hasCompleted(), isFalse);

        bool startedTapped = false;
        await tester.pumpWidget(
          createTestWidget(
            AIOnboardingScreen(
              onGetStarted: () {
                startedTapped = true;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Meet Atlas AI'), findsOneWidget);
        expect(find.text('Learns Your Goals'), findsOneWidget);
        expect(find.text('Adapts Workouts'), findsOneWidget);
        expect(find.text('Tracks Recovery'), findsOneWidget);
        expect(find.text('Personalizes Nutrition'), findsOneWidget);
        expect(find.text('Improves Over Time'), findsOneWidget);
        await tester.ensureVisible(find.text('Start Personalizing'));
        await tester.tap(find.text('Start Personalizing'));
        await tester.pumpAndSettle();

        expect(startedTapped, isTrue);
        expect(AIOnboardingScreen.hasCompleted(), isTrue);
      },
    );

    testWidgets(
      'AIStatusIndicator displays friendly status and opens bottom sheet on tap',
      (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            const Scaffold(
              body: Center(
                child: AIStatusIndicator(state: AIStatusState.learning),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Continuously learning about you'), findsOneWidget);

        await tester.tap(find.byType(AIStatusIndicator));
        await tester.pumpAndSettle();

        expect(find.text('Atlas AI Status'), findsOneWidget);
      },
    );

    testWidgets(
      'AIActionPreviewCard renders exercises and handles Save/Modify/Cancel',
      (tester) async {
        bool saveTapped = false;
        bool modifyTapped = false;
        bool cancelTapped = false;

        final card = AIActionPreviewCard(
          title: 'Push Day Hypertrophy',
          durationMinutes: 52,
          rationale: 'Recovery score is optimal (88%)',
          exercises: const [
            {'name': 'Barbell Bench Press', 'sets': 4, 'reps': 8},
            {'name': 'Incline Dumbbell Press', 'sets': 3, 'reps': 10},
            {'name': 'Cable Fly', 'sets': 3, 'reps': 12},
          ],
          onSave: () => saveTapped = true,
          onModify: () => modifyTapped = true,
          onCancel: () => cancelTapped = true,
        );

        await tester.pumpWidget(
          createTestWidget(Scaffold(body: Center(child: card))),
        );
        await tester.pumpAndSettle();

        expect(find.text('Push Day Hypertrophy'), findsOneWidget);
        expect(find.text('52 mins'), findsOneWidget);
        expect(find.text('Recovery score is optimal (88%)'), findsOneWidget);
        expect(find.text('Barbell Bench Press'), findsOneWidget);
        expect(find.text('Incline Dumbbell Press'), findsOneWidget);
        expect(find.text('Cable Fly'), findsOneWidget);

        await tester.tap(find.text('Save Workout'));
        await tester.pumpAndSettle();
        expect(saveTapped, isTrue);

        await tester.tap(find.text('Modify'));
        await tester.pumpAndSettle();
        expect(modifyTapped, isTrue);

        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(cancelTapped, isTrue);
      },
    );

    testWidgets('CoachSummaryCard expands AI reasoning breakdown on tap', (
      tester,
    ) async {
      final insight = CoachInsight(
        id: 'ins_1',
        type: InsightType.recoveryWarning,
        priority: InsightPriority.high,
        title: 'Reduce Training Volume',
        message: 'Your readiness is 46%. Take an active recovery day.',
        rationale:
            'Sleep dropped to 5h 24m while acute weekly load increased by +35%.',
        actionType: InsightActionType.reviewRecovery,
        timestamp: DateTime(2026, 8, 17),
      );

      await tester.pumpWidget(
        createTestWidget(Scaffold(body: CoachSummaryCard(insight: insight))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reduce Training Volume'), findsOneWidget);
      expect(find.text('Why am I seeing this?'), findsOneWidget);

      // Tap to expand
      await tester.tap(find.text('Why am I seeing this?'));
      await tester.pumpAndSettle();

      expect(find.text('AI Reasoning'), findsOneWidget);
      expect(
        find.text(
          'Sleep dropped to 5h 24m while acute weekly load increased by +35%.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('AICoachScreen empty state renders categorized suggestions', (
      tester,
    ) async {
      await LocalStorage.setBool(AIOnboardingScreen.completedKey, true);

      await tester.pumpWidget(createTestWidget(const AICoachScreen()));
      await tester.pumpAndSettle();

      expect(find.text('ATLAS AI CAN HELP WITH:'), findsOneWidget);
      expect(find.text('Plan my day'), findsWidgets);
      expect(find.text('Analyze my nutrition'), findsWidgets);
      expect(find.text('Check my recovery'), findsWidgets);
      expect(find.text('Track my progress'), findsWidgets);
      expect(find.text('Answer anything'), findsWidgets);
    });

    testWidgets(
      'Zero layout overflow across 320px, 360px, 390px, and 412px viewports',
      (tester) async {
        await LocalStorage.setBool(AIOnboardingScreen.completedKey, true);
        final widths = [320.0, 360.0, 390.0, 412.0];

        for (final w in widths) {
          tester.view.physicalSize = Size(w, 800);
          tester.view.devicePixelRatio = 1.0;

          await tester.pumpWidget(
            createTestWidget(const AICoachScreen(), size: Size(w, 800)),
          );
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason: 'AICoachScreen overflowed at ${w}px width',
          );

          await tester.pumpWidget(
            createTestWidget(
              const Scaffold(body: AIOnboardingScreen()),
              size: Size(w, 800),
            ),
          );
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason: 'AIOnboardingScreen overflowed at ${w}px width',
          );
        }

        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });
      },
    );
  });
}
