import 'package:flutter/material.dart';
import '../app_theme.dart';

class AiTrainerScreen extends StatelessWidget {
  const AiTrainerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 64, bottom: 16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // Welcome
                  _buildWelcome(),
                  const SizedBox(height: 32),

                  // Chat messages
                  _buildBotMessage(
                    "I've reviewed your biometric data from yesterday's recovery cycle. Your heart rate variability is up by 8%, suggesting you're ready for a higher-intensity session today.",
                    tags: [
                      'High Intensity Recommended',
                      'Restorative Focus',
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildUserMessage(
                    "Thanks, Coach. I'm feeling a bit tight in my hip flexors after sitting all day. Should I adjust the warmup?",
                  ),
                  const SizedBox(height: 24),

                  _buildBotMessage(
                    'Absolutely. Let\'s integrate 5 minutes of "90/90 Hip Switches" and "Pigeon Pose" into your session. Precision in mobility prevents injury in performance.',
                    routineCard: true,
                  ),
                  const SizedBox(height: 24),

                  _buildBotMessage(
                    "Also, don't forget your post-workout hydration. Since today's session is more intense, aim for 20g of clean protein within 45 minutes of finishing to maximize muscle protein synthesis.",
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
        // Input bar
        _buildInputBar(),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildWelcome() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryContainer.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryContainer,
                border: Border.all(
                  color: AppColors.surfaceContainerLowest,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.onSurface.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.smart_toy,
                size: 36,
                color: AppColors.onPrimaryContainer,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Good morning, Zothana.',
          style: AppTheme.headlineLgMobile,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Ready to refine your discipline today?',
          style: AppTheme.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildBotMessage(
    String text, {
    List<String>? tags,
    bool routineCard = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(top: 4),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryContainer,
          ),
          child: const Icon(
            Icons.smart_toy,
            size: 14,
            color: AppColors.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(0),
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              border: Border.all(color: AppColors.surfaceVariant),
              boxShadow: [
                BoxShadow(
                  color: AppColors.onSurface.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: AppTheme.bodyMd.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                if (tags != null) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: tags.map((tag) {
                      final isFirst = tag == tags.first;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isFirst
                              ? AppColors.tertiaryFixed
                              : AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          tag,
                          style: AppTheme.labelCaps.copyWith(
                            color: isFirst
                                ? AppColors.onTertiaryFixed
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (routineCard) ...[
                  const SizedBox(height: 16),
                  _buildRoutineCard(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserMessage(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(0),
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.onSurface.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              text,
              style: AppTheme.bodyMd.copyWith(
                color: AppColors.onPrimary,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(top: 4),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.secondaryContainer,
          ),
          child: const Icon(
            Icons.person,
            size: 14,
            color: AppColors.onSecondaryContainer,
          ),
        ),
      ],
    );
  }

  Widget _buildRoutineCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: const Icon(
              Icons.fitness_center,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SUGGESTED ROUTINE',
                  style: AppTheme.labelCaps.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'Mobility Correction A',
                  style: AppTheme.bodyMd.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.play_circle,
              color: AppColors.primary,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: AppColors.surfaceVariant),
          boxShadow: [
            BoxShadow(
              color: AppColors.onSurface.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.add_circle_outline,
                color: AppColors.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Ask Aizawl Gym AI...',
                  hintStyle: AppTheme.bodyMd.copyWith(
                    color: AppColors.outline,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary,
              ),
              child: const Icon(
                Icons.send,
                color: AppColors.onPrimary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
