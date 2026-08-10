import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aizawl_gym/data/local_storage.dart';
import 'package:aizawl_gym/models/leaderboard_entry.dart';
import 'package:aizawl_gym/services/leaderboard_service.dart';
import 'package:aizawl_gym/services/supabase/supabase_client.dart';
import 'package:aizawl_gym/providers/fitness_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SupabaseClientManager.resetInstance();
    FitnessProvider.resetInstance();
  });

  group('LeaderboardEntry Model Unit Tests', () {
    test('LeaderboardEntry fromJson, toJson, and copyWith round trip', () {
      final now = DateTime.now();
      final entry = LeaderboardEntry(
        id: 'lb_1',
        userId: 'usr_1',
        displayName: 'John Doe',
        avatarUrl: 'https://example.com/avatar.png',
        totalXP: 15000,
        rankTitle: 'Gold II',
        division: 'Division I',
        country: 'India',
        updatedAt: now,
      );

      final json = entry.toJson();
      expect(json['id'], equals('lb_1'));
      expect(json['user_id'], equals('usr_1'));
      expect(json['display_name'], equals('John Doe'));
      expect(json['total_xp'], equals(15000));
      expect(json['country'], equals('India'));

      final parsed = LeaderboardEntry.fromJson(json);
      expect(parsed.id, equals('lb_1'));
      expect(parsed.totalXP, equals(15000));
      expect(parsed.country, equals('India'));

      final updated = entry.copyWith(totalXP: 16000);
      expect(updated.totalXP, equals(16000));
      expect(updated.displayName, equals('John Doe'));

      final uiUser =
          updated.toLeaderboardUser(rankPosition: 1, isCurrentUser: true);
      expect(uiUser.rankPosition, equals(1));
      expect(uiUser.isCurrentUser, isTrue);
      expect(uiUser.name, equals('John Doe'));
      expect(uiUser.xp, equals(16000));
    });
  });

  group('LeaderboardService Unit Tests', () {
    test('getGlobalLeaderboard returns entries sorted by totalXP descending',
        () async {
      final client = SupabaseClientManager.instance;
      final table = client.from('leaderboard_entries');

      await table.insert({
        'id': 'e1',
        'user_id': 'u1',
        'display_name': 'Low XP User',
        'total_xp': 100,
        'rank_title': 'Bronze I',
        'country': 'India',
      });
      await table.insert({
        'id': 'e2',
        'user_id': 'u2',
        'display_name': 'High XP User',
        'total_xp': 9999,
        'rank_title': 'Legend',
        'country': 'India',
      });

      final service = LeaderboardService(clientManager: client);
      final global = await service.getGlobalLeaderboard();

      expect(global.length, greaterThanOrEqualTo(2));
      expect(global.first.totalXP, equals(9999));
      expect(global.first.displayName, equals('High XP User'));
    });

    test('getLocalLeaderboard filters entries by country correctly', () async {
      final client = SupabaseClientManager.instance;
      final table = client.from('leaderboard_entries');

      await table.insert({
        'id': 'e_in',
        'user_id': 'u_in',
        'display_name': 'Indian Lifter',
        'total_xp': 5000,
        'rank_title': 'Gold I',
        'country': 'India',
      });
      await table.insert({
        'id': 'e_us',
        'user_id': 'u_us',
        'display_name': 'US Lifter',
        'total_xp': 6000,
        'rank_title': 'Gold III',
        'country': 'USA',
      });

      final service = LeaderboardService(clientManager: client);
      final localIn = await service.getLocalLeaderboard(country: 'India');
      expect(localIn.every((e) => e.country == 'India'), isTrue);
      expect(localIn.any((e) => e.displayName == 'Indian Lifter'), isTrue);
    });

    test('updateLeaderboardEntry upserts user ranking correctly', () async {
      final service = LeaderboardService();
      final entry = LeaderboardEntry(
        id: 'lb_test_update',
        userId: 'usr_test_update',
        displayName: 'Test Runner',
        totalXP: 8888,
        rankTitle: 'Silver II',
        division: 'Division II',
        country: 'India',
        updatedAt: DateTime.now(),
      );

      await service.updateLeaderboardEntry(entry);
      final global = await service.getGlobalLeaderboard();
      expect(global
          .any((e) => e.displayName == 'Test Runner' && e.totalXP == 8888), isTrue);
    });
  });

  group('FitnessProvider Leaderboard Integration Tests', () {
    test('loadLeaderboard populates global, local, and friends lists', () async {
      final provider = FitnessProvider.instance;
      int notifyCount = 0;
      provider.addListener(() {
        notifyCount++;
      });

      expect(provider.globalLeaderboard.isEmpty, isTrue);

      await provider.loadLeaderboard();

      expect(provider.globalLeaderboard, isNotEmpty);
      expect(provider.localLeaderboard, isNotEmpty);
      expect(provider.friendsLeaderboard, isNotEmpty);
      expect(notifyCount, greaterThanOrEqualTo(2));
      expect(provider.isLeaderboardLoading, isFalse);
    });
  });
}
