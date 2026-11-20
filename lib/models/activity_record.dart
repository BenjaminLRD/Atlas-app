import 'cardio_route.dart';

/// Activity types supported by the Activity & Cardio intelligence engine.
enum ActivityType {
  steps('Steps', '🚶'),
  cardio('Cardio', '❤️'),
  workout('Workout', '🏋️'),
  activeMinutes('Active Minutes', '⏱'),
  sport('Sport', '⚽'),
  custom('Activity', '⚡');

  final String displayName;
  final String emoji;
  const ActivityType(this.displayName, this.emoji);
}

/// Comprehensive daily or session-level Activity Record.
class ActivityRecord {
  final String id;
  final DateTime date;
  final int steps;
  final int activeMinutes;
  final double caloriesBurned;
  final double distanceKm;
  final ActivityType type;
  final String? title;
  final String? notes;

  const ActivityRecord({
    required this.id,
    required this.date,
    this.steps = 0,
    this.activeMinutes = 0,
    this.caloriesBurned = 0.0,
    this.distanceKm = 0.0,
    this.type = ActivityType.steps,
    this.title,
    this.notes,
  });

  factory ActivityRecord.zero({DateTime? date}) {
    final now = date ?? DateTime.now();
    return ActivityRecord(
      id: 'act_today_${now.year}_${now.month}_${now.day}',
      date: now,
      steps: 0,
      activeMinutes: 0,
      caloriesBurned: 0.0,
      distanceKm: 0.0,
      type: ActivityType.steps,
      title: "Today's Movement",
    );
  }

  factory ActivityRecord.todaySample({
    int steps = 7342,
    int activeMinutes = 56,
    double caloriesBurned = 420.0,
    double distanceKm = 5.2,
  }) {
    return ActivityRecord(
      id: 'act_${DateTime.now().millisecondsSinceEpoch}',
      date: DateTime.now(),
      steps: steps,
      activeMinutes: activeMinutes,
      caloriesBurned: caloriesBurned,
      distanceKm: distanceKm,
      type: ActivityType.steps,
      title: "Today's Movement",
    );
  }

  factory ActivityRecord.fromJson(Map<String, dynamic> json) {
    final typeString = json['type'] as String?;
    final parsedType = ActivityType.values.firstWhere(
      (e) => e.name.toLowerCase() == typeString?.toLowerCase(),
      orElse: () => ActivityType.steps,
    );

    return ActivityRecord(
      id: json['id'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.parse(json['date'] as String)
          : DateTime.now(),
      steps: (json['steps'] as num?)?.toInt() ?? 0,
      activeMinutes:
          (json['activeMinutes'] as num?)?.toInt() ??
          (json['active_minutes'] as num?)?.toInt() ??
          0,
      caloriesBurned:
          (json['caloriesBurned'] as num?)?.toDouble() ??
          (json['calories_burned'] as num?)?.toDouble() ??
          0.0,
      distanceKm:
          (json['distanceKm'] as num?)?.toDouble() ??
          (json['distance_km'] as num?)?.toDouble() ??
          (json['distance'] as num?)?.toDouble() ??
          0.0,
      type: parsedType,
      title: json['title'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'steps': steps,
      'activeMinutes': activeMinutes,
      'caloriesBurned': caloriesBurned,
      'distanceKm': distanceKm,
      'type': type.name,
      'title': title,
      'notes': notes,
    };
  }

  ActivityRecord copyWith({
    String? id,
    DateTime? date,
    int? steps,
    int? activeMinutes,
    double? caloriesBurned,
    double? distanceKm,
    ActivityType? type,
    String? title,
    String? notes,
  }) {
    return ActivityRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      steps: steps ?? this.steps,
      activeMinutes: activeMinutes ?? this.activeMinutes,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      distanceKm: distanceKm ?? this.distanceKm,
      type: type ?? this.type,
      title: title ?? this.title,
      notes: notes ?? this.notes,
    );
  }
}

/// Recorded individual cardio workout session.
class CardioSession {
  final String id;
  final String exerciseId;
  final String exerciseName;
  final String category;
  final int durationSeconds;
  final double distanceKm;
  final double caloriesBurned;
  final int? avgHeartRate;
  final DateTime startTime;
  final DateTime? endTime;
  final double metValue;
  final bool isCompleted;

  /// The recorded GPS route, empty when the session had none.
  final List<RoutePoint> route;

  /// Time spent paused, which is not part of [durationSeconds].
  final int pausedSeconds;

  /// False when no defensible calorie figure existed (for example no body
  /// weight). [caloriesBurned] is then 0 only as a placeholder.
  final bool caloriesKnown;

  /// True when [caloriesBurned] is an estimate rather than a measurement.
  final bool caloriesEstimated;

