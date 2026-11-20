import '../../models/subscription.dart';
import 'billing_provider.dart';
import 'production_billing_config.dart';

/// Test store for debug builds without RevenueCat. Purchases succeed without
/// payment, so it is never used in release builds (see
/// [ProductionBillingConfig.resolveProvider]).
class LocalBillingProvider implements BillingProvider {
  static const String monthlyProductId = 'atlas_monthly_pro';
  static const String annualProductId = 'atlas_annual_pro';
  static const String lifetimeProductId = 'atlas_lifetime_pro';

  const LocalBillingProvider();

  @override
  Future<List<String>> getAvailableProducts() async {
    return const [monthlyProductId, annualProductId, lifetimeProductId];
  }

  @override
  Future<Subscription?> purchaseProduct(
    String productId, {
    required String userId,
  }) async {
    final now = DateTime.now();

    switch (productId) {
      case monthlyProductId:
        return Subscription(
          id: 'sub_m_${now.millisecondsSinceEpoch}',
          userId: userId,
          tier: SubscriptionTier.monthly,
          status: SubscriptionStatus.active,
          startDate: now,
          endDate: now.add(const Duration(days: 30)),
          isAutoRenewing: true,
          productIdentifier: monthlyProductId,
        );

      case annualProductId:
        return Subscription(
          id: 'sub_a_${now.millisecondsSinceEpoch}',
          userId: userId,
          tier: SubscriptionTier.annual,
          status: SubscriptionStatus.active,
          startDate: now,
          endDate: now.add(const Duration(days: 365)),
          isAutoRenewing: true,
          productIdentifier: annualProductId,
        );

      case lifetimeProductId:
        return Subscription(
          id: 'sub_l_${now.millisecondsSinceEpoch}',
          userId: userId,
          tier: SubscriptionTier.lifetime,
          status: SubscriptionStatus.active,
          startDate: now,
          endDate: null, // Unlimited lifetime
          isAutoRenewing: false,
          productIdentifier: lifetimeProductId,
        );

      default:
        return Subscription(
          id: 'sub_m_${now.millisecondsSinceEpoch}',
          userId: userId,
          tier: SubscriptionTier.monthly,
          status: SubscriptionStatus.active,
          startDate: now,
          endDate: now.add(const Duration(days: 30)),
          isAutoRenewing: true,
          productIdentifier: monthlyProductId,
        );
    }
  }

  @override
  Future<List<StoreOffer>> getOffers() async => const [
    StoreOffer(
      productId: annualProductId,
      title: 'Annual (test store)',
      priceString: 'Test price',
      period: 'P1Y',
    ),
    StoreOffer(
      productId: monthlyProductId,
      title: 'Monthly (test store)',
      priceString: 'Test price',
      period: 'P1M',
    ),
    StoreOffer(
      productId: lifetimeProductId,
      title: 'Lifetime (test store)',
      priceString: 'Test price',
    ),
  ];

  /// The test store has no purchase history, so there is nothing to restore.
  @override
  Future<Subscription?> restorePurchases({required String userId}) async =>
      null;

  @override
  Future<String?> managementUrl() async => null;

  @override
  Future<Subscription?> currentSubscription({required String userId}) async =>
      null;
}
