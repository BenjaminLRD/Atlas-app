/// Domain model representing a gym community event or collective quest.
class GymCommunityEvent {
  final String id;
  final String title;
  final String description;
  final String category; // 'volume', 'reps', 'workouts', 'streak'
  final double currentProgress;
  final double targetGoal;
  final String unitLabel; // 'kg', 'reps', 'sessions'
  final int participantCount;
  final int xpReward;
  final bool isJoined;
  final DateTime startDate;
  final DateTime endDate;

  GymCommunityEvent({
    required this.id,
    required this.title,
    required this.description,
    this.category = 'volume',
    required this.currentProgress,
    required this.targetGoal,
    this.unitLabel = 'kg',
    this.participantCount = 142,
    this.xpReward = 1000,
    this.isJoined = false,
    DateTime? startDate,
    DateTime? endDate,
  })  : startDate = startDate ?? DateTime.now(),
        endDate = endDate ?? DateTime.now().add(const Duration(days: 14));

  double get progressPercentage => targetGoal > 0 ? (currentProgress / targetGoal).clamp(0.0, 1.0) : 0.0;
  int get remainingDays => endDate.difference(DateTime.now()).inDays.clamp(0, 365);

  factory GymCommunityEvent.fromJson(Map<String, dynamic> json) {
    return GymCommunityEvent(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'volume',
      currentProgress: (json['currentProgress'] as num?)?.toDouble() ?? (json['current_progress'] as num?)?.toDouble() ?? 0.0,
      targetGoal: (json['targetGoal'] as num?)?.toDouble() ?? (json['target_goal'] as num?)?.toDouble() ?? 100000.0,
      unitLabel: json['unitLabel'] as String? ?? json['unit_label'] as String? ?? 'kg',
      participantCount: (json['participantCount'] as num?)?.toInt() ?? 100,
      xpReward: (json['xpReward'] as num?)?.toInt() ?? 1000,
      isJoined: json['isJoined'] as bool? ?? false,
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate'] as String) : DateTime.now(),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate'] as String) : DateTime.now().add(const Duration(days: 14)),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'currentProgress': currentProgress,
        'targetGoal': targetGoal,
        'unitLabel': unitLabel,
        'participantCount': participantCount,
        'xpReward': xpReward,
        'isJoined': isJoined,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
      };

  GymCommunityEvent copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    double? currentProgress,
    double? targetGoal,
    String? unitLabel,
    int? participantCount,
    int? xpReward,
    bool? isJoined,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return GymCommunityEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      currentProgress: currentProgress ?? this.currentProgress,
      targetGoal: targetGoal ?? this.targetGoal,
      unitLabel: unitLabel ?? this.unitLabel,
      participantCount: participantCount ?? this.participantCount,
      xpReward: xpReward ?? this.xpReward,
      isJoined: isJoined ?? this.isJoined,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}
