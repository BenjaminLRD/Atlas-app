/// Domain model representing a competitive fitness season.
class FitnessSeason {
  final String id;
  final String name;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final String rewardDescription;

  const FitnessSeason({
    required this.id,
    required this.name,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.rewardDescription,
  });

  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  int get remainingDays {
    final now = DateTime.now();
    if (now.isAfter(endDate)) return 0;
    return endDate.difference(now).inDays.clamp(0, 365);
  }

  factory FitnessSeason.fromJson(Map<String, dynamic> json) {
    return FitnessSeason(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : (json['start_date'] != null
              ? DateTime.parse(json['start_date'] as String)
              : DateTime.now()),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : (json['end_date'] != null
              ? DateTime.parse(json['end_date'] as String)
              : DateTime.now().add(const Duration(days: 30))),
      rewardDescription: json['rewardDescription'] as String? ??
          json['reward_description'] as String? ??
          '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'reward_description': rewardDescription,
      };

  FitnessSeason copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? rewardDescription,
  }) {
    return FitnessSeason(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      rewardDescription: rewardDescription ?? this.rewardDescription,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FitnessSeason &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}
