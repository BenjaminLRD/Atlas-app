import 'dart:convert';
import '../../data/local_storage.dart';
import 'rank_ladder.dart';

/// One milestone level as recorded by the server.
class RankedClaim {
  final String milestoneId;
  final int level;
  final double? value;

  /// approved | needs_video | pending_review | rejected
  final String status;
  final String? reviewerNote;

  const RankedClaim({
    required this.milestoneId,
    required this.level,
    required this.status,
    this.value,
    this.reviewerNote,
  });

  bool get isApproved => status == 'approved';
  bool get needsVideo => status == 'needs_video' || status == 'rejected';
  bool get isPendingReview => status == 'pending_review';

  factory RankedClaim.fromJson(Map<String, dynamic> json) => RankedClaim(
    milestoneId: (json['milestone_id'] ?? json['milestoneId']) as String,
    level: (json['level'] as num).toInt(),
    value: (json['value'] as num?)?.toDouble(),
    status: json['status'] as String? ?? 'approved',
    reviewerNote: (json['reviewer_note'] ?? json['reviewerNote']) as String?,
  );

  Map<String, dynamic> toJson() => {
    'milestone_id': milestoneId,
    'level': level,
    'value': value,
    'status': status,
    'reviewer_note': reviewerNote,
  };
}

/// The latest rank, as last confirmed by the server (or estimated on the
/// device when there is no backend).
class RankedSnapshot {
  final int points;
  final Map<String, int> statLevels;
  final List<RankedClaim> claims;

  /// True when [points] came from the server's approved milestones.
  final bool verified;
  final DateTime? updatedAt;

  const RankedSnapshot({
    this.points = 0,
    this.statLevels = const {},
    this.claims = const [],
    this.verified = false,
    this.updatedAt,
  });

  RankPosition get position => RankLadder.fromPoints(points);

  /// The server's status for [milestoneId] at [level], if any.
  RankedClaim? claimFor(String milestoneId, int level) {
    for (final c in claims) {
      if (c.milestoneId == milestoneId && c.level == level) return c;
    }
    return null;
  }

  factory RankedSnapshot.fromJson(Map<String, dynamic> json) => RankedSnapshot(
    points: (json['points'] as num?)?.toInt() ?? 0,
    statLevels: {
      for (final e in (json['stat_levels'] as Map? ?? const {}).entries)
        e.key.toString(): (e.value as num).toInt(),
    },
    claims: (json['claims'] as List? ?? const [])
        .map((c) => RankedClaim.fromJson(Map<String, dynamic>.from(c as Map)))
        .toList(),
    verified: json['verified'] as bool? ?? true,
    updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
  );

  Map<String, dynamic> toJson() => {
    'points': points,
    'stat_levels': statLevels,
    'claims': claims.map((c) => c.toJson()).toList(),
    'verified': verified,
    'updated_at': updatedAt?.toIso8601String(),
  };
}

/// Local cache of the user's rank, readable synchronously by any screen.
class RankedProgressStore {
  RankedProgressStore._();

  static const String storageKey = 'ranked_snapshot_v1';

  static RankedSnapshot get current {
    final raw = LocalStorage.getString(storageKey);
    if (raw == null || raw.isEmpty) return const RankedSnapshot();
    try {
      return RankedSnapshot.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const RankedSnapshot();
    }
  }

  static RankPosition get position => current.position;

  static Future<void> save(RankedSnapshot snapshot) =>
      LocalStorage.setString(storageKey, jsonEncode(snapshot.toJson()));
}
