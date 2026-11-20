import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../data/app_dependencies.dart';
import '../../providers/fitness_provider.dart';
import '../../providers/showcase_data_provider.dart';
import '../../providers/showcase_mode_provider.dart';
import '../../screens/body_composition_screen.dart';
import '../common/app_card.dart';

/// Weight Trends Card for Dashboard and Progress screens.
/// Renders 4 summary metrics (CURRENT, CHANGE, LOWEST, HIGHEST) and an interactive 6-month line graph.
/// Renders a clean illustrated empty state for fresh users who have not logged weight yet.
class WeightTrendsCard extends StatefulWidget {
  const WeightTrendsCard({super.key});

  @override
  State<WeightTrendsCard> createState() => _WeightTrendsCardState();
}

class _WeightTrendsCardState extends State<WeightTrendsCard> {
  String _selectedFilter = '6M';

  @override
  void initState() {
    super.initState();
    ShowcaseModeProvider.instance.addListener(_onStateChanged);
    FitnessProvider.instance.addListener(_onStateChanged);
    AppDependencies.instance.profileProvider.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    ShowcaseModeProvider.instance.removeListener(_onStateChanged);
    FitnessProvider.instance.removeListener(_onStateChanged);
    AppDependencies.instance.profileProvider.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isShowcase = ShowcaseModeProvider.instance.isShowcaseModeEnabled;
    final profileProvider = AppDependencies.instance.profileProvider;
    final hasRealWeight = profileProvider.weight.trim().isNotEmpty;
    final hasData = isShowcase || hasRealWeight;

    // Resolve metrics & chart data
    final showcaseSummary =
        ShowcaseDataProvider.instance.getShowcaseWeightTrendSummary();

    final currentWeightStr = isShowcase
        ? '${showcaseSummary.currentKg.toStringAsFixed(1)} kg'
        : (hasRealWeight ? '${profileProvider.weight} kg' : '-');

    final changeStr = isShowcase
        ? '↓ ${showcaseSummary.changeKg.abs().toStringAsFixed(1)} kg'
        : '-';

    final lowestStr = isShowcase
        ? '${showcaseSummary.lowestKg.toStringAsFixed(1)} kg'
        : '-';

    final highestStr = isShowcase
        ? '${showcaseSummary.highestKg.toStringAsFixed(1)} kg'
        : '-';

    final isDark = context.isDarkMode;

    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BodyCompositionScreen()),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header & Filter Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color:
                            AppColors.primaryContainer.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.trending_up_rounded,
                        color: AppColors.primaryContainer,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Weight Trends',
                        style: AppTheme.headlineMd.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.appTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Filter Chips (1M, 6M, 1Y)
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: context.appSurfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: context.appOutlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: ['1M', '6M', '1Y'].map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedFilter = filter),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryContainer
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          filter,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? const Color(0xFF0F1412)
                                : context.appTextSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Four Metric Summary Columns
          Row(
            children: [
              Expanded(
                child: _buildSummaryMetric(
                  context,
                  label: 'CURRENT',
                  value: currentWeightStr,
                  valueColor: isShowcase
                      ? AppColors.primaryContainer
                      : context.appTextPrimary,
                ),
              ),
              Expanded(
                child: _buildSummaryMetric(
                  context,
                  label: 'CHANGE',
                  value: changeStr,
                  valueColor: isShowcase ? Colors.green : context.appTextPrimary,
                ),
              ),
              Expanded(
                child: _buildSummaryMetric(
                  context,
                  label: 'LOWEST',
                  value: lowestStr,
                ),
              ),
              Expanded(
                child: _buildSummaryMetric(
                  context,
                  label: 'HIGHEST',
                  value: highestStr,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. Chart Area or Empty State
          Container(
            height: 140,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(6, 12, 16, 6),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.02)
                  : context.appSurfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.appOutlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: hasData && isShowcase
                ? _buildWeightLineChart(context, showcaseSummary.points)
                : _buildEmptyState(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(
    BuildContext context, {
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: context.appTextSecondary,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: valueColor ?? context.appTextPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No data available',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start tracking your weight to see trends over time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: context.appTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightLineChart(
    BuildContext context,
    List<WeightTrendPoint> points,
  ) {
    final spots = <FlSpot>[];
    for (int i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].weightKg));
    }

    final labels = points.map((p) => p.label).toList();

    return LineChart(
      LineChartData(
        minY: 64,
        maxY: 78,
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 4,
          getDrawingHorizontalLine: (val) {
            return FlLine(
              color: context.appOutlineVariant.withValues(alpha: 0.15),
              strokeWidth: 1,
              dashArray: [4, 4],
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 4,
              getTitlesWidget: (value, meta) {
                if (value % 4 != 0) return const SizedBox.shrink();
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: context.appTextSecondary,
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 18,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  labels[idx],
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: context.appTextSecondary,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(1)} kg',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: AppColors.primaryContainer,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: AppColors.primaryContainer,
                  strokeWidth: 1.5,
                  strokeColor: Colors.black,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primaryContainer.withValues(alpha: 0.25),
                  AppColors.primaryContainer.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
