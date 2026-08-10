import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'app_card.dart';

/// Alert card rendered when accumulated fatigue crosses threshold and deload is recommended.
class DeloadAlertCard extends StatelessWidget {
  final VoidCallback? onAcceptDeload;

  const DeloadAlertCard({
    super.key,
    this.onAcceptDeload,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  '⚠ Recovery Warning',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: context.appTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Your training load has increased significantly while recovery indicators have dropped.',
              style: TextStyle(
                fontSize: 12,
                color: context.appTextSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.trending_down_rounded,
                    color: Colors.purple,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recommended: Deload Week',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.purple,
                          ),
                        ),
                        Text(
                          'Reduce working volume and weight by 40% to allow neuromuscular adaptation.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
