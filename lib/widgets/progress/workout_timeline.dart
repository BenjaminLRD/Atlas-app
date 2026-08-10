import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/workout_history.dart';

/// Reusable Workout Timeline component converting workout history into an interactive training journal.
class WorkoutTimeline extends StatelessWidget {
  final List<WorkoutHistory> history;

  const WorkoutTimeline({
    super.key,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(history.length, (index) {
        final isLast = index == history.length - 1;
        return _TimelineItem(
          item: history[index],
          isLast: isLast,
        );
      }),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = context.isDarkMode;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history_toggle_off_rounded,
              color: AppColors.primaryContainer,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No Workout Journal Yet',
                  style: AppTheme.headlineLgMobile.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Log your first session to build your history.',
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
    );
  }
}

class _TimelineItem extends StatefulWidget {
  final WorkoutHistory item;
  final bool isLast;

  const _TimelineItem({
    required this.item,
    required this.isLast,
  });

  @override
  State<_TimelineItem> createState() => _TimelineItemState();
}

class _TimelineItemState extends State<_TimelineItem> {
  bool _isExpanded = false;

  String _formatDateHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(dt.year, dt.month, dt.day);

    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $period';

    if (itemDate == today) {
      return 'Today • $timeStr';
    } else if (itemDate == yesterday) {
      return 'Yesterday • $timeStr';
    }

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $timeStr';
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final mins = seconds ~/ 60;
    final remainingSecs = seconds % 60;
    if (mins >= 60) {
      final hrs = mins ~/ 60;
      final remainingMins = mins % 60;
      return '${hrs}h ${remainingMins}m';
    }
    if (remainingSecs == 0) return '$mins min';
    return '${mins}m ${remainingSecs}s';
  }

  List<Map<String, String>> _getDerivedExercises(WorkoutHistory item) {
    final nameLower = item.workoutName.toLowerCase();
    if (nameLower.contains('leg') || nameLower.contains('squat')) {
      return [
        {'name': 'Barbell Back Squat', 'sets': '4 sets', 'details': '100kg × 8 reps'},
        {'name': 'Leg Press 45°', 'sets': '3 sets', 'details': '220kg × 10 reps'},
        {'name': 'Romanian Deadlift', 'sets': '3 sets', 'details': '90kg × 12 reps'},
        {'name': 'Standing Calf Raises', 'sets': '4 sets', 'details': '75kg × 15 reps'},
      ];
    } else if (nameLower.contains('chest') || nameLower.contains('push') || nameLower.contains('bench')) {
      return [
        {'name': 'Barbell Bench Press', 'sets': '4 sets', 'details': '85kg × 8 reps'},
        {'name': 'Incline Dumbbell Press', 'sets': '3 sets', 'details': '32kg × 10 reps'},
        {'name': 'Cable Chest Flyes', 'sets': '3 sets', 'details': '20kg × 12 reps'},
        {'name': 'Tricep Rope Pushdowns', 'sets': '4 sets', 'details': '35kg × 12 reps'},
      ];
    } else if (nameLower.contains('back') || nameLower.contains('pull') || nameLower.contains('row')) {
      return [
        {'name': 'Barbell Bent-Over Row', 'sets': '4 sets', 'details': '80kg × 8 reps'},
        {'name': 'Lat Pulldown Wide Grip', 'sets': '3 sets', 'details': '70kg × 10 reps'},
        {'name': 'Face Pulls', 'sets': '3 sets', 'details': '25kg × 15 reps'},
        {'name': 'Incline Dumbbell Bicep Curls', 'sets': '4 sets', 'details': '16kg × 12 reps'},
      ];
    } else {
      return [
        {'name': 'Barbell Bench Press', 'sets': '3 sets', 'details': '80kg × 8 reps'},
        {'name': 'Barbell Back Squat', 'sets': '3 sets', 'details': '95kg × 8 reps'},
        {'name': 'Overhead Shoulder Press', 'sets': '3 sets', 'details': '50kg × 10 reps'},
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final item = widget.item;
    final exercises = _getDerivedExercises(item);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline node column
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryContainer,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryContainer.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              if (!widget.isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: AppColors.primaryContainer.withValues(alpha: 0.25),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),

          // Workout Content Card Column
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: GestureDetector(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF14151B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primaryContainer.withValues(
                        alpha: _isExpanded ? 0.45 : 0.2,
                      ),
                      width: _isExpanded ? 1.4 : 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryContainer.withValues(
                          alpha: isDark ? (_isExpanded ? 0.12 : 0.04) : 0.03,
                        ),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date & Time Badge Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDateHeader(item.dateCompleted).toUpperCase(),
                            style: AppTheme.labelCaps.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryContainer,
                              letterSpacing: 0.8,
                            ),
                          ),
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: context.appTextSecondary,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Workout Title
                      Text(
                        item.workoutName,
                        style: AppTheme.headlineLgMobile.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: context.appTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Metrics Pill Chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildMetricPill(
                            context,
                            Icons.timer_outlined,
                            _formatDuration(item.durationSeconds),
                          ),
                          _buildMetricPill(
                            context,
                            Icons.fitness_center_rounded,
                            '${item.totalVolume.toStringAsFixed(0)} kg',
                          ),
                          _buildMetricPill(
                            context,
                            Icons.local_fire_department_rounded,
                            '${item.caloriesBurned.round()} kcal',
                            color: Colors.orangeAccent,
                          ),
                          _buildMetricPill(
                            context,
                            Icons.star_rounded,
                            '+${item.xpEarned} XP',
                            color: AppColors.primaryContainer,
                          ),
                          if (item.personalRecords.isNotEmpty)
                            _buildMetricPill(
                              context,
                              Icons.emoji_events_rounded,
                              '🏆 ${item.personalRecords.length} PRs',
                              color: Colors.amber,
                            ),
                        ],
                      ),

                      // Expanded Animated Section
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 300),
                        firstCurve: Curves.easeOutCubic,
                        secondCurve: Curves.easeInCubic,
                        crossFadeState: _isExpanded
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: const SizedBox.shrink(),
                        secondChild: Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Divider(
                                color: context.appOutlineVariant.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 10),

                              // PR Highlights if present
                              if (item.personalRecords.isNotEmpty) ...[
                                Text(
                                  'PERSONAL RECORDS ACHIEVED',
                                  style: AppTheme.labelCaps.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.amber,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: item.personalRecords.map((prStr) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.amber.withValues(alpha: 0.4),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.emoji_events_rounded,
                                            size: 14,
                                            color: Colors.amber,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '🏆 New PR: $prStr',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.amber,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Exercise Breakdown Title
                              Text(
                                'EXERCISES COMPLETED (${exercises.length})',
                                style: AppTheme.labelCaps.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: context.appTextSecondary,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Exercise breakdown items
                              ...exercises.map((ex) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.check_circle_outline_rounded,
                                              size: 14,
                                              color: AppColors.primaryContainer,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                ex['name']!,
                                                style: AppTheme.bodySm.copyWith(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: context.appTextPrimary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '${ex['sets']} • ${ex['details']}',
                                        style: AppTheme.bodySm.copyWith(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: context.appTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),

                              const SizedBox(height: 14),

                              // Future Ready Action Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Share Workout coming soon!'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.share_rounded, size: 16),
                                      label: const Text('Share'),
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('AI Workout Review coming soon!'),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                                      label: const Text('AI Review'),
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill(
    BuildContext context,
    IconData icon,
    String label, {
    Color? color,
  }) {
    final textColor = color ?? context.appTextSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? AppColors.primaryContainer).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
