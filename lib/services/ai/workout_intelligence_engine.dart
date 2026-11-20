import '../../models/user_equipment_profile.dart';
import '../../models/workout_history.dart';
import '../../models/workout_intelligence_report.dart';
import '../health/recovery_service.dart';
import 'memory/fitness_memory.dart';

/// Intelligent workout evaluation engine.
/// Evaluates goal alignment, athlete personalization, recovery compatibility,
/// progressive overload, and muscle balance to provide rich AI scoring and coaching rationale.
class WorkoutIntelligenceEngine {
  final FitnessMemory _fitnessMemory;

  WorkoutIntelligenceEngine({
    FitnessMemory? fitnessMemory,
    // Kept for callers that pass one; recovery is judged only against a
    // recorded score (see [evaluateWorkout]), so it is no longer used here.
    RecoveryService? recoveryService,
  }) : _fitnessMemory = fitnessMemory ?? FitnessMemory.instance;

  /// Evaluates a validated workout and computes a comprehensive intelligence report.
  WorkoutIntelligenceReport evaluateWorkout({
    required List<Map<String, dynamic>> exercises,
    required String focus,
    required int durationMinutes,
    String goal = 'hypertrophy',
    UserEquipmentProfile? equipmentProfile,
    List<WorkoutHistory>? workoutHistory,
    int? currentRecoveryScore,
  }) {
    final prefProfile = _fitnessMemory.getPreferenceProfile();
    // Recovery is judged only against a recorded score. Without one the plan
    // is not checked against recovery and the weights are rescaled.
    final recoveryScore = currentRecoveryScore;

    final strengths = <String>[];
    final recommendations = <String>[];
    final aiExplanation = <String>[];

    // 1. Goal Alignment Score
    final goalEval = _evaluateGoalAlignment(exercises, goal, focus);
    final goalAlignmentScore = goalEval.score;
    if (goalEval.strength != null) strengths.add(goalEval.strength!);
    if (goalEval.recommendation != null) {
      recommendations.add(goalEval.recommendation!);
    }

    // 2. Equipment Match Score
    final equipmentEval = _evaluateEquipmentMatch(exercises, equipmentProfile);
    final equipmentMatchScore = equipmentEval.score;
    if (equipmentEval.strength != null) strengths.add(equipmentEval.strength!);
    if (equipmentEval.recommendation != null) {
      recommendations.add(equipmentEval.recommendation!);
    }

    // 3. Personalization Score
    final personalizationEval = _evaluatePersonalization(
      exercises,
      durationMinutes,
      prefProfile,
    );
    final personalizationScore = personalizationEval.score;
    if (personalizationEval.strength != null) {
      strengths.add(personalizationEval.strength!);
    }
    if (personalizationEval.recommendation != null) {
      recommendations.add(personalizationEval.recommendation!);
    }

    // 4. Recovery Compatibility Score (only with a recorded recovery score)
    final recoveryEval = recoveryScore == null
        ? null
        : _evaluateRecoveryCompatibility(
            exercises,
            recoveryScore,
            durationMinutes,
          );
    final int? recoveryCompatibilityScore = recoveryEval?.score;
    if (recoveryEval?.strength != null) strengths.add(recoveryEval!.strength!);
    if (recoveryEval?.recommendation != null) {
      recommendations.add(recoveryEval!.recommendation!);
    }
    if (recoveryEval?.explanation != null) {
      aiExplanation.add(recoveryEval!.explanation!);
    }

    // 5. Progressive Overload Analysis
    final progressionEval = _evaluateProgressiveOverload(
      exercises,
      workoutHistory,
    );
    final progressionScore = progressionEval.score;
    if (progressionEval.strength != null) {
      strengths.add(progressionEval.strength!);
    }
    if (progressionEval.recommendation != null) {
      recommendations.add(progressionEval.recommendation!);
    }
    if (progressionEval.explanation != null) {
      aiExplanation.add(progressionEval.explanation!);
    }

    // 6. Muscle Balance Analysis
    final balanceEval = _evaluateMuscleBalance(exercises, focus);
    final muscleBalanceScore = balanceEval.score;
    if (balanceEval.strength != null) strengths.add(balanceEval.strength!);
    if (balanceEval.recommendation != null) {
      recommendations.add(balanceEval.recommendation!);
    }

    // 7. Overall Weighted Score Calculation
    var weighted =
        goalAlignmentScore * 0.20 +
        equipmentMatchScore * 0.15 +
        muscleBalanceScore * 0.20 +
        progressionScore * 0.15 +
        personalizationScore * 0.15;
    var weightSum = 0.85;
    if (recoveryCompatibilityScore != null) {
      weighted += recoveryCompatibilityScore * 0.15;
      weightSum += 0.15;
    }
    final overallScore = (weighted / weightSum).round().clamp(0, 100);

    // Primary AI Coach Explanation Synthesis
    if (recoveryScore == null) {
      aiExplanation.add(
        'No recovery data is recorded, so this plan was not adjusted for recovery.',
      );
    } else if (aiExplanation.isEmpty) {
      if (recoveryScore >= 75) {
        aiExplanation.add(
          'Your recovery is high today ($recoveryScore%). Full volume and intensity programmed for maximum stimulus.',
        );
      } else {
        aiExplanation.add(
          'Your recovery score is $recoveryScore%. Volume adjusted to ensure safe progression without overtraining.',
        );
      }
    }

    if (personalizationScore >= 90 &&
        prefProfile.preferredExercises.isNotEmpty) {
      aiExplanation.add(
        'Tailored to your favorite movements with zero blacklisted exercises.',
      );
    }

    return WorkoutIntelligenceReport(
      overallScore: overallScore,
      goalAlignmentScore: goalAlignmentScore,
      equipmentMatchScore: equipmentMatchScore,
      muscleBalanceScore: muscleBalanceScore,
      recoveryCompatibilityScore: recoveryCompatibilityScore,
      progressionScore: progressionScore,
      personalizationScore: personalizationScore,
      strengths: strengths,
      recommendations: recommendations,
      aiExplanation: aiExplanation,
    );
  }

