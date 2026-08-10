import '../models/gym_community_event.dart';

/// Central service managing gym community events and collective fitness quests.
class CommunityEventService {
  static CommunityEventService? _instance;
  List<GymCommunityEvent>? _cachedEvents;

  /// Reset singleton instance (useful for testing)
  static void resetInstance() {
    _instance = null;
  }

  /// Singleton instance getter
  static CommunityEventService get instance {
    _instance ??= CommunityEventService();
    return _instance!;
  }

  static List<GymCommunityEvent> _getDefaultEvents() {
    return [
      GymCommunityEvent(
        id: 'event_1',
        title: 'Aizawl Monsoon Fitness Rally',
        description: 'Join all gym members in lifting a combined 1,000,000 kg volume this month!',
        category: 'volume',
        currentProgress: 642500.0,
        targetGoal: 1000000.0,
        unitLabel: 'kg',
        participantCount: 214,
        xpReward: 1500,
        isJoined: true,
      ),
      GymCommunityEvent(
        id: 'event_2',
        title: '100k Reps Challenge',
        description: 'Complete 100,000 total clean reps together before the season ends!',
        category: 'reps',
        currentProgress: 42300.0,
        targetGoal: 100000.0,
        unitLabel: 'reps',
        participantCount: 158,
        xpReward: 1000,
        isJoined: false,
      ),
    ];
  }

  /// Get active gym community events
  List<GymCommunityEvent> getEvents() {
    _cachedEvents ??= _getDefaultEvents();
    return List.unmodifiable(_cachedEvents!);
  }

  /// Join a community event
  void joinEvent(String eventId) {
    final list = List<GymCommunityEvent>.from(getEvents());
    final index = list.indexWhere((e) => e.id == eventId);
    if (index != -1) {
      list[index] = list[index].copyWith(
        isJoined: true,
        participantCount: list[index].participantCount + 1,
      );
      _cachedEvents = list;
    }
  }

  /// Contribute progress to joined events on workout completion
  void updateProgressOnWorkout(double volumeLifted) {
    final list = List<GymCommunityEvent>.from(getEvents());
    for (int i = 0; i < list.length; i++) {
      if (list[i].isJoined) {
        list[i] = list[i].copyWith(
          currentProgress: list[i].currentProgress + volumeLifted,
        );
      }
    }
    _cachedEvents = list;
  }
}
