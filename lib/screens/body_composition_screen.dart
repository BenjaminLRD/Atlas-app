import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/app_dependencies.dart';
import '../data/local_storage.dart';
import '../data/profile_provider.dart';
import '../services/health/platform_health_reader.dart';
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

  /// Pulls the latest smart-scale reading (written to Apple Health or Health
  /// Connect by the scale's own app) into the profile.
  void _triggerScaleSync() async {
    setState(() => _isSyncingScale = true);
    String message;
    try {
      final reader = PlatformHealthReader.instance;
      if (!PlatformHealthReader.isSupportedPlatform ||
          !await reader.isAvailable()) {
        message =
            'Connect Apple Health or Health Connect to sync your smart scale.';
      } else {
        await reader.requestPermissions();
        final body = await reader.latestBodyComposition();
        if (body.weightKg == null && body.bodyFatPercent == null) {
          message = 'No scale readings found in the last 30 days.';
        } else {
          final parts = <String>[];
          if (body.weightKg != null) {
            final kg = body.weightKg!.toStringAsFixed(1);
            await _profileProvider.updateField('weight', kg);
            parts.add('$kg kg');
          }
          if (body.bodyFatPercent != null) {
            final fat = body.bodyFatPercent!.toStringAsFixed(1);
            await _profileProvider.updateField('bodyFatPercent', fat);
            parts.add('$fat% body fat');
          }
          if (body.leanMassKg != null) {
            await _profileProvider.updateField(
              'leanMassKg',
              body.leanMassKg!.toStringAsFixed(1),
            );
          }
          message = 'Synced from your scale: ${parts.join(', ')}.';
        }
      }
    } catch (_) {
      message = 'Could not read your scale data. Try again.';
    }
    if (!mounted) return;
    setState(() => _isSyncingScale = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTheme.bodySm.copyWith(
            color: AppColors.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  double? _profileNumber(String key) =>
      double.tryParse('${_profileProvider.userProfile[key] ?? ''}');

  double? get _bodyFat => _profileNumber('bodyFatPercent');
  double? get _leanMass => _profileNumber('leanMassKg');
  int? get _restingHr => LocalStorage.getHealthMetric()?.restingHeartRate;

  static String _bmiStatus(double bmi) {
    if (bmi <= 0) return '';
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25) return 'Healthy';
    if (bmi < 30) return 'Overweight';
    return 'Obese';
  }

  @override
  Widget build(BuildContext context) {
    final rawWeight = double.tryParse(_profileProvider.weight);
    final rawHeight = double.tryParse(_profileProvider.height);
    final hasMetrics =
        rawWeight != null &&
        rawWeight > 0 &&
        rawHeight != null &&
        rawHeight > 0;

    final weight = rawWeight ?? 0.0;
    final heightCm = rawHeight ?? 0.0;
    final heightM = heightCm > 0 ? heightCm / 100.0 : 1.0;
    final bmiVal = hasMetrics ? weight / (heightM * heightM) : 0.0;
    final bmiStr = hasMetrics ? bmiVal.toStringAsFixed(1) : '--';

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
              if (!hasMetrics) ...[
                AppCard(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: AppColors.primaryContainer.withValues(
                    alpha: 0.12,
                  ),
                  borderColor: AppColors.primaryContainer.withValues(
                    alpha: 0.4,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Complete your profile to personalize your fitness journey',
                          style: AppTheme.bodyMd.copyWith(
                            fontWeight: FontWeight.w600,
                            color: context.appTextPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

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

  static const Color _accentGreen = Color(0xFF22C55E);

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
                badge: _bmiStatus(double.tryParse(bmiStr) ?? 0),
                subtitle: 'Healthy 18.5 - 24.9',
                icon: Icons.monitor_weight_outlined,
                progress: ((double.tryParse(bmiStr) ?? 0) / 40).clamp(0.0, 1.0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                context,
                title: 'BODY FAT',
                value: _bodyFat?.toStringAsFixed(1) ?? '--',
                unit: '%',
                badge: _bodyFat == null ? 'No data' : '',
                subtitle: 'Sync a smart scale',
                icon: Icons.pie_chart_outline,
                progress: ((_bodyFat ?? 0) / 40).clamp(0.0, 1.0),
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
                title: 'LEAN MASS',
                value: _leanMass?.toStringAsFixed(1) ?? '--',
                unit: 'kg',
                badge: _leanMass == null ? 'No data' : '',
                subtitle: 'From your smart scale',
                icon: Icons.fitness_center_rounded,
                progress: weight > 0 && _leanMass != null
                    ? (_leanMass! / weight).clamp(0.0, 1.0)
                    : 0.0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricTile(
                context,
                title: 'RESTING HR',
                value: _restingHr?.toString() ?? '--',
                unit: 'bpm',
                badge: _restingHr == null ? 'No data' : '',
                subtitle: 'Typical 50 - 70',
                icon: Icons.favorite_outline,
                progress: ((_restingHr ?? 0) / 100).clamp(0.0, 1.0),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(icon, color: _accentGreen, size: 16),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.labelCaps.copyWith(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Flexible(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _accentGreen.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: _accentGreen,
                  ),
                ),
              )),
            ],
          ),
          const SizedBox(height: 8),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
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
                      fontWeight: FontWeight.w600,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: context.appSurfaceElevated,
              color: _accentGreen,
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 6),

          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
                color: _accentGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Healthy Reference Ranges',
                  style: AppTheme.headlineMd.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildRangeRow(
            context,
            label: 'Body Mass Index (BMI)',
            value: bmiVal > 0 ? bmiVal.toStringAsFixed(1) : '--',
            range: '18.5 – 24.9',
            status: _bmiStatus(bmiVal),
          ),
          const Divider(height: 16),
          _buildRangeRow(
            context,
            label: 'Body Fat Percentage',
            value: _bodyFat == null ? '--' : '${_bodyFat!.toStringAsFixed(1)}%',
            range: '10.0% – 20.0% (men), 18% – 28% (women)',
            status: '',
          ),
          const Divider(height: 16),
          _buildRangeRow(
            context,
            label: 'Lean Body Mass',
            value: _leanMass == null
                ? '--'
                : '${_leanMass!.toStringAsFixed(1)} kg',
            range: 'Varies with height',
            status: '',
          ),
          const Divider(height: 16),
          _buildRangeRow(
            context,
            label: 'Resting Heart Rate',
            value: _restingHr == null ? '--' : '$_restingHr bpm',
            range: '50 – 70 bpm',
            status: '',
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
        Expanded(
          child: Column(
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
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
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
                color: _accentGreen.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                status,
                style: AppTheme.labelCaps.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _accentGreen,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAiInsightCard(BuildContext context) {
    return AppInsightCard(
      title: 'Body Composition',
      description: _bodyFat == null
          ? 'Sync a smart scale through Apple Health or Health Connect to track body fat and lean mass over time. Weight alone cannot tell fat loss from muscle gain.'
          : 'Body fat ${_bodyFat!.toStringAsFixed(1)}% from your latest scale reading. Track the trend over weeks rather than single readings, which shift with hydration.',
      icon: Icons.auto_awesome_rounded,
      accentColor: _accentGreen,
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
              color: _accentGreen.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bluetooth_connected_rounded,
              color: _accentGreen,
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
              backgroundColor: _accentGreen,
              foregroundColor: Colors.white,
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
