import '../../models/subscription.dart';
import 'billing_provider.dart';

/// Mock development implementation of [BillingProvider] simulating In-App Purchases.
class MockBillingProvider implements BillingProvider {
  static const String monthlyProductId = 'aizawl_gym_monthly_pro';
  static const String annualProductId = 'aizawl_gym_annual_pro';
  static const String lifetimeProductId = 'aizawl_gym_lifetime_pro';

  const MockBillingProvider();

  @override
  Future<List<String>> getAvailableProducts() async {
    return const [
      monthlyProductId,
      annualProductId,
      lifetimeProductId,
    ];
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
        // Default monthly fallback
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
  Future<Subscription?> restorePurchases({required String userId}) async {
    final now = DateTime.now();
    return Subscription(
      id: 'sub_restored_${now.millisecondsSinceEpoch}',
      userId: userId,
      tier: SubscriptionTier.annual,
      status: SubscriptionStatus.active,
      startDate: now.subtract(const Duration(days: 30)),
      endDate: now.add(const Duration(days: 335)),
      isAutoRenewing: true,
      productIdentifier: annualProductId,
    );
  }
}
