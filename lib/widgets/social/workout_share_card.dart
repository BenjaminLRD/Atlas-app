import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/activity_item.dart';
import '../../services/social_service.dart';
import '../../services/growth_analytics_service.dart';
import '../../widgets/common/app_button.dart';

enum ShareCardTheme {
  cyberpunkNeon,
  goldenTrophy,
  darkGlass,
  vitalityEmerald,
}

/// Visual shareable card widget capturing completed workout stats
class WorkoutShareCard extends StatelessWidget {
  final String workoutTitle;
  final int durationMinutes;
  final int exercisesCompleted;
  final double totalVolumeKg;
  final int caloriesBurned;
  final int xpEarned;
  final List<String> personalRecords;
  final ShareCardTheme theme;

  const WorkoutShareCard({
    super.key,
    required this.workoutTitle,
    required this.durationMinutes,
    required this.exercisesCompleted,
    required this.totalVolumeKg,
    required this.caloriesBurned,
    required this.xpEarned,
    this.personalRecords = const [],
    this.theme = ShareCardTheme.vitalityEmerald,
  });

  BoxDecoration _getThemeDecoration() {
    switch (theme) {
      case ShareCardTheme.cyberpunkNeon:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF4C1D95)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: const Color(0xFFA855F7), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFA855F7).withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        );
      case ShareCardTheme.goldenTrophy:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: AppGradients.goldRank,
          border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
          boxShadow: [AppShadows.goldGlow],
        );
      case ShareCardTheme.darkGlass:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: AppGradients.darkGlass,
          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
          boxShadow: [AppShadows.softCard],
        );
      case ShareCardTheme.vitalityEmerald:
        return BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: AppGradients.emeraldGlow,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [AppShadows.ambientGlow],
        );
    }
  }

  Color _getAccentColor() {
    switch (theme) {
      case ShareCardTheme.cyberpunkNeon:
        return const Color(0xFFC084FC);
      case ShareCardTheme.goldenTrophy:
        return const Color(0xFFFDE047);
      case ShareCardTheme.darkGlass:
        return Colors.white;
      case ShareCardTheme.vitalityEmerald:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _getAccentColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _getThemeDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Logo & Branding
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.fitness_center_rounded, color: accent, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AIZAWL GYM',
                    style: AppTheme.bodySm.copyWith(
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accent.withValues(alpha: 0.5)),
                ),
                child: Text(
                  '+$xpEarned XP',
                  style: AppTheme.bodySm.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Workout Title
          Text(
            workoutTitle,
            style: AppTheme.headlineLg.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 22,
            ),
          ),

          const SizedBox(height: 16),

          // 2x2 Stats Grid
          Row(
            children: [
              Expanded(
                child: _buildStatItem('DURATION', '${durationMinutes}m', Icons.timer_rounded, accent),
              ),
              Expanded(
                child: _buildStatItem('EXERCISES', '$exercisesCompleted', Icons.format_list_bulleted_rounded, accent),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _buildStatItem('TOTAL VOLUME', '${totalVolumeKg.toInt()} kg', Icons.scale_rounded, accent),
              ),
              Expanded(
                child: _buildStatItem('CALORIES', '$caloriesBurned kcal', Icons.local_fire_department_rounded, accent),
              ),
            ],
          ),

          if (personalRecords.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events_rounded, color: Color(0xFFFBBF24), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PR: ${personalRecords.first}',
                      style: AppTheme.bodySm.copyWith(
                        color: const Color(0xFFFDE047),
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color accent) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.bodySm.copyWith(
                  fontSize: 9,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: AppTheme.headlineMd.copyWith(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Show share bottom sheet with theme switching and feed posting action
  static Future<void> showShareModal(
    BuildContext context, {
    required String workoutTitle,
    required int durationMinutes,
    required int exercisesCompleted,
    required double totalVolumeKg,
    required int caloriesBurned,
    required int xpEarned,
    List<String> personalRecords = const [],
  }) async {
    ShareCardTheme selectedTheme = ShareCardTheme.vitalityEmerald;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.appSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.appOutlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'SHARE WORKOUT CARD',
                    style: AppTheme.headlineLg.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Share Card Preview
                  WorkoutShareCard(
                    workoutTitle: workoutTitle,
                    durationMinutes: durationMinutes,
                    exercisesCompleted: exercisesCompleted,
                    totalVolumeKg: totalVolumeKg,
                    caloriesBurned: caloriesBurned,
                    xpEarned: xpEarned,
                    personalRecords: personalRecords,
                    theme: selectedTheme,
                  ),

                  const SizedBox(height: 16),

                  // Theme Selector Chips
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: ShareCardTheme.values.map((t) {
                      final isSel = t == selectedTheme;
                      return GestureDetector(
                        onTap: () => setState(() => selectedTheme = t),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSel ? context.appPrimary : context.appSurfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            t.name.replaceAll('Theme', '').toUpperCase(),
                            style: AppTheme.bodySm.copyWith(
                              fontSize: 10,
                              color: isSel ? Colors.white : context.appTextSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  // Post to Community Feed Button
                  AppButton.primary(
                    label: 'POST TO COMMUNITY FEED',
                    icon: Icons.send_rounded,
                    onPressed: () async {
                      final newActivity = ActivityItem(
                        id: 'share_${DateTime.now().millisecondsSinceEpoch}',
                        userId: 'usr_local',
                        type: 'workout',
                        title: 'Shared Workout: $workoutTitle',
                        description: '$exercisesCompleted exercises • ${totalVolumeKg.toInt()} kg volume lifted in ${durationMinutes}m',
                        createdAt: DateTime.now(),
                      );

                      await SocialService.instance.createActivity(newActivity);
                      GrowthAnalyticsService.instance.trackSocialShare(shareType: 'community_feed');

                      if (!context.mounted) return;
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Workout Card Shared to Community Feed!')),
                      );
                    },
                    isPill: true,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
