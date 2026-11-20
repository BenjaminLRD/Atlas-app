import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../data/local_storage.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_button.dart';

/// Introduces AI Coach capabilities to athletes on their first visit,
/// highlighting adaptive workouts, recovery monitoring, nutrition personalization,
/// and continuous learning.
class AIOnboardingScreen extends StatelessWidget {
  final VoidCallback? onGetStarted;

  const AIOnboardingScreen({super.key, this.onGetStarted});

  static const String completedKey = 'has_completed_ai_onboarding';

  static bool hasCompleted() {
    return LocalStorage.getBool(completedKey, defaultValue: true);
  }

  static Future<void> markCompleted() async {
    await LocalStorage.setBool(completedKey, true);
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = const [
      {
        'icon': Icons.track_changes_rounded,
        'title': 'Learns Your Goals',
        'desc':
            'Understands your weight targets, muscle focus, and preferred training split.',
        'color': AppColors.primary,
      },
      {
        'icon': Icons.fitness_center_rounded,
        'title': 'Adapts Workouts',
        'desc':
            'Tailors exercises and volume dynamically based on your available gym equipment.',
        'color': Colors.cyanAccent,
      },
      {
        'icon': Icons.favorite_rounded,
        'title': 'Tracks Recovery',
        'desc':
            'Monitors sleep, resting heart rate, and fatigue to recommend timely rest & deloads.',
        'color': Colors.orangeAccent,
      },
      {
        'icon': Icons.restaurant_rounded,
        'title': 'Personalizes Nutrition',
        'desc':
            'Calculates macro distributions, daily protein targets, and balanced meal ideas.',
        'color': Colors.amberAccent,
      },
      {
        'icon': Icons.auto_awesome_rounded,
        'title': 'Improves Over Time',
        'desc':
            'Remembers your favorite exercises, avoided movements, and feedback ratings.',
        'color': Colors.purpleAccent,
      },
    ];

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: context.appTextSecondary),
          onPressed: () async {
            await markCompleted();
            if (context.mounted) {
              if (onGetStarted != null) {
                onGetStarted!();
              } else {
                Navigator.of(context).pop();
              }
            }
          },
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - AppSpacing.xl,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        // Hero AI Badge
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, Colors.cyan],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 18,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Title & Subtitle
                        Text(
                          'Meet Atlas AI',
                          textAlign: TextAlign.center,
                          style: AppTheme.headlineSm.copyWith(
                            color: context.appTextPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Your complete fitness intelligence platform built into Atlas.',
                          textAlign: TextAlign.center,
                          style: AppTheme.bodySm.copyWith(
                            color: context.appTextSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Capabilities List
                        ...capabilities.map((cap) {
                          final color = cap['color'] as Color;
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: AppCard(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              backgroundColor: context.appCardBg,
                              borderColor: color.withValues(alpha: 0.2),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.sm,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius: AppRadii.borderSm,
                                    ),
                                    child: Icon(
                                      cap['icon'] as IconData,
                                      color: color,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cap['title'] as String,
                                          style: AppTheme.bodyMd.copyWith(
                                            color: context.appTextPrimary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          cap['desc'] as String,
                                          style: AppTheme.bodySm.copyWith(
                                            color: context.appTextSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),

                    // Get Started Button
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.md),
                      child: AppButton.primary(
                        label: 'Start Personalizing',
                        icon: Icons.arrow_forward_rounded,
                        isFullWidth: true,
                        onPressed: () async {
                          await markCompleted();
                          if (context.mounted) {
                            if (onGetStarted != null) {
                              onGetStarted!();
                            } else {
                              Navigator.of(context).pop();
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
