/// Model representing an exercise media asset (video, GIF, Lottie animation, or illustration).
/// Prepared for direct Supabase storage table `exercise_media` and local fallback caching.
class ExerciseMedia {
  final String id;
  final String exerciseId;
  final String mediaType; // 'video' | 'gif' | 'lottie' | 'image'
  final String url;
  final String? thumbnail;
  final DateTime createdAt;

  const ExerciseMedia({
    required this.id,
    required this.exerciseId,
    required this.mediaType,
    required this.url,
    this.thumbnail,
    required this.createdAt,
  });

  factory ExerciseMedia.fromJson(Map<String, dynamic> json) {
    return ExerciseMedia(
      id: json['id']?.toString() ?? '',
      exerciseId:
          json['exercise_id']?.toString() ??
          json['exerciseId']?.toString() ??
          '',
      mediaType:
          json['media_type']?.toString() ??
          json['mediaType']?.toString() ??
          'video',
      url: json['url']?.toString() ?? '',
      thumbnail:
          json['thumbnail']?.toString() ?? json['thumbnail_url']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : (json['createdAt'] != null
                ? DateTime.tryParse(json['createdAt'].toString()) ??
                      DateTime.now()
                : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exercise_id': exerciseId,
      'media_type': mediaType,
      'url': url,
      'thumbnail': thumbnail,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() => toJson();

  factory ExerciseMedia.fromMap(Map<String, dynamic> map) =>
      ExerciseMedia.fromJson(map);

  ExerciseMedia copyWith({
    String? id,
    String? exerciseId,
    String? mediaType,
    String? url,
    String? thumbnail,
    DateTime? createdAt,
  }) {
    return ExerciseMedia(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      mediaType: mediaType ?? this.mediaType,
      url: url ?? this.url,
      thumbnail: thumbnail ?? this.thumbnail,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
