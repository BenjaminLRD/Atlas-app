import 'package:flutter/material.dart';
import '../models/premium_feature.dart';
import '../models/subscription.dart';
import '../providers/fitness_provider.dart';
import '../services/billing/mock_billing_provider.dart';

/// Full screen paywall and plan management UI for Aizawl Gym Pro.
class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String _selectedProductId = MockBillingProvider.annualProductId;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final provider = FitnessProvider.instance;
    final subscription = provider.subscription;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2E),
        elevation: 0,
        title: const Text(
          'Aizawl Gym Pro',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Header Banner
            _buildStatusHeader(subscription),
            const SizedBox(height: 24),

            // Feature Checklist Header
            const Text(
              'What\'s Included in Pro:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Render all 5 Premium features
            ...PremiumFeature.values.map(_buildFeatureTile),

            const SizedBox(height: 24),
            const Text(
              'Choose Your Plan:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),

            // Plan Options
            _buildPlanOption(
              productId: MockBillingProvider.annualProductId,
              title: 'Annual Pro',
              price: '\$79.99 / year',
              savingsTag: 'SAVE 33% • BEST VALUE',
              isBestValue: true,
            ),
            const SizedBox(height: 10),
            _buildPlanOption(
              productId: MockBillingProvider.monthlyProductId,
              title: 'Monthly Pro',
              price: '\$9.99 / month',
            ),
            const SizedBox(height: 10),
            _buildPlanOption(
              productId: MockBillingProvider.lifetimeProductId,
              title: 'Lifetime Pass',
              price: '\$199.99 one-time',
              savingsTag: 'UNLIMITED ACCESS',
            ),

            const SizedBox(height: 28),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        setState(() => _isLoading = true);
                        await provider.purchaseSubscription(_selectedProductId);
                        if (!mounted) return;
                        setState(() => _isLoading = false);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Subscription activated! Welcome to Pro.'),
                            backgroundColor: Color(0xFF00B894),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 3,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : Text(
                        subscription.isPremium
                            ? 'Switch to Selected Plan'
                            : 'Upgrade to Pro',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 14),

            // Footer Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    setState(() => _isLoading = true);
                    await provider.restoreSubscriptionPurchases();
                    if (!mounted) return;
                    setState(() => _isLoading = false);
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Store purchases restored successfully.'),
                        backgroundColor: Color(0xFF6C5CE7),
                      ),
                    );
                  },
                  child: const Text(
                    'Restore Purchases',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
                if (subscription.isPremium)
                  TextButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await provider.cancelUserSubscription();
                      if (!mounted) return;
                      setState(() {});
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Subscription auto-renew canceled.'),
                        ),
                      );
                    },
                    child: const Text(
                      'Cancel Auto-Renew',
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(Subscription subscription) {
    final isPro = subscription.isPremium;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPro
              ? const [Color(0xFF6C5CE7), Color(0xFFA29BFE)]
              : const [Color(0xFF2D3436), Color(0xFF1E1E2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isPro ? const Color(0xFF6C5CE7) : Colors.black).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isPro ? Icons.workspace_premium_rounded : Icons.star_border_rounded,
            color: isPro ? const Color(0xFFFFD700) : Colors.white60,
            size: 36,
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isPro ? 'Aizawl Gym Pro Active' : 'Current Tier: Free',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isPro
                    ? 'Plan: ${subscription.tier.name.toUpperCase()} • ${subscription.status.name}'
                    : 'Unlock AI Coach, Deload Alerts & Wearables',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTile(PremiumFeature feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Color(0xFFFFD700),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  feature.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
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
              ? const Color(0xFF6C5CE7).withValues(alpha: 0.2)
              : const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFFD700)
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
                          color: isBestValue
                              ? const Color(0xFFFFD700)
                              : const Color(0xFF00B894),
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
                  color: isSelected ? const Color(0xFFFFD700) : Colors.white38,
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
