import 'post_comment.dart';

/// Post categories supported in the Atlas Community Hub.
enum ActivityPostType {
  workout('Workout', '🏋️'),
  meal('Meal Prep', '🍱'),
  achievement('PR & Record', '🏆'),
  transformation('Transformation', '🔥'),
  routine('Workout Split', '📋'),
  progress('Milestone', '⚡'),
  cardio('Run & Ride', '🏃');

  final String displayName;
  final String emoji;
  const ActivityPostType(this.displayName, this.emoji);
}

/// Rich Community Feed Post Model.
class ActivityPost {
  final String id;
  final String userId;
  final String userName;
  final String? userAvatar;
  final String userRank;
  final ActivityPostType type;
  final String title;
  final String description;
  final List<String> images;
  final Map<String, dynamic>? metadata;
  final int likes;
  final int rawCommentsCount;
  final List<PostComment> commentsList;
  final int savesCount;
  final DateTime createdAt;
  final bool isLiked;
  final bool isSaved;

  /// True for built-in sample content shown so the feed is never empty.
  /// Sample posts are never real user content: they are never sent to the
  /// server, never saved among the user's own posts, and always labelled.
  final bool isSample;

  const ActivityPost({
    required this.id,
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.userRank = 'Athlete',
    required this.type,
    required this.title,
    required this.description,
    this.images = const [],
    this.metadata,
    this.likes = 0,
    int comments = 0,
    this.commentsList = const [],
    this.savesCount = 0,
    required this.createdAt,
    this.isLiked = false,
    this.isSaved = false,
    this.isSample = false,
  }) : rawCommentsCount = comments;

  /// Derived comment count strictly synchronized with actual comments collection
  int get comments =>
      commentsList.isNotEmpty ? commentsList.length : rawCommentsCount;

  // --- Type-Specific Convenience Getters ---

  /// Workout volume in kg
  double get workoutVolumeKg {
    return (metadata?['totalVolumeKg'] as num?)?.toDouble() ??
        (metadata?['volume'] as num?)?.toDouble() ??
        0.0;
  }

  /// Workout duration in minutes
  int get workoutDurationMinutes {
    return (metadata?['durationMinutes'] as num?)?.toInt() ??
        (metadata?['duration'] as num?)?.toInt() ??
        0;
  }

  /// Exercises completed in workout session
  int get workoutExercisesCount {
    return (metadata?['exercisesCount'] as num?)?.toInt() ??
        (metadata?['exercises'] as List?)?.length ??
        0;
  }

  /// XP earned during session
  int get workoutXpEarned {
    return (metadata?['xpEarned'] as num?)?.toInt() ??
        (metadata?['xp'] as num?)?.toInt() ??
        0;
  }

  /// PR exercise name
  String get prExerciseName {
    return metadata?['exerciseName'] as String? ?? 'Personal Record';
  }

  /// PR previous weight
  double get prPreviousWeightKg {
    return (metadata?['previousWeightKg'] as num?)?.toDouble() ?? 0.0;
  }

  /// PR new achieved weight
  double get prNewWeightKg {
    return (metadata?['newWeightKg'] as num?)?.toDouble() ?? 0.0;
  }

  /// PR weight delta
  double get prImprovementKg {
    final diff = prNewWeightKg - prPreviousWeightKg;
    return diff > 0
        ? diff
        : ((metadata?['improvementKg'] as num?)?.toDouble() ?? 0.0);
  }

  /// Meal prep calories
  int get mealCalories {
    return (metadata?['calories'] as num?)?.toInt() ?? 0;
  }

  /// Meal prep protein in grams
  int get mealProteinGrams {
    return (metadata?['proteinGrams'] as num?)?.toInt() ??
        (metadata?['protein'] as num?)?.toInt() ??
        0;
  }

  /// Meal prep carbs in grams
  int get mealCarbsGrams {
    return (metadata?['carbsGrams'] as num?)?.toInt() ??
        (metadata?['carbs'] as num?)?.toInt() ??
        0;
  }

