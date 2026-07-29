import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../app_theme.dart';
import '../data/nutrition_service.dart';
import '../data/profile_provider.dart';
import 'workout_session_screen.dart';
import 'weekly_workout_plan_screen.dart';

enum ChartMetric {
  weight,
  calories,
  protein,
  volume,
  bodyFat,
}

enum ChartPeriod {
  weekly,
  monthly,
  yearly,
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Nutrition Service
  late final NutritionService _nutritionService;

  // Protein State
  double _proteinConsumed = 0.0;
  double _proteinGoal = 140.0;

  // Chart interactivity state
  ChartMetric _selectedMetric = ChartMetric.weight;
  ChartPeriod _selectedPeriod = ChartPeriod.weekly;

  double _zoomScale = 1.0;
  double _horizontalShift = 0.0;

  // Track tapped point details for interactive popup values
  FlSpot? _touchedSpot;

  late final ProfileProvider _profileProvider;

  @override
  void initState() {
    super.initState();
    _nutritionService = NutritionService();
    _profileProvider = ProfileProvider();
    _profileProvider.addListener(_onProfileChanged);
    _loadState();
  }

  @override
  void dispose() {
    _profileProvider.removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onProfileChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _loadState() {
    setState(() {
      _proteinConsumed = _nutritionService.getProteinConsumed();
      _proteinGoal = _nutritionService.getProteinGoal();
    });
  }

  void _addProtein(double amount) async {
    setState(() {
      _proteinConsumed += amount;
    });
    await _nutritionService.saveProteinConsumed(_proteinConsumed);
  }

  void _resetProtein() async {
    setState(() {
      _proteinConsumed = 0;
    });
    await _nutritionService.saveProteinConsumed(_proteinConsumed);
  }

  // --- Dynamic Mock Data Generator ---
  List<FlSpot> _getChartData() {
    final List<double> values = _getRawData(_selectedMetric, _selectedPeriod);
    return List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i]));
  }

  List<double> _getRawData(ChartMetric metric, ChartPeriod period) {
    switch (metric) {
      case ChartMetric.weight:
        if (period == ChartPeriod.weekly) return [77.2, 77.0, 76.8, 76.9, 76.6, 76.4, 76.2];
        if (period == ChartPeriod.monthly) return [78.5, 78.0, 77.5, 77.2, 76.9, 76.4]; // 6 points/weeks
        return [82.0, 81.3, 80.2, 79.5, 78.4, 77.8, 76.9, 76.4, 76.0, 75.9, 75.8, 75.5]; // 12 months

      case ChartMetric.calories:
        if (period == ChartPeriod.weekly) return [320, 410, 300, 520, 480, 240, 380];
        if (period == ChartPeriod.monthly) return [280, 350, 420, 390, 480, 510];
        return [310, 340, 390, 420, 450, 410, 380, 400, 460, 490, 520, 500];

      case ChartMetric.protein:
        if (period == ChartPeriod.weekly) return [120, 145, 95, 150, 135, 110, 140];
        if (period == ChartPeriod.monthly) return [110, 125, 135, 130, 142, 148];
        return [105, 110, 115, 120, 128, 132, 130, 135, 140, 142, 145, 148];

      case ChartMetric.volume:
        if (period == ChartPeriod.weekly) return [4500, 5200, 3800, 6100, 5800, 4200, 5500];
        if (period == ChartPeriod.monthly) return [4200, 4800, 5100, 5300, 5600, 5900];
        return [3800, 4100, 4500, 4700, 4900, 5200, 5000, 5300, 5600, 5800, 6100, 6300];

      case ChartMetric.bodyFat:
        if (period == ChartPeriod.weekly) return [15.2, 15.1, 15.1, 15.0, 14.9, 14.8, 14.8];
        if (period == ChartPeriod.monthly) return [15.8, 15.5, 15.2, 15.0, 14.9, 14.8];
        return [17.5, 17.1, 16.8, 16.5, 16.0, 15.6, 15.2, 14.9, 14.7, 14.6, 14.5, 14.4];
    }
  }

  List<String> _getBottomTitles(ChartPeriod period) {
    if (period == ChartPeriod.weekly) return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    if (period == ChartPeriod.monthly) return ['Wk 1', 'Wk 2', 'Wk 3', 'Wk 4', 'Wk 5', 'Wk 6'];
    return ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  }

  String _getMetricTitle(ChartMetric metric) {
    switch (metric) {
      case ChartMetric.weight:
        return 'Weight';
      case ChartMetric.calories:
        return 'Calories';
      case ChartMetric.protein:
        return 'Protein Intake';
      case ChartMetric.volume:
        return 'Vol';
      case ChartMetric.bodyFat:
        return 'Body Fat';
    }
  }

  String _getMetricUnit(ChartMetric metric) {
    if (metric == ChartMetric.weight) return 'kg';
    if (metric == ChartMetric.calories) return 'kcal';
    if (metric == ChartMetric.protein) return 'g';
    if (metric == ChartMetric.volume) return 'kg';
    return '%';
  }

  @override
  Widget build(BuildContext context) {
    final provider = ProfileProvider();
    final now = DateTime.now();
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final dateLabel = '${weekdays[now.weekday - 1].toUpperCase()}, ${months[now.month - 1]} ${now.day}';
    final hour = now.hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 64, bottom: 120),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // Greeting
            Text(
              dateLabel,
              style: AppTheme.labelCaps.copyWith(
                color: AppColors.tertiary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$greeting, ${provider.firstName}',
              style: AppTheme.headlineLgMobile,
            ),
            const SizedBox(height: 24),

            // Main Workout Card
            _buildWorkoutCard(),
            const SizedBox(height: 16),

            // AI Daily Report
            _buildAIReportCard(),
            const SizedBox(height: 16),

            // Mini Cards (Includes updated Steps and Protein card now!)
            _buildMiniCardsRow(),
            const SizedBox(height: 48),

            // Interactive Performance Trend Chart
            _buildPerformanceTrend(),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'ACTIVE GOAL',
                  style: AppTheme.labelCaps.copyWith(
                    color: AppColors.onPrimary,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "Today's Protocol",
                style: AppTheme.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Leg Day - Hypertrophy',
            style: AppTheme.headlineMd,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.schedule, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '45 mins',
                style: AppTheme.dataDisplay.copyWith(color: AppColors.primary),
              ),
              const SizedBox(width: 24),
              const Icon(Icons.local_fire_department,
                  color: AppColors.tertiary, size: 20),
              const SizedBox(width: 8),
              Text(
                '320 kcal',
                style: AppTheme.dataDisplay.copyWith(color: AppColors.tertiary),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WorkoutSessionScreen(),
                    ),
                  ).then((_) => _loadState());
                },
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Start Workout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WeeklyWorkoutPlanScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryContainer,
                  foregroundColor: AppColors.onSecondaryContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text('View Plan'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAIReportCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topRight,
                    colors: [
                      AppColors.primary,
                      AppColors.tertiaryContainer,
                    ],
                  ),
                  border: Border.all(color: Colors.transparent, width: 2),
                ),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceContainer,
                  ),
                  child: const Icon(
                    Icons.smart_toy,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'DAILY REPORT',
                style: AppTheme.labelCaps.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '"Recovery metrics look optimal today. Focus on controlled eccentrics during your squats to maximize tension."',
            style: AppTheme.bodyMd.copyWith(
              fontStyle: FontStyle.italic,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Icon(
              Icons.chat_bubble_outline,
              color: AppColors.outline,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCardsRow() {
    return Column(
      children: [
        // Weight Card
        _buildMiniCard(
          icon: Icons.monitor_weight_outlined,
          iconBgColor: AppColors.secondaryContainer,
          iconColor: AppColors.secondary,
          label: 'CURRENT WEIGHT',
          value: ProfileProvider().weight,
          unit: ProfileProvider().massUnit,
          trailing: Text(
            '-0.4 kg',
            style: AppTheme.labelCaps.copyWith(color: AppColors.error),
          ),
        ),
        const SizedBox(height: 16),

        // Steps Card
        _buildStepsCard(),
        const SizedBox(height: 16),

        // Protein Card (REPLACED HYDRATION!)
        _buildProteinCard(),
      ],
    );
  }

  Widget _buildMiniCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String label,
    required String value,
    required String unit,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              trailing ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: AppTheme.labelCaps.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: AppTheme.dataDisplay,
                ),
                TextSpan(
                  text: ' $unit',
                  style: AppTheme.bodySm.copyWith(color: AppColors.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.directions_walk,
                    color: AppColors.primary, size: 24),
              ),
              Text(
                '72%',
                style: AppTheme.labelCaps.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'DAILY STEPS',
            style: AppTheme.labelCaps.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(text: '7,248', style: AppTheme.dataDisplay),
                TextSpan(
                  text: ' / 10k',
                  style: AppTheme.bodySm.copyWith(color: AppColors.outline),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: 0.72,
              backgroundColor: AppColors.surfaceVariant,
              color: AppColors.primary,
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProteinCard() {
    final double remaining = max(0.0, _proteinGoal - _proteinConsumed);
    final double progress = (_proteinConsumed / _proteinGoal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "TODAY'S PROTEIN INTAKE",
                  style: AppTheme.labelCaps.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${_proteinConsumed.toInt()}g',
                        style: AppTheme.dataDisplay.copyWith(fontSize: 26),
                      ),
                      TextSpan(
                        text: ' / ${_proteinGoal.toInt()}g goal',
                        style: AppTheme.bodySm.copyWith(color: AppColors.outline),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  remaining > 0 ? '$remaining g remaining' : 'Goal Achieved!',
                  style: AppTheme.bodySm.copyWith(
                    color: remaining > 0 ? AppColors.tertiary : AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => _addProtein(25),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('+25g Protein'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _resetProtein,
                      icon: const Icon(Icons.refresh, size: 20),
                      color: AppColors.outline,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Circular progress indicator
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 8,
                  backgroundColor: AppColors.surfaceContainerLow,
                  color: AppColors.primary,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: AppTheme.headlineMd.copyWith(
                  fontSize: 16,
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceTrend() {
    final spots = _getChartData();
    final xTitles = _getBottomTitles(_selectedPeriod);

    // Apply interactive sliding zoom dynamic coordinates
    final int dataSize = spots.length;
    final double maxPossibleX = (dataSize - 1).toDouble();
    // Default zoom width is the active dataset span divider by zoomScale factor
    final double activeSpan = maxPossibleX / _zoomScale;
    final double midX = maxPossibleX / 2.0;

    // Shift offsets horizontal shift
    final double targetMinX = (midX - activeSpan / 2.0 + _horizontalShift * maxPossibleX).clamp(0.0, maxPossibleX);
    final double targetMaxX = (targetMinX + activeSpan).clamp(0.0, maxPossibleX);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Performance Trend',
              style: AppTheme.headlineMd,
            ),
            // Period Switches
            Row(
              children: ChartPeriod.values.map((p) {
                final active = _selectedPeriod == p;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPeriod = p;
                      _zoomScale = 1.0;
                      _horizontalShift = 0.0;
                      _touchedSpot = null;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: active
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
                      p.name.toUpperCase().substring(0, 1) + p.name.substring(1),
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 9,
                        color: active ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Metrics Selector Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ChartMetric.values.map((m) {
              final active = _selectedMetric == m;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  selected: active,
                  checkmarkColor: AppColors.onPrimary,
                  showCheckmark: false,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceContainerLowest,
                  side: BorderSide(color: AppColors.outlineVariant),
                  label: Text(
                    _getMetricTitle(m),
                    style: AppTheme.bodySm.copyWith(
                      color: active ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                      fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  onSelected: (_) {
                    setState(() {
                      _selectedMetric = m;
                      _touchedSpot = null;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Zoom details text hint
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Pinch to Zoom • Drag Horizontally',
              style: AppTheme.bodySm.copyWith(
                color: AppColors.outline,
                fontSize: 10,
              ),
            ),
            if (_zoomScale > 1.0)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _zoomScale = 1.0;
                    _horizontalShift = 0.0;
                  });
                },
                icon: const Icon(Icons.zoom_out_map, size: 14),
                label: const Text('Reset Zoom', style: TextStyle(fontSize: 10)),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Gesture detector wrapper for scroll/pinch zoom control
        GestureDetector(
          onScaleUpdate: (details) {
            setState(() {
              if (details.scale != 1.0) {
                _zoomScale = (_zoomScale * details.scale).clamp(1.0, 5.0);
              }
              if (details.focalPointDelta.dx != 0.0) {
                // Adjust horizontal shifting factor based on drag amount
                _horizontalShift -= (details.focalPointDelta.dx / 300.0) / _zoomScale;
                _horizontalShift = _horizontalShift.clamp(-0.5, 0.5);
              }
            });
          },
          child: Container(
            height: 240,
            padding: const EdgeInsets.fromLTRB(16, 24, 24, 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: LineChart(
              LineChartData(
                minX: targetMinX,
                maxX: targetMaxX,
                lineTouchData: LineTouchData(
                  touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
                    if (touchResponse != null && touchResponse.lineBarSpots != null) {
                      final spot = touchResponse.lineBarSpots!.first;
                      setState(() {
                        _touchedSpot = spot;
                      });
                    }
                  },
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.primary,
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                      return touchedBarSpots.map((barSpot) {
                        return LineTooltipItem(
                          '${barSpot.y.toStringAsFixed(1)} ${_getMetricUnit(_selectedMetric)}',
                          AppTheme.bodySm.copyWith(
                            color: AppColors.onPrimary,
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
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.outlineVariant.withValues(alpha: 0.4),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 45,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toStringAsFixed(0)} ${_getMetricUnit(_selectedMetric)}',
                          style: AppTheme.labelCaps.copyWith(fontSize: 8, color: AppColors.outline),
                          textAlign: TextAlign.end,
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        final idx = value.round();
                        if (idx >= 0 && idx < xTitles.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              xTitles[idx],
                              style: AppTheme.labelCaps.copyWith(fontSize: 8, color: AppColors.onSurfaceVariant),
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
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.25),
                          AppColors.primary.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Display exact tapped point details if available
        if (_touchedSpot != null)
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Exact Value: ${_touchedSpot!.y.toStringAsFixed(1)} ${_getMetricUnit(_selectedMetric)} on ${xTitles[_touchedSpot!.x.round().clamp(0, xTitles.length - 1)]}',
                  style: AppTheme.bodySm.copyWith(
                    color: AppColors.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
