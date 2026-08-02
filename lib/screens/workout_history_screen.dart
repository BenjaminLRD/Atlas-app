import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/workout_history.dart';
import '../providers/fitness_provider.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/section_header.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen>
    with SingleTickerProviderStateMixin {
  List<WorkoutHistory> _history = [];
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _history = FitnessProvider.instance.workoutHistory;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimationState();
    _history = FitnessProvider.instance.workoutHistory;
  }

  void _updateAnimationState() {
    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    if (!tickerEnabled || disableAnimations) {
      if (_glowController.isAnimating) {
        _glowController.stop();
      }
    } else {
      if (!_glowController.isAnimating) {
        _glowController.repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
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
    return total / _history.length;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: FitnessProvider.instance,
      builder: (context, _) {
        _history = FitnessProvider.instance.workoutHistory;
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
  },
);
}

  Widget _buildHeaderBar(BuildContext context) {
    return AppHeader.standard(
      title: 'Progress & Analytics',
      subtitle: '${_history.length} Completed Sessions',
      onNotificationsTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      ),
      onSettingsTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      ),
    );
  }

  Widget _buildSummaryStatsRow(BuildContext context) {
    final totalHoursStr = (_totalSecondsAccumulated / 3600).toStringAsFixed(1);
    final avgCompStr = '${_averageCompletionPercentage.toStringAsFixed(0)}%';

    return Row(
      children: [
        // Total Workouts Completed Card
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(14),
            borderColor: context.isDarkMode
                ? AppColors.primaryContainer.withValues(alpha: 0.3)
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryContainer.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: AppColors.primaryContainer,
                        size: 18,
                      ),
                    ),
                    Icon(
                      Icons.auto_graph_rounded,
                      size: 14,
                      color: AppColors.primaryContainer.withValues(alpha: 0.8),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'COMPLETED',
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${_history.length}',
                      style: AppTheme.headlineLg.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'sessions',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Total Active Time Card
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(14),
            borderColor: context.isDarkMode
                ? AppColors.primaryContainer.withValues(alpha: 0.3)
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryContainer.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.timer_sharp,
                        color: AppColors.primaryContainer,
                        size: 18,
                      ),
                    ),
                    Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppColors.primaryContainer.withValues(alpha: 0.8),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'ACTIVE TIME',
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      totalHoursStr,
                      style: AppTheme.headlineLg.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'hrs',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Avg Target Completion Card
        Expanded(
          child: AppCard(
            padding: const EdgeInsets.all(14),
            borderColor: context.isDarkMode
                ? AppColors.primaryContainer.withValues(alpha: 0.3)
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryContainer.withValues(alpha: 0.3),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.verified_rounded,
                        color: AppColors.primaryContainer,
                        size: 18,
                      ),
                    ),
                    Icon(
                      Icons.trending_up_rounded,
                      size: 14,
                      color: AppColors.primaryContainer.withValues(alpha: 0.8),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'AVG TARGET',
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 10,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w600,
                    color: context.appTextSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  avgCompStr,
                  style: AppTheme.headlineLg.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: context.isDarkMode
                        ? AppColors.primaryContainer
                        : AppColors.primary,
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
      borderColor: context.isDarkMode
          ? AppColors.primaryContainer.withValues(alpha: 0.25)
          : null,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryContainer.withValues(alpha: 0.15),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryContainer.withValues(
                    alpha: context.isDarkMode ? 0.3 : 0.15,
                  ),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              size: 38,
              color: AppColors.primaryContainer,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No Training History Yet',
            style: AppTheme.headlineMd.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Complete your first workout session to automatically log performance statistics, active duration, and progress volume!',
            textAlign: TextAlign.center,
            style: AppTheme.bodySm.copyWith(
              fontSize: 13,
              height: 1.4,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.primaryContainer.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.bolt,
                  size: 14,
                  color: AppColors.primaryContainer,
                ),
                const SizedBox(width: 4),
                Text(
                  'Start a workout from the Workouts tab',
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.isDarkMode
                        ? AppColors.primaryContainer
                        : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context) {
    return Column(
      children: List.generate(_history.length, (index) {
        final item = _history[index];
        final percentInt = item.completionPercentage.toInt();

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            padding: const EdgeInsets.all(16),
            borderColor: context.isDarkMode
                ? AppColors.primaryContainer.withValues(alpha: 0.3)
                : null,
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
                          fontWeight: FontWeight.w800,
                          color: context.appTextPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(
                          alpha: 0.2,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.primaryContainer.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryContainer.withValues(
                              alpha: 0.2,
                            ),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 12,
                            color: AppColors.primaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$percentInt% Done',
                            style: AppTheme.labelCaps.copyWith(
                              color: context.isDarkMode
                                  ? AppColors.primaryContainer
                                  : AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Date timestamp
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: context.appTextSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(item.dateCompleted),
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Key metrics row (Duration & Exercises)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: context.appSurfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: context.appOutlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.timer_outlined,
                            size: 13,
                            color: AppColors.primaryContainer,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _formatDuration(item.durationSeconds),
                            style: AppTheme.bodySm.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.appTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: context.appSurfaceElevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: context.appOutlineVariant.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.fitness_center_rounded,
                            size: 13,
                            color: AppColors.primaryContainer,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${item.exercisesCompleted} Exercises',
                            style: AppTheme.bodySm.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.appTextPrimary,
                            ),
                          ),
                        ],
                      ),
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
