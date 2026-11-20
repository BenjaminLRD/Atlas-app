/// Categories of major athlete milestones.
enum MilestoneCategory {
  personalRecord('PERSONAL_RECORD'),
  weightMilestone('WEIGHT_MILESTONE'),
  streakMilestone('STREAK_MILESTONE'),
  transformationCheckpoint('TRANSFORMATION_CHECKPOINT'),
  coachingBreakthrough('COACHING_BREAKTHROUGH');

  final String code;
  const MilestoneCategory(this.code);
}

/// A permanent milestone marking a major athletic achievement or breakthrough.
class TimelineMilestone {
  final String id;
  final MilestoneCategory category;
  final String title;
  final String description;
  final double? metricValue;
  final String? unit;
  final DateTime date;
  final String? photoUrl;

  const TimelineMilestone({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    this.metricValue,
    this.unit,
    required this.date,
    this.photoUrl,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category.code,
    'title': title,
    'description': description,
    if (metricValue != null) 'metric_value': metricValue,
    if (unit != null) 'unit': unit,
    'date': date.toIso8601String(),
    if (photoUrl != null) 'photo_url': photoUrl,
  };
}

/// Athlete Journey Timeline Service.
/// Manages permanent chronological records of lifetime PRs, physical transformations, and habit streaks.
class AthleteJourneyTimeline {
  static AthleteJourneyTimeline? _instance;
  static AthleteJourneyTimeline get instance =>
      _instance ??= AthleteJourneyTimeline();

  static void resetInstance() {
    _instance = null;
  }

  final List<TimelineMilestone> _milestones = [];

  AthleteJourneyTimeline() {
    _seedFoundationalMilestones();
  }

  List<TimelineMilestone> get milestones =>
      List.unmodifiable(_milestones..sort((a, b) => b.date.compareTo(a.date)));

  void _seedFoundationalMilestones() {
    final now = DateTime.now();
    _milestones.addAll([
      TimelineMilestone(
        id: 'ms_pr_squat_140',
        category: MilestoneCategory.personalRecord,
        title: 'Squat 140kg (3 Plates Milestone)',
        description: 'Completed 140kg x 3 reps with clean depth and zero knee valgus.',
        metricValue: 140.0,
        unit: 'kg',
        date: now.subtract(const Duration(days: 14)),
      ),
      TimelineMilestone(
        id: 'ms_streak_30',
        category: MilestoneCategory.streakMilestone,
        title: '30-Day Training & Nutrition Consistency',
        description: 'Hit daily protein and completed 18 programmed sessions without missing a split.',
        metricValue: 30.0,
        unit: 'days',
        date: now.subtract(const Duration(days: 3)),
      ),
    ]);
  }

  /// Records a new athlete milestone.
  TimelineMilestone recordMilestone({
    required MilestoneCategory category,
    required String title,
    required String description,
    double? metricValue,
    String? unit,
    DateTime? date,
    String? photoUrl,
  }) {
    final milestone = TimelineMilestone(
      id: 'ms_${DateTime.now().millisecondsSinceEpoch}',
      category: category,
      title: title,
      description: description,
      metricValue: metricValue,
      unit: unit,
      date: date ?? DateTime.now(),
      photoUrl: photoUrl,
    );

    _milestones.add(milestone);
    return milestone;
  }
}
