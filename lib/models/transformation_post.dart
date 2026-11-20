/// Privacy visibility options for athlete transformation posts
enum TransformationPrivacy {
  public('Public (Community Feed)'),
  followersOnly('Followers Only'),
  private('Private (Only Me)');

  final String label;
  const TransformationPrivacy(this.label);
}

/// Domain model representing an athlete's physical & strength transformation journey.
class TransformationPost {
  final String id;
  final String userId;
  final String userName;
  final String userAvatar;
  final double beforeWeight;
  final double afterWeight;
  final String? beforePhotoUrl;
  final String? afterPhotoUrl;
  final String timeSpanLabel; // e.g. "January → March (3 months)"
  final Map<String, double>
  strengthGains; // e.g. {"Bench Press": 20.0, "Squat": 30.0}
  final Map<String, double>
  bodyMeasurements; // e.g. {"Chest": 5.0, "Waist": -4.0}
  final String caption;
  final TransformationPrivacy privacy;
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;

  const TransformationPost({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar = '',
    required this.beforeWeight,
    required this.afterWeight,
    this.beforePhotoUrl,
    this.afterPhotoUrl,
    required this.timeSpanLabel,
    this.strengthGains = const {},
    this.bodyMeasurements = const {},
    required this.caption,
    this.privacy = TransformationPrivacy.public,
    this.likesCount = 0,
    this.commentsCount = 0,
    required this.createdAt,
  });

  /// Weight delta in kg
  double get weightDelta => afterWeight - beforeWeight;

  factory TransformationPost.fromJson(Map<String, dynamic> json) {
    final rawGains =
        json['strength_gains'] as Map<String, dynamic>? ??
        json['strengthGains'] as Map<String, dynamic>? ??
        {};
    final gains = rawGains.map((k, v) => MapEntry(k, (v as num).toDouble()));

    final rawMeasures =
        json['body_measurements'] as Map<String, dynamic>? ??
        json['bodyMeasurements'] as Map<String, dynamic>? ??
        {};
    final measurements = rawMeasures.map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    );

    final privacyStr = json['privacy'] as String? ?? 'public';
    final privacy = TransformationPrivacy.values.firstWhere(
      (p) =>
          p.name == privacyStr ||
          p.name.toLowerCase() == privacyStr.toLowerCase(),
      orElse: () => TransformationPrivacy.public,
    );

    return TransformationPost(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? (json['userId'] as String? ?? ''),
      userName:
          json['user_name'] as String? ?? (json['userName'] as String? ?? ''),
      userAvatar:
          json['user_avatar'] as String? ??
          (json['userAvatar'] as String? ?? ''),
      beforeWeight:
          (json['before_weight'] as num?)?.toDouble() ??
          (json['beforeWeight'] as num?)?.toDouble() ??
          0.0,
      afterWeight:
          (json['after_weight'] as num?)?.toDouble() ??
          (json['afterWeight'] as num?)?.toDouble() ??
          0.0,
      beforePhotoUrl:
          json['before_photo_url'] as String? ??
          json['beforePhotoUrl'] as String?,
      afterPhotoUrl:
          json['after_photo_url'] as String? ??
          json['afterPhotoUrl'] as String?,
      timeSpanLabel:
          json['time_span_label'] as String? ??
          (json['timeSpanLabel'] as String? ?? ''),
      strengthGains: gains,
      bodyMeasurements: measurements,
      caption: json['caption'] as String? ?? '',
      privacy: privacy,
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : (json['createdAt'] != null
                ? DateTime.parse(json['createdAt'] as String)
                : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_avatar': userAvatar,
      'before_weight': beforeWeight,
      'after_weight': afterWeight,
      'before_photo_url': beforePhotoUrl,
      'after_photo_url': afterPhotoUrl,
      'time_span_label': timeSpanLabel,
      'strength_gains': strengthGains,
      'body_measurements': bodyMeasurements,
      'caption': caption,
      'privacy': privacy.name,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
