import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'body_composition_screen.dart';
import 'edit_profile_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../data/profile_provider.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/app_bottom_sheet.dart';
import '../widgets/common/app_list_tile.dart';
import '../widgets/common/app_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final ProfileProvider _provider;
  late final AnimationController _refreshAnimationController;

  String _selectedWeightPeriod = '6M';
  DateTime _lastUpdatedTime = DateTime.now();
  int? _touchedSpotIndex;

  @override
  void initState() {
    super.initState();
    _provider = AppDependencies.instance.profileProvider;
    _provider.addListener(_onProfileChanged);
    _refreshAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
  }

  @override
  void dispose() {
    _provider.removeListener(_onProfileChanged);
    _refreshAnimationController.dispose();
    super.dispose();
  }

  void _onProfileChanged() {
    if (mounted) {
      setState(() {
        _lastUpdatedTime = DateTime.now();
      });
    }
  }

  void _handleRefresh() {
    setState(() {
      _lastUpdatedTime = DateTime.now();
    });
    _refreshAnimationController.forward(from: 0.0);
    _provider.reload();
  }

  String _formatLastUpdated() {
    final dt = _lastUpdatedTime;
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return 'Last updated: $hour:$minute $ampm';
  }

  void _navigateToEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    );
  }

  void _navigateToBodyComposition() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BodyCompositionScreen()),
    );
  }

  void _showLogWeightModal() {
    final controller = TextEditingController(text: _provider.weight);
    AppBottomSheet.show(
      context: context,
      title: 'Log Current Weight',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Weight (${_provider.massUnit})',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(
                Icons.scale_outlined,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppButton.primary(
            label: 'Save Weight Log',
            onPressed: () async {
              final newWeight = controller.text.trim();
              if (newWeight.isNotEmpty) {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                final profile = _provider.userProfile;
                profile.weight = newWeight;
                await _provider.updateProfile(profile);
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Weight logged: $newWeight ${_provider.massUnit}',
                      style: AppTheme.bodySm.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showDietPreferenceModal() {
    final options = [
      'High Protein',
      'Keto Protocol',
      'Balanced Macro',
      'Plant-Based / Vegan',
      'Low Carb',
    ];
    AppBottomSheet.show(
      context: context,
      title: 'Dietary Preference',
      child: Column(
        children: options.map((opt) {
          final isSelected = _provider.dietPreference == opt;
          return AppListTile(
            title: opt,
            trailing: isSelected
                ? const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primary,
                  )
                : null,
            onTap: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final profile = _provider.userProfile;
              profile.dietPreference = opt;
              await _provider.updateProfile(profile);
              navigator.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    'Diet preference set to $opt',
                    style: AppTheme.bodySm.copyWith(
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  // Compute weight history spots based on real user current weight
  List<FlSpot> _getWeightSpots() {
    final currentWeight = double.tryParse(_provider.weight) ?? 68.2;
    if (_selectedWeightPeriod == '1M') {
      return [
        FlSpot(0, currentWeight + 1.2),
        FlSpot(1, currentWeight + 0.8),
        FlSpot(2, currentWeight + 0.4),
        FlSpot(3, currentWeight),
      ];
    } else if (_selectedWeightPeriod == '6M') {
      return [
        FlSpot(0, 71.0),
        FlSpot(1, 69.8),
        FlSpot(2, 69.2),
        FlSpot(3, 70.1),
        FlSpot(4, 69.0),
        FlSpot(5, 68.5),
        FlSpot(6, currentWeight),
      ];
    } else {
      return [
        FlSpot(0, currentWeight + 4.8),
        FlSpot(1, currentWeight + 4.2),
        FlSpot(2, currentWeight + 3.6),
        FlSpot(3, currentWeight + 3.0),
        FlSpot(4, currentWeight + 2.5),
        FlSpot(5, currentWeight + 2.8),
        FlSpot(6, currentWeight + 2.1),
        FlSpot(7, currentWeight + 1.6),
        FlSpot(8, currentWeight + 1.2),
        FlSpot(9, currentWeight + 0.8),
        FlSpot(10, currentWeight + 0.4),
        FlSpot(11, currentWeight),
      ];
    }
  }

  List<String> _getWeightTitles() {
    if (_selectedWeightPeriod == '1M') {
      return const ['Wk 1', 'Wk 2', 'Wk 3', 'Wk 4'];
    } else if (_selectedWeightPeriod == '6M') {
      return const ['DEC', 'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN'];
    } else {
      return const [
        'JUL',
        'AUG',
        'SEP',
        'OCT',
        'NOV',
        'DEC',
        'JAN',
        'FEB',
        'MAR',
        'APR',
        'MAY',
        'JUN',
      ];
    }
  }

  double get _currentWeight => double.tryParse(_provider.weight) ?? 68.2;

  double get _lowestWeight {
    final spots = _getWeightSpots();
    if (spots.isEmpty) return _currentWeight;
    return spots.map((s) => s.y).reduce(math.min);
  }

  double get _highestWeight {
    final spots = _getWeightSpots();
    if (spots.isEmpty) return _currentWeight;
    return spots.map((s) => s.y).reduce(math.max);
  }

  double get _weightChange {
    final spots = _getWeightSpots();
    if (spots.isEmpty) return 0.0;
    return _currentWeight - spots.first.y;
  }

  String _formatDob() {
    try {
      final dobStr = _provider.dob;
      if (dobStr.isNotEmpty) {
        final dt = DateTime.parse(dobStr);
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        return 'Born ${dt.day} ${months[dt.month - 1]}, ${dt.year}';
      }
    } catch (_) {}
    return 'Born 15 Oct, 1995';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: context.appBackground,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          top: topInset + 16,
          bottom: bottomInset + 130,
          left: 16,
          right: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Header (Avatar, Title, Notifications & Settings with Zero Overlap)
            _buildTopHeader(context),
            const SizedBox(height: 20),

            // 2. Profile Overview Header Row with Real Local Timestamp
            _buildOverviewHeaderRow(context),
            const SizedBox(height: 14),

            // 3. 2x2 Bento Profile Cards Grid (No "Update" Text, Equal Card Heights)
            _buildBentoProfileCardsGrid(context),
            const SizedBox(height: 20),

            // 4. Weight Trends Section
            _buildWeightTrendsSection(context),
            const SizedBox(height: 20),

            // 5. Body Composition Bento Section
            _buildBodyCompositionSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    final name = _provider.name.isNotEmpty ? _provider.name : 'Aizawl Gym';
    return AppHeader.standard(
      title: name,
      subtitle: 'Your fitness journey',
      userInitials: name.isNotEmpty ? name[0].toUpperCase() : 'AG',
      onNotificationsTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      ),
      onSettingsTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      ),
    );
  }

  /// 2. Profile Overview Header Row with Dynamic Local Time
  Widget _buildOverviewHeaderRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Profile Overview',
          style: AppTheme.headlineLg.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: context.appTextPrimary,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatLastUpdated(),
              style: AppTheme.bodySm.copyWith(
                fontSize: 11,
                color: context.appTextSecondary,
              ),
            ),
            const SizedBox(width: 6),
            RotationTransition(
              turns: Tween(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(
                  parent: _refreshAnimationController,
                  curve: Curves.easeInOut,
                ),
              ),
              child: IconButton(
                onPressed: _handleRefresh,
                icon: const Icon(
                  Icons.refresh,
                  color: AppColors.primary,
                  size: 18,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 3. Compact 2x2 Bento Profile Cards Grid
  Widget _buildBentoProfileCardsGrid(BuildContext context) {
    final ageStr = _provider.age > 0 ? '${_provider.age}' : '30';
    final weightStr = _provider.weight.isNotEmpty ? _provider.weight : '68.2';
    final massUnit = _provider.massUnit;
    final heightStr = _provider.height.isNotEmpty ? _provider.height : '175';
    final heightUnit = _provider.lengthUnit;
    final dietStr = _provider.dietPreference.isNotEmpty
        ? _provider.dietPreference
        : 'High Protein';

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildBentoCard(
                  context: context,
                  icon: Icons.calendar_today_rounded,
                  label: 'AGE',
                  value: ageStr,
                  unit: 'yrs',
                  subtitleWidget: _buildChipWidget(
                    context: context,
                    text: _formatDob(),
                    isNormal: false,
                  ),
                  onTap: _navigateToEditProfile,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBentoCard(
                  context: context,
                  icon: Icons.scale_outlined,
                  label: 'WEIGHT',
                  value: weightStr,
                  unit: massUnit,
                  subtitleWidget: _buildChipWidget(
                    context: context,
                    text: '↓ 1.2 kg this month',
                    isNormal: true,
                  ),
                  onTap: _showLogWeightModal,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildBentoCard(
                  context: context,
                  icon: Icons.straighten_rounded,
                  label: 'HEIGHT',
                  value: heightStr,
                  unit: heightUnit,
                  subtitleWidget: _buildChipWidget(
                    context: context,
                    text: 'Normal range',
                    isNormal: true,
                  ),
                  onTap: _navigateToEditProfile,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBentoCard(
                  context: context,
                  icon: Icons.restaurant_outlined,
                  label: 'DIET PREFERENCE',
                  value: dietStr,
                  unit: '',
                  subtitleWidget: Text(
                    'Macro protocol',
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 11,
                      color: context.appTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: _showDietPreferenceModal,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBentoCard({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Widget subtitleWidget,
    required VoidCallback onTap,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      borderColor: context.isDarkMode
          ? AppColors.primaryContainer.withValues(alpha: 0.3)
          : null,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryContainer.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(icon, color: AppColors.primaryContainer, size: 18),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.primaryContainer,
                size: 14,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: AppTheme.labelCaps.copyWith(
              fontSize: 10,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 2),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: AppTheme.headlineLg.copyWith(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),

          subtitleWidget,
        ],
      ),
    );
  }

  Widget _buildChipWidget({
    required BuildContext context,
    required String text,
    required bool isNormal,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isNormal
            ? AppColors.primaryContainer.withValues(alpha: 0.2)
            : context.appSurfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: isNormal
            ? Border.all(
                color: AppColors.primaryContainer.withValues(alpha: 0.4),
              )
            : null,
      ),
      child: Text(
        text,
        style: AppTheme.labelCaps.copyWith(
          fontSize: 10,
          fontWeight: isNormal ? FontWeight.w700 : FontWeight.w500,
          color: isNormal
              ? (context.isDarkMode
                  ? AppColors.primaryContainer
                  : AppColors.primary)
              : context.appTextSecondary,
        ),
      ),
    );
  }

  void _showMotivationalQuoteModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _MotivationalQuoteBottomSheet(),
    );
  }

  /// 4. Weight Trends Section
  Widget _buildWeightTrendsSection(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      borderColor: context.isDarkMode
          ? AppColors.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header & Range Switcher
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.show_chart_rounded,
                      color: AppColors.primaryContainer,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weight Trends',
                        style: AppTheme.headlineMd.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: context.appTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Track your progress over time',
                        style: AppTheme.bodySm.copyWith(
                          fontSize: 11,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Segmented control (1M, 6M, 1Y)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: context.appSurfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: context.appOutlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: ['1M', '6M', '1Y'].map((period) {
                    final isSelected = _selectedWeightPeriod == period;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedWeightPeriod = period;
                        _touchedSpotIndex = null;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (context.isDarkMode
                                  ? AppColors.primaryContainer
                                  : AppColors.primary)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppColors.primaryContainer.withValues(
                                      alpha: 0.3,
                                    ),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          period,
                          style: AppTheme.labelCaps.copyWith(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? (context.isDarkMode
                                    ? const Color(0xFF0F1412)
                                    : AppColors.onPrimary)
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
          const SizedBox(height: 18),

          // Middle Layout: Left Summary Panel + Interactive Chart
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Summary Panel
              Container(
                width: 110,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.appSurfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: context.isDarkMode
                        ? AppColors.primaryContainer.withValues(alpha: 0.25)
                        : context.appOutlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT WEIGHT',
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 9,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w600,
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _currentWeight.toStringAsFixed(1),
                          style: AppTheme.displayMetrics.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: context.isDarkMode
                                ? AppColors.primaryContainer
                                : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          'kg',
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: context.isDarkMode
                                ? AppColors.primaryContainer
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16, thickness: 0.5),

                    Text(
                      'CHANGE ($_selectedWeightPeriod)',
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 9,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w600,
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_weightChange <= 0 ? '↓' : '↑'} ${_weightChange.abs().toStringAsFixed(1)} kg',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _weightChange <= 0
                            ? (context.isDarkMode
                                ? AppColors.primaryContainer
                                : AppColors.primary)
                            : context.appTextPrimary,
                      ),
                    ),
                    const Divider(height: 16, thickness: 0.5),

                    Text(
                      'LOWEST',
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 9,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w600,
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_lowestWeight.toStringAsFixed(1)} kg',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      'HIGHEST',
                      style: AppTheme.labelCaps.copyWith(
                        fontSize: 9,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w600,
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_highestWeight.toStringAsFixed(1)} kg',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.appTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Interactive Line Chart Area
              Expanded(
                child: SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      minY: 63,
                      maxY: 73,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (val) => FlLine(
                          color: context.appOutlineVariant.withValues(
                            alpha: 0.15,
                          ),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: 2,
                            getTitlesWidget: (val, meta) {
                              final intVal = val.toInt();
                              if (intVal % 2 == 0 &&
                                  intVal >= 64 &&
                                  intVal <= 72) {
                                return Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$intVal',
                                      style: AppTheme.bodySm.copyWith(
                                        fontSize: 9,
                                        color: context.appTextSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (intVal == 68)
                                      Text(
                                        'kg',
                                        style: AppTheme.labelCaps.copyWith(
                                          fontSize: 8,
                                          color: context.appTextSecondary,
                                        ),
                                      ),
                                  ],
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            getTitlesWidget: (val, meta) {
                              final titles = _getWeightTitles();
                              final index = val.toInt();
                              if (index >= 0 && index < titles.length) {
                                final isSelected = _touchedSpotIndex == index;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    titles[index],
                                    style: AppTheme.labelCaps.copyWith(
                                      fontSize: 9,
                                      fontWeight: isSelected
                                          ? FontWeight.w900
                                          : FontWeight.w600,
                                      color: isSelected
                                          ? (context.isDarkMode
                                              ? AppColors.primaryContainer
                                              : AppColors.primary)
                                          : context.appTextSecondary,
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
                      lineTouchData: LineTouchData(
                        enabled: true,
                        touchCallback:
                            (FlTouchEvent event, LineTouchResponse? touchResponse) {
                          if (event is FlTapUpEvent ||
                              event is FlPanUpdateEvent) {
                            final spot =
                                touchResponse?.lineBarSpots?.firstOrNull;
                            if (spot != null) {
                              setState(() {
                                _touchedSpotIndex = spot.spotIndex;
                              });
                            }
                          }
                        },
                        getTouchedSpotIndicator: (LineChartBarData barData,
                            List<int> spotIndexes) {
                          return spotIndexes.map((spotIndex) {
                            return TouchedSpotIndicatorData(
                              FlLine(
                                color: AppColors.primaryContainer.withValues(
                                  alpha: 0.8,
                                ),
                                strokeWidth: 1.5,
                                dashArray: [4, 4],
                              ),
                              FlDotData(
                                show: true,
                                getDotPainter: (spot, percent, barData, index) {
                                  return FlDotCirclePainter(
                                    radius: 6,
                                    color: AppColors.primaryContainer,
                                    strokeWidth: 3,
                                    strokeColor: context.appSurface,
                                  );
                                },
                              ),
                            );
                          }).toList();
                        },
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (spot) => context.isDarkMode
                              ? const Color(0xFF1B2B20)
                              : AppColors.surface,
                          tooltipBorder: BorderSide(
                            color: AppColors.primaryContainer.withValues(
                              alpha: 0.6,
                            ),
                            width: 1.2,
                          ),
                          tooltipPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          getTooltipItems: (touchedSpots) {
                            final titles = _getWeightTitles();
                            return touchedSpots.map((spot) {
                              final idx = spot.spotIndex;
                              final monthLabel = idx < titles.length
                                  ? titles[idx]
                                  : 'Wk ${idx + 1}';
                              return LineTooltipItem(
                                '$monthLabel\n',
                                AppTheme.labelCaps.copyWith(
                                  fontSize: 10,
                                  color: context.appTextSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                                children: [
                                  TextSpan(
                                    text: '${spot.y.toStringAsFixed(1)} ',
                                    style: AppTheme.headlineMd.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: context.isDarkMode
                                          ? AppColors.primaryContainer
                                          : AppColors.primary,
                                    ),
                                  ),
                                  TextSpan(
                                    text: _provider.massUnit,
                                    style: AppTheme.bodySm.copyWith(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: context.appTextSecondary,
                                    ),
                                  ),
                                ],
                              );
                            }).toList();
                          },
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _getWeightSpots(),
                          isCurved: true,
                          color: context.isDarkMode
                              ? AppColors.primaryContainer
                              : AppColors.primary,
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              final isSelected = _touchedSpotIndex == index;
                              final isPeak = spot.y == 71.0 ||
                                  spot.y == 70.1 ||
                                  spot.y == _currentWeight;
                              return FlDotCirclePainter(
                                radius: isSelected ? 5.5 : (isPeak ? 4.0 : 2.5),
                                color: isSelected
                                    ? AppColors.primaryContainer
                                    : (isPeak
                                        ? (context.isDarkMode
                                            ? AppColors.primaryContainer
                                            : AppColors.primary)
                                        : context.appSurface),
                                strokeWidth: isSelected ? 3 : 2,
                                strokeColor: isSelected
                                    ? context.appSurface
                                    : (context.isDarkMode
                                        ? AppColors.primaryContainer
                                        : AppColors.primary),
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                (context.isDarkMode
                                        ? AppColors.primaryContainer
                                        : AppColors.primary)
                                    .withValues(alpha: 0.25),
                                (context.isDarkMode
                                        ? AppColors.primaryContainer
                                        : AppColors.primary)
                                    .withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Tap guidance instruction
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.center_focus_strong_rounded,
                size: 13,
                color: context.isDarkMode
                    ? AppColors.primaryContainer.withValues(alpha: 0.8)
                    : AppColors.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'Tap on any point to see details',
                style: AppTheme.labelCaps.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Interactive Motivational Banner
          GestureDetector(
            onTap: () => _showMotivationalQuoteModal(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: context.isDarkMode
                    ? const Color(0xFF132A1C)
                    : AppColors.primaryContainer.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaryContainer.withValues(
                    alpha: context.isDarkMode ? 0.7 : 0.4,
                  ),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryContainer.withValues(
                      alpha: context.isDarkMode ? 0.35 : 0.15,
                    ),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryContainer.withValues(
                            alpha: 0.3,
                          ),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: AppColors.primaryContainer,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Great job! You've maintained a healthy trend.",
                          style: AppTheme.headlineMd.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.appTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Keep pushing toward your goal weight.',
                          style: AppTheme.bodySm.copyWith(
                            fontSize: 11,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.isDarkMode
                        ? AppColors.primaryContainer
                        : AppColors.primary,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 5. Body Composition Section
  Widget _buildBodyCompositionSection(BuildContext context) {
    final weight = double.tryParse(_provider.weight) ?? 68.2;
    final heightCm = double.tryParse(_provider.height) ?? 175.0;
    final heightM = heightCm / 100.0;
    final bmiVal = weight / (heightM * heightM);
    final bmiStr = bmiVal.toStringAsFixed(1);

    return AppCard(
      padding: const EdgeInsets.all(18),
      borderColor: context.isDarkMode
          ? AppColors.primaryContainer.withValues(alpha: 0.3)
          : null,
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
                    'Body Composition',
                    style: AppTheme.headlineMd.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Key metrics at a glance',
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 11,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _navigateToBodyComposition,
                child: Row(
                  children: [
                    Text(
                      'View Details',
                      style: AppTheme.bodySm.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.isDarkMode
                            ? AppColors.primaryContainer
                            : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: context.isDarkMode
                          ? AppColors.primaryContainer
                          : AppColors.primary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3 Column Metrics Row
          Row(
            children: [
              Expanded(
                child: _buildCompositionMetricCard(
                  context: context,
                  label: 'BMI',
                  value: bmiStr,
                  unit: '',
                  chipText: 'Normal',
                  progress: 0.65,
                  rangeText: 'Healthy range: 18.5 - 24.9',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompositionMetricCard(
                  context: context,
                  label: 'BODY FAT',
                  value: '16.8',
                  unit: '%',
                  chipText: 'Athletic',
                  progress: 0.55,
                  rangeText: 'Healthy range: 10% - 20%',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCompositionMetricCard(
                  context: context,
                  label: 'MUSCLE MASS',
                  value: '54.1',
                  unit: 'kg',
                  chipText: 'Good',
                  progress: 0.80,
                  rangeText: 'Healthy range: 50kg+',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompositionMetricCard({
    required BuildContext context,
    required String label,
    required String value,
    required String unit,
    required String chipText,
    required double progress,
    required String rangeText,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.appSurfaceElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.isDarkMode
              ? AppColors.primaryContainer.withValues(alpha: 0.25)
              : context.appOutlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTheme.labelCaps.copyWith(
              fontSize: 9,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
              color: context.appTextSecondary,
            ),
          ),
          const SizedBox(height: 6),

          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: AppTheme.displayMetrics.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.appTextPrimary,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: AppTheme.bodySm.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.primaryContainer.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  chipText,
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: context.isDarkMode
                        ? AppColors.primaryContainer
                        : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: progress),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, animProgress, child) {
                return LinearProgressIndicator(
                  value: animProgress,
                  backgroundColor: context.appOutlineVariant.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    context.isDarkMode
                        ? AppColors.primaryContainer
                        : AppColors.primary,
                  ),
                  minHeight: 4,
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          Text(
            rangeText,
            style: AppTheme.bodySm.copyWith(
              fontSize: 9,
              color: context.appTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MotivationalQuote {
  final String characterName;
  final String characterSource;
  final String quoteText;
  final String highlightText;
  final String avatarSymbol;
  final String powerTag;
  final String assetName;

  const _MotivationalQuote({
    required this.characterName,
    required this.characterSource,
    required this.quoteText,
    required this.highlightText,
    required this.avatarSymbol,
    required this.powerTag,
    required this.assetName,
  });

  String get imagePath => 'assets/quotes/$assetName.png';
  String get imagePathJpg => 'assets/quotes/$assetName.jpg';
}

const List<_MotivationalQuote> _motivationalQuotes = [
  _MotivationalQuote(
    characterName: 'Goku',
    characterSource: 'Dragon Ball',
    quoteText:
        'Power comes in response to a need, not a desire. Train harder, push further, and become stronger.',
    highlightText: 'become stronger.',
    avatarSymbol: '悟',
    powerTag: 'LIMITLESS POTENTIAL',
    assetName: 'goku',
  ),
  _MotivationalQuote(
    characterName: 'Naruto',
    characterSource: 'Naruto',
    quoteText:
        'Hard work can overcome talent. Keep moving forward, even when the path is difficult.',
    highlightText: 'moving forward',
    avatarSymbol: '忍',
    powerTag: 'NEVER GIVE UP',
    assetName: 'naruto',
  ),
  _MotivationalQuote(
    characterName: 'Saitama',
    characterSource: 'One Punch Man',
    quoteText:
        'Discipline creates strength. Keep showing up and improving every single day.',
    highlightText: 'every single day.',
    avatarSymbol: '👊',
    powerTag: 'UNSTOPPABLE DISCIPLINE',
    assetName: 'saitama',
  ),
  _MotivationalQuote(
    characterName: 'Garou',
    characterSource: 'One Punch Man',
    quoteText:
        'Strength is forged through struggle. Every challenge is a chance to evolve.',
    highlightText: 'chance to evolve.',
    avatarSymbol: '狼',
    powerTag: 'EVOLUTION THROUGH STRUGGLE',
    assetName: 'garou',
  ),
];

class _MotivationalQuoteBottomSheet extends StatefulWidget {
  const _MotivationalQuoteBottomSheet();

  @override
  State<_MotivationalQuoteBottomSheet> createState() =>
      __MotivationalQuoteBottomSheetState();
}

class __MotivationalQuoteBottomSheetState
    extends State<_MotivationalQuoteBottomSheet>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _nextQuote() {
    _animController.forward(from: 0.0);
    setState(() {
      _currentIndex = (_currentIndex + 1) % _motivationalQuotes.length;
    });
  }

  void _shareQuote(_MotivationalQuote quote) {
    final textToShare =
        '"${quote.quoteText}" — ${quote.characterName} (${quote.characterSource})';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Quote copied to clipboard:\n$textToShare',
          style: AppTheme.bodySm.copyWith(
            color: AppColors.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quote = _motivationalQuotes[_currentIndex];
    final isDark = context.isDarkMode;

    return Container(
      margin: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
        top: 40,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121815) : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primaryContainer.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer
                .withValues(alpha: isDark ? 0.2 : 0.1),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Modal Header Bar: QUOTE OF THE DAY & Close button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.primaryContainer,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'QUOTE OF THE DAY',
                    style: AppTheme.labelCaps.copyWith(
                      fontSize: 12,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? AppColors.primaryContainer
                          : AppColors.primary,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: context.appSurfaceElevated,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: context.appOutlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: context.appTextSecondary,
                  ),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Main Animated Quote Content Row/Column
          FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 500;
                  final characterCard =
                      _buildCharacterArtworkCard(context, quote);
                  final quoteDetailCard = _buildQuoteDetailCard(context, quote);

                  if (isWide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 210, height: 230, child: characterCard),
                        const SizedBox(width: 18),
                        Expanded(child: quoteDetailCard),
                      ],
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 195, child: characterCard),
                        const SizedBox(height: 16),
                        quoteDetailCard,
                      ],
                    );
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Bottom Action Buttons: Another Quote & Share
          Row(
            children: [
              Expanded(
                child: AppButton.primary(
                  label: 'Another Quote',
                  icon: Icons.autorenew_rounded,
                  onPressed: _nextQuote,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton.secondary(
                  label: 'Share',
                  icon: Icons.ios_share_rounded,
                  onPressed: () => _shareQuote(quote),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterArtworkCard(
      BuildContext context, _MotivationalQuote quote) {
    final isDark = context.isDarkMode;

    return Container(
      decoration: BoxDecoration(
        color: context.appSurfaceElevated,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? AppColors.primaryContainer.withValues(alpha: 0.4)
              : AppColors.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryContainer
                .withValues(alpha: isDark ? 0.25 : 0.12),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.asset(
          quote.imagePath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Image.asset(
              quote.imagePathJpg,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildFallbackArtworkContainer(context, quote);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildFallbackArtworkContainer(
      BuildContext context, _MotivationalQuote quote) {
    final isDark = context.isDarkMode;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Dark surface base with subtle green ambient background gradient
        Container(
          decoration: BoxDecoration(
            color: context.appSurfaceElevated,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                context.appSurfaceElevated,
                AppColors.primaryContainer.withValues(alpha: 0.12),
              ],
            ),
          ),
        ),

        // Background ambient green aura circles
        Positioned(
          top: -24,
          right: -24,
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryContainer.withValues(alpha: 0.12),
            ),
          ),
        ),
        Positioned(
          bottom: -30,
          left: -20,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryContainer.withValues(alpha: 0.08),
            ),
          ),
        ),

        // Central Hero Character Artwork & Emblem Frame
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Character Emblem Badge Circle
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF0F1412) : context.appSurface,
                  border: Border.all(
                    color: AppColors.primaryContainer,
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryContainer.withValues(alpha: 0.45),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  quote.avatarSymbol,
                  style: TextStyle(
                    fontSize: quote.avatarSymbol.length > 2 ? 14 : 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryContainer,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Character Name Pill
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.primaryContainer.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  quote.characterName.toUpperCase(),
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? AppColors.primaryContainer
                        : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Power Tag Badge
              Text(
                quote.powerTag,
                style: AppTheme.labelCaps.copyWith(
                  fontSize: 9,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                  color: context.appTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuoteDetailCard(
      BuildContext context, _MotivationalQuote quote) {
    final quoteText = quote.quoteText;
    final highlightText = quote.highlightText;
    final parts = quoteText.split(highlightText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Green quote symbol badge
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primaryContainer.withValues(alpha: 0.2),
            border: Border.all(
              color: AppColors.primaryContainer.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryContainer.withValues(alpha: 0.2),
                blurRadius: 8,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            '“',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryContainer,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Quote Rich Text with Vitality Green Highlight
        RichText(
          text: TextSpan(
            style: AppTheme.headlineMd.copyWith(
              fontSize: 17,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
            ),
            children: [
              const TextSpan(text: '“ '),
              if (parts.isNotEmpty) TextSpan(text: parts.first),
              TextSpan(
                text: highlightText,
                style: TextStyle(
                  color: context.isDarkMode
                      ? AppColors.primaryContainer
                      : AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (parts.length > 1) TextSpan(text: parts.last),
              const TextSpan(text: ' ”'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Character Attribution
        Row(
          children: [
            Container(
              width: 16,
              height: 2,
              color: AppColors.primaryContainer,
            ),
            const SizedBox(width: 8),
            Text(
              quote.characterName,
              style: AppTheme.headlineMd.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: context.isDarkMode
                    ? AppColors.primaryContainer
                    : AppColors.primary,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '•  ${quote.characterSource}',
              style: AppTheme.bodySm.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.appTextSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
