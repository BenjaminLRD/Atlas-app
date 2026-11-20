import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../models/form_feedback.dart';

/// Card component presenting detected movement flaws, corrections, and cues.
class FeedbackCard extends StatelessWidget {
  final FormFeedback feedback;
  final VoidCallback? onDismiss;

  const FeedbackCard({super.key, required this.feedback, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: feedback.warnings.isNotEmpty
              ? const Color(0xFFEF4444).withValues(alpha: 0.6)
              : feedback.isGoodForm
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : const Color(0xFFF59E0B).withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    feedback.warnings.isNotEmpty
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_rounded,
                    color: feedback.warnings.isNotEmpty
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    feedback.warnings.isNotEmpty
                        ? 'FORM CORRECTIONS NEEDED'
                        : 'FORM ANALYSIS COMPLETE',
                    style: AppTheme.labelCaps.copyWith(
                      color: feedback.warnings.isNotEmpty
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFF6EE7B7),
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              if (onDismiss != null)
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Colors.white60,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Vision Confidence Badge
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.remove_red_eye_outlined,
                  size: 12,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Vision Confidence: ${feedback.confidencePercentage}%',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // 1. Warnings / Mistakes Detected
          if (feedback.warnings.isNotEmpty) ...[
            Text(
              'Mistakes Detected',
              style: AppTheme.bodySm.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            ...feedback.warnings.map(
              (warning) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFEF4444),
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        warning,
                        style: const TextStyle(
                          color: Color(0xFFFEE2E2),
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // 2. Corrections / Coaching Cues
          if (feedback.corrections.isNotEmpty) ...[
            Text(
              'Coaching Cues & Fixes',
              style: AppTheme.bodySm.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            ...feedback.corrections.map(
              (correction) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.lightbulb_outline_rounded,
                        color: Color(0xFFF59E0B),
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        correction,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // 3. Positive Feedback
          if (feedback.positiveFeedback.isNotEmpty) ...[
            Text(
              'Strengths',
              style: AppTheme.bodySm.copyWith(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            ...feedback.positiveFeedback.map(
              (pos) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.check_rounded,
                        color: Color(0xFF10B981),
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pos,
                        style: const TextStyle(
                          color: Color(0xFFD1FAE5),
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
