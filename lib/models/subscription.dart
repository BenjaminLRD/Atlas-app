enum SubscriptionTier {
  free,
  monthly,
  annual,
  lifetime,
}

enum SubscriptionStatus {
  active,
  canceled,
  expired,
  gracePeriod,
}

/// Domain model representing user subscription state, tier, and expiration.
class Subscription {
  final String id;
  final String userId;
  final SubscriptionTier tier;
  final SubscriptionStatus status;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isAutoRenewing;
  final String productIdentifier;

  const Subscription({
    required this.id,
    required this.userId,
    this.tier = SubscriptionTier.free,
    this.status = SubscriptionStatus.active,
    required this.startDate,
    this.endDate,
    this.isAutoRenewing = false,
    this.productIdentifier = 'free_plan',
  });

  /// Factory default free tier subscription.
  factory Subscription.free({String userId = 'usr_local'}) {
    return Subscription(
      id: 'sub_free',
      userId: userId,
      tier: SubscriptionTier.free,
      status: SubscriptionStatus.active,
      startDate: DateTime.now(),
      productIdentifier: 'free_plan',
    );
  }

  /// Returns true if tier is premium (monthly, annual, lifetime) and status is valid.
  bool get isPremium {
    if (tier == SubscriptionTier.free) return false;
    if (status == SubscriptionStatus.active || status == SubscriptionStatus.gracePeriod) {
      if (endDate == null) return true; // Lifetime or ongoing
      return DateTime.now().isBefore(endDate!);
    }
    return false;
  }

  /// Returns true if subscription is expired.
  bool get isExpired {
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!);
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'] as String? ?? 'sub_free',
      userId: json['userId'] as String? ?? (json['user_id'] as String? ?? 'usr_local'),
      tier: SubscriptionTier.values.firstWhere(
        (e) => e.name == json['tier'],
        orElse: () => SubscriptionTier.free,
      ),
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SubscriptionStatus.active,
      ),
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : (json['start_date'] != null
              ? DateTime.parse(json['start_date'] as String)
              : DateTime.now()),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : (json['end_date'] != null
              ? DateTime.parse(json['end_date'] as String)
              : null),
      isAutoRenewing: json['isAutoRenewing'] as bool? ??
          (json['is_auto_renewing'] as bool? ?? false),
      productIdentifier: json['productIdentifier'] as String? ??
          (json['product_identifier'] as String? ?? 'free_plan'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'tier': tier.name,
        'status': status.name,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'isAutoRenewing': isAutoRenewing,
        'productIdentifier': productIdentifier,
      };

  Subscription copyWith({
    String? id,
    String? userId,
    SubscriptionTier? tier,
    SubscriptionStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    bool? isAutoRenewing,
    String? productIdentifier,
  }) {
    return Subscription(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tier: tier ?? this.tier,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isAutoRenewing: isAutoRenewing ?? this.isAutoRenewing,
      productIdentifier: productIdentifier ?? this.productIdentifier,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Subscription &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          tier == other.tier &&
          status == other.status &&
          productIdentifier == other.productIdentifier;

  @override
  int get hashCode =>
      id.hashCode ^ tier.hashCode ^ status.hashCode ^ productIdentifier.hashCode;
}
