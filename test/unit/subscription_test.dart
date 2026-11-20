import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:atlas/data/local_storage.dart';
import 'package:atlas/models/premium_feature.dart';
import 'package:atlas/models/subscription.dart';
import 'package:atlas/providers/fitness_provider.dart';
import 'package:atlas/repositories/subscription_repository.dart';
import '../mocks/mock_billing_provider.dart';
import 'package:atlas/services/premium_access_manager.dart';
import 'package:atlas/services/subscription_service.dart';
import 'package:atlas/services/supabase/supabase_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorage.init();
    SupabaseClientManager.resetInstance();
    FitnessProvider.resetInstance();
  });

  group('Subscription Model Unit Tests', () {
    test('Subscription.free creates non-premium subscription', () {
      final sub = Subscription.free();
      expect(sub.tier, equals(SubscriptionTier.free));
      expect(sub.isPremium, isFalse);
      expect(sub.isExpired, isFalse);
    });

    test('Subscription serialization and isPremium status', () {
      final now = DateTime.now();
      final sub = Subscription(
        id: 'sub_pro_1',
        userId: 'usr_123',
        tier: SubscriptionTier.annual,
        status: SubscriptionStatus.active,
        startDate: now,
        endDate: now.add(const Duration(days: 365)),
        isAutoRenewing: true,
        productIdentifier: MockBillingProvider.annualProductId,
      );

      expect(sub.isPremium, isTrue);

      final json = sub.toJson();
      expect(json['tier'], equals('annual'));
      expect(json['status'], equals('active'));

      final parsed = Subscription.fromJson(json);
      expect(parsed.isPremium, isTrue);
      expect(parsed.tier, equals(SubscriptionTier.annual));
    });
  });

  group('PremiumFeature Enum Tests', () {
    test('PremiumFeature extension properties', () {
      expect(PremiumFeature.aiCoach.featureKey, equals('ai_coach'));
      expect(PremiumFeature.aiCoach.title, equals('Unlimited Atlas AI Coach'));
      expect(PremiumFeature.wearableSync.featureKey, equals('wearable_sync'));
      expect(PremiumFeature.values.length, equals(9));
    });
  });

  group('LocalSubscriptionRepository & Persistence Tests', () {
    test(
      'saveSubscription persists and retrieves subscription state',
      () async {
        const repo = LocalSubscriptionRepository();
        final initial = await repo.getSubscription();
        expect(initial.isPremium, isFalse);

        final proSub = Subscription(
          id: 'sub_test',
          userId: 'usr_local',
          tier: SubscriptionTier.monthly,
          status: SubscriptionStatus.active,
          startDate: DateTime.now(),
          endDate: DateTime.now().add(const Duration(days: 30)),
        );

        await repo.saveSubscription(proSub);
        final loaded = await repo.getSubscription();
        expect(loaded.isPremium, isTrue);
        expect(loaded.tier, equals(SubscriptionTier.monthly));
      },
    );
  });

  group('MockBillingProvider Unit Tests', () {
    test(
      'purchaseProduct returns active subscription for valid product IDs',
      () async {
        const billing = MockBillingProvider();
        final products = await billing.getAvailableProducts();
        expect(products.length, equals(3));

        final sub = await billing.purchaseProduct(
          MockBillingProvider.monthlyProductId,
          userId: 'usr_test',
        );

        expect(sub, isNotNull);
        expect(sub!.isPremium, isTrue);
        expect(sub.tier, equals(SubscriptionTier.monthly));
      },
    );

    test('restorePurchases restores annual subscription', () async {
      const billing = MockBillingProvider();
      final restored = await billing.restorePurchases(userId: 'usr_test');

      expect(restored, isNotNull);
      expect(restored!.isPremium, isTrue);
      expect(restored.tier, equals(SubscriptionTier.annual));
    });
  });

  group('PremiumAccessManager Feature Gating Tests', () {
    test('Free subscription blocks access to gated features', () {
      const manager = PremiumAccessManager();
      final freeSub = Subscription.free();

      // Strictly premium features
      expect(manager.canAccessFeature(PremiumFeature.adaptivePlanner, freeSub), isFalse);
      expect(manager.canAccessFeature(PremiumFeature.recoveryIntelligence, freeSub), isFalse);
      expect(manager.canAccessFeature(PremiumFeature.wearableSync, freeSub), isFalse);
      expect(manager.canAccessFeature(PremiumFeature.advancedAnalytics, freeSub), isFalse);
      expect(manager.canAccessFeature(PremiumFeature.exerciseFormAnalysis, freeSub), isFalse);
      expect(manager.canAccessFeature(PremiumFeature.recoveryPredictions, freeSub), isFalse);
      expect(manager.canAccessFeature(PremiumFeature.digitalAthleteInsights, freeSub), isFalse);

      // Quota-allowed features
      expect(manager.canAccessFeature(PremiumFeature.aiCoach, freeSub), isTrue);
      expect(manager.canAccessFeature(PremiumFeature.unlimitedFoodScanning, freeSub), isTrue);
    });

    test('Premium subscription unlocks all features', () {
      const manager = PremiumAccessManager();
      final proSub = Subscription(
        id: 'sub_pro',
        userId: 'usr_test',
        tier: SubscriptionTier.annual,
        status: SubscriptionStatus.active,
        startDate: DateTime.now(),
      );

      for (final feature in PremiumFeature.values) {
        expect(manager.canAccessFeature(feature, proSub), isTrue);
      }
    });
  });

  group('SubscriptionService Workflow Tests', () {
    test(
      'purchasePlan updates repository and unlocks feature access',
      () async {
        const service = SubscriptionService();
        final purchased = await service.purchasePlan(
          MockBillingProvider.annualProductId,
          userId: 'usr_test',
        );

        expect(purchased.isPremium, isTrue);
        expect(service.canAccess(PremiumFeature.aiCoach, purchased), isTrue);
      },
    );
  });

  group('FitnessProvider Subscription Integration Tests', () {
    test(
      'FitnessProvider purchaseSubscription and restorePurchases update reactive state',
      () async {
        final provider = FitnessProvider.instance;

        expect(provider.isPremium, isFalse);
        expect(provider.canAccessFeature(PremiumFeature.adaptivePlanner), isFalse);

        await provider.purchaseSubscription(
          MockBillingProvider.annualProductId,
        );

        expect(provider.isPremium, isTrue);
        expect(provider.canAccessFeature(PremiumFeature.adaptivePlanner), isTrue);

        await provider.cancelUserSubscription();
        expect(
          provider.subscription.status,
          equals(SubscriptionStatus.canceled),
        );
      },
    );
  });
}
