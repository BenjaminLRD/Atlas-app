/// The three plans shown on the subscription page.
enum PlanTier { free, plus, pro }

/// One line in a plan's feature list.
class PlanFeature {
  final String text;

  /// Not available yet. Shown with a "Soon" tag, never as included.
  final bool comingSoon;

  const PlanFeature(this.text, {this.comingSoon = false});
}

/// A plan as displayed and sold in the demo checkout.
class PlanOffer {
  final PlanTier tier;
  final String name;

  /// Whole rupees per month.
  final int priceInr;
  final String tagline;
  final List<PlanFeature> features;
  final bool recommended;

  /// The top plan, shown with the premium treatment.
  final bool premium;

  const PlanOffer({
    required this.tier,
    required this.name,
    required this.priceInr,
    required this.tagline,
    required this.features,
    this.recommended = false,
    this.premium = false,
  });

  String get priceLabel => priceInr == 0 ? '₹0' : '₹$priceInr';
  bool get isFree => priceInr == 0;
}

/// Plan catalogue. Feature lines only describe things the app has; anything
/// that is not live yet is marked [PlanFeature.comingSoon].
///
/// AI limits: Free and Pro match the daily request limits the `ai-proxy`
/// function enforces today (10 / 400 chat requests, 3 / 100 food scans).
/// The server has no Plus level yet, so Plus's higher limit is marked Soon.
class PlanCatalog {
  const PlanCatalog._();

  static const PlanOffer free = PlanOffer(
    tier: PlanTier.free,
    name: 'Free',
    priceInr: 0,
    tagline: 'Everything you need to start training with Atlas.',
    features: [
      PlanFeature('Workout tracking and the exercise library'),
      PlanFeature('Cardio tracking: outdoor run and ride'),
      PlanFeature('Manual food and nutrition logging'),
      PlanFeature('Hydration tracking'),
      PlanFeature('Profile and community'),
      PlanFeature('Basic health and activity overview'),
      PlanFeature('Atlas AI: 10 requests a day, 3 AI food scans a day'),
    ],
  );

  static const PlanOffer plus = PlanOffer(
    tier: PlanTier.plus,
    name: 'Atlas Plus',
    priceInr: 199,
    tagline: 'More Atlas AI and deeper insight into your training.',
    recommended: true,
    features: [
      PlanFeature('Everything in Free'),
      PlanFeature('Detailed nutrition insights'),
      PlanFeature('Extended workout and cardio statistics'),
      PlanFeature('Detailed progress tracking'),
      PlanFeature('Enhanced recovery insights'),
      PlanFeature(
        'Atlas AI: up to 100 requests a day, 30 AI food scans a day',
        comingSoon: true,
      ),
    ],
  );

  static const PlanOffer pro = PlanOffer(
    tier: PlanTier.pro,
    name: 'Atlas Pro',
    priceInr: 499,
    tagline: 'The complete Atlas experience.',
    premium: true,
    features: [
      PlanFeature('Everything in Plus'),
      PlanFeature(
        'Atlas AI: up to 400 requests a day, 100 AI food scans a day',
      ),
      PlanFeature('Adaptive workout autoregulation'),
      PlanFeature('Recovery and deload intelligence'),
      PlanFeature('Wearable health sync'),
      PlanFeature('Advanced strength analytics and 1RM'),
      PlanFeature('Real-time pose form coach'),
      PlanFeature('12-week strength and recovery predictions'),
      PlanFeature('Proactive digital athlete insights'),
      PlanFeature('New premium features as they launch', comingSoon: true),
    ],
  );

  static const List<PlanOffer> all = [free, plus, pro];

  static PlanOffer of(PlanTier tier) => all.firstWhere((p) => p.tier == tier);
}

/// Payment options in the demo checkout.
enum PaymentMethod { upi, creditCard, debitCard, netBanking, wallet }

extension PaymentMethodLabel on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.upi:
        return 'UPI';
      case PaymentMethod.creditCard:
        return 'Credit card';
      case PaymentMethod.debitCard:
        return 'Debit card';
      case PaymentMethod.netBanking:
        return 'Net banking';
      case PaymentMethod.wallet:
        return 'Wallets';
    }
  }
}
