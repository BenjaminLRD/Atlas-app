import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/activity_post.dart';

/// Visual card component for community meal prep posts and recipe ideas.
class MealPostCard extends StatelessWidget {
  final ActivityPost post;

  const MealPostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final calories = post.mealCalories;
    final protein = post.mealProteinGrams;
    final carbs = post.mealCarbsGrams;
    final fat = post.mealFatGrams;
    final ingredients = post.mealIngredients;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.restaurant_menu_rounded,
                        color: Color(0xFF10B981),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'HIGH PROTEIN MEAL PREP',
                          style: AppTheme.labelCaps.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF10B981),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (calories > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '$calories kcal',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // 3-Macro Row (Protein, Carbs, Fat)
          Row(
            children: [
              Expanded(
                child: _buildMacroPill(
                  context,
                  label: 'PROTEIN',
                  value: '${protein > 0 ? protein : 45}g',
                  color: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMacroPill(
                  context,
                  label: 'CARBS',
                  value: '${carbs > 0 ? carbs : 65}g',
                  color: const Color(0xFF3B82F6),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildMacroPill(
                  context,
                  label: 'FATS',
                  value: '${fat > 0 ? fat : 18}g',
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),

          // Ingredients Checklist
          if (ingredients.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Key Ingredients:',
              style: AppTheme.labelCaps.copyWith(
                fontSize: 9,
                color: context.appTextSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: ingredients.take(4).map((ing) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: context.appSurface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: context.appOutlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Text(
                    '• $ing',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMacroPill(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: AppTheme.labelCaps.copyWith(
                fontSize: 8,
                fontWeight: FontWeight.w800,
                color: context.appTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
