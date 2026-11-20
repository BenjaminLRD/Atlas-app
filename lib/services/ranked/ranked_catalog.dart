import 'dart:convert';
import 'package:flutter/services.dart';

/// Path of the shared milestone catalog. The same file is read by the
/// `ranked-sync` Edge Function, so both sides judge milestones identically.
const String rankedCatalogAsset =
    'supabase/functions/_shared/ranked_milestones.json';

/// How a milestone's performance is measured.
enum MilestoneMeasure {
  /// Estimated one-rep max divided by body weight (higher is better).
  bodyweightMultiple,

  /// Most reps in one set (higher is better).
  maxReps,

  /// Fastest 5 km in minutes (lower is better).
  time5kMinutes,

  /// Workouts completed in the consistency window (higher is better).
  workoutsInWindow,
}

class RankedMilestone {
  final String id;
  final String title;
  final MilestoneMeasure measure;
  final List<String> exercisePatterns;
  final List<String> excludePatterns;
  final bool requiresVideo;
  final List<double> male;
  final List<double> female;

  const RankedMilestone({
    required this.id,
    required this.title,
    required this.measure,
    this.exercisePatterns = const [],
    this.excludePatterns = const [],
    this.requiresVideo = false,
    required this.male,
    required this.female,
  });

  bool get lowerIsBetter => measure == MilestoneMeasure.time5kMinutes;

  /// Targets for levels 1–5. The female table applies when the profile's
  /// gender starts with "f"; otherwise the male table.
  List<double> targetsFor(String gender) =>
      gender.trim().toLowerCase().startsWith('f') ? female : male;

  /// Highest level (0–5) that [value] reaches.
  int levelFor(double value, String gender) {
    final targets = targetsFor(gender);
    var level = 0;
    for (var i = 0; i < targets.length; i++) {
      final reached = lowerIsBetter ? value <= targets[i] : value >= targets[i];
      if (reached) level = i + 1;
    }
    return level;
  }

  /// Whether an exercise name counts for this milestone.
  bool matchesExercise(String name) {
    final n = name.toLowerCase();
    if (excludePatterns.any(n.contains)) return false;
    return exercisePatterns.any(n.contains);
  }

  static MilestoneMeasure _measure(String raw) {
    switch (raw) {
      case 'bodyweight_multiple':
        return MilestoneMeasure.bodyweightMultiple;
      case 'max_reps':
        return MilestoneMeasure.maxReps;
      case 'time_5k_minutes':
        return MilestoneMeasure.time5kMinutes;
      default:
        return MilestoneMeasure.workoutsInWindow;
    }
  }

  factory RankedMilestone.fromJson(Map<String, dynamic> json) {
    List<double> nums(Object? v) =>
        (v as List? ?? const []).map((e) => (e as num).toDouble()).toList();
    List<String> strs(Object? v) =>
        (v as List? ?? const []).map((e) => e.toString()).toList();
    return RankedMilestone(
      id: json['id'] as String,
      title: json['title'] as String,
      measure: _measure(json['measure'] as String),
      exercisePatterns: strs(json['exercisePatterns']),
      excludePatterns: strs(json['excludePatterns']),
      requiresVideo: json['requiresVideo'] as bool? ?? false,
      male: nums(json['male']),
      female: nums(json['female']),
    );
  }
}

class RankedStat {
  final String id;
  final String name;
  final String description;

  /// `best`: the stat's level is its best milestone level.
  /// `second_best`: the level must be reached on two milestones.
  final String rule;
  final List<RankedMilestone> milestones;

  const RankedStat({
    required this.id,
    required this.name,
    required this.description,
    required this.rule,
    required this.milestones,
  });

  /// Stat level (0–5) from the levels reached per milestone.
  int levelFrom(Map<String, int> milestoneLevels) {
    final levels = milestones.map((m) => milestoneLevels[m.id] ?? 0).toList()
      ..sort((a, b) => b.compareTo(a));
    if (levels.isEmpty) return 0;
    if (rule == 'second_best') return levels.length > 1 ? levels[1] : 0;
    return levels.first;
  }

  factory RankedStat.fromJson(Map<String, dynamic> json) => RankedStat(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    rule: json['rule'] as String? ?? 'best',
    milestones: (json['milestones'] as List)
        .map((m) => RankedMilestone.fromJson(Map<String, dynamic>.from(m)))
        .toList(),
  );
}

/// The Ranked milestone catalog.
class RankedCatalog {
  final List<RankedStat> stats;
  final int levelsPerStat;
  final int videoRequiredFromLevel;
  final int consistencyWindowDays;

  const RankedCatalog({
    required this.stats,
    required this.levelsPerStat,
    required this.videoRequiredFromLevel,
    required this.consistencyWindowDays,
  });

  int get maxPoints => stats.length * levelsPerStat;

  Iterable<RankedMilestone> get milestones => stats.expand((s) => s.milestones);

  /// True when reaching [level] on [milestone] needs video proof.
  bool needsVideo(RankedMilestone milestone, int level) =>
      milestone.requiresVideo && level >= videoRequiredFromLevel;

  factory RankedCatalog.fromJson(Map<String, dynamic> json) => RankedCatalog(
    stats: (json['stats'] as List)
        .map((s) => RankedStat.fromJson(Map<String, dynamic>.from(s)))
        .toList(),
    levelsPerStat: json['levelsPerStat'] as int? ?? 5,
    videoRequiredFromLevel: json['videoRequiredFromLevel'] as int? ?? 4,
    consistencyWindowDays: json['consistencyWindowDays'] as int? ?? 28,
  );

  static RankedCatalog? _cached;

  /// Loads the catalog from the bundled asset (cached).
  static Future<RankedCatalog> load({AssetBundle? bundle}) async {
    final cached = _cached;
    if (cached != null) return cached;
    final raw = await (bundle ?? rootBundle).loadString(rankedCatalogAsset);
    return _cached = RankedCatalog.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }
}
