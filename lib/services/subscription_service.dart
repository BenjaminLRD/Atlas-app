import '../models/premium_feature.dart';
import '../models/subscription.dart';
import '../repositories/subscription_repository.dart';
import 'billing/billing_provider.dart';
import 'billing/mock_billing_provider.dart';
import 'premium_access_manager.dart';

/// Service orchestrating subscription purchases, billing store synchronization, and feature permissions.
class SubscriptionService {
  final SubscriptionRepository repository;
  final BillingProvider billingProvider;
  final PremiumAccessManager accessManager;

  const SubscriptionService({
    this.repository = const LocalSubscriptionRepository(),
    this.billingProvider = const MockBillingProvider(),
    this.accessManager = const PremiumAccessManager(),
  });

  /// Retrieves user subscription status from persistence.
  Future<Subscription> getSubscription({String? userId}) async {
    return repository.getSubscription(userId: userId);
  }

  /// Executes plan purchase via active [BillingProvider] and persists subscription state.
  Future<Subscription> purchasePlan(
    String productId, {
    required String userId,
  }) async {
    final purchased = await billingProvider.purchaseProduct(
      productId,
      userId: userId,
    );

    if (purchased != null) {
      await repository.saveSubscription(purchased);
      return purchased;
    }

    return getSubscription(userId: userId);
  }

  /// Restores prior purchases from store provider and updates local repository.
  Future<Subscription> restorePurchases({required String userId}) async {
    final restored = await billingProvider.restorePurchases(userId: userId);
    if (restored != null) {
      await repository.saveSubscription(restored);
      return restored;
    }
    return getSubscription(userId: userId);
  }

  /// Cancels active auto-renewing subscription and updates local repository.
  Future<Subscription> cancelSubscription({required String userId}) async {
    final current = await repository.getSubscription(userId: userId);
    final updated = current.copyWith(
      status: SubscriptionStatus.canceled,
      isAutoRenewing: false,
    );
    await repository.saveSubscription(updated);
    return updated;
  }

  /// Checks feature permission using [PremiumAccessManager].
  bool canAccess(PremiumFeature feature, Subscription subscription) {
    return accessManager.canAccessFeature(feature, subscription);
  }
}
