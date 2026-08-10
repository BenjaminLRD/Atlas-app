import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/personal_record.dart';
import '../../widgets/common/app_button.dart';

/// Personal Records section component displaying horizontal scrolling PR cards with detail bottom sheet.
class PersonalRecordsSection extends StatelessWidget {
  final List<PersonalRecord> records;

  const PersonalRecordsSection({
    super.key,
    required this.records,
  });

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Recent';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatFullDate(DateTime? dt) {
    if (dt == null) return 'August 5, 2026';
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  IconData _getRecordIcon(String recordType) {
    final typeLower = recordType.toLowerCase();
    if (typeLower.contains('volume')) {
      return Icons.local_fire_department_rounded; // 🔥 Highest Session Volume
    } else if (typeLower.contains('rep')) {
      return Icons.flash_on_rounded; // ⚡ Most Reps
    } else {
      return Icons.emoji_events_rounded; // 🏆 Heaviest Lift
    }
  }

  Color _getRecordAccentColor(String recordType) {
    final typeLower = recordType.toLowerCase();
    if (typeLower.contains('volume')) {
      return Colors.orangeAccent;
    } else if (typeLower.contains('rep')) {
      return Colors.lightBlueAccent;
    } else {
      return AppColors.primaryContainer;
    }
  }

  void _showPRDetailModal(BuildContext context, PersonalRecord record) {
    final isDark = context.isDarkMode;
    final accentColor = _getRecordAccentColor(record.recordType);

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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_getRecordIcon(record.recordType), color: accentColor, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.isNew ? '🏆 New Personal Record' : '🏆 Personal Record Details',
                              style: AppTheme.headlineMd.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: context.appTextPrimary,
                              ),
                            ),
                            Text(
                              record.recordType,
                              style: AppTheme.bodySm.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ],
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

                _buildModalDetailRow(context, 'Exercise', record.exerciseName),
                const SizedBox(height: 10),
                _buildModalDetailRow(
                  context,
                  'Previous',
                  record.previousValue > 0
                      ? '${record.previousValue % 1 == 0 ? record.previousValue.toInt() : record.previousValue.toStringAsFixed(1)} kg'
                      : 'N/A',
                ),
                const SizedBox(height: 10),
                _buildModalDetailRow(context, 'New Record', record.formattedValue),
                const SizedBox(height: 10),
                _buildModalDetailRow(context, 'Improvement', '+${record.improvementPercentage.toStringAsFixed(0)}%'),
                const SizedBox(height: 10),
                _buildModalDetailRow(context, 'Achieved', _formatFullDate(record.achievedDate)),
                const SizedBox(height: 10),
                _buildModalDetailRow(
                  context,
                  'Workout',
                  record.workoutId ?? '${record.exerciseName} Overload Session',
                ),
                const SizedBox(height: 18),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.military_tech_rounded, color: accentColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Celebration Unlocked: You broke your previous PR on this session!',
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

  Widget _buildModalDetailRow(BuildContext context, String label, String value) {
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

    if (records.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PERSONAL RECORDS',
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
                    color: Colors.amber.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Colors.amber,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No Personal Records Yet',
                        style: AppTheme.headlineLgMobile.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: context.appTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Set your first PR by completing workouts.',
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
              'PERSONAL RECORDS',
              style: AppTheme.labelCaps.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: context.appTextSecondary,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              '${records.length} Achievements',
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
          height: 154,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: records.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = records[index];
              final accentColor = _getRecordAccentColor(item.recordType);

              return TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 300 + (index * 100)),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(begin: 0.85, end: 1.0),
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: child,
                  );
                },
                child: GestureDetector(
                  onTap: () => _showPRDetailModal(context, item),
                  child: Container(
                    width: 240,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF14151B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accentColor.withValues(alpha: item.isNew ? 0.5 : 0.25),
                        width: item.isNew ? 1.6 : 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: item.isNew ? 0.15 : 0.05),
                          blurRadius: 12,
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
                            Row(
                              children: [
                                Icon(_getRecordIcon(item.recordType), size: 16, color: accentColor),
                                const SizedBox(width: 4),
                                Text(
                                  item.recordType.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: accentColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            if (item.isNew)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'NEW',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        Text(
                          item.exerciseName,
                          style: AppTheme.headlineLgMobile.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: context.appTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // Value animation
                        TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutCubic,
                          tween: Tween<double>(begin: 0, end: item.value),
                          builder: (context, val, _) {
                            final String displayVal = item.recordType.toLowerCase().contains('rep')
                                ? '${val.toInt()} reps'
                                : '${val % 1 == 0 ? val.toInt() : val.toStringAsFixed(1)} kg';

                            return Text(
                              displayVal,
                              style: AppTheme.headlineLgMobile.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: context.appTextPrimary,
                              ),
                            );
                          },
                        ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '+${item.improvementPercentage.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: accentColor,
                                ),
                              ),
                            ),
                            Text(
                              _formatDate(item.achievedDate),
                              style: AppTheme.bodySm.copyWith(
                                fontSize: 10,
                                color: context.appTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
