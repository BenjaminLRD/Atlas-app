import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/local_storage.dart';
import '../models/health_metric.dart';
import '../services/health/health_service.dart';
import '../services/health/recovery_service.dart';
import '../services/step_tracking_service.dart';
import '../services/steps/step_counter_service.dart';
import '../services/steps/step_models.dart';
import '../widgets/common/app_header.dart';
import '../widgets/recovery/sleep_recovery_card.dart';

/// Comprehensive Health & Wearables Telemetry Hub.
/// Displays live health metrics, 4-pillar recovery breakdown, training readiness prediction, 7-day trends, and wearable sync manager.
class HealthDashboardScreen extends StatefulWidget {
  const HealthDashboardScreen({super.key});

  @override
  State<HealthDashboardScreen> createState() => _HealthDashboardScreenState();
}

class _HealthDashboardScreenState extends State<HealthDashboardScreen> {
  HealthMetric _metric = HealthMetric(timestamp: DateTime.now());
  List<HealthMetric> _weeklyHistory = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadHealthData();
    StepCounterService.instance.addListener(_onStepsChanged);
  }

  @override
  void dispose() {
    StepCounterService.instance.removeListener(_onStepsChanged);
    super.dispose();
  }

  void _onStepsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadHealthData() async {
    final metric = await HealthService.instance.getTodayHealthMetric();
    final history = await HealthService.instance.getWeeklyHealthHistory();
    if (mounted) {
      setState(() {
        _metric = metric;
        _weeklyHistory = history;
        _isLoading = false;
      });
    }
  }

  Future<void> _syncWearableData() async {
    setState(() => _isSyncing = true);
    await HealthService.instance.requestPermissions();
    final refreshed = await HealthService.instance.getTodayHealthMetric();
    final history = await HealthService.instance.getWeeklyHealthHistory();
    await StepCounterService.instance.refreshHealthConnect();
    if (mounted) {
      final hasData =
          StepCounterService.instance.healthConnectHasData ||
          refreshed.heartRate != null ||
          refreshed.sleepMinutes != null ||
          refreshed.restingHeartRate != null;
      setState(() {
        _metric = refreshed;
        _weeklyHistory = history;
        _isSyncing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasData
                ? 'Health data updated from ${refreshed.source == 'none' ? 'Health Connect' : refreshed.source}'
                : 'No health data found. Allow access in Health Connect and make sure a watch or app is writing data there.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final recovery = RecoveryService.instance.calculateFromHealthMetric(
      _metric,
      stepsToday: StepCounterService.instance.today.steps,
      workouts: LocalStorage.getWorkoutHistory(),
    );

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppHeader.back(
        title: 'Health & Wearables',
        subtitle: 'Activity intelligence, sleep & recovery',
        trailing: IconButton(
          icon: _isSyncing
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.appPrimary,
                  ),
                )
              : Icon(Icons.sync_rounded, color: context.appPrimary),
          tooltip: 'Sync Health Data',
          onPressed: _isSyncing ? null : _syncWearableData,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHealthData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero: last night's sleep and recovery.
                    const SleepRecoveryCard(),
                    const SizedBox(height: 22),
                    _sectionLabel(context, 'Today'),
                    _buildTelemetryBentoGrid(context),
                    const SizedBox(height: 22),
                    _sectionLabel(context, 'Recovery breakdown'),
                    _buildPillarsBreakdownCard(context, recovery),
                    const SizedBox(height: 22),
                    _sectionLabel(context, 'Last 7 days'),
                    _buildWeeklyTrendsCard(context),
                    const SizedBox(height: 22),
                    _sectionLabel(context, 'Data sources'),
                    _buildWearablesSyncCard(context),
                  ],
                ),
              ),
            ),
    );
  }

  // Accent colours, lifted a little on dark so they stay readable.
  Color _blue(BuildContext c) =>
      c.isDarkMode ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
  Color _purple(BuildContext c) =>
      c.isDarkMode ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
  Color _amber(BuildContext c) =>
      c.isDarkMode ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
  Color _orange(BuildContext c) =>
      c.isDarkMode ? const Color(0xFFFB923C) : const Color(0xFFEA580C);
  Color _red(BuildContext c) =>
      c.isDarkMode ? const Color(0xFFF87171) : const Color(0xFFDC2626);

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: AppTheme.labelCaps.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: context.appTextSecondary,
        ),
      ),
    );
  }

  /// A translucent card: a faint light-to-clear gradient with a thin border.
  Widget _glass(
    BuildContext context, {
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
    double radius = 18,
  }) {
    final dark = context.isDarkMode;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.03),
                ]
              : [Colors.white, Colors.white.withValues(alpha: 0.7)],
        ),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.12)
              : context.appOutlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: child,
    );
  }

  Widget _buildTelemetryBentoGrid(BuildContext context) {
    final km = StepTrackingService.distanceKmFor(
      StepCounterService.instance.today.steps,
    );
    final tiles = [
      _buildMetricTile(
        context,
        title: 'STEPS',
        value: StepCounterService.instance.today.display,
        subtitle: km == null ? 'Distance: --' : '~${km.toStringAsFixed(1)} km',
        icon: Icons.directions_walk_rounded,
        color: _blue(context),
      ),
      _buildMetricTile(
        context,
        title: 'ACTIVE CALS',
        value: _metric.formattedCalories,
        subtitle: 'Burned',
        icon: Icons.local_fire_department_rounded,
        color: _orange(context),
      ),
      _buildMetricTile(
        context,
        title: 'HEART RATE',
        value: _metric.formattedHeartRate,
        subtitle: _metric.restingHeartRate == null
            ? 'Resting: --'
            : 'Resting: ${_metric.restingHeartRate} bpm',
        icon: Icons.favorite_rounded,
        color: _red(context),
      ),
      _buildMetricTile(
        context,
        title: 'SLEEP DURATION',
        value: _metric.formattedSleep,
        subtitle: _metric.deepSleepMinutes == null
            ? 'Deep sleep: --'
            : '${_metric.deepSleepMinutes}m deep sleep',
        icon: Icons.bedtime_rounded,
        color: _purple(context),
      ),
    ];
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[0]),
              const SizedBox(width: 10),
              Expanded(child: tiles[1]),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[2]),
              const SizedBox(width: 10),
              Expanded(child: tiles[3]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    // A missing reading is shown as "--" in a quieter tone; a real value,
    // including a genuine zero, is shown in full strength.
    final missing = value.trim().startsWith('--');
    return _glass(
      context,
      padding: const EdgeInsets.all(14),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.labelCaps.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: context.appTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: missing ? context.appTextMuted : context.appTextPrimary,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: context.appTextSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarsBreakdownCard(
    BuildContext context,
    RecoveryBreakdown recovery,
  ) {
    return _glass(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recovery score',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: recovery.isAvailable
                      ? context.appPrimary.withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: recovery.isAvailable
                        ? context.appPrimary.withValues(alpha: 0.5)
                        : context.appOutlineVariant,
                  ),
                ),
                child: Text(
                  recovery.isAvailable
                      ? '${recovery.totalScore}/100'
                      : 'Unavailable',
                  key: const Key('recovery_total'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: recovery.isAvailable
                        ? context.appPrimary
                        : context.appTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (!recovery.isAvailable) ...[
            const SizedBox(height: 8),
            Text(
              recovery.recommendation,
              key: const Key('recovery_unavailable_note'),
              style: AppTheme.bodySm.copyWith(
                fontSize: 12,
                height: 1.35,
                color: context.appTextSecondary,
              ),
            ),
          ],
          const SizedBox(height: 14),
          _buildPillarRow(
            context,
            label: 'Sleep duration & quality',
            points: recovery.sleepComponent,
            maxPoints: 40,
            icon: Icons.bedtime_rounded,
            color: _purple(context),
          ),
          const SizedBox(height: 12),
          _buildPillarRow(
            context,
            label: 'Training volume & frequency',
            points: recovery.trainingComponent,
            maxPoints: 30,
            icon: Icons.fitness_center_rounded,
            color: _blue(context),
          ),
          const SizedBox(height: 12),
          _buildPillarRow(
            context,
            label: 'Daily movement & steps',
            points: recovery.activityComponent,
            maxPoints: 20,
            icon: Icons.directions_walk_rounded,
            color: context.appPrimary,
          ),
          const SizedBox(height: 12),
          _buildPillarRow(
            context,
            label: 'Rest days & CNS recovery',
            points: recovery.restDaysComponent,
            maxPoints: 10,
            icon: Icons.spa_rounded,
            color: _amber(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPillarRow(
    BuildContext context, {
    required String label,
    required double? points,
    required int maxPoints,
    required IconData icon,
    required Color color,
  }) {
    final ratio = points == null ? 0.0 : (points / maxPoints).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.appTextPrimary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              points == null
                  ? '-- / $maxPoints pts'
                  : '${points.toStringAsFixed(1)} / $maxPoints pts',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: points == null ? context.appTextMuted : color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: context.isDarkMode
                ? Colors.white.withValues(alpha: 0.10)
                : color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ],
    );
  }

  /// Sleep hours recorded for [day] in the health store, or null.
  double? _sleepHoursOn(DateTime day) {
    for (final m in _weeklyHistory) {
      if (m.timestamp.year == day.year &&
          m.timestamp.month == day.month &&
          m.timestamp.day == day.day) {
        final h = m.sleepHours;
        return h > 0 ? h : null;
      }
    }
    return null;
  }

  Widget _buildWeeklyTrendsCard(BuildContext context) {
    final blue = _blue(context);
    final purple = _purple(context);
    return _glass(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final day in StepCounterService.instance.week)
                Expanded(child: _dayColumn(context, day, blue, purple)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              _legend(context, blue, 'Steps'),
              _legend(context, purple, 'Sleep (hours)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dayColumn(
    BuildContext context,
    DayStepTotal day,
    Color blue,
    Color purple,
  ) {
    final steps = day.steps;
    final stepRatio = steps == null ? 0.0 : (steps / 12000.0).clamp(0.05, 1.0);
    final date = DateTime.parse(day.dayKey);
    final sleepHours = _sleepHoursOn(date);
    return Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            sleepHours == null ? '--' : '${sleepHours.toStringAsFixed(1)}h',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: sleepHours == null ? context.appTextMuted : purple,
            ),
          ),
        ),
        const SizedBox(height: 6),
        // No reading: no bar, never a bar for a made-up count.
        SizedBox(
          height: 56,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 14,
              height: 56 * stepRatio,
              decoration: BoxDecoration(
                color: blue,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            steps == null ? '--' : '$steps',
            style: TextStyle(
              fontSize: 10,
              color: steps == null
                  ? context.appTextMuted
                  : context.appTextSecondary,
            ),
          ),
        ),
        Text(
          _getDayLetter(date),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: context.appTextPrimary,
          ),
        ),
      ],
    );
  }

  Widget _legend(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: context.appTextSecondary),
        ),
      ],
    );
  }

  Widget _buildWearablesSyncCard(BuildContext context) {
    // Shown from what Health Connect really returned, not assumed.
    final receiving = StepCounterService.instance.healthConnectHasData;
    final statusColor = receiving ? context.appPrimary : context.appTextMuted;
    return _glass(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _blue(context).withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.health_and_safety_rounded,
                  color: _blue(context),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Google Health Connect',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Steps, calories, sleep, heart rate',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      key: const Key('health_connect_status'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        receiving ? 'RECEIVING DATA' : 'NO DATA YET',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _stepSourcesLine(),
            key: const Key('step_sources_line'),
            style: TextStyle(fontSize: 12, color: context.appTextSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            receiving
                ? 'Readings come from your watch or band through Health Connect.'
                : 'Tap sync and allow access. A watch or app must be writing data to Health Connect.',
            style: AppTheme.bodySm.copyWith(
              fontSize: 12,
              height: 1.35,
              color: context.appTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Both step sources for today side by side, so a wrong total can be traced
  /// to the source that produced it. The larger one is shown as today's steps.
  String _stepSourcesLine() {
    final t = StepCounterService.instance.today;
    String f(int? v) => v == null ? '--' : '$v';
    return "Today's steps: phone sensor ${f(t.phoneSteps)} · Health Connect "
        '${f(t.healthConnectSteps)}'
        '${t.hasReading ? ' (larger one is shown)' : ''}';
  }

  String _getDayLetter(DateTime date) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return days[(date.weekday - 1) % 7];
  }
}
