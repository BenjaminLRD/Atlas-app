import '../ai/prompt/adaptive_prompt_builder.dart';

/// Intent classifications for hands-free gym voice commands.
enum VoiceCommandIntent {
  startWorkout('start_workout'),
  nextExercise('next_exercise'),
  startTimer('start_timer'),
  pauseTimer('pause_timer'),
  logSet('log_set'),
  checkProgress('check_progress'),
  explainExercise('explain_exercise'),
  unknown('unknown');

  final String code;
  const VoiceCommandIntent(this.code);
}

/// Parsed voice command payload with extracted parameters.
class ParsedVoiceCommand {
  final String rawTranscript;
  final VoiceCommandIntent intent;
  final double? extractedWeightKg;
  final int? extractedReps;
  final int? extractedRestSeconds;
  final String? exerciseNameQuery;
  final double confidence; // 0.0 to 1.0

  const ParsedVoiceCommand({
    required this.rawTranscript,
    required this.intent,
    this.extractedWeightKg,
    this.extractedReps,
    this.extractedRestSeconds,
    this.exerciseNameQuery,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
    'raw_transcript': rawTranscript,
    'intent': intent.name,
    if (extractedWeightKg != null) 'extracted_weight_kg': extractedWeightKg,
    if (extractedReps != null) 'extracted_reps': extractedReps,
    if (extractedRestSeconds != null) 'extracted_rest_sec': extractedRestSeconds,
    if (exerciseNameQuery != null) 'exercise_query': exerciseNameQuery,
    'confidence': confidence,
  };
}

/// Natural Language Voice Coach Service.
/// Enables hands-free workout logging, exercise explanations,
/// timer controls, and spoken audio feedback during active training.
class VoiceCoachService {
  static VoiceCoachService? _instance;
  static VoiceCoachService get instance => _instance ??= VoiceCoachService();

  static void resetInstance() {
    _instance = null;
  }

  final List<ParsedVoiceCommand> _commandHistory = [];

  List<ParsedVoiceCommand> get commandHistory => List.unmodifiable(_commandHistory);

  /// Parses natural spoken transcripts into structured gym commands.
  ParsedVoiceCommand parseVoiceCommand(String transcript) {
    final clean = transcript.toLowerCase().trim();

    // 1. Log Set (e.g. "log set 100 kg for 8 reps", "logged 8 reps at 80kg", "got 10 reps")
    final setWeightMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:kg|kilos|lbs)?\s*(?:for|x|at)\s*(\d+)\s*reps?').firstMatch(clean);
    final repsWeightMatch = RegExp(r'(\d+)\s*reps?\s*(?:at|with|for)?\s*(\d+(?:\.\d+)?)\s*(?:kg|kilos|lbs)?').firstMatch(clean);
    final onlyRepsMatch = RegExp(r'(?:log|got|completed|did)\s*(\d+)\s*reps?').firstMatch(clean);

    if (setWeightMatch != null) {
      final weight = double.tryParse(setWeightMatch.group(1) ?? '');
      final reps = int.tryParse(setWeightMatch.group(2) ?? '');
      return _recordCommand(ParsedVoiceCommand(
        rawTranscript: transcript,
        intent: VoiceCommandIntent.logSet,
        extractedWeightKg: weight,
        extractedReps: reps,
        confidence: 0.95,
      ));
    } else if (repsWeightMatch != null) {
      final reps = int.tryParse(repsWeightMatch.group(1) ?? '');
      final weight = double.tryParse(repsWeightMatch.group(2) ?? '');
      return _recordCommand(ParsedVoiceCommand(
        rawTranscript: transcript,
        intent: VoiceCommandIntent.logSet,
        extractedWeightKg: weight,
        extractedReps: reps,
        confidence: 0.95,
      ));
    } else if (onlyRepsMatch != null) {
      final reps = int.tryParse(onlyRepsMatch.group(1) ?? '');
      return _recordCommand(ParsedVoiceCommand(
        rawTranscript: transcript,
        intent: VoiceCommandIntent.logSet,
        extractedReps: reps,
        confidence: 0.90,
      ));
    }