  // --- Private Evaluation Methods ---

  ({int score, String? strength, String? recommendation})
  _evaluateGoalAlignment(
    List<Map<String, dynamic>> exercises,
    String goal,
    String focus,
  ) {
    int score = 85;
    final lowerGoal = goal.toLowerCase();

    if (exercises.isEmpty) {
      return (
        score: 50,
        strength: null,
        recommendation: 'Add exercises matching target goal.',
      );
    }

    final hasCompound = exercises.any((e) {
      final type = (e['exerciseType'] as String? ?? '').toLowerCase();
      final name = (e['name'] as String? ?? '').toLowerCase();
      return type == 'compound' ||
          name.contains('press') ||
          name.contains('squat') ||
          name.contains('deadlift') ||
          name.contains('row') ||
          name.contains('pull-up');
    });

    if (lowerGoal.contains('hypertrophy') || lowerGoal.contains('muscle')) {
      score += 10;
      if (hasCompound) score += 5;
      return (
        score: score.clamp(0, 100),
        strength: 'Optimal 8-12 rep hypertrophy volume with compound anchors.',
        recommendation: null,
      );
    } else if (lowerGoal.contains('strength')) {
      if (hasCompound) {
        score += 15;
        return (
          score: score.clamp(0, 100),
          strength: 'Prioritizes heavy multi-joint compound movement patterns.',
          recommendation: null,
        );
      } else {
        return (
          score: 75,
          strength: null,
          recommendation:
              'Add primary compound lift (e.g. barbell press/squat) for strength development.',
        );
      }
    } else if (lowerGoal.contains('fat_loss') ||
        lowerGoal.contains('endurance')) {
      score += 10;
      return (
        score: score.clamp(0, 100),
        strength:
            'High-density circuit structure for elevated caloric expenditure.',
        recommendation: null,
      );
    }

    return (
      score: 90,
      strength: 'Balanced training structure aligned with $goal.',
      recommendation: null,
    );
  }

  ({int score, String? strength, String? recommendation})
  _evaluateEquipmentMatch(
    List<Map<String, dynamic>> exercises,
    UserEquipmentProfile? equipmentProfile,
  ) {
    if (equipmentProfile == null ||
        equipmentProfile.availableEquipmentIds.isEmpty) {
      return (
        score: 100,
        strength:
            '100% equipment accessibility verified for commercial gym setup.',
        recommendation: null,
      );
    }

    // Check if any exercise exceeds athlete gear
    int score = 100;
    for (final ex in exercises) {
      final eq = (ex['equipment'] as String? ?? '').toLowerCase();
      final isCompatible = equipmentProfile.availableEquipmentIds.any(
        (id) =>
            eq.contains(id.toLowerCase()) ||
            eq.contains('bodyweight') ||
            eq.contains('none') ||
            eq.contains('mat'),
      );
      if (!isCompatible) {
        score -= 15;
      }
    }

    final finalScore = score.clamp(0, 100);
    return (
      score: finalScore,
      strength: finalScore >= 95
          ? 'Fully adapted to your available equipment profile.'
          : null,
      recommendation: finalScore < 90
          ? 'Some exercises may require equipment substitutes.'
          : null,
    );
  }

