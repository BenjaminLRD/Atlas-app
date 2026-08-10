import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/badge.dart';
import '../../services/achievement_service.dart';
import 'badge_detail_popup.dart';
import 'app_animation.dart';
import 'app_card.dart';
import 'app_chip.dart';
import 'app_empty_state.dart';

/// Full-featured interactive Achievement Gallery widget displaying locked/unlocked fitness badges,
/// categorization filters, and milestone progress.
class AchievementGallery extends StatefulWidget {
  final List<String> unlockedBadgeIds;
  final Function(AchievementBadge)? onBadgeTap;

  const AchievementGallery({
    super.key,
    required this.unlockedBadgeIds,
    this.onBadgeTap,
  });

  @override
  State<AchievementGallery> createState() => _AchievementGalleryState();
}

class _AchievementGalleryState extends State<AchievementGallery> {
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Milestone',
    'Consistency',
    'Strength',
    'Nutrition',
  ];

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
        return const Color(0xFFFFD700); // Gold
      case 'epic':
        return const Color(0xFFFF6D00); // Orange
      case 'rare':
        return const Color(0xFF00E5FF); // Cyan
      case 'common':
      default:
        return AppColors.primaryContainer;
    }
  }

  @override
  Widget build(BuildContext context) {
    final allBadges = AchievementService.allAchievements;
    final unlockedSet = widget.unlockedBadgeIds.toSet();

    final filteredBadges = _selectedCategory == 'All'
        ? allBadges
        : allBadges.where((b) => b.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();

    final unlockedCount = allBadges.where((b) => unlockedSet.contains(b.id)).length;
    final totalCount = allBadges.length;
    final progressFraction = totalCount > 0 ? unlockedCount / totalCount : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Overall Progress Header Card
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ACHIEVEMENTS UNLOCKED',
                        style: AppTheme.labelCaps.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: context.appTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$unlockedCount of $totalCount Badges',
                        style: AppTheme.headlineMd.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: context.appTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.15),
                      borderRadius: AppRadii.borderFull,
                    ),
                    child: Text(
                      '${(progressFraction * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: AppRadii.borderFull,
                child: SizedBox(
                  height: 8,
                  child: Stack(
                    children: [
                      Container(
                        color: context.isDarkMode
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                      FractionallySizedBox(
                        widthFactor: progressFraction.clamp(0.0, 1.0),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: AppGradients.vitalityGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // 2. Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categories.map((cat) {
              final selected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: AppChip(
                  label: cat,
                  isSelected: selected,
                  onTap: () => setState(() => _selectedCategory = cat),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // 3. Badges Grid
        if (filteredBadges.isEmpty)
          AppEmptyState.noAchievements(cardFramed: true)
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredBadges.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (context, index) {
              final badge = filteredBadges[index];
              final isUnlocked = unlockedSet.contains(badge.id);
              final rarityColor = _getRarityColor(badge.rarity);
              final displayBadge = badge.copyWith(isUnlocked: isUnlocked);

              return AppAnimation.scaleIn(
                duration: Duration(milliseconds: 200 + (index * 40)),
                child: GestureDetector(
                  onTap: () {
                    if (widget.onBadgeTap != null) {
                      widget.onBadgeTap!(displayBadge);
                    } else {
                      BadgeDetailPopup.show(context, displayBadge);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isUnlocked
                          ? (context.isDarkMode
                              ? const Color(0xFF1B1E22)
                              : Colors.white)
                          : (context.isDarkMode
                              ? Colors.white.withValues(alpha: 0.03)
                              : Colors.black.withValues(alpha: 0.03)),
                      borderRadius: AppRadii.borderLg,
                      border: Border.all(
                        color: isUnlocked
                            ? rarityColor.withValues(alpha: 0.5)
                            : context.appOutlineVariant.withValues(alpha: 0.2),
                        width: isUnlocked ? 1.5 : 1.0,
                      ),
                      boxShadow: isUnlocked
                          ? [
                              BoxShadow(
                                color: rarityColor.withValues(alpha: 0.15),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isUnlocked
                                    ? rarityColor.withValues(alpha: 0.15)
                                    : (context.isDarkMode
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.black.withValues(alpha: 0.05)),
                              ),
                              child: Icon(
                                displayBadge.iconData,
                                size: 24,
                                color: isUnlocked
                                    ? rarityColor
                                    : context.appTextSecondary.withValues(alpha: 0.4),
                              ),
                            ),
                            if (!isUnlocked)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1E2228),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.lock_rounded,
                                    size: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          badge.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 11,
                            fontWeight: isUnlocked ? FontWeight.w700 : FontWeight.w500,
                            color: isUnlocked
                                ? context.appTextPrimary
                                : context.appTextSecondary.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
