import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/subscription_plan.dart';
import '../services/billing/demo_plan_store.dart';
import 'checkout_screen.dart';
import '../models/subscription.dart';
import '../providers/fitness_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/app_dependencies.dart';
import '../services/billing/billing_provider.dart';
import '../services/billing/production_billing_config.dart';

/// Full screen paywall and plan management UI for Atlas Pro.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final DemoPlanStore _demo = DemoPlanStore.instance;

  @override
  void initState() {
    super.initState();
    _demo.addListener(_changed);
    FitnessProvider.instance.addListener(_changed);
  }

  @override
  void dispose() {
    _demo.removeListener(_changed);
    FitnessProvider.instance.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// The plan the athlete is on. A real store subscription is always Pro; the
  /// demo plan only applies when there is no real one.
  PlanTier get _currentTier =>
      FitnessProvider.instance.isPremium ? PlanTier.pro : _demo.demoTier;

  bool get _currentIsDemo =>
      !FitnessProvider.instance.isPremium && _demo.demoTier != PlanTier.free;

  Future<void> _choose(PlanOffer plan) async {
    if (plan.isFree) {
      await _demo.resetToFree();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Switched back to Free (demo).')),
      );
      return;
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => CheckoutScreen(plan: plan)));
  }

  String _selectedProductId = ProductionBillingConfig.annualProductId;
  bool _isLoading = false;
  late final Future<List<StoreOffer>> _offers = AppDependencies
      .instance
      .subscriptionService
      .billingProvider
      .getOffers();

  static String _periodLabel(String? period) {
    switch (period) {
      case 'P1M':
        return ' / month';
      case 'P1Y':
        return ' / year';
      case null:
        return ' one-time';
      default:
        return '';
    }
  }

  static String _planTitle(String productId) {
    switch (productId) {
      case ProductionBillingConfig.monthlyProductId:
        return 'Monthly Pro';
      case ProductionBillingConfig.lifetimeProductId:
        return 'Lifetime Pass';
      default:
        return 'Annual Pro';
    }
  }

  Future<void> _purchase(FitnessProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);
    String? message;
    try {
      final wasPremium = provider.isPremium;
      await provider.purchaseSubscription(_selectedProductId);
      if (provider.isPremium && !wasPremium) {
        message = 'Welcome to Atlas Pro!';
      } else if (provider.isPremium) {
        message = 'Your plan was updated.';
      }
      // Otherwise the purchase was cancelled: say nothing.
    } catch (e) {
      message = 'The purchase did not go through. You were not charged.';
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (message != null) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _restore(FitnessProvider provider) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);
    String message;
    try {
      await provider.restoreSubscriptionPurchases();
      message = provider.isPremium
          ? 'Your Atlas Pro subscription was restored.'
          : 'No previous purchases were found for this account.';
    } catch (_) {
      message = 'Could not reach the store. Try again.';
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  /// Cancelling happens in Google Play / the App Store.
  Future<void> _manage() async {
    final messenger = ScaffoldMessenger.of(context);
    final url = await AppDependencies.instance.subscriptionService
        .managementUrl();
    if (url != null &&
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      return;
    }
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Manage or cancel your subscription in Google Play > Payments & subscriptions.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = FitnessProvider.instance;
    final subscription = provider.subscription;
    final current = _currentTier;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        elevation: 0,
        title: const Text('Plans'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _currentPlanBanner(context, current),
            const SizedBox(height: 14),
            Text(
              'Choose how you train with Atlas.',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Plans are in preview. Payment here is a demo: nothing is charged and your real account limits do not change.',
              key: const Key('plans_preview_note'),
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: context.appTextSecondary,
              ),
            ),
            const SizedBox(height: 18),
            for (final plan in PlanCatalog.all) ...[
              _PlanCard(
                plan: plan,
                isCurrent: plan.tier == current,
                isDemoCurrent: plan.tier == current && _currentIsDemo,
                onSelect: () => _choose(plan),
              ),
              const SizedBox(height: 14),
            ],
            const SizedBox(height: 6),
            _storeSection(context, provider, subscription),
          ],
        ),
      ),
    );
  }

  Widget _currentPlanBanner(BuildContext context, PlanTier current) {
    final plan = PlanCatalog.of(current);
    final real = FitnessProvider.instance.isPremium;
    final purchase = _demo.lastPurchase;
    return GlassPanel(
      key: const Key('current_plan_banner'),
      borderColor: context.appPrimary.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_rounded, color: context.appPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your plan: ${plan.name}',
                  key: const Key('current_plan_name'),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            real
                ? 'Active through your store subscription.'
                : (_currentIsDemo
                      ? 'Demo plan${purchase == null ? '' : ' · ref ${purchase.reference}'}. Your real account is still on Free.'
                      : 'You are on the Free plan.'),
            style: TextStyle(color: context.appTextSecondary, fontSize: 13),
          ),
          if (_currentIsDemo) ...[
            const SizedBox(height: 8),
            TextButton(
              key: const Key('switch_to_free'),
              onPressed: () => _choose(PlanCatalog.free),
              child: const Text('Switch back to Free (demo)'),
            ),
          ],
        ],
      ),
    );
  }

  /// The real store subscription (Atlas Pro through Google Play / App Store).
  Widget _storeSection(
    BuildContext context,
    FitnessProvider provider,
    Subscription subscription,
  ) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const Key('store_section'),
        tilePadding: EdgeInsets.zero,
        title: Text(
          'Store subscription',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: context.appTextPrimary,
          ),
        ),
        subtitle: Text(
          'Subscribe to Atlas Pro through Google Play, restore or manage it.',
          style: TextStyle(fontSize: 12, color: context.appTextSecondary),
        ),
        children: [
          FutureBuilder<List<StoreOffer>>(
            future: _offers,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final offers = snapshot.data ?? const <StoreOffer>[];
              if (offers.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Store plans are not available right now. Check your connection, or try again later.',
                    style: TextStyle(
                      color: context.appTextSecondary,
                      fontSize: 13,
                    ),
                  ),
                );
              }
              if (!offers.any((o) => o.productId == _selectedProductId)) {
                _selectedProductId = offers.first.productId;
              }
              return Column(
                children: [
                  for (final offer in offers) ...[
                    _buildPlanOption(
                      productId: offer.productId,
                      title: _planTitle(offer.productId),
                      price:
                          '${offer.priceString}${_periodLabel(offer.period)}',
                      savingsTag:
                          offer.productId ==
                              ProductionBillingConfig.annualProductId
                          ? 'BEST VALUE'
                          : null,
                      isBestValue:
                          offer.productId ==
                          ProductionBillingConfig.annualProductId,
                    ),
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : () => _purchase(provider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.black,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              subscription.isPremium
                                  ? 'Switch to selected plan'
                                  : 'Subscribe to Atlas Pro',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                onPressed: _isLoading ? null : () => _restore(provider),
                child: const Text('Restore purchases'),
              ),
              if (subscription.isPremium)
                TextButton(
                  onPressed: _manage,
                  child: const Text('Manage subscription'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanOption({
    required String productId,
    required String title,
    required String price,
    String? savingsTag,
    bool isBestValue = false,
  }) {
    final isSelected = _selectedProductId == productId;

    return GestureDetector(
      onTap: () => setState(() => _selectedProductId = productId),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (savingsTag != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          savingsTag,
                          style: TextStyle(
                            color: isBestValue ? Colors.black : Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  price,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.white38,
                  width: isSelected ? 6 : 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanOffer plan;
  final bool isCurrent;
  final bool isDemoCurrent;
  final VoidCallback onSelect;

  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.isDemoCurrent,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.appPrimary;
    final amber = context.isDarkMode
        ? const Color(0xFFFBBF24)
        : const Color(0xFFB45309);
    final highlight = plan.recommended ? accent : (plan.premium ? amber : null);
    final tag = plan.recommended
        ? 'RECOMMENDED'
        : (plan.premium ? 'PREMIUM' : null);
    return GlassPanel(
      key: Key('plan_${plan.tier.name}'),
      borderColor: highlight?.withValues(alpha: 0.75),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
              if (tag != null)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: highlight!.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: highlight),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: highlight,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 4,
            children: [
              Text(
                plan.priceLabel,
                key: Key('price_${plan.tier.name}'),
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: context.appTextPrimary,
                  height: 1.0,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '/month',
                  style: TextStyle(color: context.appTextSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            plan.tagline,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 14),
          for (final f in plan.features)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      f.comingSoon
                          ? Icons.schedule_rounded
                          : Icons.check_circle_rounded,
                      size: 17,
                      color: f.comingSoon ? context.appTextMuted : accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: f.text,
                        children: [
                          if (f.comingSoon)
                            TextSpan(
                              text: '  Soon',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: context.appTextMuted,
                              ),
                            ),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.3,
                        color: f.comingSoon
                            ? context.appTextSecondary
                            : context.appTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: isCurrent
                ? OutlinedButton(
                    key: Key('plan_button_${plan.tier.name}'),
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      isDemoCurrent ? 'Current plan (demo)' : 'Current plan',
                    ),
                  )
                : ElevatedButton(
                    key: Key('plan_button_${plan.tier.name}'),
                    onPressed: onSelect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: plan.isFree
                          ? Colors.white.withValues(alpha: 0.1)
                          : accent,
                      foregroundColor: plan.isFree
                          ? context.appTextPrimary
                          : Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      plan.isFree
                          ? 'Switch to Free (demo)'
                          : 'Choose ${plan.name}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
