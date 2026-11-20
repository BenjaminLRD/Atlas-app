import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../common/app_card.dart';
import '../common/app_button.dart';

/// Card rendered in chat when AI generates an actionable workout proposal,
/// allowing the athlete to inspect exercises, see reasoning, and save or modify.
class AIActionPreviewCard extends StatelessWidget {
  final String title;
  final int durationMinutes;
  final String? focus;
  final String? rationale;
  final List<Map<String, dynamic>> exercises;
  final VoidCallback? onSave;
  final VoidCallback? onModify;
  final VoidCallback? onCancel;

  const AIActionPreviewCard({
    super.key,
    required this.title,
    required this.durationMinutes,
    this.focus,
    this.rationale,
    required this.exercises,
    this.onSave,
    this.onModify,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      backgroundColor: context.appCardBg,
      borderColor: AppColors.primary.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs - 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: AppRadii.borderSm,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.primary,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'AI Generated Routine',
                      style: AppTheme.labelCaps.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: context.appTextSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$durationMinutes mins',
                    style: AppTheme.bodySm.copyWith(
                      color: context.appTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Workout Title
          Text(
            title,
            style: AppTheme.bodyLg.copyWith(
              color: context.appTextPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),

          // Rationale / Why
          if (rationale != null && rationale!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              rationale!,
              style: AppTheme.bodySm.copyWith(
                color: context.appTextSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),

          // Exercise List Preview
          Text(
            'Exercises (${exercises.length})',
            style: AppTheme.labelCaps.copyWith(color: context.appTextSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: context.isDarkMode
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: AppRadii.borderSm,
              border: Border.all(color: context.appCardBorder),
            ),
            child: Column(
              children: exercises.map((ex) {
                final name = ex['name'] as String? ?? 'Exercise';
                final sets = ex['sets'] ?? 3;
                final reps = ex['reps'] ?? 10;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          name,
                          style: AppTheme.bodySm.copyWith(
                            color: context.appTextPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '$sets × $reps',
                        style: AppTheme.bodySm.copyWith(
                          color: context.appTextSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Action Buttons: Save, Modify, Cancel
          Row(
            children: [
              Expanded(
                flex: 2,
                child: AppButton.primary(
                  label: 'Save Workout',
                  icon: Icons.bookmark_added_rounded,
                  onPressed: onSave ?? () {},
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton.secondary(
                  label: 'Modify',
                  icon: Icons.tune_rounded,
                  onPressed: onModify ?? () {},
                ),
              ),
              if (onCancel != null) ...[
                const SizedBox(width: AppSpacing.xs),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: context.appTextSecondary,
                  tooltip: 'Cancel',
                  onPressed: onCancel,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
