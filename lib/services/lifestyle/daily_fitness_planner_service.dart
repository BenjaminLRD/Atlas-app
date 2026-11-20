import '../../../models/fitness_context.dart';
import 'calendar_integration_service.dart';

/// Categories of daily schedule blocks.
enum PlanItemType {
  workoutSession,
  mealWindow,
  proteinTrigger,
  hydrationCheck,
  recoveryProtocol,
  sleepPreparation,
}

/// Single time-blocked action item on the daily fitness itinerary.
class DailyPlanItem {
  final String time; // e.g. '07:30 AM', '05:30 PM'
  final String title;
  final String description;
  final PlanItemType type;
  bool isCompleted;

  DailyPlanItem({
    required this.time,
    required this.title,
    required this.description,
    required this.type,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
    'time': time,
    'title': title,
    'description': description,
    'type': type.name,
    'is_completed': isCompleted,
  };
}

/// Full 24-hour lifestyle and training plan for an athlete.
class DailySchedulePlan {
  final DateTime date;
  final String dayTheme; // 'Upper Hypertrophy Focus', 'Active Recovery & Carb Refeed'
  final int readinessScore;
  final List<DailyPlanItem> schedule;
  final String coachFocusNote;

  const DailySchedulePlan({
    required this.date,
    required this.dayTheme,
    required this.readinessScore,
    required this.schedule,
    required this.coachFocusNote,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'day_theme': dayTheme,
    'readiness_score': readinessScore,
    'schedule': schedule.map((i) => i.toJson()).toList(),
    'coach_note': coachFocusNote,
  };
}

/// Autonomous Daily Fitness Planner Service.
/// Synthesizes seamless 24-hour fitness schedules aligning workouts,
/// meal timing, protein pacing, and sleep hygiene with daily calendar reality.
class DailyFitnessPlannerService {
  static DailyFitnessPlannerService? _instance;
  static DailyFitnessPlannerService get instance =>
      _instance ??= DailyFitnessPlannerService();

  static void resetInstance() {
    _instance = null;
  }

  final CalendarIntegrationService _calendarService;

  DailyFitnessPlannerService({CalendarIntegrationService? calendarService})
      : _calendarService = calendarService ?? CalendarIntegrationService.instance;

  /// Generates a personalized daily schedule plan.
  DailySchedulePlan generateDailyPlan({
    required FitnessContext context,
    List<CalendarEvent> calendarEvents = const [],
    DateTime? targetDate,
  }) {
    final date = targetDate ?? DateTime.now();
    final readiness = context.recoveryState?.recoveryScore ?? 80;
    final isRestDay = readiness < 60 || (context.recoveryState?.isDeloadRecommended ?? false);

    // Find available training window
    final windows = _calendarService.findAvailableTrainingWindows(
      targetDay: date,
      events: calendarEvents,
    );

    final bestWindow = windows.isNotEmpty
        ? windows.firstWhere(
            (w) => w.durationMinutes >= 60,
            orElse: () => windows.first,
          )
        : null;

    final workoutTime = bestWindow != null
        ? '${bestWindow.startTime.hour.toString().padLeft(2, '0')}:${bestWindow.startTime.minute.toString().padLeft(2, '0')}'
        : '05:30 PM';

    final items = <DailyPlanItem>[
      DailyPlanItem(
        time: '07:30 AM',
        title: 'Morning Hydration & Leucine Kickoff',
        description: 'Drink 500ml water + 35g protein shake or egg-white breakfast.',
        type: PlanItemType.proteinTrigger,
      ),
      DailyPlanItem(
        time: '10:30 AM',
        title: 'Step Pacing & Hydration Check',
        description: 'Target 3,000 steps reached. Hydrate with electrolyte water.',
        type: PlanItemType.hydrationCheck,
      ),
      DailyPlanItem(
        time: '01:00 PM',
        title: 'High-Protein Lunch',
        description: 'Chicken breast / salmon, complex carbs (rice/sweet potato), and greens (~45g protein).',
        type: PlanItemType.mealWindow,
      ),
    ];

    if (isRestDay) {
      items.add(DailyPlanItem(
        time: '05:00 PM',
        title: 'Active Recovery & Tissue Mobility',
        description: '20 min foam rolling, hip flexor openers, and 30 min zone 1 walk.',
        type: PlanItemType.recoveryProtocol,
      ));
    } else {
      items.add(DailyPlanItem(
        time: workoutTime,
        title: 'Main Workout: Upper Body Hypertrophy',
        description: 'Progressive overload on Bench Press and Rows. Duration: ${bestWindow?.durationMinutes ?? 60} min.',
        type: PlanItemType.workoutSession,
      ));
      items.add(DailyPlanItem(
        time: '07:00 PM',
        title: 'Post-Workout Anabolic Window',
        description: '40g fast-acting protein + 60g carbohydrates for rapid glycogen repletion.',
        type: PlanItemType.mealWindow,
      ));
    }

    items.add(DailyPlanItem(
      time: '10:00 PM',
      title: 'Sleep Hygiene & Melatonin Prep',
      description: 'Dim screens, cool room to 19°C, 10 min deep parasympathetic breathwork.',
      type: PlanItemType.sleepPreparation,
    ));

    final theme = isRestDay
        ? 'Active Recovery & Parasympathetic Restoration'
        : 'High-Volume Upper Body Progression';

    final note = isRestDay
        ? 'Readiness is $readiness/100. Prioritize recovery and sleep hygiene.'
        : 'Optimal readiness ($readiness/100). Push for 1-2 extra reps on final working sets.';

    return DailySchedulePlan(
      date: date,
      dayTheme: theme,
      readinessScore: readiness,
      schedule: items,
      coachFocusNote: note,
    );
  }
}
