import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../providers/fitness_provider.dart';
import '../../main.dart';
import '../onboarding/user_goal_setup_flow.dart';
import '../../widgets/common/app_card.dart';

/// Post-signup Profile Setup Screen for customizing display name & identity.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late TextEditingController _displayNameController;
  int _selectedAvatarIndex = 0;

  final List<IconData> _avatarIcons = const [
    Icons.fitness_center,
    Icons.sports_gymnastics,
    Icons.directions_run,
    Icons.sports_kabaddi,
    Icons.bolt,
    Icons.auto_awesome,
  ];

  @override
  void initState() {
    super.initState();
    final user = FitnessProvider.instance.currentUser;
    _displayNameController = TextEditingController(text: user?.displayName ?? '');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _handleComplete() async {
    final user = FitnessProvider.instance.currentUser;
    if (user != null && _displayNameController.text.trim().isNotEmpty) {
      final updated = user.copyWith(
        displayName: _displayNameController.text.trim(),
        updatedAt: DateTime.now(),
      );
      await FitnessProvider.instance.updateAuthUser(updated);
    }

    if (!mounted) return;

    final goalCompleted = FitnessProvider.instance.currentGoal != null;
    if (!goalCompleted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const UserGoalSetupFlow()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FitnessProvider.instance.currentUser;

    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Welcome to Aizawl Gym!',
                textAlign: TextAlign.center,
                style: AppTheme.headlineLg.copyWith(
                  color: context.appTextPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Personalize your profile to customize your AI Coach & training identity.',
                textAlign: TextAlign.center,
                style: AppTheme.bodySm.copyWith(
                  color: context.appTextSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Avatar Selection Card
              AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    Text(
                      'Choose Your Avatar',
                      style: AppTheme.bodyLg.copyWith(
                        color: context.appTextPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.md,
                      children: List.generate(_avatarIcons.length, (index) {
                        final isSelected = index == _selectedAvatarIndex;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedAvatarIndex = index),
                          child: AnimatedContainer(
                            duration: AppDurations.fast,
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : context.isDarkMode
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : context.appCardBorder,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                            child: Icon(
                              _avatarIcons[index],
                              color: isSelected ? Colors.white : AppColors.primary,
                              size: 28,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Display Name Field
              TextField(
                controller: _displayNameController,
                style: AppTheme.bodyMd.copyWith(
                  color: context.appTextPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  hintText: user?.displayName ?? 'Gym Member',
                  prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.primary),
                  border: OutlineInputBorder(
                    borderRadius: AppRadii.borderLg,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Action Button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _handleComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadii.borderLg,
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'CONTINUE TO GOAL SETUP',
                    style: AppTheme.bodyLg.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
