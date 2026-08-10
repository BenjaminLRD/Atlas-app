import 'package:flutter/material.dart';
import '../models/user_role.dart';
import '../providers/fitness_provider.dart';

/// Admin dashboard UI for managing gym facilities, trainer assignments, and role permissions.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = FitnessProvider.instance;
    final gym = provider.activeGym;
    final currentRole = provider.userRole;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2E),
        elevation: 0,
        title: const Text(
          'Gym Admin Console',
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
                // Gym Hub Info Card
                _buildGymInfoCard(gym?.name ?? 'Aizawl Gym Main Hub', gym?.location ?? 'Zarkawt, Aizawl', gym?.memberCount ?? 248, gym?.trainerCount ?? 12),
                const SizedBox(height: 24),

                // Role Switcher Segmented Section
                const Text(
                  'Switch Active Role',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Test ecosystem permissions as a Member, Trainer, or Admin.',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 14),

                Row(
                  children: UserRole.values.map((role) {
                    final isSelected = currentRole == role;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          await provider.setUserRole(role);
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF6C5CE7)
                                : const Color(0xFF1E1E2E),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFA29BFE)
                                  : Colors.white10,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _getRoleIcon(role),
                                color: isSelected ? Colors.white : Colors.white54,
                                size: 20,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                role.name.toUpperCase(),
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),

                // Gym Management Actions
                const Text(
                  'Facility Management',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 14),

                _buildManagementTile(
                  title: 'Assign Member to Trainer',
                  subtitle: 'Link unassigned members to head coaches',
                  icon: Icons.person_add_alt_1_rounded,
                  onTap: () {
                    provider.assignMemberToTrainer('usr_m_03');
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Member assigned to Coach Lalthanmawia'),
                        backgroundColor: Color(0xFF00B894),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _buildManagementTile(
                  title: 'Manage Certified Trainers',
                  subtitle: '12 Trainers active in facility hub',
                  icon: Icons.verified_user_rounded,
                  onTap: () {},
                ),
                const SizedBox(height: 10),
                _buildManagementTile(
                  title: 'Gym Membership Records',
                  subtitle: '248 Members registered at Zarkawt Hub',
                  icon: Icons.badge_rounded,
                  onTap: () {},
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.member:
        return Icons.person_rounded;
      case UserRole.trainer:
        return Icons.fitness_center_rounded;
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
    }
  }

  Widget _buildGymInfoCard(String name, String location, int members, int trainers) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C5CE7), Color(0xFF2D2B55)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C5CE7).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_city_rounded, color: Color(0xFFFFD700), size: 28),
              const SizedBox(width: 12),
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
                    Text(
                      location,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Members', '$members'),
              _buildStatItem('Trainers', '$trainers'),
              _buildStatItem('Status', 'Active Hub'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildManagementTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF6C5CE7)),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
        onTap: onTap,
      ),
    );
  }
}
