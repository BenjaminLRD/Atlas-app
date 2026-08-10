import 'dart:math';
import 'package:flutter/material.dart';
import '../../app_theme.dart';

/// Interactive Donut Chart displaying Muscle Group Distribution with segment selection and training recommendations.
class MuscleBalanceChart extends StatefulWidget {
  final Map<String, double> distribution;
  final double totalWeeklyVolume;
  final double totalMonthlyVolume;

  const MuscleBalanceChart({
    super.key,
    required this.distribution,
    this.totalWeeklyVolume = 12000.0,
    this.totalMonthlyVolume = 45000.0,
  });

  @override
  State<MuscleBalanceChart> createState() => _MuscleBalanceChartState();
}

class _MuscleBalanceChartState extends State<MuscleBalanceChart> {
  String? _selectedMuscleGroup;

  final Map<String, Color> _groupColors = const {
    'Legs': Color(0xFF10B981),
    'Chest': Color(0xFF3B82F6),
    'Back': Color(0xFF8B5CF6),
    'Arms': Color(0xFFF59E0B),
    'Shoulders': Color(0xFFEC4899),
    'Core': Color(0xFF06B6D4),
  };

  final Map<String, double> _recommendedTargets = const {
    'Legs': 30.0,
    'Chest': 25.0,
    'Back': 25.0,
    'Arms': 10.0,
    'Shoulders': 10.0,
    'Core': 5.0,
  };

  @override
  void initState() {
    super.initState();
    if (widget.distribution.isNotEmpty) {
      _selectedMuscleGroup = widget.distribution.keys.first;
    }
  }

  String _getRecommendation(String group, double currentPct, double targetPct) {
    if (currentPct < targetPct - 5.0) {
      return 'Volume is below target ($targetPct%). Consider adding 2-3 extra sets of $group training this week.';
    } else if (currentPct > targetPct + 10.0) {
      return 'High proportion of $group volume. Ensure adequate recovery before adding intensity.';
    } else {
      return 'Optimal volume balance for $group. Maintain current training distribution.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final dist = widget.distribution.isEmpty
        ? {'Legs': 35.0, 'Chest': 25.0, 'Back': 20.0, 'Arms': 20.0}
        : widget.distribution;

    final selectedGroup = _selectedMuscleGroup ?? dist.keys.first;
    final double currentPct = dist[selectedGroup] ?? 0.0;
    final double recPct = _recommendedTargets[selectedGroup] ?? 20.0;
    final String recommendation = _getRecommendation(selectedGroup, currentPct, recPct);

    final double groupWeeklyVolume = (widget.totalWeeklyVolume * (currentPct / 100.0));
    final double groupMonthlyVolume = (widget.totalMonthlyVolume * (currentPct / 100.0));

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14151B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.appOutlineVariant.withValues(alpha: 0.3),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'MUSCLE BALANCE',
                style: AppTheme.labelCaps.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: context.appTextSecondary,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                'Interactive Donut',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Donut Chart & Legend Row
          Row(
            children: [
              // Custom Donut Painter
              SizedBox(
                width: 130,
                height: 130,
                child: CustomPaint(
                  painter: _DonutChartPainter(
                    distribution: dist,
                    colors: _groupColors,
                    selectedGroup: selectedGroup,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${currentPct.toStringAsFixed(0)}%',
                          style: AppTheme.headlineLgMobile.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.appTextPrimary,
                          ),
                        ),
                        Text(
                          selectedGroup,
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _groupColors[selectedGroup] ?? AppColors.primaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Tapable Muscle Group Badges
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: dist.entries.map((entry) {
                    final isSelected = entry.key == selectedGroup;
                    final color = _groupColors[entry.key] ?? AppColors.primaryContainer;

                    return GestureDetector(
                      onTap: () => setState(() => _selectedMuscleGroup = entry.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withValues(alpha: 0.2)
                              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? color : context.appOutlineVariant.withValues(alpha: 0.2),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${entry.key} ${entry.value.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? context.appTextPrimary : context.appTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(color: context.appOutlineVariant.withValues(alpha: 0.3), height: 1),
          const SizedBox(height: 14),

          // Selected Group Details & Recommendations
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$selectedGroup Breakdown',
                style: AppTheme.headlineLgMobile.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: context.appTextPrimary,
                ),
              ),
              Text(
                'Target: ${recPct.toStringAsFixed(0)}%',
                style: AppTheme.bodySm.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Est. Weekly Volume: ${groupWeeklyVolume.toStringAsFixed(0)} kg',
                style: AppTheme.bodySm.copyWith(fontSize: 11, color: context.appTextSecondary),
              ),
              Text(
                'Est. Monthly Volume: ${groupMonthlyVolume.toStringAsFixed(0)} kg',
                style: AppTheme.bodySm.copyWith(fontSize: 11, color: context.appTextSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primaryContainer.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppColors.primaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    recommendation,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.appTextPrimary,
                    ),
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

class _DonutChartPainter extends CustomPainter {
  final Map<String, double> distribution;
  final Map<String, Color> colors;
  final String selectedGroup;

  _DonutChartPainter({
    required this.distribution,
    required this.colors,
    required this.selectedGroup,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 8;
    final strokeWidth = 16.0;

    double total = distribution.values.fold(0.0, (sum, v) => sum + v);
    if (total == 0) total = 1.0;

    double startAngle = -pi / 2;

    distribution.forEach((group, val) {
      final sweepAngle = (val / total) * 2 * pi;
      final isSelected = group == selectedGroup;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? strokeWidth + 4 : strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = colors[group] ?? AppColors.primaryContainer;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle - 0.05,
        false,
        paint,
      );

      startAngle += sweepAngle;
    });
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.selectedGroup != selectedGroup || oldDelegate.distribution != distribution;
  }
}