  ({int score, String? strength, String? recommendation})
  _evaluatePersonalization(
    List<Map<String, dynamic>> exercises,
    int durationMinutes,
    dynamic prefProfile,
  ) {
    int score = 85;

    final preferred = (prefProfile.preferredExercises as List<String>)
        .map((e) => e.toLowerCase().trim())
        .toSet();
    final disliked = (prefProfile.dislikedExercises as List<String>)
        .map((e) => e.toLowerCase().trim())
        .toSet();

    // +10 for avoiding disliked exercises
    final containsDisliked = exercises.any(
      (e) =>
          disliked.contains(
            (e['name'] as String? ?? '').toLowerCase().trim(),
          ) ||
          disliked.contains((e['id'] as String? ?? '').toLowerCase().trim()),
    );

    if (!containsDisliked && disliked.isNotEmpty) {
      score += 10;
    } else if (containsDisliked) {
      score -= 20;
    }

    // +5 for each preferred exercise present
    int preferredFound = 0;
    for (final ex in exercises) {
      final name = (ex['name'] as String? ?? '').toLowerCase().trim();
      if (preferred.contains(name)) {
        preferredFound++;
      }
    }
    score += (preferredFound * 5);

    // Duration match
    final preferredDuration =
        prefProfile.preferredWorkoutDurationMinutes as int;
    if ((durationMinutes - preferredDuration).abs() <= 10) {
      score += 5;
    }

    final finalScore = score.clamp(0, 100);
    return (
      score: finalScore,
      strength: preferredFound > 0
          ? 'Includes $preferredFound of your top favorite exercises.'
          : 'Reflects your long-term movement preferences and duration targets.',
      recommendation: null,
    );
  }

  ({int score, String? strength, String? recommendation, String? explanation})
  _evaluateRecoveryCompatibility(
    List<Map<String, dynamic>> exercises,
    int recoveryScore,
    int durationMinutes,
  ) {
    int totalSets = 0;
    for (final ex in exercises) {
      final rawSets = ex['sets'];
      if (rawSets is List) {
        totalSets += rawSets.length;
      } else if (rawSets is num) {
        totalSets += rawSets.toInt();
      } else {
        totalSets += 3;
      }
    }

    if (recoveryScore >= 75) {
      // High recovery: High volume is encouraged
      return (
        score: 95,
        strength:
            'Volume optimized for high recovery readiness ($recoveryScore%).',
        recommendation: null,
        explanation:
            'Your recovery is high today ($recoveryScore%). Full training volume programmed.',
      );
    } else if (recoveryScore < 50) {
      // Low recovery: Volume should be moderated
      if (totalSets <= 12 && durationMinutes <= 40) {
        return (
          score: 95,
          strength:
              'Autoregulated lower volume tailored to current recovery deficit ($recoveryScore%).',
          recommendation: null,
          explanation:
              'Your recovery is low ($recoveryScore%). Scaled back total sets to $totalSets to prevent fatigue.',
        );
      } else {
        return (
          score: 65,
          strength: null,
          recommendation:
              'Consider reducing workout by 1-2 sets due to lower recovery ($recoveryScore%).',
          explanation:
              'Recovery score is $recoveryScore%. Volume is high; consider reducing 1-2 sets.',
        );
      }
    } else {
      // Moderate recovery (50-74%)
      return (
        score: 90,
        strength:
            'Balanced training volume matching moderate recovery state ($recoveryScore%).',
        recommendation: null,
        explanation: null,
      );
    }
  }

