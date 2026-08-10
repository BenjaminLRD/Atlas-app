import '../../models/subscription.dart';

/// Abstract provider interface for store billing operations (App Store, Google Play, Mock).
abstract class BillingProvider {
  /// Fetch list of available store product identifiers.
  Future<List<String>> getAvailableProducts();

  /// Purchase a subscription plan by product identifier.
  Future<Subscription?> purchaseProduct(String productId, {required String userId});

  /// Restore active store purchases.
  Future<Subscription?> restorePurchases({required String userId});
}
