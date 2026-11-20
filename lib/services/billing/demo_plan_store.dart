import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../data/local_storage.dart';
import '../../models/subscription_plan.dart';

/// A finished demo checkout. It holds the plan, amount and a mock reference,
/// never any payment detail.
class DemoPurchase {
  final PlanTier tier;
  final int amountInr;
  final PaymentMethod method;

  /// Name of the chosen option, such as "Google Pay" or "HDFC Bank". Not an
  /// account or card number.
  final String methodDetail;
  final String reference;
  final DateTime at;

  const DemoPurchase({
    required this.tier,
    required this.amountInr,
    required this.method,
    required this.methodDetail,
    required this.reference,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
    'tier': tier.name,
    'amountInr': amountInr,
    'method': method.name,
    'methodDetail': methodDetail,
    'reference': reference,
    'at': at.toIso8601String(),
  };

  static DemoPurchase? fromJson(Map<String, dynamic> j) {
    try {
      return DemoPurchase(
        tier: PlanTier.values.byName(j['tier'] as String),
        amountInr: j['amountInr'] as int,
        method: PaymentMethod.values.byName(j['method'] as String),
        methodDetail: j['methodDetail'] as String? ?? '',
        reference: j['reference'] as String,
        at: DateTime.parse(j['at'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}

/// The plan chosen in the demo checkout.
///
/// This is a demo preference kept on the device. It is NOT an entitlement:
/// nothing that decides real access (PremiumAccessManager, the AI quota on the
/// server, the store subscription) ever reads it. Showcase Mode uses its own
/// key, so a demo purchase made there never reaches a real account, and the
/// store never learns of either.
class DemoPlanStore extends ChangeNotifier {
  DemoPlanStore._();
  static final DemoPlanStore instance = DemoPlanStore._();

  static const String realKey = 'atlas_demo_plan_v1';
  static const String showcaseKey = 'atlas_showcase_demo_plan_v1';

  String get _key =>
      LocalStorage.isShowcaseModeEnabled() ? showcaseKey : realKey;

  /// The last demo purchase in the current mode, or null.
  DemoPurchase? get lastPurchase {
    final raw = LocalStorage.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return DemoPurchase.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// The demo plan in the current mode; Free when none was chosen.
  PlanTier get demoTier => lastPurchase?.tier ?? PlanTier.free;

  Future<void> record(DemoPurchase purchase) async {
    await LocalStorage.setString(_key, jsonEncode(purchase.toJson()));
    notifyListeners();
  }

  /// Back to Free in the demo. Removes only the demo preference.
  Future<void> resetToFree() async {
    await LocalStorage.setString(_key, '');
    notifyListeners();
  }
}
