import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app_theme.dart';
import '../../models/referral.dart';
import '../../services/referral_service.dart';
import '../../services/growth_analytics_service.dart';
import '../../widgets/common/app_card.dart';

/// Card widget managing referral code sharing, referral statistics, and claiming referral codes.
class ReferralCard extends StatefulWidget {
  const ReferralCard({super.key});

  @override
  State<ReferralCard> createState() => _ReferralCardState();
}

class _ReferralCardState extends State<ReferralCard> {
  late final ReferralService _referralService;
  late ReferralData _data;
  final TextEditingController _codeController = TextEditingController();
  bool _isClaiming = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _referralService = ReferralService.instance;
    _data = _referralService.getReferralData();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _claimCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isClaiming = true;
      _statusMessage = null;
    });

    final success = await _referralService.claimReferralCode(code);

    if (!mounted) return;

    setState(() {
      _isClaiming = false;
      if (success) {
        _statusMessage = 'Referral Code Claimed! +250 XP Granted!';
        _codeController.clear();
      } else {
        _statusMessage = 'Invalid or duplicate referral code.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.card_giftcard_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REFERRAL PROGRAM',
                      style: AppTheme.headlineMd.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      'Invite friends & earn 500 XP per conversion',
                      style: AppTheme.bodySm.copyWith(
                        color: context.appTextSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Code Container with Copy Action
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: context.appSurfaceVariant,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.appOutlineVariant),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR REFERRAL CODE',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 9,
                        color: context.appTextSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _data.referralCode,
                      style: AppTheme.headlineMd.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _data.referralCode));
                    GrowthAnalyticsService.instance.trackReferralSent();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Referral Code Copied to Clipboard!')),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('COPY'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w800, fontSize: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Referral Stats Row
          Row(
            children: [
              Expanded(
                child: _buildStatTile(context, 'Invited', '${_data.totalReferredCount}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatTile(context, 'Joined', '${_data.convertedCount}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatTile(context, 'XP Earned', '+${_data.totalXpEarned}'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Claim Friend Code Input
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _codeController,
                    style: AppTheme.bodySm.copyWith(fontSize: 12, fontWeight: FontWeight.w700),
                    decoration: InputDecoration(
                      hintText: 'Enter friend\'s code (e.g. AIRZAWL-ALEX)',
                      hintStyle: AppTheme.bodySm.copyWith(fontSize: 10, color: context.appTextSecondary),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      filled: true,
                      fillColor: context.appSurfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: _isClaiming ? null : _claimCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isClaiming
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('REDEEM', style: AppTheme.bodySm.copyWith(fontWeight: FontWeight.w800, fontSize: 11)),
                ),
              ),
            ],
          ),

          if (_statusMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _statusMessage!,
              style: AppTheme.bodySm.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _statusMessage!.contains('Claimed') ? AppColors.primary : AppColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatTile(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: context.appSurfaceVariant,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: AppTheme.bodySm.copyWith(fontSize: 9, color: context.appTextSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTheme.headlineMd.copyWith(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
