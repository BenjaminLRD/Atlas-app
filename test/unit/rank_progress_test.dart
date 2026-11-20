import 'package:atlas/data/gamification_service.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/services/ranked/rank_ladder.dart';
import 'package:atlas/services/ranked/ranked_progress_store.dart';
import 'package:atlas/widgets/common/animated_rank_progress_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GamificationService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    await RankedProgressStore.save(const RankedSnapshot());
    service = GamificationService();
  });

  Map<String, dynamic> requirementFor(String tier, String division) => service
      .getNextRankRequirement(fallback: RankLadder.parse(tier, division));

  group('RankLadder.parse', () {
    test('maps tier and division to the ladder position', () {
      expect(RankLadder.parse('Bronze', 'III').index, 0);
      expect(RankLadder.parse('Gold', 'II').title, 'Gold II');
      expect(RankLadder.parse('gold', 'ii').title, 'Gold II');
      expect(RankLadder.parse('Champion', 'I').isTop, isTrue);
    });

    test('unknown or unranked values are unranked', () {
      expect(RankLadder.parse('Unranked', 'Unranked').isRanked, isFalse);
      expect(RankLadder.parse('Elite', 'I').isRanked, isFalse);
      expect(RankLadder.parse('Gold', '').isRanked, isFalse);
    });
  });

  group('next milestone and progress come from the current rank', () {
    test('Bronze III targets Bronze II', () {
      final r = requirementFor('Bronze', 'III');
      expect(r['currentRank'], 'Bronze III');
      expect(r['nextRank'], 'Bronze II');
      expect(r['neededMilestones'], 1);
      expect(r['points'], 1);
      expect(r['progressPercentage'], closeTo(1 / 18, 1e-9));
    });

    test('Gold II targets Gold I, never Bronze III (the reported bug)', () {
      final r = requirementFor('Gold', 'II');
      expect(r['currentRank'], 'Gold II');
      expect(r['nextRank'], 'Gold I');
      expect(r['nextRank'], isNot('Bronze III'));
      expect(r['neededMilestones'], 1);
      expect(r['points'], 8);
      expect(r['progressPercentage'], greaterThan(0));
      expect(r['progressPercentage'], closeTo(8 / 18, 1e-9));
    });

    test('a tier boundary moves to the next tier', () {
      final r = requirementFor('Silver', 'I');
      expect(r['nextRank'], 'Gold III');
      expect(r['neededMilestones'], 1);
      final bronze = requirementFor('Bronze', 'I');
      expect(bronze['nextRank'], 'Silver III');
    });

    test('every rank on the ladder targets the next one up', () {
      for (var i = 0; i < RankLadder.divisionCount - 1; i++) {
        final position = RankLadder.fromPoints(RankLadder.pointsForIndex(i));
        final r = service.getNextRankRequirement(fallback: position);
        final next = RankLadder.fromPoints(RankLadder.pointsForIndex(i + 1));
        expect(r['currentRank'], position.title);
        expect(r['nextRank'], next.title);
        expect(r['neededMilestones'], 1);
        expect(r['isMaxRank'], isFalse);
      }
    });

    test('the highest rank is a max-rank state with no lower target', () {
      final r = requirementFor('Champion', 'I');
      expect(r['currentRank'], 'Champion I');
      expect(r['isMaxRank'], isTrue);
      expect(r['nextRank'], 'Max Rank Reached');
      expect(r['neededMilestones'], 0);
      expect(r['progressPercentage'], 1.0);
    });

    test('unranked users are pointed at the first rank', () {
      final r = service.getNextRankRequirement();
      expect(r['currentRank'], 'Unranked');
      expect(r['nextRank'], 'Bronze III');
      expect(r['neededMilestones'], 1);
      expect(r['progressPercentage'], 0.0);
    });

    test('a verified Ranked rank wins over the fallback', () async {
      await RankedProgressStore.save(const RankedSnapshot(points: 7));
      final r = requirementFor('Bronze', 'III');
      expect(r['currentRank'], 'Gold III');
      expect(r['nextRank'], 'Gold II');
    });

    test('points above the top still read as max rank', () async {
      await RankedProgressStore.save(const RankedSnapshot(points: 20));
      final r = service.getNextRankRequirement();
      expect(r['currentRank'], 'Champion I');
      expect(r['isMaxRank'], isTrue);
      expect(r['progressPercentage'], 1.0);
    });
  });

  group('AnimatedRankProgressCard', () {
    Widget card({
      required String current,
      required String next,
      required int points,
      required int needed,
      bool isMax = false,
    }) => MaterialApp(
      home: Scaffold(
        body: AnimatedRankProgressCard(
          currentRank: current,
          nextRank: next,
          currentPoints: points,
          targetPoints: 18,
          milestonesToNext: needed,
          isMaxRank: isMax,
        ),
      ),
    );

    testWidgets('Gold II shows its own next milestone and progress', (
      tester,
    ) async {
      await tester.pumpWidget(
        card(current: 'Gold II', next: 'Gold I', points: 8, needed: 1),
      );
      await tester.pump(
        const Duration(seconds: 2),
      ); // the emblem pulses forever
      expect(find.text('GOLD II'), findsOneWidget);
      expect(find.text('1 milestone to Gold I'), findsOneWidget);
      expect(find.text('44%'), findsOneWidget);
      expect(find.textContaining('Bronze'), findsNothing);
    });

    testWidgets('Bronze III shows 1 milestone and a small progress', (
      tester,
    ) async {
      await tester.pumpWidget(
        card(current: 'Bronze III', next: 'Bronze II', points: 1, needed: 1),
      );
      await tester.pump(
        const Duration(seconds: 2),
      ); // the emblem pulses forever
      expect(find.text('1 milestone to Bronze II'), findsOneWidget);
      expect(find.text('5%'), findsOneWidget);
    });

    testWidgets('multiple milestones use the plural', (tester) async {
      await tester.pumpWidget(
        card(current: 'Gold II', next: 'Platinum III', points: 8, needed: 2),
      );
      await tester.pump(
        const Duration(seconds: 2),
      ); // the emblem pulses forever
      expect(find.text('2 milestones to Platinum III'), findsOneWidget);
    });

    testWidgets('the highest rank shows a max-rank state', (tester) async {
      await tester.pumpWidget(
        card(
          current: 'Champion I',
          next: 'Max Rank Reached',
          points: 18,
          needed: 0,
          isMax: true,
        ),
      );
      await tester.pump(
        const Duration(seconds: 2),
      ); // the emblem pulses forever
      expect(find.text('CHAMPION I'), findsOneWidget);
      expect(find.text('Max rank reached'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.textContaining('milestone'), findsNothing);
    });
  });
}
