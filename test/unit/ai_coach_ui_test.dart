import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aizawl_gym/models/coach_message.dart';
import 'package:aizawl_gym/models/recommendation.dart';
import 'package:aizawl_gym/widgets/coach/coach_summary_card.dart';
import 'package:aizawl_gym/widgets/coach/recommendation_card.dart';
import 'package:aizawl_gym/screens/ai_coach_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CoachMessage Model Tests', () {
    test('serialization and copyWith work symmetrically', () {
      final msg = CoachMessage(
        id: 'msg_1',
        role: CoachRole.user,
        content: 'How do I hit my protein goal?',
        timestamp: DateTime(2026, 8, 8, 1, 0),
      );

      final json = msg.toJson();
      expect(json['id'], equals('msg_1'));
      expect(json['role'], equals('user'));
      expect(json['content'], equals('How do I hit my protein goal?'));

      final restored = CoachMessage.fromJson(json);
      expect(restored.id, equals('msg_1'));
      expect(restored.role, equals(CoachRole.user));
      expect(restored.content, equals('How do I hit my protein goal?'));

      final updated = msg.copyWith(content: 'New content');
      expect(updated.content, equals('New content'));
      expect(updated.id, equals('msg_1'));
    });
  });

  group('CoachSummaryCard Widget Tests', () {
    testWidgets('renders active count and top recommendation', (tester) async {
      final now = DateTime.now();
      final recs = [
        Recommendation(
          id: 'rec_protein',
          title: 'Boost Daily Protein Intake',
          description: 'Your 7-day average is 90g, below target.',
          category: RecommendationCategory.nutrition,
          priority: RecommendationPriority.high,
          actionTitle: 'LOG MEAL',
          reasoning: 'High protein supports muscle recovery.',
          metricTrigger: '45% hit rate',
          createdAt: now,
        ),
      ];

      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CoachSummaryCard(
              recommendations: recs,
              onViewAdviceTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('AI Coach'), findsOneWidget);
      expect(find.text('1 active recommendation'), findsOneWidget);
      expect(find.text('Boost Daily Protein Intake'), findsOneWidget);

      await tester.tap(find.text('VIEW ADVICE'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });
  });

  group('RecommendationCard Widget Tests', () {
    testWidgets('renders category badge, priority, reasoning, and triggers callbacks', (tester) async {
      final now = DateTime.now();
      final rec = Recommendation(
        id: 'rec_recovery',
        title: 'Active Recovery Suggested',
        description: 'You completed 4 consecutive workout days.',
        category: RecommendationCategory.recovery,
        priority: RecommendationPriority.high,
        actionTitle: 'SCHEDULE REST',
        actionRoute: 'open_workout',
        reasoning: 'Continuous training without rest increases injury risk.',
        metricTrigger: '4-day streak',
        createdAt: now,
      );

      bool actionTriggered = false;
      bool dismissTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecommendationCard(
              recommendation: rec,
              onActionTap: () {
                actionTriggered = true;
              },
              onDismissTap: () {
                dismissTriggered = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('RECOVERY'), findsOneWidget);
      expect(find.text('HIGH'), findsOneWidget);
      expect(find.text('Active Recovery Suggested'), findsOneWidget);
      expect(find.text('Continuous training without rest increases injury risk.'), findsOneWidget);
      expect(find.text('Trigger: 4-day streak'), findsOneWidget);

      // Tap action button
      await tester.tap(find.text('SCHEDULE REST'));
      await tester.pumpAndSettle();
      expect(actionTriggered, isTrue);

      // Tap dismiss button
      await tester.tap(find.byTooltip('Dismiss recommendation'));
      await tester.pumpAndSettle();
      expect(dismissTriggered, isTrue);
    });
  });

  group('AICoachScreen Widget Tests', () {
    testWidgets('renders header, recommendations feed, and ask coach section', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AICoachScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('AI Coach'), findsWidgets);
      expect(find.text('ONLINE'), findsOneWidget);
      expect(find.text('Ask AI Coach'), findsOneWidget);
      expect(find.text('How do I hit my protein goal?'), findsOneWidget);

      // Tap starter question chip
      await tester.tap(find.text('How do I hit my protein goal?'), warnIfMissed: false);
      await tester.pump();

      expect(find.text('How do I hit my protein goal?'), findsWidgets);
    });
  });
}