  /// Meal prep fat in grams
  int get mealFatGrams {
    return (metadata?['fatGrams'] as num?)?.toInt() ??
        (metadata?['fat'] as num?)?.toInt() ??
        0;
  }

  /// Meal prep ingredients list
  List<String> get mealIngredients {
    final list = metadata?['ingredients'] as List?;
    return list?.map((e) => e.toString()).toList() ?? const [];
  }

  /// Routine / Split days and exercise plan
  List<Map<String, dynamic>> get routineDays {
    final raw = metadata?['days'] as List?;
    if (raw != null) {
      return raw.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  /// Friendly relative timestamp
  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  factory ActivityPost.fromJson(Map<String, dynamic> json) {
    final rawType = json['type'] as String?;
    final parsedType = ActivityPostType.values.firstWhere(
      (e) => e.name.toLowerCase() == rawType?.toLowerCase(),
      orElse: () => ActivityPostType.workout,
    );

    final rawCommentsList =
        json['commentsList'] as List? ?? json['comments_list'] as List?;
    final parsedComments = rawCommentsList != null
        ? rawCommentsList
            .map(
              (e) => PostComment.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList()
        : const <PostComment>[];

    return ActivityPost(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? json['user_id'] as String? ?? '',
      userName:
          json['userName'] as String? ??
          json['user_name'] as String? ??
          'Athlete',
      userAvatar:
          json['userAvatar'] as String? ?? json['user_avatar'] as String?,
      userRank:
          json['userRank'] as String? ??
          json['user_rank'] as String? ??
          'Bronze IV',
      type: parsedType,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      images:
          (json['images'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      metadata: json['metadata'] as Map<String, dynamic>?,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      comments: (json['comments'] as num?)?.toInt() ?? parsedComments.length,
      commentsList: parsedComments,
      savesCount:
          (json['savesCount'] as num?)?.toInt() ??
          (json['saves_count'] as num?)?.toInt() ??
          0,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : (json['created_at'] != null
                ? DateTime.parse(json['created_at'] as String)
                : DateTime.now()),
      isLiked: json['isLiked'] as bool? ?? json['is_liked'] as bool? ?? false,
      isSaved: json['isSaved'] as bool? ?? json['is_saved'] as bool? ?? false,
      isSample: json['isSample'] as bool? ?? json['is_sample'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'userRank': userRank,
      'type': type.name,
      'title': title,
      'description': description,
      'images': images,
      if (metadata != null) 'metadata': metadata,
      'likes': likes,
      'comments': comments,
      'commentsList': commentsList.map((c) => c.toJson()).toList(),
      'savesCount': savesCount,
      'createdAt': createdAt.toIso8601String(),
      'isLiked': isLiked,
      'isSaved': isSaved,
      if (isSample) 'isSample': true,
    };
  }

  ActivityPost copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userAvatar,
    String? userRank,
    ActivityPostType? type,
    String? title,
    String? description,
    List<String>? images,
    Map<String, dynamic>? metadata,
    int? likes,
    int? comments,
    List<PostComment>? commentsList,
    int? savesCount,
    DateTime? createdAt,
    bool? isLiked,
    bool? isSaved,
    bool? isSample,
  }) {
    return ActivityPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      userRank: userRank ?? this.userRank,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      images: images ?? this.images,
      metadata: metadata ?? this.metadata,
      likes: likes ?? this.likes,
      comments: comments ?? (commentsList != null ? commentsList.length : this.comments),
      commentsList: commentsList ?? this.commentsList,
      savesCount: savesCount ?? this.savesCount,
      createdAt: createdAt ?? this.createdAt,
      isLiked: isLiked ?? this.isLiked,
      isSaved: isSaved ?? this.isSaved,
      isSample: isSample ?? this.isSample,
    );
  }
}
