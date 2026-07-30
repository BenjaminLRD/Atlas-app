import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../data/workout_service.dart';
import '../models/workout_history.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/section_header.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final WorkoutService _workoutService;
  late List<WorkoutHistory> _history;
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _workoutService = AppDependencies.instance.workoutService;
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _loadHistory();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _loadHistory() {
    setState(() {
      _history = _workoutService.getWorkoutHistory();
    });
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months[dt.month - 1];
    final day = dt.day;
    final year = dt.year;
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$month $day, $year • $hour:$minute $period';
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    }
    final mins = seconds ~/ 60;
    final remainingSecs = seconds % 60;
    if (mins >= 60) {
      final hrs = mins ~/ 60;
      final remainingMins = mins % 60;
      return '${hrs}h ${remainingMins}m';
    }
    if (remainingSecs == 0) {
      return '$mins min';
    }
    return '${mins}m ${remainingSecs}s';
  }

  int get _totalSecondsAccumulated {
    return _history.fold(0, (sum, item) => sum + item.durationSeconds);
  }

  double get _averageCompletionPercentage {
    if (_history.isEmpty) return 0.0;
    final total = _history.fold(
      0.0,
      (sum, item) => sum + item.completionPercentage,
    );
    return (total / _history.length) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      body: Stack(
        children: [
          // Background ambient green glow highlights with animated pulse
          Positioned(
            top: -80,
            left: MediaQuery.of(context).size.width * 0.2,
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.6 + (_glowController.value * 0.4),
                  child: Transform.scale(
                    scale: 0.95 + (_glowController.value * 0.1),
                    child: child,
                  ),
                );
              },
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(
                    alpha: context.isDarkMode ? 0.16 : 0.08,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 60,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 130,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Navigation & Header Bar
                  _buildHeaderBar(context),
                  const SizedBox(height: 18),

                  // 2. Summary Statistics Bento Row
                  _buildSummaryStatsRow(context),
                  const SizedBox(height: 24),

                  // 3. Section Header
                  const SectionHeader(
                    title: 'Recorded Training Logs',
                    subtitle: 'Chronological workout history & volume stats',
                  ),
                  const SizedBox(height: 14),

                  // 4. Workout Logs List or Empty State
                  if (_history.isEmpty)
                    _buildEmptyState(context)
                  else
                    _buildHistoryList(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(BuildContext context) {
    return AppHeader.back(
      title: 'Workout History',
      subtitle: '${_history.length} Sessions',
      onBackTap: () => Navigator.maybePop(context),
    );
  }

  Widget _buildSummaryStatsRow(BuildContext context) {
    final totalHoursStr = (_totalSecondsAccumulated / 3600).toStringAsFixed(1);
    final avgCompStr = '${_averageCompletionPercentage.toStringAsFixed(0)}%';

    return Row(
      children: [
        // Total Workouts
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.emoji_events_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(height: 8),
                Text(
                  'COMPLETED',
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 10,
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_history.length}',
                  style: AppTheme.displayMetrics.copyWith(
                    fontSize: 20,
                    color: context.appTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Total Duration
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.timer_outlined,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(height: 8),
                Text(
                  'ACTIVE TIME',
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 10,
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$totalHoursStr hrs',
                  style: AppTheme.displayMetrics.copyWith(
                    fontSize: 20,
                    color: context.appTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Avg Completion
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.task_alt_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(height: 8),
                Text(
                  'AVG TARGET',
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 10,
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  avgCompStr,
                  style: AppTheme.displayMetrics.copyWith(
                    fontSize: 20,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.fitness_center_rounded,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No Completed Workouts Yet',
              style: AppTheme.headlineMd.copyWith(
                fontSize: 18,
                color: context.appTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Finish your first workout training session to automatically log performance statistics!',
              style: AppTheme.bodySm.copyWith(
                color: context.appTextSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context) {
    return Column(
      children: List.generate(_history.length, (index) {
        final item = _history[index];
        final percentInt = (item.completionPercentage * 100).toInt();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Workout name & percentage badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.workoutName,
                        style: AppTheme.headlineMd.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: context.appTextPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(
                          alpha: 0.25,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        '$percentInt% Completed',
                        style: AppTheme.labelCaps.copyWith(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Date timestamp
                Text(
                  _formatDate(item.dateCompleted),
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 10,
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 12),

                // Key metrics row (Duration & Exercises)
                Row(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _formatDuration(item.durationSeconds),
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.appTextPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Row(
                      children: [
                        const Icon(
                          Icons.format_list_bulleted_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${item.exercisesCompleted} Exercises',
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.appTextPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
