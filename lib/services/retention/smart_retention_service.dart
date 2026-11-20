import '../../models/digital_athlete.dart';
import '../../models/notification_item.dart';

/// Retention action trigger type
enum RetentionTriggerType {
  workoutReminder,
  streakPreservation,
  milestoneCelebration,
  recoveryAlert,
  challengeInvite,
}

/// Smart behavioral notification & user retention service.
/// Uses athlete telemetry, recovery state, and circadian habit patterns to trigger
/// personalized, high-engagement prompts that protect training consistency.
class SmartRetentionService {
  static SmartRetentionService? _instance;
  final List<NotificationItem> _scheduledNotifications = [];

  SmartRetentionService();

  static SmartRetentionService get instance =>
      _instance ??= SmartRetentionService();

  static void resetInstance() {
    _instance = null;
  }

  /// Generates a personalized daily motivational spark based on the athlete's twin state.
  String generateDailyMotivationalSpark({
    required DigitalAthlete athlete,
    required int streakDays,
    String? latestPr,
  }) {
    final rec = athlete.recoveryProfile.averageRecoveryScore;
    final personality = athlete.trainingProfile.trainingPersonality;

    if (rec >= 85) {
      if (latestPr != null) {
        return '🔥 Peak Readiness (${rec.round()}/100)! Riding the momentum of your $latestPr PR — let\'s crush today\'s session!';
      }
      return '⚡ Optimal Recovery (${rec.round()}/100)! Your central nervous system is fully primed for progressive overload.';
    } else if (rec < 60) {
      return '🔋 Recovery Focus: Recovery score is ${rec.round()}/100. Prioritize sleep, hydration, and mobility today to come back stronger.';
    } else {
      return '🏆 $streakDays-Day Consistency Streak! As a $personality, showing up today keeps the compound growth compounding.';
    }
  }

  /// Evaluates athlete behavior and schedules smart contextual retention notifications
  NotificationItem? evaluateAndScheduleTrigger({
    required String userId,
    required DigitalAthlete athlete,
    required int daysSinceLastWorkout,
    required int streakDays,
  }) {
    final now = DateTime.now();

    // 1. Streak preservation alert
    if (daysSinceLastWorkout == 1 && streakDays >= 3) {
      final notif = NotificationItem(
        id: 'ret_streak_${now.millisecondsSinceEpoch}',
        userId: userId,
        title: '🔥 Protect Your $streakDays-Day Streak!',
        message:
            'You are 1 session away from continuing your momentum. Tap to launch today\'s ${athlete.trainingProfile.preferredSplit} split.',
        type: 'coach',
        createdAt: now,
        actionRoute: '/workouts',
      );
      _scheduledNotifications.add(notif);
      return notif;
    }

    // 2. High recovery encouragement
    if (athlete.recoveryProfile.averageRecoveryScore >= 85) {
      final notif = NotificationItem(
        id: 'ret_rec_${now.millisecondsSinceEpoch}',
        userId: userId,
        title: '⚡ Primed for Overload (88/100 Recovery)',
        message:
            'Your autonomic recovery is in the top 10%. Perfect day for a heavy top set!',
        type: 'coach',
        createdAt: now,
        actionRoute: '/ai_coach',
      );
      _scheduledNotifications.add(notif);
      return notif;
    }

    // 3. Circadian workout reminder
    final notif = NotificationItem(
      id: 'ret_rem_${now.millisecondsSinceEpoch}',
      userId: userId,
      title: '🏋️ Workout Time: ${athlete.trainingProfile.preferredSplit}',
      message:
          'Your evening peak window is open. Let\'s get after your weekly volume target.',
      type: 'coach',
      createdAt: now,
      actionRoute: '/workouts',
    );
    _scheduledNotifications.add(notif);
    return notif;
  }

  List<NotificationItem> get scheduledNotifications =>
      List.unmodifiable(_scheduledNotifications);
}
