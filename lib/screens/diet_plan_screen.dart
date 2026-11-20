import 'meal_prep_hub_screen.dart';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/nutrition_totals.dart';
import '../providers/fitness_provider.dart';
import '../services/nutrition/weight_goal_status.dart';
import '../widgets/common/app_empty_state.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/section_header.dart';
import '../widgets/nutrition/food_search_sheet.dart';
import '../widgets/nutrition/macro_progress_card.dart';
import '../widgets/nutrition/meal_card.dart';
import '../widgets/nutrition/nutrition_hero_card.dart';
import '../widgets/nutrition_analytics/calorie_trend_card.dart';
import '../widgets/nutrition_analytics/macro_distribution_chart.dart';
import '../widgets/nutrition_analytics/nutrition_insight_section.dart';
import '../widgets/nutrition_analytics/nutrition_summary_card.dart';
import '../widgets/nutrition_analytics/protein_performance_card.dart';
import '../data/local_storage.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'weight_gain_plan_screen.dart';
import 'weight_goal_setup_screen.dart';

/// Premium Nutrition Analytics Dashboard Screen
class DietPlanScreen extends StatelessWidget {
  const DietPlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final provider = FitnessProvider.instance;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppHeader.standard(
        title: 'NUTRITION DASHBOARD',
        subtitle: 'Track your daily macros, trends & goals',
        showNotifications: true,
        showSettings: true,
        onNotificationsTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NotificationsScreen(),
            ),
          );
        },
        onSettingsTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
          );
        },
      ),
      body: ListenableBuilder(
        listenable: provider,
        builder: (context, _) {
          final log = provider.todayNutritionLog;
          final meals = provider.todaysMeals;
          final summary = provider.nutritionSummary;

          return SafeArea(
            child: SingleChildScrollView(
              key: const PageStorageKey('diet_plan_scroll_view'),
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: 120,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Hero Nutrition Card
                  const NutritionHeroCard(),
                  const SizedBox(height: 12),

                  // 1.2 Dedicated Prominent ADD FOOD Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        FoodSearchSheet.show(
                          context,
                          mealId: 'Breakfast',
                          mealTitle: 'Breakfast',
                        );
                      },
                      icon: const Icon(Icons.add_circle_rounded, size: 20),
                      label: const Text(
                        'ADD FOOD',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          fontSize: 14,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? AppColors.primaryContainer
                            : AppColors.primary,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      key: const Key('meal_preps_button'),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MealPrepHubScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.lunch_dining_rounded, size: 20),
                      label: const Text(
                        'MEAL PREPS',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark
                            ? AppColors.primaryContainer
                            : AppColors.primary,
                        side: BorderSide(
                          color: isDark
                              ? AppColors.primaryContainer
                              : AppColors.primary,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1.5. Weight Goal Program Target Comparison Banner
                  _buildWeightGoalBanner(context, log.totals),
                  const SizedBox(height: 20),

                  // 2. Macro Progress Cards Grid
                  const SectionHeader(title: 'MACRONUTRIENTS'),
                  const SizedBox(height: 10),
                  MacroProgressCard.grid(context: context, log: log),
                  const SizedBox(height: 24),

                  // 3. Today's Meals Section
                  SectionHeader(
                    title: "TODAY'S MEALS",
                    subtitle:
                        '${log.completedMeals} of ${meals.length} Completed',
                  ),
                  const SizedBox(height: 12),

                  if (meals.isEmpty)
                    AppEmptyState.noNutrition(
                      onAddFood: () {
                        FoodSearchSheet.show(
                          context,
                          mealId: 'Breakfast',
                          mealTitle: 'Breakfast',
                        );
                      },
                      cardFramed: true,
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: meals.length,
                      itemBuilder: (context, index) {
                        final meal = meals[index];
                        return MealCard(key: ValueKey(meal.id), meal: meal);
                      },
                    ),

                  const SizedBox(height: 24),

                  // 4. Nutrition Analytics Section
                  const SectionHeader(
                    title: 'NUTRITION ANALYTICS',
                    subtitle: 'Weekly trends & macro breakdown',
                  ),
                  const SizedBox(height: 12),

                  NutritionSummaryCard(summary: summary),
                  const SizedBox(height: 12),

                  ProteinPerformanceCard(summary: summary),
                  const SizedBox(height: 12),

                  MacroDistributionChart(summary: summary),
                  const SizedBox(height: 12),

                  CalorieTrendCard(summary: summary),
                  const SizedBox(height: 24),

                  // 5. Nutrition Insights Section
                  NutritionInsightSection(summary: summary),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeightGoalBanner(BuildContext context, NutritionTotals logged) {
    final weightGoal = LocalStorage.getWeightGoal();
    final isDark = context.isDarkMode;

    if (weightGoal == null) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WeightGoalSetupScreen()),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryContainer.withValues(
              alpha: isDark ? 0.2 : 0.1,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.monitor_weight_rounded,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Weight Goal Program',
                      style: AppTheme.headlineMd.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Set a mass gain or fat loss target to get custom daily meal blueprints.',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 11,
                        color: context.appTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      );
    }

    final targetCalories = weightGoal.dailyCalorieTarget;
    final isSurplusGoal = weightGoal.isWeightGain;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WeightGainPlanScreen(goal: weightGoal),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161F2E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Goal Header & Goal Badge
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      const Icon(
                        Icons.trending_up_rounded,
                        color: AppColors.primary,
                        size: 16,
                      ),
                      Text(
                        weightGoal.type.displayName.toUpperCase(),
                        style: AppTheme.labelCaps.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: context.appOutlineVariant.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Text(
                          '${targetCalories.toStringAsFixed(0)} kcal Goal',
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // 2. Weight Progression
                  Text(
                    '${weightGoal.currentWeight.toStringAsFixed(0)}kg → ${weightGoal.targetWeight.toStringAsFixed(0)}kg',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: context.appTextPrimary,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // 3. Calorie Remaining / Surplus Status
                  Text(
                    weightGoalCalorieStatus(
                      targetCalories: targetCalories,
                      totals: logged,
                      isSurplusGoal: isSurplusGoal,
                    ),
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.appTextSecondary,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
