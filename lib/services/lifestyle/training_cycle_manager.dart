/// Periodization mesocycle phases.
enum MesocyclePhase {
  hypertrophyAccumulation('Hypertrophy (Volume Accumulation)'),
  strengthIntensification('Strength (Intensity & Neural Drive)'),
  peakingRealization('Peaking (1RM Realization)'),
  activeDeloadRecovery('Deload (Systemic Resensitization)'),
  fatLossCut('Metabolic Cut (Volume Maintenance)');

  final String label;
  const MesocyclePhase(this.label);
}

/// Single week programming blueprint within a mesocycle.
class TrainingBlockWeek {
  final int weekNumber;
  final MesocyclePhase phase;
  final int targetVolumeSetsPerMuscle;
  final double targetRPE;
  final int targetRIR; // Reps In Reserve
  final bool isDeload;

  const TrainingBlockWeek({
    required this.weekNumber,
    required this.phase,
    required this.targetVolumeSetsPerMuscle,
    required this.targetRPE,
    required this.targetRIR,
    required this.isDeload,
  });

  Map<String, dynamic> toJson() => {
    'week': weekNumber,
    'phase': phase.name,
    'volume_sets': targetVolumeSetsPerMuscle,
    'target_rpe': targetRPE,
    'target_rir': targetRIR,
    'is_deload': isDeload,
  };
}

/// Multi-week periodized training mesocycle.
class TrainingMesocycle {
  final String id;
  final String title;
  final MesocyclePhase primaryPhase;
  final int totalWeeks;
  final int currentWeek;
  final List<TrainingBlockWeek> weeks;
  final String programmingGoal;

  const TrainingMesocycle({
    required this.id,
    required this.title,
    required this.primaryPhase,
    required this.totalWeeks,
    required this.currentWeek,
    required this.weeks,
    required this.programmingGoal,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'phase': primaryPhase.name,
    'total_weeks': totalWeeks,
    'current_week': currentWeek,
    'weeks': weeks.map((w) => w.toJson()).toList(),
    'goal': programmingGoal,
  };
}

/// Long-Term Periodization & Training Cycle Manager.
/// Programs structured multi-week progressive overload blocks with systematic step loading and deloads.
class TrainingCycleManager {
  static TrainingCycleManager? _instance;
  static TrainingCycleManager get instance =>
      _instance ??= TrainingCycleManager();

  static void resetInstance() {
    _instance = null;
  }

  /// Generates a complete 4-week hypertrophy accumulation mesocycle.
  TrainingMesocycle generateHypertrophyMesocycle({
    String title = 'Hypertrophy Accumulation Block',
    int baseVolumeSets = 12,
  }) {
    final weeks = [
      TrainingBlockWeek(
        weekNumber: 1,
        phase: MesocyclePhase.hypertrophyAccumulation,
        targetVolumeSetsPerMuscle: baseVolumeSets,
        targetRPE: 7.5,
        targetRIR: 3,
        isDeload: false,
      ),
      TrainingBlockWeek(
        weekNumber: 2,
        phase: MesocyclePhase.hypertrophyAccumulation,
        targetVolumeSetsPerMuscle: baseVolumeSets + 2,
        targetRPE: 8.0,
        targetRIR: 2,
        isDeload: false,
      ),
      TrainingBlockWeek(
        weekNumber: 3,
        phase: MesocyclePhase.hypertrophyAccumulation,
        targetVolumeSetsPerMuscle: baseVolumeSets + 4,
        targetRPE: 9.0,
        targetRIR: 1,
        isDeload: false,
      ),
      TrainingBlockWeek(
        weekNumber: 4,
        phase: MesocyclePhase.activeDeloadRecovery,
        targetVolumeSetsPerMuscle: (baseVolumeSets * 0.5).round(),
        targetRPE: 6.5,
        targetRIR: 4,
        isDeload: true,
      ),
    ];

    return TrainingMesocycle(
      id: 'meso_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      primaryPhase: MesocyclePhase.hypertrophyAccumulation,
      totalWeeks: 4,
      currentWeek: 1,
      weeks: weeks,
      programmingGoal: 'Progressively step volume from 12 to 16 sets before a 50% resensitization deload.',
    );
  }
}
