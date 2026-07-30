import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../data/profile_provider.dart';
import '../widgets/common/ambient_background.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_header.dart';
import '../widgets/common/app_insight_card.dart';

class BodyCompositionScreen extends StatefulWidget {
  const BodyCompositionScreen({super.key});

  @override
  State<BodyCompositionScreen> createState() => _BodyCompositionScreenState();
}

class _BodyCompositionScreenState extends State<BodyCompositionScreen> {
  late final ProfileProvider _profileProvider;
  bool _isSyncingScale = false;

  @override
  void initState() {
    super.initState();
    _profileProvider = AppDependencies.instance.profileProvider;
    _profileProvider.addListener(_onProfileChanged);
  }

  @override
  void dispose() {
    _profileProvider.removeListener(_onProfileChanged);
    super.dispose();
  }

  void _onProfileChanged() {
    if (mounted) setState(() {});
  }

  void _triggerScaleSync() async {
    setState(() => _isSyncingScale = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isSyncingScale = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Smart scale telemetry synced successfully! (68.2 kg, 16.8% Body Fat)',
            style: AppTheme.bodySm.copyWith(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final weight = double.tryParse(_profileProvider.weight) ?? 68.2;
    final heightCm = double.tryParse(_profileProvider.height) ?? 175.0;
    final heightM = heightCm / 100.0;
    final bmiVal = weight / (heightM * heightM);
    final bmiStr = bmiVal.toStringAsFixed(1);

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppHeader.back(
        title: 'Body Composition',
        subtitle: 'Biometric telemetry & vital signs',
        onBackTap: () => Navigator.maybePop(context),
      ),
      body: AmbientBackground(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            top: 12,
            bottom: bottomInset + 32,
            left: 16,
            right: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Core Biometric Overview Bento Grid
              _buildCoreMetricsGrid(context, bmiStr: bmiStr, weight: weight),
              const SizedBox(height: 16),

              // 2. Healthy Ranges Comparison Table Card
              _buildHealthyRangesCard(context, bmiVal: bmiVal),
              const SizedBox(height: 16),

              // 3. AI Body Composition Analysis Card
              _buildAiInsightCard(context),
              const SizedBox(height: 16),

              // 4. Smart Scale Bluetooth Sync Status Card
              _buildSmartScaleSyncCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoreMetricsGrid(
    BuildContext context, {
    required String bmiStr,
    required double weight,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                context,
                title: 'BMI',
                value: bmiStr,
                unit: '',
                badge: 'Normal',
                subtitle: 'Healthy 18.5 - 24.9',
                icon: Icons.monitor_weight_outlined,
                progress: 0.62,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                context,
                title: 'BODY FAT',
                value: '16.8',
                unit: '%',
                badge: 'Athletic',
                subtitle: 'Target 10% - 20%',
                icon: Icons.pie_chart_outline,
                progress: 0.52,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                context,
                title: 'MUSCLE MASS',
                value: '54.1',
                unit: 'kg',
                badge: 'Good',
                subtitle: 'Target 50kg+',
                icon: Icons.fitness_center_rounded,
                progress: 0.82,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                context,
                title: 'RESTING HR',
                value: '54',
                unit: 'bpm',
                badge: 'Optimal',
                subtitle: 'Target 50 - 65',
                icon: Icons.favorite_outline,
                progress: 0.45,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    required String unit,
    required String badge,
    required String subtitle,
    required IconData icon,
    required double progress,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: AppTheme.labelCaps.copyWith(
                      fontSize: 10,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: AppTheme.displayMetrics.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.appTextPrimary,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 3),
                Text(
                  unit,
                  style: AppTheme.bodySm.copyWith(
                    fontSize: 12,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: context.appSurfaceElevated,
              color: AppColors.primary,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 6),

          Text(
            subtitle,
            style: AppTheme.bodySm.copyWith(
              fontSize: 10,
              color: context.appTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthyRangesCard(
    BuildContext context, {
    required double bmiVal,
  }) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.table_chart_outlined,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Healthy Reference Ranges',
                style: AppTheme.headlineMd.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.appTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildRangeRow(
            context,
            label: 'Body Mass Index (BMI)',
            value: bmiVal.toStringAsFixed(1),
            range: '18.5 – 24.9',
            status: 'Normal',
          ),
          const Divider(height: 16),
          _buildRangeRow(
            context,
            label: 'Body Fat Percentage',
            value: '16.8%',
            range: '10.0% – 20.0%',
            status: 'Athletic',
          ),
          const Divider(height: 16),
          _buildRangeRow(
            context,
            label: 'Skeletal Muscle Mass',
            value: '54.1 kg',
            range: '50.0 kg+',
            status: 'Optimal',
          ),
          const Divider(height: 16),
          _buildRangeRow(
            context,
            label: 'Visceral Fat Index',
            value: 'Level 4',
            range: 'Level 1 – 9',
            status: 'Low Risk',
          ),
          const Divider(height: 16),
          _buildRangeRow(
            context,
            label: 'Resting Heart Rate',
            value: '54 bpm',
            range: '50 – 70 bpm',
            status: 'Excellent',
          ),
        ],
      ),
    );
  }

  Widget _buildRangeRow(
    BuildContext context, {
    required String label,
    required String value,
    required String range,
    required String status,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTheme.bodySm.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Target: $range',
              style: AppTheme.bodySm.copyWith(
                fontSize: 11,
                color: context.appTextSecondary,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Text(
              value,
              style: AppTheme.bodySm.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status,
                style: AppTheme.labelCaps.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAiInsightCard(BuildContext context) {
    return const AppInsightCard(
      title: 'AI Body Composition Analysis',
      description:
          'Your muscle-to-fat ratio is in the top 15th percentile for intermediate athletes. Continuing your progressive overload protocol while maintaining 140g daily protein will optimize hypertrophy without increasing visceral fat.',
      icon: Icons.auto_awesome_rounded,
    );
  }

  Widget _buildSmartScaleSyncCard(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bluetooth_connected_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Scale Bluetooth Sync',
                  style: AppTheme.headlineMd.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Auto-syncs weight & fat % on scale step-on',
                  style: AppTheme.bodySm.copyWith(
                    fontSize: 11,
                    color: context.appTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          ElevatedButton(
            onPressed: _isSyncingScale ? null : _triggerScaleSync,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _isSyncingScale
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Sync',
                    style: AppTheme.bodySm.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
