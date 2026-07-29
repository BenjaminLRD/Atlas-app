class ActiveWorkoutSession {
  String workoutName;
  String? workoutId;
  int currentIndex;
  int seconds;
  bool isPaused;
  List<List<bool>> completedSets;

  ActiveWorkoutSession({
    this.workoutName = 'Workout Session',
    this.workoutId,
    required this.currentIndex,
    required this.seconds,
    required this.isPaused,
    required this.completedSets,
  });

  factory ActiveWorkoutSession.fromJson(Map<String, dynamic> json) {
    List<List<bool>> sets = [];
    final rawSets = json['completedSets'] as List?;
    if (rawSets != null) {
      sets = rawSets
          .map((e) => (e as List).map((b) => b as bool).toList())
          .toList();
    }
    return ActiveWorkoutSession(
      workoutName: json['workoutName'] as String? ?? 'Workout Session',
      workoutId: json['workoutId'] as String?,
      currentIndex: json['currentIndex'] as int? ?? 0,
      seconds: json['seconds'] as int? ?? 0,
      isPaused: json['isPaused'] as bool? ?? false,
      completedSets: sets,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workoutName': workoutName,
      'workoutId': workoutId,
      'currentIndex': currentIndex,
      'seconds': seconds,
      'isPaused': isPaused,
      'completedSets': completedSets,
    };
  }

  /// Map indexing operator for backwards compatibility
  dynamic operator [](String key) {
    switch (key) {
      case 'workoutName':
        return workoutName;
      case 'workoutId':
        return workoutId;
      case 'currentIndex':
        return currentIndex;
      case 'seconds':
        return seconds;
      case 'isPaused':
        return isPaused;
      case 'completedSets':
        return completedSets;
      default:
        return null;
    }
  }

  /// Map assignment operator for backwards compatibility
  void operator []=(String key, dynamic value) {
    switch (key) {
      case 'workoutName':
        workoutName = value?.toString() ?? workoutName;
        break;
      case 'workoutId':
        workoutId = value?.toString();
        break;
      case 'currentIndex':
        if (value is int) currentIndex = value;
        break;
      case 'seconds':
        if (value is int) seconds = value;
        break;
      case 'isPaused':
        if (value is bool) isPaused = value;
        break;
      case 'completedSets':
        if (value is List) {
          completedSets = value
              .map((e) => (e as List).map((b) => b as bool).toList())
              .toList();
        }
        break;
    }
  }

  ActiveWorkoutSession copyWith({
    String? workoutName,
    String? workoutId,
    int? currentIndex,
    int? seconds,
    bool? isPaused,
    List<List<bool>>? completedSets,
  }) {
    return ActiveWorkoutSession(
      workoutName: workoutName ?? this.workoutName,
      workoutId: workoutId ?? this.workoutId,
      currentIndex: currentIndex ?? this.currentIndex,
      seconds: seconds ?? this.seconds,
      isPaused: isPaused ?? this.isPaused,
      completedSets: completedSets ?? List.from(this.completedSets),
    );
  }
}
