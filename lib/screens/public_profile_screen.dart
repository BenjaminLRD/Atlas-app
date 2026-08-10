import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/leaderboard_entry.dart';
import '../models/friend_challenge.dart';
import '../services/friend_challenge_service.dart';
import '../services/growth_analytics_service.dart';

/// Public user profile screen showcasing rank, level, badges, stats, and social actions.
class PublicProfileScreen extends StatefulWidget {
  final LeaderboardEntry user;

  const PublicProfileScreen({
    super.key,
    required this.user,
  });

  static Future<void> showModal(BuildContext context, LeaderboardEntry user) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => PublicProfileScreen(user: user),
    );
  }

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  bool _isFriend = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: context.appOutlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // User Avatar & Rank Badge Overlay
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: context.appSurfaceVariant,
                backgroundImage: widget.user.avatarUrl != null ? NetworkImage(widget.user.avatarUrl!) : null,
                child: widget.user.avatarUrl == null
                    ? Text(
                        widget.user.displayName.substring(0, 1).toUpperCase(),
                        style: AppTheme.headlineLg.copyWith(color: AppColors.primary, fontSize: 24),
                      )
                    : null,
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFFFBBF24),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events_rounded, color: Colors.black, size: 14),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Display Name & Rank Title
          Text(
            widget.user.displayName,
            style: AppTheme.headlineLg.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            '${widget.user.rankTitle} • ${widget.user.division}',
            style: AppTheme.bodySm.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12),
          ),

          const SizedBox(height: 16),

          // 3x Metrics Bar
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(context, 'TOTAL XP', '${widget.user.totalXP}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(context, 'WORKOUTS', '48'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(context, 'STREAK', '12 Days'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _isFriend = !_isFriend);
                    GrowthAnalyticsService.instance.trackCommunityInteraction(interactionType: 'friend_toggle');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_isFriend ? 'Friend Added!' : 'Friend Removed')),
                    );
                  },
                  icon: Icon(_isFriend ? Icons.person_remove_rounded : Icons.person_add_rounded, size: 16),
                  label: Text(_isFriend ? 'FRIENDS' : 'ADD FRIEND'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isFriend ? context.appSurfaceVariant : AppColors.primary,
                    foregroundColor: _isFriend ? context.appTextPrimary : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    FriendChallengeService.instance.createChallenge(
                      opponentId: widget.user.userId,
                      opponentName: widget.user.displayName,
                      type: ChallengeType.volumeShowdown,
                      title: '1v1 VOLUME SHOWDOWN',
                      targetGoal: 10000.0,
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Challenge sent to ${widget.user.displayName}!')),
                    );
                  },
                  icon: const Icon(Icons.emoji_events_rounded, size: 16, color: Color(0xFFF59E0B)),
                  label: const Text('CHALLENGE'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.appSurfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: AppTheme.bodySm.copyWith(fontSize: 9, color: context.appTextSecondary)),
          const SizedBox(height: 2),
          Text(value, style: AppTheme.headlineMd.copyWith(fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