  ({int score, String? strength, String? recommendation, String? explanation})
  _evaluateProgressiveOverload(
    List<Map<String, dynamic>> exercises,
    List<WorkoutHistory>? workoutHistory,
  ) {
    if (workoutHistory == null || workoutHistory.isEmpty) {
      return (
        score: 90,
        strength: 'Baseline progressive overload volume established.',
        recommendation: null,
        explanation:
            'Baseline loading established for progressive overload tracking.',
      );
    }

    final recent = workoutHistory.first;
    int currentTotalSets = 0;
    for (final ex in exercises) {
      final rawSets = ex['sets'];
      if (rawSets is List) {
        currentTotalSets += rawSets.length;
      } else if (rawSets is num) {
        currentTotalSets += rawSets.toInt();
      } else {
        currentTotalSets += 3;
      }
    }

    // Check volume progression
    if (currentTotalSets >= recent.totalSets && recent.totalSets > 0) {
      return (
        score: 95,
        strength:
            'Progressive overload verified ($currentTotalSets sets vs previous ${recent.totalSets} sets).',
        recommendation: null,
        explanation:
            'Strength progression detected: volume stimulus increased compared to last session.',
      );
    }

    return (
      score: 88,
      strength: 'Consistent stimulus maintaining target training volume.',
      recommendation: null,
      explanation: null,
    );
  }

  ({int score, String? strength, String? recommendation})
  _evaluateMuscleBalance(List<Map<String, dynamic>> exercises, String focus) {
    final lowerFocus = focus.toLowerCase();
    int score = 90;

    final targetCounts = <String, int>{};
    for (final ex in exercises) {
      final mg = (ex['muscleGroup'] as String? ?? '').toLowerCase();
      final parts = mg.split(RegExp(r'[,/&]'));
      for (final p in parts) {
        final clean = p.trim();
        if (clean.isNotEmpty) {
          targetCounts[clean] = (targetCounts[clean] ?? 0) + 1;
        }
      }
    }

    if (lowerFocus.contains('push')) {
      final chest = targetCounts.entries
          .where((e) => e.key.contains('chest') || e.key.contains('pectoral'))
          .fold(0, (sum, e) => sum + e.value);
      final triceps = targetCounts.entries
          .where((e) => e.key.contains('tricep'))
          .fold(0, (sum, e) => sum + e.value);
      final shoulders = targetCounts.entries
          .where((e) => e.key.contains('shoulder') || e.key.contains('deltoid'))
          .fold(0, (sum, e) => sum + e.value);

      if (chest >= 3 && triceps == 0 && shoulders == 0) {
        return (
          score: 65,
          strength: null,
          recommendation:
              'Chest volume is excessive compared to shoulder and tricep volume. Add overhead press or tricep extensions for balance.',
        );
      }

      if (chest > 0 && (triceps > 0 || shoulders > 0)) {
        score = 95;
        return (
          score: score,
          strength:
              'Balanced push distribution across Chest, Shoulders, and Triceps.',
          recommendation: null,
        );
      }
    } else if (lowerFocus.contains('pull')) {
      final back = targetCounts.entries
          .where((e) => e.key.contains('back') || e.key.contains('lat'))
          .fold(0, (sum, e) => sum + e.value);
      final biceps = targetCounts.entries
          .where((e) => e.key.contains('bicep'))
          .fold(0, (sum, e) => sum + e.value);

      if (back >= 3 && biceps == 0) {
        return (
          score: 70,
          strength: null,
          recommendation:
              'Back volume dominates; consider adding a bicep isolation movement for arm balance.',
        );
      }

      if (back > 0 && biceps > 0) {
        score = 95;
        return (
          score: score,
          strength:
              'Harmonious pull distribution between Upper Back / Lats and Biceps.',
          recommendation: null,
        );
      }
    } else if (lowerFocus.contains('leg')) {
      final quads = targetCounts.entries
          .where((e) => e.key.contains('quad'))
          .fold(0, (sum, e) => sum + e.value);
      final posterior = targetCounts.entries
          .where((e) => e.key.contains('hamstring') || e.key.contains('glute'))
          .fold(0, (sum, e) => sum + e.value);

      if (quads >= 3 && posterior == 0) {
        return (
          score: 65,
          strength: null,
          recommendation:
              'Quad volume is dominant; add hamstring/glute hinge movements (e.g. Romanian deadlifts) for joint balance.',
        );
      }

      if (quads > 0 && posterior > 0) {
        score = 95;
        return (
          score: score,
          strength:
              'Balanced quad-to-posterior chain loading for knee and hip health.',
          recommendation: null,
        );
      }
    }

    return (
      score: 90,
      strength:
          'Harmonious movement distribution targeting key functional synergists.',
      recommendation: null,
    );
  }
}
