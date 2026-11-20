/// Health data source indicating where a health or sleep metric originated.
enum HealthDataSource {
  manual('Manually logged'),
  appleHealth('From Apple Health'),
  healthConnect('From Health Connect'),
  wearable('From Connected Wearable'),
  showcase('Showcase Mode');

  final String label;
  const HealthDataSource(this.label);
}

/// Subjective rating of sleep quality.
enum SleepQuality {
  poor('Poor', '😴'),
  fair('Fair', '😐'),
  good('Good', '😊'),
  excellent('Excellent', '🔥');

  final String label;
  final String emoji;
  const SleepQuality(this.label, this.emoji);

  static SleepQuality fromString(String? val) {
    if (val == null) return SleepQuality.good;
    return SleepQuality.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase() || e.label.toLowerCase() == val.toLowerCase(),
      orElse: () => SleepQuality.good,
    );
  }
}

/// Consistency rating of sleep schedule (bedtime & wake-time regularity).
enum SleepConsistency {
  optimal('Optimal'),
  good('Good'),
  fair('Fair'),
  irregular('Irregular');

  final String label;
  const SleepConsistency(this.label);

  static SleepConsistency fromString(String? val) {
    if (val == null) return SleepConsistency.good;
    return SleepConsistency.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase() || e.label.toLowerCase() == val.toLowerCase(),
      orElse: () => SleepConsistency.good,
    );
  }
}

/// Domain model representing a single night's sleep record.
class SleepRecord {
  final String id;
  final String userId;
  final DateTime date;
  final DateTime bedtime;
  final DateTime wakeTime;
  final int durationMinutes;
  final SleepQuality quality;
  final SleepConsistency consistency;
  final HealthDataSource source;
  final double? restingHeartRate; // in bpm
  final double? hrv; // in ms
  final String? notes;

  const SleepRecord({
    required this.id,
    this.userId = 'usr_local',
    required this.date,
    required this.bedtime,
    required this.wakeTime,
    required this.durationMinutes,
    this.quality = SleepQuality.good,
    this.consistency = SleepConsistency.good,
    this.source = HealthDataSource.manual,
    this.restingHeartRate,
    this.hrv,
    this.notes,
  });

  /// Factory helper that calculates durationMinutes automatically from bedtime and wakeTime.
  factory SleepRecord.fromTimes({
    required String id,
    String userId = 'usr_local',
    required DateTime date,
    required DateTime bedtime,
    required DateTime wakeTime,
    SleepQuality quality = SleepQuality.good,
    SleepConsistency consistency = SleepConsistency.good,
    HealthDataSource source = HealthDataSource.manual,
    double? restingHeartRate,
    double? hrv,
    String? notes,
  }) {
    var diff = wakeTime.difference(bedtime).inMinutes;
    if (diff < 0) {
      // Overnight sleep crossing midnight
      diff += 24 * 60;
    }
    return SleepRecord(
      id: id,
      userId: userId,
      date: date,
      bedtime: bedtime,
      wakeTime: wakeTime,
      durationMinutes: diff,
      quality: quality,
      consistency: consistency,
      source: source,
      restingHeartRate: restingHeartRate,
      hrv: hrv,
      notes: notes,
    );
  }

  /// Formatted duration string e.g. "7h 42m"
  String get formattedDuration {
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }

  /// Sleep duration in fractional hours (e.g. 7.7)
  double get durationHours => durationMinutes / 60.0;

  /// Formatted bedtime string e.g. "11:18 PM"
  String get formattedBedtime {
    final hour = bedtime.hour;
    final minute = bedtime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }

  /// Formatted wake-up time string e.g. "7:00 AM"
  String get formattedWakeTime {
    final hour = wakeTime.hour;
    final minute = wakeTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }

  /// Human-readable day label e.g. "Mon", "Tue"
  String get dayLabel {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'date': date.toIso8601String(),
        'bedtime': bedtime.toIso8601String(),
        'wakeTime': wakeTime.toIso8601String(),
        'durationMinutes': durationMinutes,
        'quality': quality.name,
        'consistency': consistency.name,
        'source': source.name,
        'restingHeartRate': restingHeartRate,
        'hrv': hrv,
        'notes': notes,
      };

  factory SleepRecord.fromJson(Map<String, dynamic> json) {
    return SleepRecord(
      id: json['id'] as String? ?? 'sleep_${DateTime.now().millisecondsSinceEpoch}',
      userId: json['userId'] as String? ?? 'usr_local',
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : DateTime.now(),
      bedtime: json['bedtime'] != null ? DateTime.parse(json['bedtime'] as String) : DateTime.now().subtract(const Duration(hours: 8)),
      wakeTime: json['wakeTime'] != null ? DateTime.parse(json['wakeTime'] as String) : DateTime.now(),
      durationMinutes: json['durationMinutes'] as int? ?? 462,
      quality: SleepQuality.fromString(json['quality'] as String?),
      consistency: SleepConsistency.fromString(json['consistency'] as String?),
      source: HealthDataSource.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => HealthDataSource.manual,
      ),
      restingHeartRate: (json['restingHeartRate'] as num?)?.toDouble(),
      hrv: (json['hrv'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
    );
  }

  SleepRecord copyWith({
    String? id,
    String? userId,
    DateTime? date,
    DateTime? bedtime,
    DateTime? wakeTime,
    int? durationMinutes,
    SleepQuality? quality,
    SleepConsistency? consistency,
    HealthDataSource? source,
    double? restingHeartRate,
    double? hrv,
    String? notes,
  }) {
    return SleepRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      bedtime: bedtime ?? this.bedtime,
      wakeTime: wakeTime ?? this.wakeTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      quality: quality ?? this.quality,
      consistency: consistency ?? this.consistency,
      source: source ?? this.source,
      restingHeartRate: restingHeartRate ?? this.restingHeartRate,
      hrv: hrv ?? this.hrv,
      notes: notes ?? this.notes,
    );
  }
}
