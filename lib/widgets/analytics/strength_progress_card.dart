import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/progress_summary.dart';
import '../../widgets/common/app_button.dart';

/// Horizontal scrolling Strength Progression cards with progress bars and exercise detail modal.
class StrengthProgressCard extends StatelessWidget {
  final List<TopExercise> topExercises;

  const StrengthProgressCard({
    super.key,
    required this.topExercises,
  });

  void _showExerciseDetailModal(BuildContext context, TopExercise exercise) {
    final isDark = context.isDarkMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exercise.exerciseName,
                            style: AppTheme.headlineMd.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            exercise.muscleGroup,
                            style: AppTheme.bodySm.copyWith(
                              fontSize: 12,
                              color: AppColors.primaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: context.appOutlineVariant.withValues(alpha: 0.3)),
                const SizedBox(height: 14),

                _buildModalRow(context, 'Current PR', '${exercise.maxWeight.toStringAsFixed(1)} kg'),
                const SizedBox(height: 10),
                _buildModalRow(context, 'Improvement', '+${exercise.percentageImprovement.toStringAsFixed(1)}%'),
                const SizedBox(height: 10),
                _buildModalRow(context, 'Sessions Tracked', '${exercise.sessionsCompleted}'),
                const SizedBox(height: 10),
                _buildModalRow(context, 'Total Lifetime Volume', '${exercise.totalVolume.toStringAsFixed(0)} kg'),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryContainer.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryContainer, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Recommendation: Increase load by +2.5kg next session to keep progressive overload.',
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.appTextPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                AppButton.primary(
                  label: 'CLOSE',
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTheme.bodySm.copyWith(
            fontSize: 13,
            color: context.appTextSecondary,
          ),
        ),
        Text(
          value,
          style: AppTheme.headlineMd.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: context.appTextPrimary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    if (topExercises.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STRENGTH PROGRESSION',
            style: AppTheme.labelCaps.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: context.appTextSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF14151B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: context.appOutlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.trending_up_rounded,
                    color: AppColors.primaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Strength Logs Yet',
                        style: AppTheme.headlineLgMobile.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: context.appTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Complete workouts to track exercise progression.',
                        style: AppTheme.bodySm.copyWith(
                          fontSize: 12,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'STRENGTH PROGRESSION',
              style: AppTheme.labelCaps.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: context.appTextSecondary,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              '${topExercises.length} Tracked',
              style: AppTheme.bodySm.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 148,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: topExercises.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final ex = topExercises[index];
              final prevWeight = (ex.maxWeight / (1 + (ex.percentageImprovement / 100.0))).clamp(0.0, ex.maxWeight);

              return GestureDetector(
                onTap: () => _showExerciseDetailModal(context, ex),
                child: Container(
                  width: 250,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF14151B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryContainer.withValues(alpha: 0.25),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryContainer.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              ex.exerciseName,
                              style: AppTheme.headlineLgMobile.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: context.appTextPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '+${ex.percentageImprovement.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${prevWeight.toStringAsFixed(1)}kg  →  ${ex.maxWeight.toStringAsFixed(1)}kg',
                        style: AppTheme.headlineMd.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: context.appTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Animated progress bar
                      TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        tween: Tween<double>(begin: 0, end: (ex.percentageImprovement / 50.0).clamp(0.1, 1.0)),
                        builder: (context, val, _) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: val,
                              minHeight: 6,
                              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryContainer),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
