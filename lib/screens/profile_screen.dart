import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'edit_profile_screen.dart';
import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../data/profile_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileProvider _provider;
  String _selectedWeightPeriod = '6M';

  List<FlSpot> _getWeightSpots() {
    if (_selectedWeightPeriod == '1M') {
      return const [
        FlSpot(0, 78.5),
        FlSpot(1, 78.0),
        FlSpot(2, 77.2),
        FlSpot(3, 76.4),
      ];
    } else if (_selectedWeightPeriod == '6M') {
      return const [
        FlSpot(0, 80.0),
        FlSpot(1, 78.5),
        FlSpot(2, 79.0),
        FlSpot(3, 77.5),
        FlSpot(4, 77.0),
        FlSpot(5, 76.4),
      ];
    } else {
      return const [
        FlSpot(0, 82.0),
        FlSpot(1, 81.3),
        FlSpot(2, 80.2),
        FlSpot(3, 79.5),
        FlSpot(4, 78.4),
        FlSpot(5, 77.8),
        FlSpot(6, 76.9),
        FlSpot(7, 76.4),
        FlSpot(8, 76.0),
        FlSpot(9, 75.9),
        FlSpot(10, 75.8),
        FlSpot(11, 75.5),
      ];
    }
  }

  List<String> _getWeightTitles() {
    if (_selectedWeightPeriod == '1M') {
      return const ['Wk 1', 'Wk 2', 'Wk 3', 'Wk 4'];
    } else if (_selectedWeightPeriod == '6M') {
      return const ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN'];
    } else {
      return const ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    }
  }

  double get _minY {
    final spots = _getWeightSpots();
    if (spots.isEmpty) return 74.0;
    final minYVal = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    return (minYVal - 1.0).floorToDouble();
  }

  double get _maxY {
    final spots = _getWeightSpots();
    if (spots.isEmpty) return 83.0;
    final maxYVal = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    return (maxYVal + 1.0).ceilToDouble();
  }

  @override
  void initState() {
    super.initState();
    _provider = AppDependencies.instance.profileProvider;
    _provider.addListener(_onProfileChanged);
  }

  @override
  void dispose() {
    _provider.removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onProfileChanged() {
    if (mounted) setState(() {});
  }

  void _navigateToEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EditProfileScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 64, bottom: 100),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // Profile Header
            _buildProfileHeader(),
            const SizedBox(height: 24),

            // Metrics Grid
            _buildMetricsGrid(),
            const SizedBox(height: 24),

            // Weight Trends Chart
            _buildWeightTrends(),
            const SizedBox(height: 24),

            // Athletic Stats & AI Insight
            _buildAthleticStats(),
            const SizedBox(height: 24),
            _buildAIInsight(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: _navigateToEditProfile,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MEMBER PROFILE',
                style: AppTheme.labelCaps.copyWith(
                  color: AppColors.tertiary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _provider.displayName.replaceAll(' ', '\n'),
                style: AppTheme.headlineLgMobile,
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: _navigateToEditProfile,
          icon: const Icon(Icons.edit, size: 16),
          label: Text(
            'Edit Profile',
            style: AppTheme.bodySm.copyWith(color: AppColors.onPrimary),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.onPrimary,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: [
        _buildMetricCard(
          context: context,
          icon: Icons.calendar_today,
          label: 'AGE',
          value: '${_provider.age}',
          subtitle: 'Years Old',
        ),
        _buildMetricCard(
          context: context,
          icon: Icons.monitor_weight,
          label: 'WEIGHT',
          value: _provider.weight,
          unit: _provider.massUnit,
          subtitle: 'Current weight',
        ),
        _buildMetricCard(
          context: context,
          icon: Icons.straighten,
          label: 'HEIGHT',
          value: _provider.height,
          unit: _provider.lengthUnit,
          subtitle: 'Current height',
        ),
        _buildMetricCard(
          context: context,
          icon: Icons.restaurant,
          label: 'DIET',
          value: _provider.dietPreference,
          subtitle: 'Preferred diet',
          isText: true,
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    String? unit,
    required String subtitle,
    bool isText = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label,
                  style: AppTheme.labelCaps.copyWith(
                    color: AppColors.onSecondaryContainer,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (isText)
            Text(
              value,
              style: AppTheme.dataDisplay.copyWith(fontSize: 18),
            )
          else
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(text: value, style: AppTheme.dataDisplay),
                  if (unit != null)
                    TextSpan(
                      text: ' $unit',
                      style: AppTheme.bodySm.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTheme.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String get _selectedWeightPeriodDescription {
    if (_selectedWeightPeriod == '1M') return 'month';
    if (_selectedWeightPeriod == '6M') return '6 months';
    return 'year';
  }

  Widget _buildWeightTrends() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Weight Trends', style: AppTheme.headlineMd),
                  const SizedBox(height: 4),
                  Text(
                    'Progress over the last $_selectedWeightPeriodDescription',
                    style: AppTheme.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildTimeChip('1M', _selectedWeightPeriod == '1M'),
                  const SizedBox(width: 8),
                  _buildTimeChip('6M', _selectedWeightPeriod == '6M'),
                  const SizedBox(width: 8),
                  _buildTimeChip('1Y', _selectedWeightPeriod == '1Y'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF191C1B),
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    tooltipMargin: 16,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        return LineTooltipItem(
                          '${barSpot.y.toStringAsFixed(1)} kg',
                          TextStyle(
                            color: AppColors.onPrimaryFixed,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.surfaceVariant,
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final titles = _getWeightTitles();
                        final index = value.toInt();
                        if (index >= 0 && index < titles.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              titles[index],
                              style: AppTheme.labelCaps.copyWith(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _getWeightSpots(),
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: AppColors.primary,
                          strokeWidth: 1.5,
                          strokeColor: AppColors.surface,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary.withValues(alpha: 0.1),
                          AppColors.primary.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
                minY: _minY,
                maxY: _maxY,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(String label, bool isActive) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedWeightPeriod = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(100),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: AppTheme.labelCaps.copyWith(
            color: isActive ? AppColors.onPrimary : AppColors.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildAthleticStats() {
    // Calculate BMI from provider data
    final heightVal = double.tryParse(_provider.height) ?? 175.0;
    final weightVal = double.tryParse(_provider.weight) ?? 68.2;
    final heightM = _provider.lengthUnit == 'cm' ? heightVal / 100.0 : heightVal * 0.0254;
    final bmi = weightVal / (heightM * heightM);
    final bmiStr = bmi.toStringAsFixed(1);
    final bmiLabel = bmi < 18.5
        ? 'Underweight'
        : bmi < 25.0
            ? 'Normal'
            : bmi < 30.0
                ? 'Overweight'
                : 'Obese';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text('Athletic Stats', style: AppTheme.headlineMd),
          const SizedBox(height: 16),
          _buildStatRow(
            'BMI',
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(bmiStr, style: AppTheme.dataDisplay.copyWith(fontSize: 16)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    bmiLabel,
                    style: AppTheme.labelCaps.copyWith(
                      color: AppColors.onPrimaryFixedVariant,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            showBorder: true,
          ),
          _buildStatRow(
            'Body Fat %',
            Text('14.2%', style: AppTheme.dataDisplay.copyWith(fontSize: 16)),
            showBorder: true,
          ),
          _buildStatRow(
            'Resting Heart Rate',
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '54 ',
                    style: AppTheme.dataDisplay.copyWith(fontSize: 16),
                  ),
                  TextSpan(
                    text: 'bpm',
                    style: AppTheme.bodySm.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            showBorder: false,
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, Widget value, {bool showBorder = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: showBorder
            ? const Border(
                bottom: BorderSide(color: AppColors.outlineVariant, width: 1),
              )
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTheme.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          value,
        ],
      ),
    );
  }

  Widget _buildAIInsight() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.onSurface.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('AI Trainer Insight', style: AppTheme.headlineMd),
              const Icon(
                Icons.smart_toy,
                color: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '"Your weight progression shows a consistent -0.2kg per week trend. This align perfectly with your \'Disciplined Serenity\' protocol. Your recovery metrics suggest we can increase volume in next week\'s resistance sessions."',
            style: AppTheme.bodySm.copyWith(
              color: AppColors.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: const LinearProgressIndicator(
              value: 0.8,
              backgroundColor: AppColors.surfaceContainer,
              color: AppColors.primary,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'GOAL COMPLETION: 80%',
            style: AppTheme.labelCaps.copyWith(
              color: AppColors.tertiary,
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