    // 2. Start / Pause Timer (e.g. "start timer 90 seconds", "start rest timer", "pause timer")
    if (clean.contains('pause timer') || clean.contains('stop timer') || clean.contains('cancel rest')) {
      return _recordCommand(ParsedVoiceCommand(
        rawTranscript: transcript,
        intent: VoiceCommandIntent.pauseTimer,
        confidence: 0.95,
      ));
    }

    if (clean.contains('start timer') || clean.contains('start rest') || clean.contains('rest timer')) {
      final secMatch = RegExp(r'(\d+)\s*(?:sec|second|seconds|min|minute|minutes)?').firstMatch(clean);
      int? seconds;
      if (secMatch != null) {
        final val = int.tryParse(secMatch.group(1) ?? '');
        if (clean.contains('min')) {
          seconds = val != null ? val * 60 : null;
        } else {
          seconds = val;
        }
      }
      return _recordCommand(ParsedVoiceCommand(
        rawTranscript: transcript,
        intent: VoiceCommandIntent.startTimer,
        extractedRestSeconds: seconds ?? 90,
        confidence: 0.92,
      ));
    }

    // 3. Start Workout
    if (clean.contains('start workout') || clean.contains('begin workout') || clean.contains('let\'s go') || clean.contains('begin session')) {
      return _recordCommand(ParsedVoiceCommand(
        rawTranscript: transcript,
        intent: VoiceCommandIntent.startWorkout,
        confidence: 0.96,
      ));
    }

    // 4. Next Exercise
    if (clean.contains('next exercise') || clean.contains('next movement') || clean.contains('skip exercise') || clean.contains('move on')) {
      return _recordCommand(ParsedVoiceCommand(
        rawTranscript: transcript,
        intent: VoiceCommandIntent.nextExercise,
        confidence: 0.95,
      ));
    }

    // 5. Check Progress
    if (clean.contains('check progress') || clean.contains('how am i doing') || clean.contains('total volume') || clean.contains('streak status')) {
      return _recordCommand(ParsedVoiceCommand(
        rawTranscript: transcript,
        intent: VoiceCommandIntent.checkProgress,
        confidence: 0.90,
      ));
    }

    // 6. Explain Exercise (e.g. "explain romanian deadlift", "how do I squat")
    if (clean.contains('explain') || clean.contains('how do i do') || clean.contains('form cues for')) {
      final query = clean.replaceAll(RegExp(r'explain|how do i do|form cues for|exercise'), '').trim();
      return _recordCommand(ParsedVoiceCommand(
        rawTranscript: transcript,
        intent: VoiceCommandIntent.explainExercise,
        exerciseNameQuery: query.isNotEmpty ? query : null,
        confidence: 0.88,
      ));
    }

    return _recordCommand(ParsedVoiceCommand(
      rawTranscript: transcript,
      intent: VoiceCommandIntent.unknown,
      confidence: 0.40,
    ));
  }

  /// Synthesizes spoken coaching feedback tailored to persona tone.
  String synthesizeSpeechFeedback({
    required String message,
    CoachStyle style = CoachStyle.supportive,
  }) {
    switch (style) {
      case CoachStyle.direct:
        return 'Atlas: $message Keep moving.';
      case CoachStyle.technical:
        return 'Atlas Analysis: $message';
      case CoachStyle.concise:
        return message;
      case CoachStyle.supportive:
        return 'Great work! $message';
    }
  }

  ParsedVoiceCommand _recordCommand(ParsedVoiceCommand command) {
    _commandHistory.add(command);
    if (_commandHistory.length > 50) {
      _commandHistory.removeAt(0);
    }
    return command;
  }
}
