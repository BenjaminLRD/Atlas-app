import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'workout_session_screen.dart';
import 'weekly_workout_plan_screen.dart';
import 'workout_history_screen.dart';

class WorkoutPlanScreen extends StatelessWidget {
  const WorkoutPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 64, bottom: 100),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // Header
            _buildHeader(context),
            const SizedBox(height: 48),

            // Today's Workout Highlight
            _buildTodayWorkout(context),
            const SizedBox(height: 24),

            // Weekly Schedule
            _buildWeeklySchedule(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ACTIVE PROGRAM',
              style: AppTheme.labelCaps.copyWith(
                color: AppColors.tertiary,
                letterSpacing: 1.5,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const WorkoutHistoryScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.history, size: 16, color: AppColors.primary),
              label: Text(
                'History',
                style: AppTheme.labelCaps.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.outlineVariant),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Hybrid Strength II',
          style: AppTheme.headlineLgMobile,
        ),
        const SizedBox(height: 8),
        Text(
          'Week 4: Peak Performance phase. Focus on disciplined breathing and technical integrity during high-intensity blocks.',
          style: AppTheme.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Oct 14 - Oct 20',
                style: AppTheme.labelCaps.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTodayWorkout(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'TODAY',
                  style: AppTheme.labelCaps.copyWith(
                    color: AppColors.onPrimary,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'WEDNESDAY',
                style: AppTheme.labelCaps.copyWith(
                  color: AppColors.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Upper Body Flow & Power',
            style: AppTheme.headlineMd,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMetricCol('Duration', '65', 'min'),
              const SizedBox(width: 32),
              _buildIntensityCol(),
              const SizedBox(width: 32),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FOCUS',
                    style: AppTheme.labelCaps.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hypertrophy',
                    style: AppTheme.bodySm.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WorkoutSessionScreen(),
                ),
              );
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Workout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
              textStyle: AppTheme.bodyMd.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCol(String label, String value, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTheme.labelCaps.copyWith(
            color: AppColors.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: AppTheme.dataDisplay,
              ),
              TextSpan(
                text: unit,
                style: AppTheme.bodyMd.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntensityCol() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'INTENSITY',
          style: AppTheme.labelCaps.copyWith(
            color: AppColors.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primaryFixed,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'HIGH',
            style: AppTheme.labelCaps.copyWith(
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeeklySchedule(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Weekly Schedule',
            style: AppTheme.headlineMd.copyWith(fontSize: 20),
          ),
        ),
        const SizedBox(height: 12),
        _buildDayRow(
          context,
          day: 'MON',
          date: '14',
          title: 'Lower Body Technical',
          subtitle: 'Focus: Knee stability & mobility',
          isActive: false,
        ),
        const SizedBox(height: 12),
        _buildDayRow(
          context,
          day: 'TUE',
          date: '15',
          title: 'Active Recovery: Zone 2',
          subtitle: 'Light cycling or swimming',
          isActive: false,
        ),
        const SizedBox(height: 12),
        _buildDayRow(
          context,
          day: 'WED',
          date: '16',
          title: 'Upper Body Flow & Power',
          subtitle: 'Current Session',
          isActive: true,
        ),
        const SizedBox(height: 12),
        _buildDayRow(
          context,
          day: 'THU',
          date: '17',
          title: 'Rest & Mindfulness',
          subtitle: 'Complete recovery',
          isActive: false,
        ),
        const SizedBox(height: 12),
        _buildDayRow(
          context,
          day: 'FRI',
          date: '18',
          title: 'Full Body Integrative',
          subtitle: 'Compound movements',
          isActive: false,
        ),
      ],
    );
  }

  Widget _buildDayRow(
    BuildContext context, {
    required String day,
    required String date,
    required String title,
    required String subtitle,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const WeeklyWorkoutPlanScreen(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primaryFixed.withValues(alpha: 0.3)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.outlineVariant,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Column(
                children: [
                  Text(
                    day,
                    style: AppTheme.labelCaps.copyWith(
                      color: isActive ? AppColors.primary : AppColors.tertiary,
                      fontSize: 10,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  Text(
                    date,
                    style: AppTheme.headlineMd.copyWith(
                      fontSize: 18,
                      color: isActive ? AppColors.primary : AppColors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 32,
              width: 1,
              color: isActive
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.outlineVariant,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTheme.bodyMd.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? AppColors.onPrimaryContainer
                          : AppColors.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTheme.bodySm.copyWith(
                      color: isActive
                          ? AppColors.onPrimaryFixedVariant
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'ACTIVE',
                  style: AppTheme.labelCaps.copyWith(
                    color: AppColors.onPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              color: isActive ? AppColors.primary : AppColors.outlineVariant,
            ),
          ],
        ),
      ),
    );
  }
}
