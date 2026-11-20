import '../models/premium_feature.dart';
import '../models/subscription.dart';
import '../repositories/subscription_repository.dart';
import 'billing/billing_provider.dart';
import 'billing/local_billing_provider.dart';
import 'premium_access_manager.dart';

/// Service orchestrating subscription purchases, billing store synchronization, and feature permissions.
class SubscriptionService {
  final SubscriptionRepository repository;
  final BillingProvider billingProvider;
  final PremiumAccessManager accessManager;

  const SubscriptionService({
    this.repository = const LocalSubscriptionRepository(),
    this.billingProvider = const LocalBillingProvider(),
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

  /// Syncs the locally stored subscription with the store (no prompt). Keeps
  /// the stored one when the store has nothing active, so the test store
  /// still works; with a real store an expired plan ends up free.
  Future<Subscription> refreshFromStore({required String userId}) async {
    final current = await billingProvider.currentSubscription(userId: userId);
    if (current != null) {
      await repository.saveSubscription(current);
      return current;
    }
    final stored = await getSubscription(userId: userId);
    if (stored.isPremium && billingProvider is! LocalBillingProvider) {
      final free = Subscription.free(userId: userId);
      await repository.saveSubscription(free);
      return free;
    }
    return stored;
  }

  /// Store page for managing or cancelling the subscription (cancelling
  /// happens in Google Play / the App Store, not in the app).
  Future<String?> managementUrl() => billingProvider.managementUrl();

  /// Records a cancellation locally (used by the test store).
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
