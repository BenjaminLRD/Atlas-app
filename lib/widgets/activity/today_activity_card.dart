import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../screens/cardio_activity_screen.dart';
import '../../services/activity_score_service.dart';
import '../../services/step_tracking_service.dart';
import '../../services/steps/step_counter_service.dart';
import '../common/app_card.dart';

/// Interactive Dashboard summary card showcasing today's movement, steps, calories, and activity score.
class TodayActivityCard extends StatelessWidget {
  final bool isWorkoutCompleted;
  final int workoutMinutes;

  const TodayActivityCard({
    super.key,
    this.isWorkoutCompleted = false,
    this.workoutMinutes = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StepCounterService.instance,
      builder: (context, _) => _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    const stepService = StepTrackingService();
    const scoreService = ActivityScoreService();

    final todayAct = stepService.today;
    final stepGoal = stepService.getStepGoal();
    final cardioMinutes = ActivityScoreService.cardioMinutesOn(DateTime.now());
    final calories = StepTrackingService.caloriesFor(todayAct.steps);
    final scoreResult = scoreService.getTodayScore(
      isWorkoutCompleted: isWorkoutCompleted,
      workoutMinutes: workoutMinutes,
    );

    final stepProgress = todayAct.steps == null || stepGoal <= 0
        ? 0.0
        : (todayAct.steps! / stepGoal).clamp(0.0, 1.0);

    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: () {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CardioActivityScreen()));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(
                          alpha: 0.15,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.directions_run_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Today\'s Activity',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: context.appTextPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${scoreResult.totalScore} Score ${scoreResult.emoji}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Steps Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${todayAct.display} / ${stepGoal.toString()} steps',
                  style: AppTheme.bodySm.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.appTextPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                todayAct.hasReading ? '${(stepProgress * 100).toInt()}%' : '--',
                style: AppTheme.bodySm.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: stepProgress,
              backgroundColor: context.appSurfaceElevated,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),

          // 3 Column Metrics
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context,
                  title: 'WORKOUT',
                  value: isWorkoutCompleted ? 'Completed ✅' : 'Pending ⏳',
                  color: isWorkoutCompleted
                      ? const Color(0xFF10B981)
                      : context.appTextSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMetricTile(
                  context,
                  title: 'CALORIES (EST.)',
                  value: calories == null ? '--' : '~${calories.round()} kcal',
                  color: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMetricTile(
                  context,
                  title: 'CARDIO TODAY',
                  value: '$cardioMinutes mins',
                  color: const Color(0xFF3B82F6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: context.appSurfaceElevated,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              style: AppTheme.labelCaps.copyWith(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: context.appTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
