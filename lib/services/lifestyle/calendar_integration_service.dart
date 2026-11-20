/// Single athlete calendar event or commitment.
class CalendarEvent {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final bool isMandatory;

  const CalendarEvent({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.isMandatory = true,
  });

  Duration get duration => endTime.difference(startTime);

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'start_time': startTime.toIso8601String(),
    'end_time': endTime.toIso8601String(),
    'is_mandatory': isMandatory,
  };
}

/// Available workout window computed from calendar gaps.
class WorkoutTimeSlot {
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final String recommendedFormat; // 'full_75min', 'express_45min', 'split_two_a_day'

  const WorkoutTimeSlot({
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.recommendedFormat,
  });

  Map<String, dynamic> toJson() => {
    'start_time': startTime.toIso8601String(),
    'end_time': endTime.toIso8601String(),
    'duration_minutes': durationMinutes,
    'format': recommendedFormat,
  };
}

/// Calendar Integration & Schedule Conflict Resolver.
/// Mines calendar events, identifies free training gaps, and automatically adapts session density.
class CalendarIntegrationService {
  static CalendarIntegrationService? _instance;
  static CalendarIntegrationService get instance =>
      _instance ??= CalendarIntegrationService();

  static void resetInstance() {
    _instance = null;
  }

  /// Calculates available workout slots given daily calendar events.
  List<WorkoutTimeSlot> findAvailableTrainingWindows({
    required DateTime targetDay,
    required List<CalendarEvent> events,
    int preferredWorkoutDurationMinutes = 60,
  }) {
    final slots = <WorkoutTimeSlot>[];

    // Day boundaries: 06:00 to 22:00
    final dayStart = DateTime(targetDay.year, targetDay.month, targetDay.day, 6, 0);
    final dayEnd = DateTime(targetDay.year, targetDay.month, targetDay.day, 22, 0);

    final sortedEvents = List<CalendarEvent>.from(events)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    DateTime cursor = dayStart;

    for (final event in sortedEvents) {
      if (event.startTime.isAfter(cursor)) {
        final gapMinutes = event.startTime.difference(cursor).inMinutes;
        if (gapMinutes >= 40) {
          slots.add(WorkoutTimeSlot(
            startTime: cursor,
            endTime: event.startTime,
            durationMinutes: gapMinutes,
            recommendedFormat: gapMinutes >= 75
                ? 'full_75min'
                : gapMinutes >= 55
                    ? 'standard_60min'
                    : 'express_45min',
          ));
        }
      }
      if (event.endTime.isAfter(cursor)) {
        cursor = event.endTime;
      }
    }

    if (dayEnd.isAfter(cursor)) {
      final finalGap = dayEnd.difference(cursor).inMinutes;
      if (finalGap >= 40) {
        slots.add(WorkoutTimeSlot(
          startTime: cursor,
          endTime: dayEnd,
          durationMinutes: finalGap,
          recommendedFormat: finalGap >= 75 ? 'full_75min' : 'standard_60min',
        ));
      }
    }

    return slots;
  }
}
