/// Model class representing a Weekly Challenge in Aizawl Gym
class WeeklyChallenge {
  final String id;
  final String title;
  final String description;
  final String category;
  final double targetValue;
  final double currentProgress;
  final int xpReward;
  final bool completed;
  final DateTime? startDate;
  final DateTime? endDate;

  const WeeklyChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.targetValue,
    this.currentProgress = 0.0,
    required this.xpReward,
    this.completed = false,
    this.startDate,
    this.endDate,
  });

  /// Calculate completion progress ratio clamped between 0.0 and 1.0
  double get progressPercentage {
    if (targetValue <= 0) return 0.0;
    return (currentProgress / targetValue).clamp(0.0, 1.0);
  }

  /// Formatted progress string (e.g., "3 / 5" or "6,500 / 10,000 kg")
  String get formattedProgress {
    if (category.toLowerCase() == 'volume') {
      return '${currentProgress.toInt()} / ${targetValue.toInt()} kg';
    }
    return '${currentProgress.toInt()} / ${targetValue.toInt()}';
  }

  factory WeeklyChallenge.fromJson(Map<String, dynamic> json) {
    return WeeklyChallenge(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      targetValue: (json['targetValue'] as num?)?.toDouble() ?? 1.0,
      currentProgress: (json['currentProgress'] as num?)?.toDouble() ?? 0.0,
      xpReward: (json['xpReward'] as num?)?.toInt() ?? 100,
      completed: json['completed'] as bool? ?? false,
      startDate: json['startDate'] != null
          ? DateTime.tryParse(json['startDate'] as String)
          : null,
      endDate: json['endDate'] != null
          ? DateTime.tryParse(json['endDate'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'targetValue': targetValue,
      'currentProgress': currentProgress,
      'xpReward': xpReward,
      'completed': completed,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
    };
  }

  WeeklyChallenge copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    double? targetValue,
    double? currentProgress,
    int? xpReward,
    bool? completed,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return WeeklyChallenge(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      targetValue: targetValue ?? this.targetValue,
      currentProgress: currentProgress ?? this.currentProgress,
      xpReward: xpReward ?? this.xpReward,
      completed: completed ?? this.completed,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  @override
  String toString() {
    return 'WeeklyChallenge(id: $id, title: $title, progress: $currentProgress/$targetValue, completed: $completed)';
  }
}
