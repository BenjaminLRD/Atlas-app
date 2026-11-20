import 'form_feedback.dart';

/// Consolidated result of a complete exercise movement analysis.
class ExerciseAnalysis {
  final String exerciseName;
  final FormFeedback feedback;
  final int repCount;
  final List<String> detectedMistakes;
  final List<String> corrections;
  final Map<String, double> jointAngles;
  final Map<String, dynamic> metrics;
  final DateTime timestamp;

  ExerciseAnalysis({
    required this.exerciseName,
    required this.feedback,
    required this.repCount,
    required this.detectedMistakes,
    required this.corrections,
    this.jointAngles = const {},
    this.metrics = const {},
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  int get formScore => feedback.score;
  bool get isGoodForm => feedback.isGoodForm;
  double get confidence => feedback.confidence;
  int get confidencePercentage => feedback.confidencePercentage;

  factory ExerciseAnalysis.fromJson(Map<String, dynamic> json) {
    return ExerciseAnalysis(
      exerciseName: json['exerciseName'] as String? ?? 'Exercise',
      feedback: json['feedback'] != null
          ? FormFeedback.fromJson(json['feedback'] as Map<String, dynamic>)
          : FormFeedback(
              score: (json['formScore'] as num? ?? 100).toInt(),
              warnings: (json['warnings'] as List? ?? [])
                  .map((e) => e.toString())
                  .toList(),
              corrections: (json['corrections'] as List? ?? [])
                  .map((e) => e.toString())
                  .toList(),
            ),
      repCount: (json['repCount'] as num? ?? 0).toInt(),
      detectedMistakes:
          (json['detectedMistakes'] as List? ?? json['warnings'] as List? ?? [])
              .map((e) => e.toString())
              .toList(),
      corrections: (json['corrections'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      jointAngles: (json['jointAngles'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
      metrics: json['metrics'] as Map<String, dynamic>? ?? {},
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'exerciseName': exerciseName,
    'feedback': feedback.toJson(),
    'repCount': repCount,
    'detectedMistakes': detectedMistakes,
    'corrections': corrections,
    'jointAngles': jointAngles,
    'metrics': metrics,
    'timestamp': timestamp.toIso8601String(),
  };
}
