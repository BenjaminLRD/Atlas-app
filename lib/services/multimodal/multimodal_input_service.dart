import '../form_detection/pose_models.dart';

/// Supported types of input streams entering Atlas AI.
enum ModalityType {
  cameraVision,
  voiceAudio,
  wearableBiosignal,
  workoutTelemetry,
  nutritionLog,
}

/// Unified multi-stream data payload captured across sensors during an athlete session.
class MultimodalInputPayload {
  final String sessionId;
  final PoseFrame? visionPoseFrame;
  final String? voiceTranscript;
  final double? heartRateBpm;
  final double? hrvRmssd;
  final double? movementVelocityMs;
  final int? currentReps;
  final double? currentWeightKg;
  final String? activeExerciseName;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  const MultimodalInputPayload({
    required this.sessionId,
    this.visionPoseFrame,
    this.voiceTranscript,
    this.heartRateBpm,
    this.hrvRmssd,
    this.movementVelocityMs,
    this.currentReps,
    this.currentWeightKg,
    this.activeExerciseName,
    required this.timestamp,
    this.metadata = const {},
  });

  bool get hasVision => visionPoseFrame != null;
  bool get hasVoice => voiceTranscript != null && voiceTranscript!.trim().isNotEmpty;
  bool get hasWearable => heartRateBpm != null || hrvRmssd != null;
  bool get hasWorkoutData => currentReps != null || currentWeightKg != null;

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    if (visionPoseFrame != null) 'pose_frame': visionPoseFrame!.toJson(),
    if (voiceTranscript != null) 'voice_transcript': voiceTranscript,
    if (heartRateBpm != null) 'heart_rate_bpm': heartRateBpm,
    if (hrvRmssd != null) 'hrv_rmssd': hrvRmssd,
    if (movementVelocityMs != null) 'movement_velocity_ms': movementVelocityMs,
    if (currentReps != null) 'current_reps': currentReps,
    if (currentWeightKg != null) 'current_weight_kg': currentWeightKg,
    if (activeExerciseName != null) 'active_exercise': activeExerciseName,
    'timestamp': timestamp.toIso8601String(),
    'metadata': metadata,
  };
}

/// Centralized Multimodal Input Stream Service.
/// Aggregates real-time camera visual poses, microphone speech transcripts,
/// smartwatch heart rate/strain signals, and barbell velocity sensors.
class MultimodalInputService {
  static MultimodalInputService? _instance;
  static MultimodalInputService get instance =>
      _instance ??= MultimodalInputService();

  static void resetInstance() {
    _instance = null;
  }

  final List<MultimodalInputPayload> _inputHistory = [];
  MultimodalInputPayload? _latestPayload;

  MultimodalInputPayload? get latestPayload => _latestPayload;
  List<MultimodalInputPayload> get inputHistory => List.unmodifiable(_inputHistory);

  /// Ingests a new multimodal data frame.
  MultimodalInputPayload ingestPayload(MultimodalInputPayload payload) {
    _latestPayload = payload;
    _inputHistory.add(payload);
    if (_inputHistory.length > 200) {
      _inputHistory.removeAt(0); // Maintain rolling window to prevent memory bloat
    }
    return payload;
  }

  /// Clears all stored multimodal telemetry.
  void clearHistory() {
    _inputHistory.clear();
    _latestPayload = null;
  }
}
