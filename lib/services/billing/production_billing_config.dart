import 'package:flutter/foundation.dart';
import 'billing_provider.dart';
import 'local_billing_provider.dart';
import 'revenuecat_billing_provider.dart';

/// Store products and the billing provider for this build.
///
/// Create these product ids in Google Play Console (and App Store Connect),
/// attach them to a RevenueCat entitlement named [entitlementId], and set
/// regional prices in the store consoles. The app shows whatever price the
/// store returns for the user's country.
class ProductionBillingConfig {
  static const String monthlyProductId = 'atlas_monthly_pro';
  static const String annualProductId = 'atlas_annual_pro';
  static const String lifetimeProductId = 'atlas_lifetime_pro';
  static const String entitlementId = 'pro';

  static const List<String> allProductIds = [
    monthlyProductId,
    annualProductId,
    lifetimeProductId,
  ];

  /// RevenueCat when its key is set; the local test store in debug builds;
  /// otherwise no purchases at all (never free Pro in release builds).
  static BillingProvider resolveProvider() {
    if (RevenueCatBillingProvider.isAvailable) {
      return const RevenueCatBillingProvider();
    }
    if (kDebugMode) return const LocalBillingProvider();
    return const UnavailableBillingProvider();
  }

  /// Validates product ids and that a real store is configured.
  static bool isProductionReady() =>
      allProductIds.every((id) => id.startsWith('atlas_')) &&
      RevenueCatBillingProvider.isAvailable;
}
