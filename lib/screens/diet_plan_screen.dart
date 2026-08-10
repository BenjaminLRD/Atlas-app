import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../providers/fitness_provider.dart';
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
import 'notifications_screen.dart';
import 'settings_screen.dart';

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
        subtitle: 'Track your daily macros, trends, and analytics',
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
            MaterialPageRoute(
              builder: (context) => const SettingsScreen(),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          FoodSearchSheet.show(
            context,
            mealId: 'meal_breakfast',
            mealTitle: 'Breakfast',
          );
        },
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'ADD FOOD',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: provider,
        builder: (context, _) {
          final log = provider.todayNutritionLog;
          final meals = provider.todaysMeals;
          final summary = provider.nutritionSummary;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Hero Nutrition Card
                  const NutritionHeroCard(),
                  const SizedBox(height: 20),

                  // 2. Macro Progress Cards Grid
                  const SectionHeader(
                    title: 'MACRONUTRIENTS',
                  ),
                  const SizedBox(height: 10),
                  MacroProgressCard.grid(context: context, log: log),
                  const SizedBox(height: 24),

                  // 3. Today's Meals Section
                  SectionHeader(
                    title: "TODAY'S MEALS",
                    subtitle: '${log.completedMeals} of ${meals.length} Completed',
                  ),
                  const SizedBox(height: 12),

                  if (meals.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF14151B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.appOutlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.restaurant_rounded,
                            size: 40,
                            color: AppColors.primaryContainer.withValues(alpha: 0.6),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Start tracking your meals',
                            style: AppTheme.headlineMd.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add your first meal to begin nutrition tracking.',
                            style: AppTheme.bodySm.copyWith(
                              fontSize: 12,
                              color: context.appTextSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              FoodSearchSheet.show(
                                context,
                                mealId: 'meal_breakfast',
                                mealTitle: 'Breakfast',
                              );
                            },
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('+ Add First Meal'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryContainer,
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ],
                      ),
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

                  const SizedBox(height: 80), // Padding for FloatingActionButton
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
