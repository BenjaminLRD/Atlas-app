class ActiveWorkoutSession {
  String workoutName;
  String? workoutId;
  int currentIndex;
  int currentSetIndex;
  int seconds;
  bool isPaused;
  List<List<bool>> completedSets;
  List<Map<String, dynamic>>? exercisesData;
  DateTime? startTime;

  ActiveWorkoutSession({
    this.workoutName = 'Workout Session',
    this.workoutId,
    required this.currentIndex,
    this.currentSetIndex = 0,
    required this.seconds,
    required this.isPaused,
    required this.completedSets,
    this.exercisesData,
    this.startTime,
  });

  factory ActiveWorkoutSession.fromJson(Map<String, dynamic> json) {
    List<List<bool>> sets = [];
    final rawSets = json['completedSets'] as List?;
    if (rawSets != null) {
      sets = rawSets
          .map((e) => (e as List).map((b) => b as bool).toList())
          .toList();
    }

    List<Map<String, dynamic>>? exData;
    final rawExData = json['exercisesData'] as List?;
    if (rawExData != null) {
      exData = rawExData
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    DateTime? parsedStartTime;
    if (json['startTime'] != null) {
      parsedStartTime = DateTime.tryParse(json['startTime'].toString());
    }

    return ActiveWorkoutSession(
      workoutName: json['workoutName'] as String? ?? 'Workout Session',
      workoutId: json['workoutId'] as String?,
      currentIndex: json['currentIndex'] as int? ?? 0,
      currentSetIndex: json['currentSetIndex'] as int? ?? 0,
      seconds: json['seconds'] as int? ?? 0,
      isPaused: json['isPaused'] as bool? ?? false,
      completedSets: sets,
      exercisesData: exData,
      startTime: parsedStartTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'workoutName': workoutName,
      'workoutId': workoutId,
      'currentIndex': currentIndex,
      'currentSetIndex': currentSetIndex,
      'seconds': seconds,
      'isPaused': isPaused,
      'completedSets': completedSets,
      if (exercisesData != null) 'exercisesData': exercisesData,
      if (startTime != null) 'startTime': startTime!.toIso8601String(),
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
      case 'currentSetIndex':
        return currentSetIndex;
      case 'seconds':
        return seconds;
      case 'isPaused':
        return isPaused;
      case 'completedSets':
        return completedSets;
      case 'exercisesData':
        return exercisesData;
      case 'startTime':
        return startTime;
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
      case 'currentSetIndex':
        if (value is int) currentSetIndex = value;
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
      case 'exercisesData':
        if (value is List) {
          exercisesData = value
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
        break;
      case 'startTime':
        if (value is DateTime) {
          startTime = value;
        } else if (value is String) {
          startTime = DateTime.tryParse(value);
        }
        break;
    }
  }

  ActiveWorkoutSession copyWith({
    String? workoutName,
    String? workoutId,
    int? currentIndex,
    int? currentSetIndex,
    int? seconds,
    bool? isPaused,
    List<List<bool>>? completedSets,
    List<Map<String, dynamic>>? exercisesData,
    DateTime? startTime,
  }) {
    return ActiveWorkoutSession(
      workoutName: workoutName ?? this.workoutName,
      workoutId: workoutId ?? this.workoutId,
      currentIndex: currentIndex ?? this.currentIndex,
      currentSetIndex: currentSetIndex ?? this.currentSetIndex,
      seconds: seconds ?? this.seconds,
      isPaused: isPaused ?? this.isPaused,
      completedSets: completedSets ?? List.from(this.completedSets),
      exercisesData:
          exercisesData ??
          (this.exercisesData != null ? List.from(this.exercisesData!) : null),
      startTime: startTime ?? this.startTime,
    );
  }
}
