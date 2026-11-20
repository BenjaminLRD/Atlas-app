import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/workout_intelligence_report.dart';
import '../common/app_card.dart';

/// Reusable UI card displaying AI workout verification, quality scoring, and coach rationale.
class AiVerifiedWorkoutCard extends StatelessWidget {
  final WorkoutIntelligenceReport? report;
  final String? coachNotes;
  final bool isAdapted;
  final String? adaptationNote;
  final VoidCallback? onTap;

  const AiVerifiedWorkoutCard({
    super.key,
    this.report,
    this.coachNotes,
    this.isAdapted = false,
    this.adaptationNote,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rep =
        report ??
        const WorkoutIntelligenceReport(
          overallScore: 92,
          goalAlignmentScore: 95,
          equipmentMatchScore: 100,
          muscleBalanceScore: 94,
          recoveryCompatibilityScore: 88,
          progressionScore: 90,
          personalizationScore: 95,
          strengths: [
            'Optimal 8-12 rep hypertrophy volume with compound anchors.',
            'Balanced push distribution across Chest, Shoulders, and Triceps.',
          ],
          aiExplanation: [
            'Your recovery is high today. Full volume programmed with progressive stimulus over your last session.',
          ],
        );

    final isDark = context.isDarkMode;
    final notes =
        coachNotes ??
        (rep.aiExplanation.isNotEmpty
            ? rep.aiExplanation.join(' ')
            : 'Your recovery is high today. Added an extra chest set because your last push session volume was below target.');

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: AI Workout Score & Star & Adaptation Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: AppColors.primaryContainer,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'AI Workout Score',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                          if (isAdapted) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.orange.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.bolt_rounded,
                                    size: 12,
                                    color: Colors.orange,
                                  ),
                                  SizedBox(width: 2),
                                  Text(
                                    'Adapted',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        isAdapted
                            ? 'Dynamically Adapted to Last Session'
                            : 'Verified Optimal Routine',
                        style: TextStyle(
                          fontSize: 11,
                          color: isAdapted
                              ? Colors.orange
                              : context.appTextSecondary,
                          fontWeight: isAdapted
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryContainer.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${rep.overallScore}/100',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryContainer,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // 2. Metrics Score Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  context,
                  label: 'Goal Match',
                  score: rep.goalAlignmentScore,
                  color: AppColors.primaryContainer,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricItem(
                  context,
                  label: 'Equipment',
                  score: rep.equipmentMatchScore,
                  color: Colors.cyanAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricItem(
                  context,
                  label: 'Recovery',
                  score: rep.recoveryCompatibilityScore,
                  color: Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricItem(
                  context,
                  label: 'Progression',
                  score: rep.progressionScore,
                  color: Colors.orangeAccent,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 3. AI Coach Notes Callout
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.psychology_rounded,
                      size: 15,
                      color: AppColors.primaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'AI Coach Notes',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: context.appTextPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  notes,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(
    BuildContext context, {
    required String label,
    required int? score,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.isDarkMode
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.appTextSecondary,
            ),
          ),
          Text(
            score == null ? '--' : '$score%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: (score ?? 0) >= 90 ? color : context.appTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
