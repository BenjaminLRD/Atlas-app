import '../../../models/exercise.dart';
import 'training_adjustment.dart';
import 'workout_performance_analyzer.dart';

/// Summary report detailing all adaptive changes applied to an upcoming workout.
class AdaptiveTrainingSummary {
  final List<TrainingAdjustment> adjustmentsApplied;
  final String coachExplanation;
  final bool hasAdaptations;

  const AdaptiveTrainingSummary({
    required this.adjustmentsApplied,
    required this.coachExplanation,
    required this.hasAdaptations,
  });

  Map<String, dynamic> toJson() => {
    'hasAdaptations': hasAdaptations,
    'adjustmentsCount': adjustmentsApplied.length,
    'adjustments': adjustmentsApplied.map((a) => a.toJson()).toList(),
    'coachExplanation': coachExplanation,
  };

  factory AdaptiveTrainingSummary.fromJson(Map<String, dynamic> json) {
    final rawAdj = json['adjustments'] as List? ?? const [];
    final list = rawAdj
        .map(
          (a) =>
              TrainingAdjustment.fromJson(Map<String, dynamic>.from(a as Map)),
        )
        .toList();

    return AdaptiveTrainingSummary(
      hasAdaptations: json['hasAdaptations'] as bool? ?? false,
      adjustmentsApplied: list,
      coachExplanation:
          json['coachExplanation'] as String? ??
          'Standard progressive training active.',
    );
  }
}

/// Central Adaptation Engine that coordinates performance analysis and automatically
/// modifies exercise selection, sets, reps, weights, and rest periods for upcoming sessions.
class AdaptationEngine {
  final WorkoutPerformanceAnalyzer _analyzer;

  AdaptationEngine({WorkoutPerformanceAnalyzer? analyzer})
    : _analyzer = analyzer ?? WorkoutPerformanceAnalyzer();

  /// Analyzes past session telemetry and produces applicable training adjustments.
  Future<List<TrainingAdjustment>> analyzeSession(
    WorkoutPerformanceData performance,
  ) async {
    return _analyzer.analyzeSession(performance);
  }

  /// Evaluates multi-session history for plateaus.
  List<TrainingAdjustment> detectPlateaus(
    List<WorkoutPerformanceData> history,
  ) {
    return _analyzer.detectPlateaus(history);
  }

  /// Applies active training adjustments to a base generated workout routine.
  ({
    List<Map<String, dynamic>> adaptedExercises,
    AdaptiveTrainingSummary summary,
  })
  applyAdaptations({
    required List<Map<String, dynamic>> baseExercises,
    required List<TrainingAdjustment> adjustments,
  }) {
    if (adjustments.isEmpty) {
      return (
        adaptedExercises: baseExercises,
        summary: const AdaptiveTrainingSummary(
          adjustmentsApplied: [],
          coachExplanation:
              'Workout is optimized for steady progressive overload.',
          hasAdaptations: false,
        ),
      );
    }

    final modifiedList = <Map<String, dynamic>>[];
    final applied = <TrainingAdjustment>[];
    final explanationNotes = <String>[];

    final adjMap = <String, TrainingAdjustment>{};
    for (final adj in adjustments) {
      adjMap[adj.affectedExercise.toLowerCase().trim()] = adj;
    }

    for (final rawEx in baseExercises) {
      final name = (rawEx['name'] as String? ?? '').trim();
      final adj = adjMap[name.toLowerCase()];

      if (adj == null) {
        modifiedList.add(Map<String, dynamic>.from(rawEx));
        continue;
      }

      applied.add(adj);
      final exCopy = Map<String, dynamic>.from(rawEx);

      switch (adj.adjustmentType) {
        case AdjustmentType.increaseWeight:
          final currentWeight =
              (exCopy['defaultWeight'] as num?)?.toDouble() ??
              (exCopy['weight'] as num?)?.toDouble() ??
              40.0;
          final newWeight = (currentWeight * adj.weightMultiplier);
          final roundedWeight =
              (newWeight * 2).round() / 2; // Round to nearest 0.5kg
          exCopy['weight'] = roundedWeight;
          exCopy['defaultWeight'] = roundedWeight;
          explanationNotes.add(
            'Increased $name load to ${roundedWeight}kg (${adj.reason})',
          );
          break;

        case AdjustmentType.decreaseWeight:
          final currentWeight =
              (exCopy['defaultWeight'] as num?)?.toDouble() ??
              (exCopy['weight'] as num?)?.toDouble() ??
              40.0;
          final newWeight = (currentWeight * adj.weightMultiplier);
          final roundedWeight = (newWeight * 2).round() / 2;
          exCopy['weight'] = roundedWeight;
          exCopy['defaultWeight'] = roundedWeight;
          explanationNotes.add(
            'Scaled back $name to ${roundedWeight}kg (${adj.reason})',
          );
          break;

        case AdjustmentType.increaseVolume:
          final currentSets = (exCopy['sets'] is num)
              ? (exCopy['sets'] as num).toInt()
              : ((exCopy['sets'] as List?)?.length ?? 3);
          final newSets = (currentSets + adj.setsDelta).clamp(1, 6);
          exCopy['sets'] = newSets;
          explanationNotes.add(
            'Added extra working set on $name (${adj.reason})',
          );
          break;

        case AdjustmentType.decreaseVolume:
          final currentSets = (exCopy['sets'] is num)
              ? (exCopy['sets'] as num).toInt()
              : ((exCopy['sets'] as List?)?.length ?? 3);
          final newSets = (currentSets + adj.setsDelta).clamp(1, 6);
          exCopy['sets'] = newSets;
          explanationNotes.add(
            'Reduced volume on $name to $newSets sets (${adj.reason})',
          );
          break;

        case AdjustmentType.exerciseSwap:
        case AdjustmentType.plateauBreak:
          if (adj.suggestedReplacement != null &&
              adj.suggestedReplacement!.isNotEmpty) {
            final replacementObj =
                Exercise.findByName(adj.suggestedReplacement!) ??
                Exercise.getById(adj.suggestedReplacement!);
            if (replacementObj != null) {
              exCopy['id'] = replacementObj.id;
              exCopy['name'] = replacementObj.name;
              exCopy['muscleGroup'] = replacementObj.muscleGroup;
              exCopy['equipment'] = replacementObj.equipment;
              exCopy['instructions'] = replacementObj.instructions;
              exCopy['coachingTips'] = replacementObj.coachingTips;
              explanationNotes.add(
                'Substituted $name with ${replacementObj.name} (${adj.reason})',
              );
            }
          }
          break;

        case AdjustmentType.deload:
          final currentWeight =
              (exCopy['defaultWeight'] as num?)?.toDouble() ?? 40.0;
          exCopy['weight'] = (currentWeight * 0.6).roundToDouble();
          exCopy['defaultWeight'] = (currentWeight * 0.6).roundToDouble();
          exCopy['sets'] = 2;
          explanationNotes.add('Deload intensity applied to $name.');
          break;

        case AdjustmentType.maintain:
          break;
      }

      modifiedList.add(exCopy);
    }

    final summaryText = explanationNotes.isNotEmpty
        ? 'Your workout was adapted: ${explanationNotes.join("; ")}.'
        : 'Your workout was adapted to match your latest training adaptations.';

    return (
      adaptedExercises: modifiedList,
      summary: AdaptiveTrainingSummary(
        adjustmentsApplied: applied,
        coachExplanation: summaryText,
        hasAdaptations: applied.isNotEmpty,
      ),
    );
  }
}
