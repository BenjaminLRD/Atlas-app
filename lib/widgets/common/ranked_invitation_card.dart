import 'package:flutter/material.dart';
import '../../app_theme.dart';
import 'app_animation.dart';
import 'app_bottom_sheet.dart';
import 'app_card.dart';

/// Card widget inviting unranked users to join Ranked Mode.
class RankedInvitationCard extends StatelessWidget {
  final VoidCallback onJoin;
  final VoidCallback? onLearnMore;

  const RankedInvitationCard({
    super.key,
    required this.onJoin,
    this.onLearnMore,
  });

  @override
  Widget build(BuildContext context) {
    return AppAnimation.slideFadeIn(
      child: AppCard(
        backgroundColor: const Color(0xFF1E1535),
        borderColor: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Header Row: Icon + Title/Heading + Optional Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xFFA78BFA),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'RANKED MODE',
                        style: AppTheme.labelCaps.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFA78BFA),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ready to compete?',
                        style: AppTheme.headlineMd.copyWith(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Text(
                    '✨ Optional',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFC4B5FD),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. Description
            Text(
              'Join Ranked Mode to compete with others, climb the leaderboard and earn exclusive rewards.',
              style: AppTheme.bodySm.copyWith(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.75),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            // 3. Action Buttons Row: Learn More + Join Ranked Mode
            Row(
              children: [
                // Learn More Button
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Learn more about Ranked Mode',
                    child: GestureDetector(
                      onTap:
                          onLearnMore ??
                          () => showRankedLearnMoreBottomSheet(context, onJoin),
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Learn More',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Join Ranked Mode Button
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Join Ranked Mode',
                    child: GestureDetector(
                      onTap: onJoin,
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF7C3AED,
                              ).withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                'Join Ranked Mode',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal explaining Ranked Mode details
void showRankedLearnMoreBottomSheet(BuildContext context, VoidCallback onJoin) {
  AppBottomSheet.show(
    context: context,
    title: 'About Ranked Mode',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoTile(
          icon: Icons.emoji_events_rounded,
          iconColor: const Color(0xFFF59E0B),
          title: 'Competitive Progression',
          description:
              'Compete with athletes across Aizawl. Earn XP through workouts and nutrition tracking to climb from Bronze to Legend tier.',
        ),
        const SizedBox(height: 16),
        _buildInfoTile(
          icon: Icons.bolt_rounded,
          iconColor: const Color(0xFF8B5CF6),
          title: 'How XP Works',
          description:
              'Complete daily workouts, maintain consistency streaks, and hit your nutrition macro targets to gain XP points.',
        ),
        const SizedBox(height: 16),
        _buildInfoTile(
          icon: Icons.workspace_premium_rounded,
          iconColor: const Color(0xFFEC4899),
          title: 'Exclusive Rewards & Badges',
          description:
              'Unlock exclusive profile rank badges, title flair, and special achievements to display on community leaderboards.',
        ),
        const SizedBox(height: 16),
        _buildInfoTile(
          icon: Icons.lock_open_rounded,
          iconColor: const Color(0xFF10B981),
          title: '100% Voluntary & Optional',
          description:
              'Ranked Mode is completely optional. You can join or pause anytime without affecting your workout history or personal progress.',
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onJoin();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 4,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Join Ranked Mode',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildInfoTile({
  required IconData icon,
  required Color iconColor,
  required String title,
  required String description,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.7),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
