import '../../../models/fitness_context.dart';

/// Contextual check-in checkpoints throughout the day.
enum CompanionCheckInType {
  morningBriefing,
  preWorkoutMotivation,
  postWorkoutRefuel,
  eveningWindDown,
}

/// Conversational companion message synthesized for the athlete.
class CompanionDialogue {
  final CompanionCheckInType type;
  final String greeting;
  final String messageBody;
  final String callToAction;
  final DateTime timestamp;

  const CompanionDialogue({
    required this.type,
    required this.greeting,
    required this.messageBody,
    required this.callToAction,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'greeting': greeting,
    'body': messageBody,
    'cta': callToAction,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Atlas Conversational Companion Mode Service.
/// Provides proactive, intelligent check-ins throughout the athlete's day,
/// celebrating progress, reinforcing daily habits, and guiding workout execution.
class CompanionModeService {
  static CompanionModeService? _instance;
  static CompanionModeService get instance =>
      _instance ??= CompanionModeService();

  static void resetInstance() {
    _instance = null;
  }

  /// Synthesizes a conversational check-in dialogue.
  CompanionDialogue generateCheckIn({
    required CompanionCheckInType type,
    required FitnessContext context,
    String? customWorkoutName,
  }) {
    final name = (context.userProfile?.name != null && context.userProfile!.name.isNotEmpty)
        ? context.userProfile!.name
        : 'Athlete';
    final readiness = context.recoveryState?.recoveryScore ?? 80;
    final now = DateTime.now();

    switch (type) {
      case CompanionCheckInType.morningBriefing:
        return CompanionDialogue(
          type: type,
          greeting: 'Good morning, $name!',
          messageBody: 'Your systemic readiness is $readiness/100. Target protein today is ${context.userGoal?.targetProtein.round() ?? 160}g.',
          callToAction: 'View Daily Itinerary',
          timestamp: now,
        );

      case CompanionCheckInType.preWorkoutMotivation:
        final workout = customWorkoutName ?? 'Scheduled Resistance Session';
        return CompanionDialogue(
          type: type,
          greeting: 'Ready to train, $name?',
          messageBody: '$workout is queued. Target 2 RIR on your primary compound lifts and lock in focus.',
          callToAction: 'Launch Live Vision Coach',
          timestamp: now,
        );

      case CompanionCheckInType.postWorkoutRefuel:
        return CompanionDialogue(
          type: type,
          greeting: 'Outstanding work, $name!',
          messageBody: 'Session logged. Rehydrate with 600ml water and consume 35-40g protein to trigger muscle protein synthesis.',
          callToAction: 'Log Post-Workout Meal',
          timestamp: now,
        );

      case CompanionCheckInType.eveningWindDown:
        return CompanionDialogue(
          type: type,
          greeting: 'Evening review, $name.',
          messageBody: 'Consistency on point today. Dim screens and aim for 7.5+ hours of sleep to optimize overnight recovery.',
          callToAction: 'Complete Evening Check-In',
          timestamp: now,
        );
    }
  }
}
