import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/nutrition_summary.dart';

/// Interactive Macro Distribution Chart displaying Protein, Carbs, and Fats energy ratios
class MacroDistributionChart extends StatefulWidget {
  final NutritionSummary summary;

  const MacroDistributionChart({
    super.key,
    required this.summary,
  });

  @override
  State<MacroDistributionChart> createState() => _MacroDistributionChartState();
}

class _MacroDistributionChartState extends State<MacroDistributionChart> {
  String _selectedMacro = 'protein';

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final mb = widget.summary.macroBalance;

    final proteinPct = (mb['protein'] ?? 30.0).clamp(0.0, 100.0);
    final carbsPct = (mb['carbs'] ?? 50.0).clamp(0.0, 100.0);
    final fatsPct = (mb['fats'] ?? 20.0).clamp(0.0, 100.0);

    final avgP = widget.summary.averageProtein;
    final avgC = widget.summary.averageCarbohydrates;
    final avgF = widget.summary.averageFats;

    String recommendation = 'Balanced distribution for muscle recovery & endurance.';
    String macroTitle = 'Protein';
    double pct = proteinPct;
    double grams = avgP;
    Color macroColor = const Color(0xFF64B5F6);

    if (_selectedMacro == 'carbs') {
      macroTitle = 'Carbohydrates';
      pct = carbsPct;
      grams = avgC;
      macroColor = const Color(0xFFFFB74D);
      recommendation = 'Primary energy source for intense resistance workouts.';
    } else if (_selectedMacro == 'fats') {
      macroTitle = 'Fats';
      pct = fatsPct;
      grams = avgF;
      macroColor = const Color(0xFFE57373);
      recommendation = 'Essential for hormone production and vital organ support.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14151B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: context.appOutlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MACRO DISTRIBUTION',
                style: AppTheme.labelCaps.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryContainer,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                'Tap segment for details',
                style: AppTheme.bodySm.copyWith(
                  fontSize: 10,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Multi-Segment Progress Bar (Interactive Donut Representation)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 18,
              child: Row(
                children: [
                  Expanded(
                    flex: proteinPct.round().clamp(1, 100),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedMacro = 'protein'),
                      child: Container(color: const Color(0xFF64B5F6)),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: carbsPct.round().clamp(1, 100),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedMacro = 'carbs'),
                      child: Container(color: const Color(0xFFFFB74D)),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: fatsPct.round().clamp(1, 100),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedMacro = 'fats'),
                      child: Container(color: const Color(0xFFE57373)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Interactive Segment Details Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: macroColor.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: macroColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: macroColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$macroTitle — ${pct.toStringAsFixed(0)}% (${grams.toStringAsFixed(0)}g avg)',
                        style: AppTheme.headlineMd.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: context.appTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        recommendation,
                        style: AppTheme.bodySm.copyWith(
                          fontSize: 11,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
