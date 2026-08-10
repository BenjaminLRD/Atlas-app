import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_theme.dart';
import '../models/brief_item.dart';
import '../models/daily_brief.dart';
import '../providers/fitness_provider.dart';
import '../widgets/coach/coach_action_handler.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_page.dart';

/// Full screen AI Coach Daily Briefing displaying categorized daily advice and insights.
class DailyBriefScreen extends StatefulWidget {
  final DailyBrief? brief;

  const DailyBriefScreen({
    super.key,
    this.brief,
  });

  @override
  State<DailyBriefScreen> createState() => _DailyBriefScreenState();
}

class _DailyBriefScreenState extends State<DailyBriefScreen> {
  @override
  void initState() {
    super.initState();
    FitnessProvider.instance.addListener(_onFitnessChanged);
  }

  @override
  void dispose() {
    FitnessProvider.instance.removeListener(_onFitnessChanged);
    super.dispose();
  }

  void _onFitnessChanged() {
    if (mounted) setState(() {});
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'play_circle_outline':
        return Icons.play_circle_outline;
      case 'restaurant':
        return Icons.restaurant;
      case 'restaurant_menu':
        return Icons.restaurant_menu;
      case 'bolt':
        return Icons.bolt;
      case 'flag':
        return Icons.flag;
      case 'edit_note':
        return Icons.edit_note;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'military_tech':
        return Icons.military_tech;
      default:
        return Icons.auto_awesome;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toUpperCase()) {
      case 'TRAINING':
        return AppColors.primary;
      case 'NUTRITION':
        return AppColors.tertiary;
      case 'GOALS':
        return AppColors.secondary;
      case 'GAMIFICATION':
        return const Color(0xFFFFB300);
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brief = widget.brief ?? FitnessProvider.instance.dailyBrief;

    if (brief == null) {
      return AppPage.back(
        title: 'Daily Briefing',
        subtitle: 'Proactive AI fitness insights',
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final dateFormatted = DateFormat('EEEE, MMMM d, yyyy').format(brief.date);
    final trainingItems = brief.items.where((i) => i.category.toUpperCase() == 'TRAINING').toList();
    final nutritionItems = brief.items.where((i) => i.category.toUpperCase() == 'NUTRITION').toList();
    final progressItems = brief.items
        .where((i) => i.category.toUpperCase() == 'GOALS' || i.category.toUpperCase() == 'GAMIFICATION')
        .toList();

    return AppPage.back(
      title: 'Daily Briefing',
      subtitle: dateFormatted,
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.md,
          bottom: AppSpacing.xxl + 40,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Coach Header & Date Tag
            _buildCoachHeader(context, brief, dateFormatted),
            const SizedBox(height: AppSpacing.xl),

            // 2. Today's Focus Card
            _buildFocusSection(context, brief),
            const SizedBox(height: AppSpacing.xxl),

            // 3. Training Advice Section
            if (trainingItems.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                title: 'Training Advice',
                icon: Icons.fitness_center,
                color: AppColors.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              ...trainingItems.map((item) => _buildAdviceCard(context, item)),
              const SizedBox(height: AppSpacing.xxl),
            ],

            // 4. Nutrition Advice Section
            if (nutritionItems.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                title: 'Nutrition Advice',
                icon: Icons.restaurant,
                color: AppColors.tertiary,
              ),
              const SizedBox(height: AppSpacing.md),
              ...nutritionItems.map((item) => _buildAdviceCard(context, item)),
              const SizedBox(height: AppSpacing.xxl),
            ],

            // 5. Progress & Goal Advice Section
            if (progressItems.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                title: 'Progress & Goals',
                icon: Icons.emoji_events,
                color: AppColors.secondary,
              ),
              const SizedBox(height: AppSpacing.md),
              ...progressItems.map((item) => _buildAdviceCard(context, item)),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCoachHeader(BuildContext context, DailyBrief brief, String dateStr) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.8),
            AppColors.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadii.borderXl,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'AI COACH BRIEF',
                      style: AppTheme.bodyLg.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: AppRadii.borderFull,
                      ),
                      child: Text(
                        brief.focusArea,
                        style: AppTheme.labelCaps.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: AppTheme.bodySm.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusSection(BuildContext context, DailyBrief brief) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.center_focus_strong,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Today\'s Focus',
                style: AppTheme.bodyLg.copyWith(
                  color: context.appTextPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            brief.headline,
            style: AppTheme.headlineLg.copyWith(
              color: AppColors.primary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            brief.summary,
            style: AppTheme.bodyMd.copyWith(
              color: context.appTextSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: AppTheme.bodyLg.copyWith(
            color: context.appTextPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAdviceCard(BuildContext context, BriefItem item) {
    final catColor = _getCategoryColor(item.category);
    final iconData = _getIconData(item.icon);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.15),
                    borderRadius: AppRadii.borderMd,
                  ),
                  child: Icon(iconData, color: catColor, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: AppTheme.bodyLg.copyWith(
                          color: context.appTextPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs + 2,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.1),
                          borderRadius: AppRadii.borderFull,
                        ),
                        child: Text(
                          item.category.toUpperCase(),
                          style: AppTheme.labelCaps.copyWith(
                            color: catColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              item.description,
              style: AppTheme.bodyMd.copyWith(
                color: context.appTextSecondary,
                height: 1.35,
              ),
            ),
            if (item.actionRoute != null && item.actionTitle != null) ...[
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    CoachActionHandler.handleAction(context, item.actionRoute);
                  },
                  icon: Icon(Icons.arrow_forward_rounded, size: 16, color: catColor),
                  label: Text(
                    item.actionTitle!.toUpperCase(),
                    style: AppTheme.labelCaps.copyWith(
                      color: catColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