  const CardioSession({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.category,
    required this.durationSeconds,
    this.distanceKm = 0.0,
    required this.caloriesBurned,
    this.avgHeartRate,
    required this.startTime,
    this.endTime,
    this.metValue = 8.0,
    this.isCompleted = true,
    this.route = const [],
    this.pausedSeconds = 0,
    this.caloriesKnown = true,
    this.caloriesEstimated = true,
  });

  /// Running or cycling when the session was recorded with GPS, else null.
  CardioKind? get kind => CardioKind.fromKey(category);

  bool get hasRoute => route.length >= 2;

  /// Average speed in km/h, or null when distance or time is missing.
  double? get avgSpeedKmh {
    if (distanceKm <= 0.01 || durationSeconds <= 0) return null;
    return distanceKm / (durationSeconds / 3600);
  }

  /// Formatted duration string MM:SS or HH:MM:SS
  String get formattedDuration {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Pace in min/km if distance is tracked
  String get paceMinutesPerKm {
    if (distanceKm <= 0.05 || durationSeconds <= 0) return '--:--';
    final totalMinutes = durationSeconds / 60.0;
    final paceDecimal = totalMinutes / distanceKm;
    final paceMins = paceDecimal.toInt();
    final paceSecs = ((paceDecimal - paceMins) * 60).toInt();
    return '$paceMins:${paceSecs.toString().padLeft(2, '0')} /km';
  }

  /// Average calories burned per minute
  double get caloriesPerMinute {
    if (durationSeconds <= 0) return 0.0;
    return caloriesBurned / (durationSeconds / 60.0);
  }

  factory CardioSession.fromJson(Map<String, dynamic> json) {
    return CardioSession(
      id: json['id'] as String? ?? '',
      exerciseId:
          json['exerciseId'] as String? ?? json['exercise_id'] as String? ?? '',
      exerciseName:
          json['exerciseName'] as String? ??
          json['exercise_name'] as String? ??
          'Cardio Workout',
      category: json['category'] as String? ?? 'Running',
      durationSeconds:
          (json['durationSeconds'] as num?)?.toInt() ??
          (json['duration_seconds'] as num?)?.toInt() ??
          0,
      distanceKm:
          (json['distanceKm'] as num?)?.toDouble() ??
          (json['distance_km'] as num?)?.toDouble() ??
          0.0,
      caloriesBurned:
          (json['caloriesBurned'] as num?)?.toDouble() ??
          (json['calories_burned'] as num?)?.toDouble() ??
          0.0,
      avgHeartRate:
          (json['avgHeartRate'] as num?)?.toInt() ??
          (json['avg_heart_rate'] as num?)?.toInt(),
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'] as String)
          : (json['start_time'] != null
                ? DateTime.parse(json['start_time'] as String)
                : DateTime.now()),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : (json['end_time'] != null
                ? DateTime.parse(json['end_time'] as String)
                : null),
      metValue:
          (json['metValue'] as num?)?.toDouble() ??
          (json['met_value'] as num?)?.toDouble() ??
          8.0,
      isCompleted:
          json['isCompleted'] as bool? ?? json['is_completed'] as bool? ?? true,
      route: RoutePoint.listFromJson(json['route']),
      pausedSeconds: (json['pausedSeconds'] as num?)?.toInt() ?? 0,
      caloriesKnown: json['caloriesKnown'] as bool? ?? true,
      caloriesEstimated: json['caloriesEstimated'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'category': category,
      'durationSeconds': durationSeconds,
      'distanceKm': distanceKm,
      'caloriesBurned': caloriesBurned,
      'avgHeartRate': avgHeartRate,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'metValue': metValue,
      'isCompleted': isCompleted,
      if (route.isNotEmpty) 'route': RoutePoint.listToJson(route),
      if (pausedSeconds > 0) 'pausedSeconds': pausedSeconds,
      if (!caloriesKnown) 'caloriesKnown': false,
      if (!caloriesEstimated) 'caloriesEstimated': false,
    };
  }

  CardioSession copyWith({
    String? id,
    String? exerciseId,
    String? exerciseName,
    String? category,
    int? durationSeconds,
    double? distanceKm,
    double? caloriesBurned,
    int? avgHeartRate,
    DateTime? startTime,
    DateTime? endTime,
    double? metValue,
    bool? isCompleted,
    List<RoutePoint>? route,
    int? pausedSeconds,
    bool? caloriesKnown,
    bool? caloriesEstimated,
  }) {
    return CardioSession(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      category: category ?? this.category,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      distanceKm: distanceKm ?? this.distanceKm,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      avgHeartRate: avgHeartRate ?? this.avgHeartRate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      metValue: metValue ?? this.metValue,
      isCompleted: isCompleted ?? this.isCompleted,
      route: route ?? this.route,
      pausedSeconds: pausedSeconds ?? this.pausedSeconds,
      caloriesKnown: caloriesKnown ?? this.caloriesKnown,
      caloriesEstimated: caloriesEstimated ?? this.caloriesEstimated,
    );
  }
}
