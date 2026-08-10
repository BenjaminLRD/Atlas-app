/// Data model representing a Personal Record (PR) achievement.
class PersonalRecord {
  final String id;
  final String? exerciseId;
  final String exerciseName;
  final String muscleGroup;
  final String recordType;
  final double value;
  final double previousValue;
  final double improvementPercentage;
  final DateTime? achievedDate;
  final String? workoutId;
  final bool isNew;

  const PersonalRecord({
    required this.id,
    this.exerciseId,
    required this.exerciseName,
    this.muscleGroup = 'General',
    required this.recordType,
    required this.value,
    this.previousValue = 0.0,
    this.improvementPercentage = 0.0,
    this.achievedDate,
    this.workoutId,
    this.isNew = false,
  });

  /// Formatted value string e.g. "100 kg", "12,500 kg", "150 reps"
  String get formattedValue {
    if (recordType.toLowerCase().contains('rep')) {
      return '${value.toInt()} reps';
    }
    if (value >= 1000) {
      final formatted = value.toStringAsFixed(0).replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
      return '$formatted kg';
    }
    return '${value % 1 == 0 ? value.toInt() : value.toStringAsFixed(1)} kg';
  }

  factory PersonalRecord.fromJson(Map<String, dynamic> json) {
    return PersonalRecord(
      id: json['id'] as String? ?? '',
      exerciseId: json['exerciseId'] as String?,
      exerciseName: json['exerciseName'] as String? ?? 'Exercise',
      muscleGroup: json['muscleGroup'] as String? ?? 'General',
      recordType: json['recordType'] as String? ?? 'Heaviest Lift',
      value: (json['value'] as num?)?.toDouble() ?? 0.0,
      previousValue: (json['previousValue'] as num?)?.toDouble() ?? 0.0,
      improvementPercentage:
          (json['improvementPercentage'] as num?)?.toDouble() ?? 0.0,
      achievedDate: json['achievedDate'] != null
          ? DateTime.tryParse(json['achievedDate'].toString())
          : (json['dateAchieved'] != null
              ? DateTime.tryParse(json['dateAchieved'].toString())
              : null),
      workoutId: json['workoutId'] as String?,
      isNew: json['isNew'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'muscleGroup': muscleGroup,
        'recordType': recordType,
        'value': value,
        'previousValue': previousValue,
        'improvementPercentage': improvementPercentage,
        'achievedDate': achievedDate?.toIso8601String(),
        'workoutId': workoutId,
        'isNew': isNew,
      };

  PersonalRecord copyWith({
    String? id,
    String? exerciseId,
    String? exerciseName,
    String? muscleGroup,
    String? recordType,
    double? value,
    double? previousValue,
    double? improvementPercentage,
    DateTime? achievedDate,
    String? workoutId,
    bool? isNew,
  }) {
    return PersonalRecord(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      recordType: recordType ?? this.recordType,
      value: value ?? this.value,
      previousValue: previousValue ?? this.previousValue,
      improvementPercentage: improvementPercentage ?? this.improvementPercentage,
      achievedDate: achievedDate ?? this.achievedDate,
      workoutId: workoutId ?? this.workoutId,
      isNew: isNew ?? this.isNew,
    );
  }
}
