import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;
import '../../models/subscription.dart';
import 'billing_provider.dart';
import 'production_billing_config.dart';

/// [BillingProvider] backed by RevenueCat (Google Play Billing / StoreKit).
///
/// RevenueCat validates receipts with the stores; its webhook updates the
/// user's tier on the server (`revenuecat-webhook`), which is what AI quotas
/// trust. The app user id is the Supabase user id, linked on sign-in.
class RevenueCatBillingProvider implements BillingProvider {
  static bool _configured = false;

  /// Public SDK key for this platform, passed at build time
  /// (`--dart-define=REVENUECAT_ANDROID_KEY=goog_...`). Client-safe.
  static String get apiKey {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return const String.fromEnvironment('REVENUECAT_ANDROID_KEY');
    }
    if (Platform.isIOS) {
      return const String.fromEnvironment('REVENUECAT_IOS_KEY');
    }
    return '';
  }

  static bool get isAvailable => apiKey.isNotEmpty;

  const RevenueCatBillingProvider();

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await rc.Purchases.configure(rc.PurchasesConfiguration(apiKey));
    _configured = true;
  }

  /// Links purchases to the signed-in account.
  static Future<void> logIn(String userId) async {
    if (!isAvailable) return;
    await const RevenueCatBillingProvider()._ensureConfigured();
    await rc.Purchases.logIn(userId);
  }

  /// Unlinks purchases on sign-out.
  static Future<void> logOut() async {
    if (!isAvailable || !_configured) return;
    try {
      await rc.Purchases.logOut();
    } catch (_) {
      // Already anonymous.
    }
  }

  Future<List<rc.Package>> _packages() async {
    await _ensureConfigured();
    final offerings = await rc.Purchases.getOfferings();
    return offerings.current?.availablePackages ?? const [];
  }

  /// Google Play subscription ids look like "atlas_annual_pro:annual".
  static String _baseId(String storeId) => storeId.split(':').first;

  @override
  Future<List<String>> getAvailableProducts() async => (await _packages())
      .map((p) => _baseId(p.storeProduct.identifier))
      .toList();

  @override
  Future<List<StoreOffer>> getOffers() async => [
    for (final p in await _packages())
      StoreOffer(
        productId: _baseId(p.storeProduct.identifier),
        title: p.storeProduct.title,
        priceString: p.storeProduct.priceString,
        period: p.storeProduct.subscriptionPeriod,
      ),
  ];

  @override
  Future<Subscription?> purchaseProduct(
    String productId, {
    required String userId,
  }) async {
    final package = (await _packages()).where(
      (p) => _baseId(p.storeProduct.identifier) == productId,
    );
    if (package.isEmpty) {
      throw StateError('This plan is not available in your store right now.');
    }
    try {
      final result = await rc.Purchases.purchase(
        rc.PurchaseParams.package(package.first),
      );
      return _subscriptionFrom(result.customerInfo, userId);
    } on PlatformException catch (e) {
      if (rc.PurchasesErrorHelper.getErrorCode(e) ==
          rc.PurchasesErrorCode.purchaseCancelledError) {
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<Subscription?> restorePurchases({required String userId}) async {
    await _ensureConfigured();
    final info = await rc.Purchases.restorePurchases();
    return _subscriptionFrom(info, userId);
  }

  @override
  Future<Subscription?> currentSubscription({required String userId}) async {
    await _ensureConfigured();
    return _subscriptionFrom(await rc.Purchases.getCustomerInfo(), userId);
  }

  @override
  Future<String?> managementUrl() async {
    await _ensureConfigured();
    return (await rc.Purchases.getCustomerInfo()).managementURL;
  }

  /// The active `pro` entitlement as a [Subscription], or null.
  static Subscription? _subscriptionFrom(rc.CustomerInfo info, String userId) {
    final pro = info.entitlements.active[ProductionBillingConfig.entitlementId];
    if (pro == null || !pro.isActive) return null;
    final productId = _baseId(pro.productIdentifier);
    final tier = productId == ProductionBillingConfig.monthlyProductId
        ? SubscriptionTier.monthly
        : productId == ProductionBillingConfig.lifetimeProductId
        ? SubscriptionTier.lifetime
        : SubscriptionTier.annual;
    return Subscription(
      id: 'sub_rc_${pro.originalPurchaseDate}',
      userId: userId,
      tier: tier,
      status: SubscriptionStatus.active,
      startDate: DateTime.tryParse(pro.originalPurchaseDate) ?? DateTime.now(),
      endDate: pro.expirationDate == null
          ? null
          : DateTime.tryParse(pro.expirationDate!),
      isAutoRenewing: pro.willRenew,
      productIdentifier: productId,
    );
  }
}
