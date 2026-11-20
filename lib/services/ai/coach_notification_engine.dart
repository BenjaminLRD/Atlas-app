import '../athlete/athlete_state_aggregator.dart';

/// Categories of proactive notifications emitted by [CoachNotificationEngine].
enum NotificationType {
  workoutReminder('WORKOUT_REMINDER'),
  recoveryWarning('RECOVERY_WARNING'),
  achievementAlert('ACHIEVEMENT_ALERT'),
  progressMilestone('PROGRESS_MILESTONE');

  final String code;
  const NotificationType(this.code);
}

/// Structured proactive notification tailored to athlete behavior.
class ProactiveNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final String priority; // 'high', 'medium', 'low'
  final int? targetHour; // 0 to 23
  final String? route;
  final DateTime timestamp;

  const ProactiveNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.priority = 'medium',
    this.targetHour,
    this.route,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.code,
    'title': title,
    'body': body,
    'priority': priority,
    if (targetHour != null) 'target_hour': targetHour,
    if (route != null) 'route': route,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Autonomous Notification Engine generating personalized, non-spam coaching alerts:
/// workout reminders, recovery warnings, achievement celebrations, and progress milestones.
class CoachNotificationEngine {
  static CoachNotificationEngine? _instance;
  static CoachNotificationEngine get instance =>
      _instance ??= CoachNotificationEngine();

  /// Generates a prioritized, behavior-personalized list of smart notifications.
  List<ProactiveNotification> generateNotifications({
    required AthleteStateSnapshot state,
    int maxPerDay = 3,
    DateTime? referenceTime,
  }) {
    final notifications = <ProactiveNotification>[];
    final now = referenceTime ?? DateTime.now();

    // -------------------------------------------------------------------------
    // 1. RECOVERY WARNINGS (Highest Priority if fatigued/sleep-deprived)
    // -------------------------------------------------------------------------
    final measured = state.recovery.isMeasured;
    final readiness = state.recovery.readinessScore;
    final sleep = state.recovery.sleepHours;

    if (measured &&
        (readiness < 50 || (sleep != null && sleep > 0 && sleep < 6.0))) {
      notifications.add(
        ProactiveNotification(
          id: 'notif_rec_${now.millisecondsSinceEpoch}',
          type: NotificationType.recoveryWarning,
          title: 'Recovery Warning 💤',
          body:
              'Autonomic readiness dropped to $readiness% (${sleep == null ? 'sleep not recorded' : 'Sleep: ${sleep.toStringAsFixed(1)}h'}). Atlas recommends an active recovery mobility session today.',
          priority: 'high',
          route: '/recovery',
          timestamp: now,
        ),
      );
    }

    // -------------------------------------------------------------------------
    // 2. WORKOUT REMINDERS (Personalized by Circadian Training Window)
    // -------------------------------------------------------------------------
    // Workout reminders do not depend on recovery; they stay unless a measured
    // readiness is low.
    if (!measured || readiness >= 50) {
      final prefTime = state.behavior.preferredWorkoutTime.toLowerCase();
      int scheduledHour = 18;
      String windowLabel = 'evening';

      if (prefTime == 'morning') {
        scheduledHour = 7;
        windowLabel = 'morning';
      } else if (prefTime == 'afternoon') {
        scheduledHour = 15;
        windowLabel = 'afternoon';
      }

      final workoutName = state.workout.lastWorkoutName.isNotEmpty
          ? state.workout.lastWorkoutName
          : 'Scheduled Split';

      notifications.add(
        ProactiveNotification(
          id: 'notif_wo_${now.millisecondsSinceEpoch}',
          type: NotificationType.workoutReminder,
          title: 'Ready for $workoutName? 🏋️',
          body:
              'Your $windowLabel training session is coming up. Hydrate and get primed for progressive overload.',
          priority: 'medium',
          targetHour: scheduledHour,
          route: '/workout',
          timestamp: now,
        ),
      );
    }

    // -------------------------------------------------------------------------
    // 3. ACHIEVEMENT ALERTS (PRs and Consistency Streaks)
    // -------------------------------------------------------------------------
    if (state.behavior.streakDays >= 3) {
      notifications.add(
        ProactiveNotification(
          id: 'notif_ach_${now.millisecondsSinceEpoch}',
          type: NotificationType.achievementAlert,
          title: '🔥 ${state.behavior.streakDays}-Day Training Streak!',
          body:
              'Incredible discipline! You are in the top 10% of consistent athletes this week.',
          priority: 'medium',
          route: '/progress',
          timestamp: now,
        ),
      );
    } else if (state.workout.prsAchieved.isNotEmpty) {
      notifications.add(
        ProactiveNotification(
          id: 'notif_pr_${now.millisecondsSinceEpoch}',
          type: NotificationType.achievementAlert,
          title: '🏆 New Volume PR Achieved!',
          body:
              'Congratulations on breaking your volume record on ${state.workout.prsAchieved.first}.',
          priority: 'high',
          route: '/progress',
          timestamp: now,
        ),
      );
    }

    // -------------------------------------------------------------------------
    // 4. PROGRESS MILESTONES (Nutrition & Volume)
    // -------------------------------------------------------------------------
    // Null when some food has no protein value: no reminder then.
    final protDelta = state.nutrition.proteinDelta;

    if (protDelta != null && protDelta > 25.0) {
      notifications.add(
        ProactiveNotification(
          id: 'notif_nut_${now.millisecondsSinceEpoch}',
          type: NotificationType.progressMilestone,
          title: 'Protein Fuel Target 🥩',
          body:
              'You need ${protDelta.round()}g more protein to hit your daily recovery target. Add a protein shake or lean snack.',
          priority: 'medium',
          targetHour: 19,
          route: '/nutrition',
          timestamp: now,
        ),
      );
    }

    // Sort by priority (high > medium > low) and cap to maxPerDay
    notifications.sort((a, b) {
      final pA = a.priority == 'high' ? 0 : (a.priority == 'medium' ? 1 : 2);
      final pB = b.priority == 'high' ? 0 : (b.priority == 'medium' ? 1 : 2);
      return pA.compareTo(pB);
    });

    return notifications.take(maxPerDay).toList();
  }
}
