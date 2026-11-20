import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../data/local_storage.dart';
import '../common/app_card.dart';

/// Modal bottom sheet for connecting and managing wearable integrations (Apple Health, Health Connect, Garmin, Fitbit).
class ConnectWearableModal extends StatefulWidget {
  const ConnectWearableModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => const ConnectWearableModal(),
    );
  }

  @override
  State<ConnectWearableModal> createState() => _ConnectWearableModalState();
}

class _ConnectWearableModalState extends State<ConnectWearableModal> {
  bool _isConnected = false;
  String _selectedSource = 'Apple Health';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isConnected = LocalStorage.getIsWearableConnected();
    _selectedSource = LocalStorage.getConnectedWearableSource();
  }

  Future<void> _toggleConnection(String source) async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 400));

    final newConnectedState = !(_isConnected && _selectedSource == source);
    await LocalStorage.setWearableConnected(
      newConnectedState,
      source: source,
    );

    if (mounted) {
      setState(() {
        _isConnected = newConnectedState;
        _selectedSource = source;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newConnectedState
                ? 'Connected to $source! Telemetry will sync automatically.'
                : 'Disconnected from $source.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.appTextSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.watch_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Connect Wearable',
                      style: AppTheme.headlineSm.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: context.appTextPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  iconSize: 20,
                ),
              ],
            ),
            const SizedBox(height: 12),

            Text(
              'Connect a wearable or health platform to automatically import sleep duration, resting heart rate, HRV, steps, and activity metrics.',
              style: TextStyle(
                fontSize: 12,
                color: context.appTextSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),

            // Platforms List
            _buildSourceTile(
              context,
              name: 'Apple Health',
              subtitle: 'Sleep, Resting HR, HRV, Steps, Active Calories',
              icon: Icons.favorite_rounded,
              iconColor: const Color(0xFFEF4444),
            ),
            const SizedBox(height: 10),
            _buildSourceTile(
              context,
              name: 'Health Connect (Android)',
              subtitle: 'Sleep, Heart Rate, Steps, Workouts',
              icon: Icons.android_rounded,
              iconColor: const Color(0xFF10B981),
            ),
            const SizedBox(height: 10),
            _buildSourceTile(
              context,
              name: 'Garmin Connect',
              subtitle: 'Advanced Sleep Stages, HRV Status, Stress',
              icon: Icons.watch_outlined,
              iconColor: const Color(0xFF3B82F6),
            ),
            const SizedBox(height: 10),
            _buildSourceTile(
              context,
              name: 'Fitbit / Pixel Watch',
              subtitle: 'Daily Sleep Score, Resting HR, SpO2',
              icon: Icons.fitness_center_rounded,
              iconColor: const Color(0xFF8B5CF6),
            ),
            const SizedBox(height: 18),

            // Privacy Note
            Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: context.appTextSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Your health data is stored securely on device and never shared without consent.',
                    style: TextStyle(
                      fontSize: 10,
                      color: context.appTextSecondary,
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

  Widget _buildSourceTile(
    BuildContext context, {
    required String name,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    final isCurrentConnected = _isConnected && _selectedSource == name;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _isLoading ? null : () => _toggleConnection(name),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrentConnected
                  ? Colors.white12
                  : AppColors.primary,
              foregroundColor: isCurrentConnected
                  ? context.appTextPrimary
                  : Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              isCurrentConnected ? 'DISCONNECT' : 'CONNECT',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
