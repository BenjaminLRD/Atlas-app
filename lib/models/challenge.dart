/// Domain model representing a weekly fitness or nutrition challenge.
class Challenge {
  final String id;
  final String title;
  final String description;
  final String category; // 'training', 'nutrition', 'volume', 'streak', 'strength'
  final double targetValue;
  final int rewardXP;
  final DateTime startDate;
  final DateTime endDate;

  const Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.targetValue,
    required this.rewardXP,
    required this.startDate,
    required this.endDate,
  });

  /// Check whether the challenge is currently active based on start and end dates.
  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  /// Remaining duration until the challenge expires.
  Duration get remainingTime {
    final now = DateTime.now();
    if (now.isAfter(endDate)) return Duration.zero;
    return endDate.difference(now);
  }

  /// Formatted countdown label (e.g. "3d 12h left" or "Expired").
  String get countdownLabel {
    final remaining = remainingTime;
    if (remaining == Duration.zero) return 'Expired';
    if (remaining.inDays > 0) {
      final hours = remaining.inHours % 24;
      return '${remaining.inDays}d ${hours}h left';
    }
    if (remaining.inHours > 0) {
      final minutes = remaining.inMinutes % 60;
      return '${remaining.inHours}h ${minutes}m left';
    }
    return '${remaining.inMinutes}m left';
  }

  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'training',
      targetValue: (json['targetValue'] as num?)?.toDouble() ??
          (json['target_value'] as num?)?.toDouble() ??
          1.0,
      rewardXP: (json['rewardXP'] as num?)?.toInt() ??
          (json['reward_xp'] as num?)?.toInt() ??
          100,
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : (json['start_date'] != null
              ? DateTime.parse(json['start_date'] as String)
              : DateTime.now()),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : (json['end_date'] != null
              ? DateTime.parse(json['end_date'] as String)
              : DateTime.now().add(const Duration(days: 7))),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'target_value': targetValue,
        'reward_xp': rewardXP,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
      };

  Challenge copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    double? targetValue,
    int? rewardXP,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return Challenge(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      targetValue: targetValue ?? this.targetValue,
      rewardXP: rewardXP ?? this.rewardXP,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Challenge &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          category == other.category &&
          targetValue == other.targetValue &&
          rewardXP == other.rewardXP;

  @override
  int get hashCode =>
      id.hashCode ^ category.hashCode ^ targetValue.hashCode ^ rewardXP.hashCode;
}
