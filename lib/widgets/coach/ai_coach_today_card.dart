import 'package:flutter/material.dart';
import '../../models/daily_coach_brief.dart';
import '../../theme/app_theme.dart';

/// Premium autonomous AI Coach Today card rendered on the dashboard.
/// Highlights live recovery readiness, scheduled workout split, daily protein pacing,
/// and instant action triggers.
class AICoachTodayCard extends StatelessWidget {
  final DailyCoachBrief brief;
  final VoidCallback? onStartWorkout;
  final VoidCallback? onAskCoach;
  final VoidCallback? onViewDetails;

  const AICoachTodayCard({
    super.key,
    required this.brief,
    this.onStartWorkout,
    this.onAskCoach,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Only recorded values: no score, workout or protein target is made up.
    final int? recoveryScore = brief.recovery.scoreOrNull;
    final workoutTitle = brief.workout.title.isNotEmpty
        ? brief.workout.title
        : 'No workout planned';
    final consumedProtein = brief.nutrition.proteinGrams.toInt();
    final int? targetProtein = brief.nutrition.proteinTargetGrams > 0
        ? brief.nutrition.proteinTargetGrams.toInt()
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: AI Coach Badge & Recovery Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.smart_toy_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI COACH TODAY',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        brief.greeting,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: recoveryScore == null
                      ? Colors.grey.withValues(alpha: 0.15)
                      : (recoveryScore >= 75
                            ? Colors.green.withValues(alpha: 0.15)
                            : (recoveryScore >= 50
                                  ? Colors.orange.withValues(alpha: 0.15)
                                  : Colors.red.withValues(alpha: 0.15))),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Text(
                      recoveryScore == null ? 'Recovery --' : '$recoveryScore%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: recoveryScore == null
                            ? Colors.grey
                            : (recoveryScore >= 75
                                  ? Colors.green
                                  : (recoveryScore >= 50
                                        ? Colors.orange
                                        : Colors.red)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('🔥', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Proactive Coach Directive
          if (brief.proactiveMessage.isNotEmpty) ...[
            Text(
              brief.proactiveMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(
                  alpha: 0.85,
                ),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Focus & Nutrition Row
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "TODAY'S FOCUS",
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        workoutTitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROTEIN PACING',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.grey,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        targetProtein == null
                            ? '${consumedProtein}g'
                            : '$consumedProtein/${targetProtein}g',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onStartWorkout,
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Start Workout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onAskCoach,
                icon: const Icon(Icons.chat_bubble_outline, size: 16),
                label: const Text('Ask Coach'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
