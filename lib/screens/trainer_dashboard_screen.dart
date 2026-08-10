import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../providers/fitness_provider.dart';
import 'member_detail_screen.dart';

/// Trainer dashboard UI for managing assigned athletes, monitoring readiness, and reviewing coach notes.
class TrainerDashboardScreen extends StatefulWidget {
  const TrainerDashboardScreen({super.key});

  @override
  State<TrainerDashboardScreen> createState() => _TrainerDashboardScreenState();
}

class _TrainerDashboardScreenState extends State<TrainerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FitnessProvider.instance.refreshTrainerData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = FitnessProvider.instance;
    final trainer = provider.activeTrainerProfile;
    final gym = provider.activeGym;
    final members = provider.assignedMembers;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2E),
        elevation: 0,
        title: const Text(
          'Trainer Hub',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: provider,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Coach Profile Card
                _buildTrainerHeader(
                  trainer?.displayName ?? 'Coach Lalthanmawia',
                  gym?.name ?? 'Aizawl Gym Hub',
                  trainer?.bio ?? 'Head Coach',
                  trainer?.rating ?? 4.9,
                  trainer?.yearsExperience ?? 8,
                ),
                const SizedBox(height: 20),

                // Metrics Row
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Assigned Athletes',
                        '${members.length}',
                        Icons.groups_rounded,
                        const Color(0xFF6C5CE7),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'Deload Alerts',
                        '1 Active',
                        Icons.warning_amber_rounded,
                        const Color(0xFFFF7675),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // AI Coach Summary Overview Card
                _buildAISummaryBanner(provider),
                const SizedBox(height: 24),

                // Assigned Athletes Header
                const Text(
                  'Assigned Athletes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                if (members.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E2E),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'No athletes assigned yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                else
                  ...members.map((member) => _buildAthleteTile(context, member)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrainerHeader(
    String name,
    String gymName,
    String bio,
    double rating,
    int years,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E1E2E), Color(0xFF2D2B55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
            child: const Icon(
              Icons.sports_rounded,
              color: Color(0xFF6C5CE7),
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$gymName • $years yrs exp',
                  style: const TextStyle(
                    color: Color(0xFF00B894),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '$rating Rating',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAISummaryBanner(FitnessProvider provider) {
    final contextSnapshot = provider.buildFitnessContext();
    final summary = provider.generateMemberAISummary(
      memberContext: contextSnapshot,
      memberName: 'Active Member Squad',
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF6C5CE7).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: Color(0xFF6C5CE7), size: 20),
              SizedBox(width: 8),
              Text(
                'AI Coach Assistant Insight',
                style: TextStyle(
                  color: Color(0xFF6C5CE7),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            summary.summaryText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAthleteTile(BuildContext context, AppUser member) {
    final isYou = member.id == 'usr_local';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: isYou
              ? const Color(0xFF6C5CE7).withValues(alpha: 0.3)
              : Colors.white10,
          child: Text(
            member.displayName.isNotEmpty ? member.displayName[0] : 'A',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          member.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          member.email,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Colors.white38,
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MemberDetailScreen(member: member),
            ),
          );
        },
      ),
    );
  }
}
