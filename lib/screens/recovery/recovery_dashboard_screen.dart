import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../../models/health_metrics.dart';
import '../../models/recovery/recovery_report.dart';
import '../../models/recovery/training_readiness_score.dart';
import '../../providers/fitness_provider.dart';
import '../../services/wearables/wearable_service.dart';

/// Health Prediction & Adaptive Recovery Dashboard UI (Phase C.2).
class RecoveryDashboardScreen extends StatefulWidget {
  const RecoveryDashboardScreen({super.key});

  @override
  State<RecoveryDashboardScreen> createState() =>
      _RecoveryDashboardScreenState();
}

class _RecoveryDashboardScreenState extends State<RecoveryDashboardScreen> {
  bool _isEvaluating = false;
  bool _isSyncingWearable = false;
  WearablePlatform _selectedPlatform = Platform.isIOS
      ? WearablePlatform.appleHealth
      : WearablePlatform.googleFit;

  @override
  void initState() {
    super.initState();
    _refreshDashboard();
  }

  Future<void> _refreshDashboard() async {
    setState(() => _isEvaluating = true);
    final provider = FitnessProvider();
    await provider.evaluateTrainingReadiness();
    setState(() => _isEvaluating = false);
  }

  Future<void> _handleWearableSync() async {
    setState(() => _isSyncingWearable = true);
    final provider = FitnessProvider();
    final synced = await provider.syncWearableHealthData(
      platform: _selectedPlatform,
    );
    setState(() => _isSyncingWearable = false);

    if (mounted) {
      final store = _selectedPlatform == WearablePlatform.appleHealth
          ? 'Apple Health'
          : 'Health Connect';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            synced == null
                ? 'No data found in $store. Allow access and make sure a watch or app is writing data there.'
                : 'Synced health data from $store',
          ),
          backgroundColor: synced == null
              ? const Color(0xFF475569)
              : const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = FitnessProvider();
    final report = provider.latestRecoveryReport;
    final metrics = provider.todayHealthMetrics;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Recovery & Training Readiness',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: _isEvaluating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh, color: Colors.white),
            onPressed: _isEvaluating ? null : _refreshDashboard,
          ),
        ],
      ),
      body: report == null
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Training Readiness Hero Gauge
                  _buildReadinessHeroCard(report.readinessScore),
                  const SizedBox(height: 18),

                  // 2. "Should You Train Hard Today?" Answer Box
                  _buildTrainHardAnswerCard(report),
                  const SizedBox(height: 18),

                  // 3. 5-Factor Physiological Recovery Breakdown
                  _buildFactorBreakdownCard(report.readinessScore),
                  const SizedBox(height: 18),

                  // 4. Training Load Analytics (ATL, CTL, ACWR, TSB)
                  _buildTrainingLoadCard(report),
                  const SizedBox(height: 18),

                  // 5. Wearable Health & Sleep Telemetry Card
                  _buildWearableTelemetryCard(metrics),
                  const SizedBox(height: 18),

                  // 6. Wearable Device Sync Section
                  _buildWearableSyncCard(),
                  const SizedBox(height: 24),

                  // 7. Action Button
                  if (report.suggestedVolumeAdjustmentPercent < 0)
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Applied ${report.suggestedVolumeAdjustmentPercent.abs().round()}% adaptive volume scaling to today\'s session!',
                            ),
                            backgroundColor: const Color(0xFF6366F1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.tune, color: Colors.white),
                      label: Text(
                        'Apply Adaptive Plan (${report.suggestedVolumeAdjustmentPercent.round()}% Volume)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildReadinessHeroCard(TrainingReadinessScore readiness) {
    if (!readiness.isAvailable) {
      return _buildReadinessUnavailableCard(readiness);
    }
    final score = readiness.score;
    final isHigh = score >= 70.0;
    final isMod = score >= 50.0 && score < 70.0;
    final themeColor = isHigh
        ? const Color(0xFF10B981) // Emerald
        : isMod
        ? const Color(0xFFF59E0B) // Amber
        : const Color(0xFFEF4444); // Crimson

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: themeColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular Readiness Ring
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: CircularProgressIndicator(
                  value: (score / 100.0).clamp(0.0, 1.0),
                  strokeWidth: 8.5,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(themeColor),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${score.round()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    readiness.readinessGrade,
                    style: TextStyle(
                      color: themeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    readiness.status.toUpperCase(),
                    style: TextStyle(
                      color: themeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  readiness.explanation,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// No sleep, HRV or heart-rate reading: no score, no colour, no gauge.
  Widget _buildReadinessUnavailableCard(TrainingReadinessScore readiness) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TRAINING READINESS',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Unavailable',
            key: Key('readiness_unavailable'),
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            readiness.explanation,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainHardAnswerCard(RecoveryReport report) {
    if (!report.readinessScore.isAvailable) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Should you train hard today?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Can't tell yet. Atlas won't guess without sleep or heart-rate data.",
              key: Key('train_hard_unavailable'),
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ],
        ),
      );
    }
    final canTrainHard = report.readinessScore.score >= 70.0;
    final bannerColor = canTrainHard
        ? const Color(0xFF065F46)
        : const Color(0xFF7F1D1D);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: canTrainHard
              ? const Color(0xFF10B981)
              : const Color(0xFFEF4444),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            canTrainHard ? Icons.fitness_center : Icons.nightlife_outlined,
            color: canTrainHard
                ? const Color(0xFF34D399)
                : const Color(0xFFF87171),
            size: 26,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Should you train hard today?',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  report.trainHardAnswer,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactorBreakdownCard(TrainingReadinessScore readiness) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Readiness Factor Breakdown',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 14),
          _buildProgressRow(
            'Workout Recovery (30%)',
            readiness.workoutRecoveryContribution,
            const Color(0xFF38BDF8),
          ),
          const SizedBox(height: 10),
          _buildProgressRow(
            'Sleep Quality (25%)',
            readiness.sleepContribution,
            const Color(0xFF818CF8),
          ),
          const SizedBox(height: 10),
          _buildProgressRow(
            'HRV Parasympathetic Tone (20%)',
            readiness.hrvContribution,
            const Color(0xFF34D399),
          ),
          const SizedBox(height: 10),
          _buildProgressRow(
            'Training Load & ACWR (15%)',
            readiness.trainingLoadContribution,
            const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 10),
          _buildProgressRow(
            'Nutrition & Fueling (10%)',
            readiness.nutritionContribution,
            const Color(0xFFA855F7),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow(String label, double? value, Color color) {
    if (value == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 12.5),
          ),
          const Text(
            '--',
            style: TextStyle(
              color: Colors.white38,
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
            Text(
              '${value.round()}%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (value / 100.0).clamp(0.0, 1.0),
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildTrainingLoadCard(RecoveryReport report) {
    final acwr = report.acuteToChronicRatio;
    final hasHistory = report.hasTrainingHistory;
    final isSweetSpot = hasHistory && acwr >= 0.8 && acwr <= 1.3;
    final isSpike = hasHistory && report.isVolumeSpikeDetected;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Training Load Analytics',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSpike
                      ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                      : (isSweetSpot
                            ? const Color(0xFF10B981).withValues(alpha: 0.2)
                            : const Color(0xFFF59E0B).withValues(alpha: 0.2)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  !hasHistory
                      ? 'NO WORKOUTS YET'
                      : (isSpike
                            ? 'VOLUME SPIKE'
                            : (isSweetSpot ? 'SWEET SPOT' : 'MODERATE')),
                  style: TextStyle(
                    color: isSpike
                        ? const Color(0xFFEF4444)
                        : (isSweetSpot
                              ? const Color(0xFF34D399)
                              : const Color(0xFFF59E0B)),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildLoadTile(
                'Acute Load (7d)',
                hasHistory ? '${report.acuteTrainingLoad.round()}' : '--',
                'kg / strain',
              ),
              const SizedBox(width: 12),
              _buildLoadTile(
                'Chronic Load (28d)',
                hasHistory ? '${report.chronicTrainingLoad.round()}' : '--',
                'avg / wk',
              ),
              const SizedBox(width: 12),
              _buildLoadTile(
                'ACWR Ratio',
                hasHistory ? acwr.toStringAsFixed(2) : '--',
                !hasHistory
                    ? 'Log workouts'
                    : (isSweetSpot ? 'Optimal' : 'Caution'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadTile(String title, String value, String sub) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: const TextStyle(color: Colors.white38, fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWearableTelemetryCard(HealthMetrics? metrics) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Wearable Physiological Signals',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                metrics?.sourceDevice ?? 'No data source connected',
                style: const TextStyle(color: Color(0xFF818CF8), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildSignalTile(
                'Sleep',
                metrics?.sleepHours == null
                    ? '--'
                    : '${metrics!.sleepHours!.toStringAsFixed(1)} hrs',
                Icons.bedtime_outlined,
                const Color(0xFF818CF8),
              ),
              const SizedBox(width: 10),
              _buildSignalTile(
                'Resting HR',
                metrics?.restingHeartRate == null
                    ? '--'
                    : '${metrics!.restingHeartRate!.round()} bpm',
                Icons.favorite_border,
                const Color(0xFFEF4444),
              ),
              const SizedBox(width: 10),
              _buildSignalTile(
                'HRV',
                metrics?.heartRateVariability == null
                    ? '--'
                    : '${metrics!.heartRateVariability!.round()} ms',
                Icons.show_chart,
                const Color(0xFF34D399),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignalTile(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWearableSyncCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF312E81).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Wearable Ecosystem Sync',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _buildPlatformChip(WearablePlatform.appleHealth, 'Apple Health'),
              _buildPlatformChip(WearablePlatform.googleFit, 'Health Connect'),
            ],
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _isSyncingWearable ? null : _handleWearableSync,
            icon: _isSyncingWearable
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync, color: Colors.white, size: 18),
            label: Text(
              _selectedPlatform == WearablePlatform.appleHealth
                  ? 'Sync Apple Health data'
                  : 'Sync Health Connect data',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformChip(WearablePlatform platform, String label) {
    final isSelected = _selectedPlatform == platform;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.white70,
          fontSize: 12,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF6366F1),
      backgroundColor: const Color(0xFF1E293B),
      onSelected: (val) {
        if (val) setState(() => _selectedPlatform = platform);
      },
    );
  }
}
