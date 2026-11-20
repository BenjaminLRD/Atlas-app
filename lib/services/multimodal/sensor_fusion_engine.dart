import '../../../models/recovery_state.dart';

/// Cardiovascular intensity training zones.
enum CardioZone {
  zone1ActiveRecovery('Zone 1 (Active Recovery <60%)'),
  zone2Endurance('Zone 2 (Aerobic Base 60-70%)'),
  zone3Aerobic('Zone 3 (Tempo 70-80%)'),
  zone4Threshold('Zone 4 (Lactate Threshold 80-90%)'),
  zone5Maximal('Zone 5 (Max Aerobic / Anaerobic >90%)');

  final String label;
  const CardioZone(this.label);
}

/// Unified, holistic athlete physiological and biomechanical state.
class UnifiedAthleteState {
  final double currentHeartRateBpm;
  final double maxHeartRateBpm;
  final CardioZone cardioZone;
  final double physiologicalStrainIndex; // 0.0 to 10.0 scale
  final double realTimeRPE; // 1.0 to 10.0
  final double velocityLossPercentage; // Drop in concentric speed from set 1
  final int recommendedRestSeconds;
  final String recoveryStatus;
  final DateTime timestamp;

  const UnifiedAthleteState({
    required this.currentHeartRateBpm,
    required this.maxHeartRateBpm,
    required this.cardioZone,
    required this.physiologicalStrainIndex,
    required this.realTimeRPE,
    required this.velocityLossPercentage,
    required this.recommendedRestSeconds,
    required this.recoveryStatus,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'heart_rate_bpm': currentHeartRateBpm,
    'max_heart_rate': maxHeartRateBpm,
    'cardio_zone': cardioZone.name,
    'strain_index': physiologicalStrainIndex,
    'real_time_rpe': realTimeRPE,
    'velocity_loss_pct': velocityLossPercentage,
    'recommended_rest_sec': recommendedRestSeconds,
    'recovery_status': recoveryStatus,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Multi-Sensor Fusion Engine.
/// Fuses optical heart rate biosignals, barbell concentric velocities,
/// autonomic HRV recovery, and accumulated session work into a unified state.
class SensorFusionEngine {
  static SensorFusionEngine? _instance;
  static SensorFusionEngine get instance =>
      _instance ??= SensorFusionEngine();

  static void resetInstance() {
    _instance = null;
  }

  /// Calculates a unified athlete state from real-time wearable, velocity, and workout inputs.
  UnifiedAthleteState fuseTelemetry({
    required double heartRateBpm,
    int athleteAge = 26,
    double initialRepVelocityMs = 0.75,
    double currentRepVelocityMs = 0.65,
    int setsCompletedInSession = 3,
    RecoveryState? recoveryState,
  }) {
    final now = DateTime.now();

    // 1. Calculate Estimated Max Heart Rate (Tanaka formula: 208 - 0.7 * age)
    final maxHr = 208.0 - (0.7 * athleteAge);
    final hrPercentage = (heartRateBpm / maxHr) * 100.0;

    // 2. Classify Cardio Zone
    CardioZone zone;
    if (hrPercentage < 60.0) {
      zone = CardioZone.zone1ActiveRecovery;
    } else if (hrPercentage < 70.0) {
      zone = CardioZone.zone2Endurance;
    } else if (hrPercentage < 80.0) {
      zone = CardioZone.zone3Aerobic;
    } else if (hrPercentage < 90.0) {
      zone = CardioZone.zone4Threshold;
    } else {
      zone = CardioZone.zone5Maximal;
    }

    // 3. Calculate Velocity Loss Percentage
    double velocityLossPct = 0.0;
    if (initialRepVelocityMs > 0.0 && currentRepVelocityMs < initialRepVelocityMs) {
      velocityLossPct = ((initialRepVelocityMs - currentRepVelocityMs) /
              initialRepVelocityMs) *
          100.0;
    }

    // 4. Calculate Physiological Strain Index (0.0 to 10.0 scale)
    double strain = (hrPercentage / 10.0);
    strain += (velocityLossPct / 15.0);
    strain += (setsCompletedInSession * 0.2);
    if (recoveryState != null && recoveryState.recoveryScore < 60) {
      strain += 1.0; // Baseline penalty for under-recovered athlete
    }
    final clampedStrain = strain.clamp(1.0, 10.0);

    // 5. Estimate Real-Time RPE
    double rpe = 5.0;
    if (velocityLossPct >= 35.0 || hrPercentage >= 88.0) {
      rpe = 9.5; // Near failure
    } else if (velocityLossPct >= 28.0 || hrPercentage >= 80.0) {
      rpe = 9.0;
    } else if (velocityLossPct >= 20.0 || hrPercentage >= 75.0) {
      rpe = 8.0;
    } else if (velocityLossPct >= 10.0 || hrPercentage >= 68.0) {
      rpe = 7.0;
    } else {
      rpe = 6.0;
    }

    // 6. Compute Adaptive Rest Duration
    int restSeconds = 90;
    if (clampedStrain >= 8.0 || velocityLossPct >= 25.0) {
      restSeconds = 150; // Heavy CNS fatigue - lengthen rest
    } else if (clampedStrain >= 6.0) {
      restSeconds = 120;
    } else if (zone == CardioZone.zone1ActiveRecovery) {
      restSeconds = 60; // Light work - quick turnaround
    }

    final recoveryStatus = recoveryState != null
        ? 'Recovery Score: ${recoveryState.recoveryScore}/100 (${recoveryState.fatigueLevel.name})'
        : 'Optimal Readiness';

    return UnifiedAthleteState(
      currentHeartRateBpm: heartRateBpm,
      maxHeartRateBpm: double.parse(maxHr.toStringAsFixed(1)),
      cardioZone: zone,
      physiologicalStrainIndex: double.parse(clampedStrain.toStringAsFixed(1)),
      realTimeRPE: double.parse(rpe.toStringAsFixed(1)),
      velocityLossPercentage: double.parse(velocityLossPct.toStringAsFixed(1)),
      recommendedRestSeconds: restSeconds,
      recoveryStatus: recoveryStatus,
      timestamp: now,
    );
  }
}
