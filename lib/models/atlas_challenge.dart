/// What a challenge measures. Every metric is something Atlas actually records.
enum ChallengeMetric {
  /// Workouts logged in the window.
  workouts('Workouts', 'workouts'),

  /// Workout minutes logged in the window.
  minutes('Workout minutes', 'min'),

  /// Total weight lifted in the window.
  volumeKg('Volume lifted', 'kg'),

  /// Days on which the step total reached the daily goal. Needs step readings
  /// from this phone; without them the challenge shows "unavailable".
  stepDays('Days at step goal', 'days');

  final String label;
  final String unit;
  const ChallengeMetric(this.label, this.unit);

  bool get needsSteps => this == ChallengeMetric.stepDays;
}

enum AtlasChallengeStatus {
  /// Waiting for you to accept or decline.
  invited,

  /// Running: progress is counted from the start date.
  active,

  /// The goal was reached.
  completed,

  /// You declined the invitation.
  declined,

  /// The time ran out, or the opponent reached the goal first.
  expired,
}

/// A challenge you take on, alone or against a sample athlete.
///
/// Your progress is never stored: it is counted from your own workout history
/// and step readings whenever it is shown. A sample opponent's progress is
/// scripted from their sample stats and is always labelled as sample. There are
/// no challenges between real people yet (that needs a server feature).
class AtlasChallenge {
  final String id;
  final String title;
  final ChallengeMetric metric;

  /// The goal: workouts, minutes, kg, or days at the step goal.
  final double target;

  /// Daily step goal, for [ChallengeMetric.stepDays] only.
  final int stepGoal;

  final int durationDays;
  final DateTime createdAt;

  /// Set when the challenge starts (on accept, or at creation for your own).
  final DateTime? startDate;
  final DateTime? endDate;

  final AtlasChallengeStatus status;

  /// Key of the sample athlete this is against, or null for a self-challenge.
  final String? opponentKey;

  /// True when the sample athlete invited you (so it starts as an invitation).
  final bool incoming;

  /// An invitation lapses at this time if it is not answered.
  final DateTime? inviteExpiresAt;

  final DateTime? completedAt;

  /// Why it ended without being completed, shown to the user.
  final String? endNote;

  final int xpReward;
  final bool rewardPaid;

  const AtlasChallenge({
    required this.id,
    required this.title,
    required this.metric,
    required this.target,
    required this.durationDays,
    required this.createdAt,
    required this.status,
    this.stepGoal = 10000,
    this.startDate,
    this.endDate,
    this.opponentKey,
    this.incoming = false,
    this.inviteExpiresAt,
    this.completedAt,
    this.endNote,
    this.xpReward = 0,
    this.rewardPaid = false,
  });

  bool get isSample => opponentKey != null;
  bool get isOpen =>
      status == AtlasChallengeStatus.invited ||
      status == AtlasChallengeStatus.active;

  /// "4 workouts", "150 min", "20,000 kg", "7 days at 10,000 steps".
  String get objective {
    String n(double v) {
      final s = v.round().toString();
      final b = StringBuffer();
      for (var i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
        b.write(s[i]);
      }
      return b.toString();
    }

    switch (metric) {
      case ChallengeMetric.workouts:
        return '${n(target)} workouts';
      case ChallengeMetric.minutes:
        return '${n(target)} workout minutes';
      case ChallengeMetric.volumeKg:
        return '${n(target)} kg lifted';
      case ChallengeMetric.stepDays:
        return '${n(target)} days of ${n(stepGoal.toDouble())} steps';
    }
  }

  AtlasChallenge copyWith({
    AtlasChallengeStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? completedAt,
    String? endNote,
    bool? rewardPaid,
  }) {
    return AtlasChallenge(
      id: id,
      title: title,
      metric: metric,
      target: target,
      durationDays: durationDays,
      createdAt: createdAt,
      status: status ?? this.status,
      stepGoal: stepGoal,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      opponentKey: opponentKey,
      incoming: incoming,
      inviteExpiresAt: inviteExpiresAt,
      completedAt: completedAt ?? this.completedAt,
      endNote: endNote ?? this.endNote,
      xpReward: xpReward,
      rewardPaid: rewardPaid ?? this.rewardPaid,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'metric': metric.name,
    'target': target,
    'step_goal': stepGoal,
    'duration_days': durationDays,
    'created_at': createdAt.toIso8601String(),
    'start_date': startDate?.toIso8601String(),
    'end_date': endDate?.toIso8601String(),
    'status': status.name,
    'opponent_key': opponentKey,
    'incoming': incoming,
    'invite_expires_at': inviteExpiresAt?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'end_note': endNote,
    'xp_reward': xpReward,
    'reward_paid': rewardPaid,
  };

  static DateTime? _d(Object? v) => v is String ? DateTime.tryParse(v) : null;

  factory AtlasChallenge.fromJson(Map<String, dynamic> j) {
    return AtlasChallenge(
      id: j['id'] as String? ?? '',
      title: j['title'] as String? ?? 'Challenge',
      metric: ChallengeMetric.values.firstWhere(
        (m) => m.name == j['metric'],
        orElse: () => ChallengeMetric.workouts,
      ),
      target: (j['target'] as num?)?.toDouble() ?? 1,
      stepGoal: (j['step_goal'] as num?)?.toInt() ?? 10000,
      durationDays: (j['duration_days'] as num?)?.toInt() ?? 7,
      createdAt: _d(j['created_at']) ?? DateTime.now(),
      startDate: _d(j['start_date']),
      endDate: _d(j['end_date']),
      status: AtlasChallengeStatus.values.firstWhere(
        (s) => s.name == j['status'],
        orElse: () => AtlasChallengeStatus.expired,
      ),
      opponentKey: j['opponent_key'] as String?,
      incoming: j['incoming'] as bool? ?? false,
      inviteExpiresAt: _d(j['invite_expires_at']),
      completedAt: _d(j['completed_at']),
      endNote: j['end_note'] as String?,
      xpReward: (j['xp_reward'] as num?)?.toInt() ?? 0,
      rewardPaid: j['reward_paid'] as bool? ?? false,
    );
  }
}

/// A ready-made challenge the user can pick.
class ChallengePreset {
  final String id;
  final String title;
  final ChallengeMetric metric;
  final double target;
  final int durationDays;
  final int stepGoal;
  final int xpReward;
  const ChallengePreset(
    this.id,
    this.title,
    this.metric,
    this.target,
    this.durationDays, {
    this.stepGoal = 10000,
    this.xpReward = 150,
  });

  static const presets = <ChallengePreset>[
    ChallengePreset(
      'w4',
      '4 workouts this week',
      ChallengeMetric.workouts,
      4,
      7,
    ),
    ChallengePreset(
      'm150',
      '150 workout minutes',
      ChallengeMetric.minutes,
      150,
      7,
    ),
    ChallengePreset(
      'v20k',
      '20,000 kg lifted',
      ChallengeMetric.volumeKg,
      20000,
      7,
    ),
    ChallengePreset(
      's7',
      '10,000 steps a day for 7 days',
      ChallengeMetric.stepDays,
      7,
      7,
      xpReward: 200,
    ),
    ChallengePreset(
      'w12',
      '12 workouts in 30 days',
      ChallengeMetric.workouts,
      12,
      30,
      xpReward: 300,
    ),
  ];
}
