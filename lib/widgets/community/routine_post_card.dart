import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/activity_post.dart';

/// Visual card component for shared workout routines and splits.
class RoutinePostCard extends StatelessWidget {
  final ActivityPost post;

  const RoutinePostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final splitName = post.metadata?['splitName'] as String? ?? post.title;
    final days = post.routineDays;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge
          // Header Tag Ribbon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_view_week_rounded,
                        color: Color(0xFF8B5CF6),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'WORKOUT SPLIT ROUTINE',
                          style: AppTheme.labelCaps.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF8B5CF6),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (post.savesCount > 0) ...[
                const SizedBox(width: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bookmark_added_rounded,
                      color: Color(0xFF8B5CF6),
                      size: 14,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${post.savesCount} saves',
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Split Title
          Text(
            splitName,
            style: AppTheme.headlineMd.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // Days List
          if (days.isNotEmpty)
            Column(
              children: days.take(3).map((day) {
                final dayName = day['dayName'] as String? ?? 'Day 1';
                final exercises =
                    (day['exercises'] as List?)
                        ?.map((e) => e.toString())
                        .toList() ??
                    [];

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: context.appSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF8B5CF6,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          dayName.split(':').first.trim(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF8B5CF6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          exercises.take(3).join(' • '),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.appTextPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
