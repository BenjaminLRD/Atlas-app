class Challenge {
  final String id;
  final String title;
  final String description;
  final String
  category; // 'training', 'nutrition', 'volume', 'streak', 'strength'
  final double targetValue;
  final double currentProgress;
  final int participants;
  final int rewardXP;
  final DateTime startDate;
  final DateTime endDate;
  final String? sponsorBrand;
  final String? sponsorLogo;
  final String? discountCode;
  final String? rewardBadge;
  final double completionRate;
  final int engagementCount;

  const Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.targetValue,
    this.currentProgress = 0.0,
    this.participants = 1,
    required this.rewardXP,
    required this.startDate,
    required this.endDate,
    this.sponsorBrand,
    this.sponsorLogo,
    this.discountCode,
    this.rewardBadge,
    this.completionRate = 0.0,
    this.engagementCount = 0,
  });

  /// Convenience aliases for Challenge requirements
  String get type => category;
  double get target => targetValue;
  DateTime get deadline => endDate;
  bool get isSponsored => sponsorBrand != null && sponsorBrand!.isNotEmpty;

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
      category:
          json['category'] as String? ??
          (json['type'] as String? ?? 'training'),
      targetValue:
          (json['targetValue'] as num?)?.toDouble() ??
          (json['target_value'] as num?)?.toDouble() ??
          (json['target'] as num?)?.toDouble() ??
          1.0,
      currentProgress:
          (json['currentProgress'] as num?)?.toDouble() ??
          (json['current_progress'] as num?)?.toDouble() ??
          0.0,
      participants: (json['participants'] as num?)?.toInt() ?? 1,
      rewardXP:
          (json['rewardXP'] as num?)?.toInt() ??
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
                : (json['deadline'] != null
                      ? DateTime.parse(json['deadline'] as String)
                      : DateTime.now().add(const Duration(days: 7)))),
      sponsorBrand:
          json['sponsorBrand'] as String? ?? json['sponsor_brand'] as String?,
      sponsorLogo:
          json['sponsorLogo'] as String? ?? json['sponsor_logo'] as String?,
      discountCode:
          json['discountCode'] as String? ?? json['discount_code'] as String?,
      rewardBadge:
          json['rewardBadge'] as String? ?? json['reward_badge'] as String?,
      completionRate:
          (json['completionRate'] as num?)?.toDouble() ??
          (json['completion_rate'] as num?)?.toDouble() ??
          0.0,
      engagementCount:
          (json['engagementCount'] as num?)?.toInt() ??
          (json['engagement_count'] as num?)?.toInt() ??
          0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category,
    'target_value': targetValue,
    'current_progress': currentProgress,
    'participants': participants,
    'reward_xp': rewardXP,
    'start_date': startDate.toIso8601String(),
    'end_date': endDate.toIso8601String(),
    if (sponsorBrand != null) 'sponsor_brand': sponsorBrand,
    if (sponsorLogo != null) 'sponsor_logo': sponsorLogo,
    if (discountCode != null) 'discount_code': discountCode,
    if (rewardBadge != null) 'reward_badge': rewardBadge,
    'completion_rate': completionRate,
    'engagement_count': engagementCount,
  };

  Challenge copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    double? targetValue,
    double? currentProgress,
    int? participants,
    int? rewardXP,
    DateTime? startDate,
    DateTime? endDate,
    String? sponsorBrand,
    String? sponsorLogo,
    String? discountCode,
    String? rewardBadge,
    double? completionRate,
    int? engagementCount,
  }) {
    return Challenge(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      targetValue: targetValue ?? this.targetValue,
      currentProgress: currentProgress ?? this.currentProgress,
      participants: participants ?? this.participants,
      rewardXP: rewardXP ?? this.rewardXP,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      sponsorBrand: sponsorBrand ?? this.sponsorBrand,
      sponsorLogo: sponsorLogo ?? this.sponsorLogo,
      discountCode: discountCode ?? this.discountCode,
      rewardBadge: rewardBadge ?? this.rewardBadge,
      completionRate: completionRate ?? this.completionRate,
      engagementCount: engagementCount ?? this.engagementCount,
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
          rewardXP == other.rewardXP &&
          sponsorBrand == other.sponsorBrand;

  @override
  int get hashCode =>
      id.hashCode ^
      category.hashCode ^
      targetValue.hashCode ^
      rewardXP.hashCode ^
      sponsorBrand.hashCode;
}
