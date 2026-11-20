import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../common/app_card.dart';

/// Modal dialog / bottom sheet explaining transparently how sleep duration,
/// consistency, and recovery insights are calculated, with an explicit non-medical disclaimer.
class CalculationInfoModal extends StatelessWidget {
  const CalculationInfoModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => const CalculationInfoModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.appTextSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'How is this calculated?',
                          style: AppTheme.headlineSm.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: context.appTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Explanations
                _buildExplanationTile(
                  context,
                  icon: Icons.hotel_rounded,
                  title: 'Sleep Duration & Goal',
                  explanation:
                      'Sleep hours are computed from your bedtime and wake time. The default target is 8 hours of sleep per night.',
                ),
                const SizedBox(height: 10),
                _buildExplanationTile(
                  context,
                  icon: Icons.schedule_rounded,
                  title: 'Sleep Consistency',
                  explanation:
                      'Measured by comparing your daily bedtime variance over your last 7 recorded nights. Regular schedules promote higher quality restorative rest.',
                ),
                const SizedBox(height: 10),
                _buildExplanationTile(
                  context,
                  icon: Icons.favorite_rounded,
                  title: 'Physiological Baselines (RHR & HRV)',
                  explanation:
                      'When syncing a smartwatch or Apple Health / Health Connect, your resting heart rate and HRV are compared against your personal 7-day rolling baseline.',
                ),
                const SizedBox(height: 10),
                _buildExplanationTile(
                  context,
                  icon: Icons.label_important_outline_rounded,
                  title: 'Transparent Provenance Badges',
                  explanation:
                      '• "From Apple Health / Health Connect": Sourced directly from your connected device.\n'
                      '• "Manually logged": Calculated from your manual bedtime/wake logs.\n'
                      '• "Showcase Mode": Sample realistic data active during demo previews.',
                ),
                const SizedBox(height: 16),

                // Non-medical Disclaimer Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.amber,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Non-Medical Notice: Recovery insights are lifestyle summaries intended for training organization. They do not constitute medical advice or physiological diagnosis.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.appTextPrimary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'GOT IT',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExplanationTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String explanation,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  explanation,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appTextSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
