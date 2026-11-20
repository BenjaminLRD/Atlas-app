/// Recognized voice commands for hands-free workout coaching.
enum VoiceCommandType {
  startWorkout,
  nextExercise,
  recommendWeight,
  startRestTimer,
  explainExercise,
  checkProgress,
  unknown;

  String get displayName {
    switch (this) {
      case VoiceCommandType.startWorkout:
        return 'Start Workout';
      case VoiceCommandType.nextExercise:
        return 'Next Exercise';
      case VoiceCommandType.recommendWeight:
        return 'Weight Guidance';
      case VoiceCommandType.startRestTimer:
        return 'Start Rest Timer';
      case VoiceCommandType.explainExercise:
        return 'Exercise Form Cue';
      case VoiceCommandType.checkProgress:
        return 'Progress Check';
      case VoiceCommandType.unknown:
        return 'Unknown Command';
    }
  }
}

/// Parsed voice command payload with spoken response for Text-To-Speech (TTS).
class VoiceCommandResult {
  final VoiceCommandType type;
  final String rawInput;
  final String ttsResponse;
  final String? action;
  final Map<String, dynamic>? actionParams;

  const VoiceCommandResult({
    required this.type,
    required this.rawInput,
    required this.ttsResponse,
    this.action,
    this.actionParams,
  });
}

/// Voice coach service parsing spoken athlete commands and providing synthesized audio cues.
class VoiceCoachService {
  static VoiceCoachService? _instance;
  static VoiceCoachService get instance => _instance ??= VoiceCoachService();

  /// Parses voice transcription string into an actionable command and TTS audio response.
  VoiceCommandResult parseVoiceCommand(
    String spokenInput, {
    String? activeExerciseName,
    double? activeWeightKg,
  }) {
    final lower = spokenInput.trim().toLowerCase();

    if (lower.contains('start workout') ||
        lower.contains('begin workout') ||
        lower.contains('start session')) {
      return VoiceCommandResult(
        type: VoiceCommandType.startWorkout,
        rawInput: spokenInput,
        ttsResponse:
            'Starting your workout. Lock in and begin your warm-up sets.',
        action: 'start_workout',
      );
    }

    if (lower.contains('next exercise') ||
        lower.contains('skip exercise') ||
        lower.contains('next movement')) {
      return VoiceCommandResult(
        type: VoiceCommandType.nextExercise,
        rawInput: spokenInput,
        ttsResponse: 'Moving to the next exercise. Set up your equipment.',
        action: 'next_exercise',
      );
    }

    if (lower.contains('how much weight') ||
        lower.contains('what weight') ||
        lower.contains('weight recommendation')) {
      final weightStr = activeWeightKg != null
          ? '${activeWeightKg.toStringAsFixed(1)} kilograms'
          : 'your target load';
      final exStr = activeExerciseName ?? 'this movement';
      return VoiceCommandResult(
        type: VoiceCommandType.recommendWeight,
        rawInput: spokenInput,
        ttsResponse:
            'For $exStr, load $weightStr. Focus on controlled eccentric tempo.',
        action: 'recommend_weight',
        actionParams: {
          'exercise': activeExerciseName,
          'weight': activeWeightKg,
        },
      );
    }

    if (lower.contains('start rest timer') ||
        lower.contains('rest timer') ||
        lower.contains('start timer') ||
        lower.contains('rest 90') ||
        lower.contains('rest time')) {
      return VoiceCommandResult(
        type: VoiceCommandType.startRestTimer,
        rawInput: spokenInput,
        ttsResponse: 'Rest timer started. Take deep breaths and recover.',
        action: 'start_rest_timer',
        actionParams: {'durationSeconds': 90},
      );
    }

    if (lower.contains('explain this exercise') ||
        lower.contains('how to do') ||
        lower.contains('form check') ||
        lower.contains('technique cue') ||
        lower.contains('explain exercise')) {
      final exStr = activeExerciseName ?? 'this exercise';
      return VoiceCommandResult(
        type: VoiceCommandType.explainExercise,
        rawInput: spokenInput,
        ttsResponse:
            'For $exStr: Keep your core braced, control the eccentric phase, and drive through the full range of motion.',
        action: 'explain_exercise',
      );
    }

    if (lower.contains('am i progressing') ||
        lower.contains('check my progress') ||
        lower.contains('how am i doing') ||
        lower.contains('progress report')) {
      return VoiceCommandResult(
        type: VoiceCommandType.checkProgress,
        rawInput: spokenInput,
        ttsResponse:
            'Your compound strength is up 8% this month, and you are on a 4-workout weekly streak. Keep pushing!',
        action: 'check_progress',
      );
    }

    return VoiceCommandResult(
      type: VoiceCommandType.unknown,
      rawInput: spokenInput,
      ttsResponse:
          'I didn\'t catch that command. You can say start workout, next exercise, start rest timer, or ask for weight guidance.',
    );
  }
}
