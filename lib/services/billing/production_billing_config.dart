/// Configuration helper for App Store / Google Play In-App Purchase launch readiness.
class ProductionBillingConfig {
  static const String monthlyProductId = 'aizawl_gym_monthly_pro';
  static const String annualProductId = 'aizawl_gym_annual_pro';
  static const String lifetimeProductId = 'aizawl_gym_lifetime_pro';

  static const List<String> allProductIds = [
    monthlyProductId,
    annualProductId,
    lifetimeProductId,
  ];

  static const String receiptVerificationEndpoint =
      'https://api.aizawlgym.com/v1/billing/verify-receipt';

  /// Validates production store readiness and product SKUs.
  static bool isProductionReady() {
    for (final id in allProductIds) {
      if (id.isEmpty || !id.startsWith('aizawl_gym_')) {
        return false;
      }
    }
    return receiptVerificationEndpoint.startsWith('https://');
  }
}
