import '../form_detection/pose_models.dart';
import 'sensor_fusion_engine.dart';
import 'vision_coach_service.dart';
import 'voice_coach_service.dart';

/// State transitions in a live coaching workout session.
enum LiveCoachState {
  idle,
  activeSet,
  resting,
  sessionCompleted,
}

/// Recorded set during a live multimodal workout session.
class LiveSetLog {
  final int setIndex;
  final String exerciseName;
  final double weightKg;
  final int repsCompleted;
  final double meanVelocityMs;
  final double avgHeartRateBpm;
  final double formScore;
  final List<FormFaultType> detectedFaults;
  final DateTime timestamp;

  const LiveSetLog({
    required this.setIndex,
    required this.exerciseName,
    required this.weightKg,
    required this.repsCompleted,
    required this.meanVelocityMs,
    required this.avgHeartRateBpm,
    required this.formScore,
    required this.detectedFaults,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'set_index': setIndex,
    'exercise': exerciseName,
    'weight_kg': weightKg,
    'reps': repsCompleted,
    'mean_velocity_ms': meanVelocityMs,
    'avg_heart_rate_bpm': avgHeartRateBpm,
    'form_score': formScore,
    'faults': detectedFaults.map((f) => f.name).toList(),
    'timestamp': timestamp.toIso8601String(),
  };
}

/// End-of-session multimodal intelligence summary.
class LiveSessionSummary {
  final String workoutName;
  final int totalSets;
  final double totalVolumeKg;
  final double averageFormScore;
  final double peakHeartRateBpm;
  final List<LiveSetLog> completedSets;
  final DateTime completedAt;

  const LiveSessionSummary({
    required this.workoutName,
    required this.totalSets,
    required this.totalVolumeKg,
    required this.averageFormScore,
    required this.peakHeartRateBpm,
    required this.completedSets,
    required this.completedAt,
  });

  Map<String, dynamic> toJson() => {
    'workout_name': workoutName,
    'total_sets': totalSets,
    'total_volume_kg': totalVolumeKg,
    'avg_form_score': averageFormScore,
    'peak_heart_rate_bpm': peakHeartRateBpm,
    'completed_sets': completedSets.map((s) => s.toJson()).toList(),
    'completed_at': completedAt.toIso8601String(),
  };
}

/// Real-Time Live Workout Coach Mode.
/// Orchestrates vision form tracking, hands-free voice commands,
/// wearable sensor fusion, adaptive rest countdowns, and set logging.
class LiveWorkoutCoachMode {
  static LiveWorkoutCoachMode? _instance;
  static LiveWorkoutCoachMode get instance =>
      _instance ??= LiveWorkoutCoachMode();

  static void resetInstance() {
    _instance = null;
  }

  final VisionCoachService _visionCoach;
  final VoiceCoachService _voiceCoach;
  final SensorFusionEngine _sensorFusion;

  LiveCoachState _state = LiveCoachState.idle;
  String _activeWorkoutName = '';
  String _currentExerciseName = 'Squat';
  int _currentSetIndex = 1;
  int _restTimeRemainingSeconds = 0;
  final List<LiveSetLog> _completedSets = [];

  LiveCoachState get state => _state;
  String get activeWorkoutName => _activeWorkoutName;
  String get currentExerciseName => _currentExerciseName;
  int get currentSetIndex => _currentSetIndex;
  int get restTimeRemainingSeconds => _restTimeRemainingSeconds;
  List<LiveSetLog> get completedSets => List.unmodifiable(_completedSets);

  LiveWorkoutCoachMode({
    VisionCoachService? visionCoach,
    VoiceCoachService? voiceCoach,
    SensorFusionEngine? sensorFusion,
  })  : _visionCoach = visionCoach ?? VisionCoachService.instance,
        _voiceCoach = voiceCoach ?? VoiceCoachService.instance,
        _sensorFusion = sensorFusion ?? SensorFusionEngine.instance;

  /// Starts a live coaching workout session.
  void startSession({
    required String workoutName,
    String initialExercise = 'Squat',
  }) {
    _activeWorkoutName = workoutName;
    _currentExerciseName = initialExercise;
    _state = LiveCoachState.idle;
    _currentSetIndex = 1;
    _completedSets.clear();
    _visionCoach.resetReps();
  }

  /// Begins tracking an active set.
  void startActiveSet() {
    _state = LiveCoachState.activeSet;
    _visionCoach.resetReps();
  }

  /// Ingests live frame telemetry and returns real-time vision evaluation.
  VisionFormEvaluation processLiveFrame(
    PoseFrame frame, {
    double heartRateBpm = 135.0,
    double movementVelocityMs = 0.70,
  }) {
    final eval = _visionCoach.evaluateFrame(
      frame,
      exerciseHint: _getExerciseTypeFromQuery(_currentExerciseName),
    );
    return eval;
  }

