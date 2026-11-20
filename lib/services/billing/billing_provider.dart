import '../../models/subscription.dart';

/// A plan as the store sells it in the user's country, with a localized
/// price (the store handles regional pricing).
class StoreOffer {
  final String productId;
  final String title;

  /// e.g. "₹399.00" or "$9.99", formatted by the store for the user's region.
  final String priceString;

  /// ISO 8601 period such as "P1M" or "P1Y"; null for one-time purchases.
  final String? period;

  const StoreOffer({
    required this.productId,
    required this.title,
    required this.priceString,
    this.period,
  });
}

/// Abstract provider interface for store billing operations (App Store, Google Play, Mock).
abstract class BillingProvider {
  /// Fetch list of available store product identifiers.
  Future<List<String>> getAvailableProducts();

  /// Plans with localized store prices.
  Future<List<StoreOffer>> getOffers();

  /// Purchase a subscription plan by product identifier.
  Future<Subscription?> purchaseProduct(
    String productId, {
    required String userId,
  });

  /// Restore active store purchases. Returns null when the store has none.
  Future<Subscription?> restorePurchases({required String userId});

  /// Store page where the user manages or cancels their subscription, or
  /// null when not available.
  Future<String?> managementUrl();

  /// The account's active subscription as the store knows it, without any
  /// store prompt (used at sign-in on a new device). Null when free.
  Future<Subscription?> currentSubscription({required String userId});
}

/// Billing when no store is configured (release build without a RevenueCat
/// key): nothing can be bought or restored.
class UnavailableBillingProvider implements BillingProvider {
  const UnavailableBillingProvider();

  static const String message =
      'Purchases are not available in this version of the app.';

  @override
  Future<List<String>> getAvailableProducts() async => const [];

  @override
  Future<List<StoreOffer>> getOffers() async => const [];

  @override
  Future<Subscription?> purchaseProduct(
    String productId, {
    required String userId,
  }) async => throw StateError(message);

  @override
  Future<Subscription?> restorePurchases({required String userId}) async =>
      null;

  @override
  Future<String?> managementUrl() async => null;

  @override
  Future<Subscription?> currentSubscription({required String userId}) async =>
      null;
}
