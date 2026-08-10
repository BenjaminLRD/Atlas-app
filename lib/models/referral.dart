/// Domain model representing referral system state and tracking for a user.
class ReferralData {
  final String referralCode;
  final String referrerId;
  final int totalReferredCount;
  final int convertedCount;
  final int totalXpEarned;
  final List<String> referredUserIds;
  final DateTime createdAt;

  ReferralData({
    required this.referralCode,
    required this.referrerId,
    this.totalReferredCount = 0,
    this.convertedCount = 0,
    this.totalXpEarned = 0,
    this.referredUserIds = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ReferralData.initial({String userId = 'usr_local'}) {
    final codeSuffix = userId.replaceAll('usr_', '').toUpperCase();
    return ReferralData(
      referralCode: 'AIRZAWL-$codeSuffix',
      referrerId: userId,
      totalReferredCount: 2,
      convertedCount: 1,
      totalXpEarned: 500,
      referredUserIds: const ['usr_alex', 'usr_maya'],
    );
  }

  factory ReferralData.fromJson(Map<String, dynamic> json) {
    return ReferralData(
      referralCode: json['referralCode'] as String? ?? json['referral_code'] as String? ?? 'AIRZAWL-GYM',
      referrerId: json['referrerId'] as String? ?? json['referrer_id'] as String? ?? 'usr_local',
      totalReferredCount: (json['totalReferredCount'] as num?)?.toInt() ?? (json['total_referred_count'] as num?)?.toInt() ?? 0,
      convertedCount: (json['convertedCount'] as num?)?.toInt() ?? (json['converted_count'] as num?)?.toInt() ?? 0,
      totalXpEarned: (json['totalXpEarned'] as num?)?.toInt() ?? (json['total_xp_earned'] as num?)?.toInt() ?? 0,
      referredUserIds: (json['referredUserIds'] as List?)?.map((e) => e.toString()).toList() ??
          (json['referred_user_ids'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : (json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() => {
        'referralCode': referralCode,
        'referrerId': referrerId,
        'totalReferredCount': totalReferredCount,
        'convertedCount': convertedCount,
        'totalXpEarned': totalXpEarned,
        'referredUserIds': referredUserIds,
        'createdAt': createdAt.toIso8601String(),
      };

  ReferralData copyWith({
    String? referralCode,
    String? referrerId,
    int? totalReferredCount,
    int? convertedCount,
    int? totalXpEarned,
    List<String>? referredUserIds,
    DateTime? createdAt,
  }) {
    return ReferralData(
      referralCode: referralCode ?? this.referralCode,
      referrerId: referrerId ?? this.referrerId,
      totalReferredCount: totalReferredCount ?? this.totalReferredCount,
      convertedCount: convertedCount ?? this.convertedCount,
      totalXpEarned: totalXpEarned ?? this.totalXpEarned,
      referredUserIds: referredUserIds ?? this.referredUserIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