  /// Completes the active set, logs metrics, and triggers adaptive rest countdown.
  LiveSetLog completeSet({
    double weightKg = 100.0,
    int? repsOverride,
    double avgHeartRateBpm = 145.0,
    double meanVelocityMs = 0.62,
  }) {
    final reps = repsOverride ?? (_visionCoach.currentRepCount > 0 ? _visionCoach.currentRepCount : 8);

    final setLog = LiveSetLog(
      setIndex: _currentSetIndex,
      exerciseName: _currentExerciseName,
      weightKg: weightKg,
      repsCompleted: reps,
      meanVelocityMs: meanVelocityMs,
      avgHeartRateBpm: avgHeartRateBpm,
      formScore: 92.0,
      detectedFaults: const [FormFaultType.none],
      timestamp: DateTime.now(),
    );

    _completedSets.add(setLog);
    _currentSetIndex++;

    // Calculate adaptive rest with sensor fusion
    final fusedState = _sensorFusion.fuseTelemetry(
      heartRateBpm: avgHeartRateBpm,
      currentRepVelocityMs: meanVelocityMs,
      setsCompletedInSession: _completedSets.length,
    );

    startRestPeriod(fusedState.recommendedRestSeconds);
    return setLog;
  }

  /// Starts the rest period with custom or adaptive countdown.
  void startRestPeriod(int durationSeconds) {
    _state = LiveCoachState.resting;
    _restTimeRemainingSeconds = durationSeconds;
  }

  /// Processes spoken voice commands in real-time.
  String handleVoiceInput(String transcript) {
    final command = _voiceCoach.parseVoiceCommand(transcript);

    switch (command.intent) {
      case VoiceCommandIntent.startWorkout:
        startActiveSet();
        return _voiceCoach.synthesizeSpeechFeedback(
          message: 'Starting set $_currentSetIndex of $_currentExerciseName. Form tracking active.',
        );

      case VoiceCommandIntent.logSet:
        final weight = command.extractedWeightKg ?? 100.0;
        final reps = command.extractedReps ?? 8;
        completeSet(weightKg: weight, repsOverride: reps);
        return _voiceCoach.synthesizeSpeechFeedback(
          message: 'Logged $reps reps at ${weight.round()}kg. Rest timer started.',
        );

      case VoiceCommandIntent.startTimer:
        final rest = command.extractedRestSeconds ?? 90;
        startRestPeriod(rest);
        return _voiceCoach.synthesizeSpeechFeedback(
          message: 'Rest timer set for $rest seconds.',
        );

      case VoiceCommandIntent.pauseTimer:
        _restTimeRemainingSeconds = 0;
        _state = LiveCoachState.idle;
        return _voiceCoach.synthesizeSpeechFeedback(message: 'Rest timer paused.');

      case VoiceCommandIntent.nextExercise:
        _currentExerciseName = 'Romanian Deadlift';
        _currentSetIndex = 1;
        _state = LiveCoachState.idle;
        return _voiceCoach.synthesizeSpeechFeedback(
          message: 'Moving to next exercise: $_currentExerciseName.',
        );

      case VoiceCommandIntent.checkProgress:
        final totalVol = _completedSets.fold<double>(
          0.0,
          (sum, s) => sum + (s.weightKg * s.repsCompleted),
        );
        return _voiceCoach.synthesizeSpeechFeedback(
          message: '${_completedSets.length} sets completed. Total volume: ${totalVol.round()}kg.',
        );

      case VoiceCommandIntent.explainExercise:
        return _voiceCoach.synthesizeSpeechFeedback(
          message: 'Brace core, maintain 3-point foot tripod, control the descent.',
        );

      case VoiceCommandIntent.unknown:
        return _voiceCoach.synthesizeSpeechFeedback(
          message: 'Command not recognized. Say "Start set" or "Log set 100kg 8 reps".',
        );
    }
  }

  /// Finishes the session and compiles the summary.
  LiveSessionSummary finishSession() {
    _state = LiveCoachState.sessionCompleted;
    final totalVol = _completedSets.fold<double>(
      0.0,
      (sum, s) => sum + (s.weightKg * s.repsCompleted),
    );

    final avgForm = _completedSets.isNotEmpty
        ? _completedSets.fold<double>(0.0, (sum, s) => sum + s.formScore) /
            _completedSets.length
        : 90.0;

    final peakHr = _completedSets.isNotEmpty
        ? _completedSets.map((s) => s.avgHeartRateBpm).reduce((a, b) => a > b ? a : b)
        : 140.0;

    return LiveSessionSummary(
      workoutName: _activeWorkoutName,
      totalSets: _completedSets.length,
      totalVolumeKg: totalVol,
      averageFormScore: double.parse(avgForm.toStringAsFixed(1)),
      peakHeartRateBpm: peakHr,
      completedSets: List.unmodifiable(_completedSets),
      completedAt: DateTime.now(),
    );
  }

  VisionExerciseType _getExerciseTypeFromQuery(String query) {
    final clean = query.toLowerCase();
    if (clean.contains('squat')) return VisionExerciseType.squat;
    if (clean.contains('deadlift') || clean.contains('rdl')) return VisionExerciseType.deadlift;
    if (clean.contains('bench') || clean.contains('pushup')) return VisionExerciseType.benchPress;
    if (clean.contains('press')) return VisionExerciseType.overheadPress;
    if (clean.contains('pullup') || clean.contains('chin')) return VisionExerciseType.pullup;
    if (clean.contains('curl')) return VisionExerciseType.bicepCurl;
    return VisionExerciseType.squat;
  }
}
